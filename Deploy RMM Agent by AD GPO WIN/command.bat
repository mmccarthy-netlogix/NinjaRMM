<#
Datto RMM agent deploy by immediate scheduled task GPP - release v2.25.20
Designed and written by Jon North, Datto, September 2019

Major update 2.25.8 written March-October 2020
Minor update 2.25.15 written January-February 2021
Minor update 2.25.16 written March 2021
Minor update 2.25.20 written April 2021

Firstly create the install script and download the Agent installer, and copy them both across to a subfolder in SYSVOL
Then unzip, modify and create the immediate scheduled task GPP, and link at either domain root or specific OUs
Optional OU targeting, with or without inheritance, allows for granular control of both deployment targeting and the sites the Agents associate to via generated CSV file
Force SYSVOL replication to ensure multi-DC environments run the GPO on next policy refresh
Finally, optionally run immediate and silent GPUpdate via Specops GPUpdate application

The script that runs on GPUpdate will determine if the Datto RMM Agent is already installed and instantly exit if so
Otherwise it'll remove all dregs of any previous installation then install, with site override parameter if configured
Finally it will launch the Agent Browser (system tray icon) as every logged-in user, as applicable, via self-deleting Windows scheduled tasks

Specops GPUpdate used and redistributed by agreement
More information at https://specopssoft.com/product/specops-gpupdate/
#>

Function Write-ExitMessage ($ExitMessage) {
    $host.ui.WriteErrorLine("$ExitMessage`r`nExit message: $_`r`n$($Error[0].Exception.InnerException.InnerException.Message)")
    exit 1}

function Remove-DRMMGPO {
    # Check if GPO exists from previous run and delete if so, in order to delete all previous links from anywhere in the domain
    # This may appear over-engineered but the "impossible" situation of multiple GPOs with the same name can actually occur
    Write-Output "Checking if GPO already exists..."
    try {$GPOs=Get-GPO -All | Where-Object {$_.DisplayName -eq $GPOName} }
    catch {Write-ExitMessage "Unable to read GPOs from $DomainFQDN. If the`r`n$UserContext user does not have privileges to do this, rerun`r`nusing site-level credentials of a user that does."}
    if ($GPOs) {
        Write-Output "GPO already exists, attempting to remove..."
        foreach ($GPO in $GPOs) {
            Write-Output "Removing GPO with ID $($GPO.id)..."
            try {Remove-GPO -Guid $GPO.id}
            catch {Write-ExitMessage "Unable to remove GPO ID $($GPO.id). If the`r`n$UserContext user does not have privileges to create and modify`r`nGPOs on $DomainFQDN, rerun using site-level credentials of a user`r`nthat does."}
            Write-Output "Previous GPO successfully removed"
        }
    } else {Write-Output "GPO does not exist, not attempting to remove"}
}

# This will ensure all try/catch logic blocks create terminating errors so the catch will always trigger if an error occurs
$ErrorActionPreference="Stop"

# First of all, check we are in a domain, instant fail if not
If (-not (Get-WmiObject win32_computersystem).partofdomain) {$host.ui.WriteErrorLine("This computer is not in a domain. Cannot continue") ; exit 1}

# Next check we are running on a device with a UI (ie not Server Core), instant fail if not
try {$NullVar=New-Object -ComObject shell.application}
catch {Write-ExitMessage "This device is unable to launch shell applications.`r`nPlease re-run on your domain's Management Server."}

# Write the user context and variable values to StdOut for verification
$UserContext=([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name
Write-Output "Variable values: UseOUTargeting: $env:UseOUTargeting; ImmediateGPUpdate: $Env:ImmediateGPUpdate; RemoveGPO: $env:RemoveGPO; RecreateCSV: $env:RecreateCSV"
Write-Output "Current user context is $UserContext"

# Check this machine has GPMC installed and is accessible by the user context, instant fail if not
try {Import-Module GroupPolicy}
catch [System.IO.FileNotFoundException] {Write-ExitMessage "GroupPolicy Powershell module not found. You need to install the GPMC or`r`nRSAT GPMC feature on $env:COMPUTERNAME before you can run this component."}
catch {Write-ExitMessage "GroupPolicy Powershell module import failed. If the $UserContext`r`nuser does not have privileges to import the GroupPolicy Powershell module`r`non $env:COMPUTERNAME, rerun using site-level credentials of a user that does."}

# Get target domain/DC details and output for validation
$DomainFQDN=(Get-WmiObject win32_computersystem).Domain
try {$TargetIP=[System.Net.Dns]::Resolve($DomainFQDN).AddressList[0].IPAddressToString}
catch {Write-ExitMessage "Unable to resolve domain name $DomainFQDN.`r`nPlease check your DNS configuration and retry."}
try {$TargetDC=[System.Net.Dns]::GetHostByAddress($TargetIP).HostName}
catch {Write-ExitMessage "Unable to reverse lookup $TargetIP to validate hostname.`r`nPlease check your DNS configuration and retry."}
Write-Output "Domain FQDN: $DomainFQDN`r`nTarget Domain Controller: $TargetDC"

$GPOName="Datto RMM Agent install by immediate scheduled task"

# Set install folder variable
$InstallFolder="\\$DomainFQDN\SYSVOL\$DomainFQDN\Policies\DattoRMMAgentDeploy"
$TargetDCFolder="\\$TargetDC\SYSVOL\$DomainFQDN\Policies\DattoRMMAgentDeploy"
Write-Output "FQDN install replication folder: $InstallFolder"
Write-Output "Direct target DC folder: $TargetDCFolder`r`n`r`n"

# Check install folder exists and create if not
Write-Output "Checking for installation folder`r`n$InstallFolder..."
If (-not (Test-Path "$InstallFolder")) {
    Write-Output "Installation folder not found. Attempting to create..."
    try {New-Item -ItemType Directory $InstallFolder | Out-Null}
    catch {Write-ExitMessage "$InstallFolder folder creation failed.`r`nEnsure the $UserContext user has write privileges to`r`n\\$TargetDC\SYSVOL\$DomainFQDN\Policies"}
    Write-Output "Installation folder`r`n$InstallFolder created`r`n`r`n"
} else {Write-Output "Installation folder confirmed`r`n`r`n"}

# Check if RemoveGPO is set true and if so, remove the GPO and InstallFolder and force SYSVOL replication
if ($env:RemoveGPO -eq "true") {
    Write-Output "Removing GPO..."
    Remove-DRMMGPO
    Write-Output "Removing $InstallFolder and contents..."
    try {Remove-Item -Path $InstallFolder -Recurse -Force}
    catch {Write-ExitMessage "Unable to remove $InstallFolder.`r`nEnsure the $UserContext user has write access to it."}
    # Force SYSVOL share replication for deleted folder
    Write-Output "Forcing SYSVOL replication..."
    repadmin /syncall /APeq
    exit
}

# Create the CSV file for OU DN's if it doesn't exist, or if RecreateCSV is set true, and UseOUTargeting is set true
if ($env:UseOUTargeting -eq "true") {
    $CSVFile="$TargetDCFolder\DattoRMMSiteIDs.csv"
    $CreateCSV=$false
    Write-Output "UseOUTargeting selected.`r`nChecking CSV file exists or if RecreateCSV set to true..."
    if (-not (Test-Path $CSVFile)) {Write-Output "CSV lookup file not found. Creating..." ; $CreateCSV=$true}
    if ($env:RecreateCSV -eq "true") {Write-Output "RecreateCSV set true. Recreating..." ; $CreateCSV=$true}
    if ($CreateCSV -eq $true) {
        try {Import-Module ActiveDirectory}
        catch [System.IO.FileNotFoundException] {Write-ExitMessage "ActiveDirectory Powershell module not found. You need to install the ADDS or`r`nRSAT ADDS feature on $env:COMPUTERNAME before you can generate the CSV file."}
        catch {Write-ExitMessage "ActiveDirectory Powershell module import failed. If the $UserContext`r`nuser does not have privileges to import the ActiveDirectory Powershell module`r`non $env:COMPUTERNAME, rerun using site-level credentials of a user that does."}
        try {$OUs=Get-ADOrganizationalUnit -Filter * -Properties CanonicalName | Select-Object -Property Name,DistinguishedName,CanonicalName}
        catch {Write-ExitMessage "Unable to perform OU lookup. Ensure the $UserContext user`r`nhas read access to the $DomainFQDN domain AD"}
        foreach ($OU in $OUs) {$OU | Add-Member -MemberType NoteProperty -Name "SiteID" -Value $env:CS_PROFILE_UID}
        try {$OUs | ConvertTo-Csv -NoTypeInformation -UseCulture | Out-File $CSVFile -Encoding utf8}
        catch {Write-ExitMessage "Unable to write CSV file $CSVFile.`r`nEnsure the $UserContext user has write access to`r`n$TargetDCFolder"}
        # Force SYSVOL share replication for Agent download, GPO script and GPO
        Write-Output "Forcing SYSVOL replication..."
        repadmin /syncall /APeq
        Write-Output "CSV lookup file created at`r`n$CSVFile`r`nand replicated to other DCs. Customise this file to remove any OUs out of`r`nscope, and update site IDs for any you want to change, then rerun this component.`r`nSee dat.to/rmmgpo for full instructions"
        exit
    } else {Write-Output "CSV file $CSVFile found. Checking dates...`r`n"
            # Check if CSV file has been modified since creation, exit if not
            $CSVFileProperties=Get-Item $CSVFile
            Write-Output "CSV file creation date/time is $($CSVFileProperties.CreationTime)"
            Write-Output "CSV file last modify date/time is $($CSVFileProperties.LastWriteTime)"
            if ($CSVFileProperties.CreationTime -eq $CSVFileProperties.LastWriteTime) {$host.ui.WriteErrorLine("CSV file has not been changed since it was written. If you made changes to`r`nthe file you need to ensure they're saved before you rerun this component.`r`nIf you have multiple DCs and your saved changes were overwritten you may`r`nneed to run DFS replication manually. If you want to deploy to all OUs and`r`nto this site only, rerun the component setting UseOUTargeting to False") ; exit 1}
            else {Write-Output "CSV file has been modified. Continuing...`r`n`r`n"}
        }
}

# Download Agent, customise/deploy the script and build/import/link the GPO

# Create agent installation switches for proxy details if applicable
Write-Output "Creating GPO script customised for $DomainFQDN..."
$Switches="/PXTP $env:CS_PROFILE_PROXY_TYPE"
IF (Test-Path env:CS_PROFILE_PROXY_PORT) {$Switches+=" /PXPT $env:CS_PROFILE_PROXY_PORT"}
IF (Test-Path env:CS_PROFILE_PROXY_HOST) {$Switches+=" /PXAD $env:CS_PROFILE_PROXY_HOST"}
IF (Test-Path env:CS_PROFILE_PROXY_USERNAME) {$Switches+=" /PXUS $env:CS_PROFILE_PROXY_USERNAME"}
IF (Test-Path env:CS_PROFILE_PROXY_PASSWORD) {$Switches+=" /PXPD $env:CS_PROFILE_PROXY_PASSWORD"}

# Create DRMMAgentDeploy.ps1 into installation folder
$GPOScript='# Install Datto RMM Agent via GPO with immediate scheduled task GPP v5.2
# Written by Jon North, Datto, March-June 2020

# Check Datto RMM Agent service exists and instantly exit if so
if (Get-Service cagservice) {exit}

# Remove any dregs from previous failed installs/uninstalls that will prevent the Agent installing
# Define architecture-based variables
$Arch=[intptr]::size*8
$WinReg="HKLM:\SOFTWARE"
if ($Arch -eq 32) {$PF=$env:ProgramFiles} else {$PF="$env:ProgramFiles (x86)" ; $WinReg+="\WOW6432Node"}

# Kill any existing processes and wait until they terminate
$Gui=(Get-Process -Name gui | Where-Object {$_.Path -Like "*CentraStage*"}).id
$AemAgent=(Get-Process -Name AEMAgent | Where-Object {$_.Path -Like "*CentraStage*"}).id
$Aria2c=(Get-Process -Name aria2c | Where-Object {$_.Path -Like "*CentraStage*"}).id

Stop-Process -Id $Gui -Force
Stop-Process -Id $AemAgent -Force
Stop-Process -Id $Aria2c -Force

Wait-Process -Id $Gui
Wait-Process -Id $AemAgent
Wait-Process -Id $Aria2c

# Uninstall if possible
if (Test-Path "$PF\CentraStage\uninst.exe") {Start-Process "$PF\CentraStage\uninst.exe" -Wait}

# Delete files and folders
Remove-Item "$PF\CentraStage" -Recurse -Force
Remove-Item "$env:windir\System32\config\systemprofile\AppData\Local\CentraStage" -Recurse -Force
Remove-Item "$env:windir\SysWOW64\System32\config\systemprofile\AppData\Local\Service" -Recurse -Force
Remove-Item "$env:windir\SysWOW64\config\systemprofile\AppData\Local\CentraStage" -Recurse -Force
Remove-Item "$env:windir\System32\config\systemprofile\AppData\Local\warp\packages\AEMAgent.exe" -Force
Remove-Item "$env:TEMP\.net\AEMAgent" -Recurse -Force
Remove-Item "$env:ProgramData\CentraStage" -Recurse -Force

$ProfilePath="$env:SystemDrive\Users"
$Usernames = Get-ChildItem -Path $ProfilePath
foreach ($Username in $Usernames) {Remove-Item "$ProfilePath\$Username\AppData\Local\CentraStage" -Recurse -Force}

# Delete registry keys and values
New-PSDrive -PSProvider Registry -Root HKEY_CLASSES_ROOT -Name HKCR
Remove-Item "HKCR:\cag" -Recurse -Force
Remove-Item "HKLM:\SOFTWARE\CentraStage" -Recurse -Force
Remove-ItemProperty "$WinReg\Microsoft\Windows\CurrentVersion\Run" -Name "CentraStage" -Force

'
if ($env:UseOUTargeting -eq "true") {
    $GPOScript+='# Look up site ID from the OU DN CSV lookup file, exit if not defined
$Dn=(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine")."Distinguished-Name"
$DNLookup=Import-Csv "'+$InstallFolder+'\DattoRMMSiteIDs.csv" -UseCulture
foreach ($Lookup in $DNLookup) {if ($Dn.Substring($Dn.Length -(($Lookup.DistinguishedName).length)) -eq $Lookup.DistinguishedName) {$SiteID=$Lookup.SiteID} } # Blank lines will simply not set SiteID
if (-not $SiteId) {exit 1}

# Validate site ID format from the CSV lookup file, exit if invalid
if ($SiteId -notmatch ''[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}'') {exit 1}

# Install the Agent, overriding the Site ID with the variable value from CSV lookup file. We use cmd.exe to suppress the prompt you get with Start-Process
cmd /c "'+$InstallFolder+'\DRMMSetup.exe" /prof $SiteID '+$Switches+'
'} else {$GPOScript+='# Install the Agent. We use cmd.exe to suppress the prompt you get with Start-Process
cmd /c "'+$InstallFolder+'\DRMMSetup.exe" '+$Switches+'
'}
$GPOScript+='
# Wait until CagService exists then kill gui.exe process running as System in the Datto RMM folder
do {Start-Sleep -Seconds 1} until (Get-Service CagService)
Get-Process -Name gui | Where-Object {$_.Path -Like "*CentraStage*"} | Stop-Process

# Determine if there are any logged-in users and if so, create scheduled task to launch gui.exe as them
if (query user) {
    $LoggedInUsers=(((query user) -replace ''>'', '''') -replace ''\s{2,}'', '','' | ConvertFrom-Csv).Username
    $TaskStartTime = (Get-Date).AddMinutes(3).ToString("HH:mm")
    $TaskEndTime = (Get-Date).AddMinutes(5).ToString("HH:mm")
    foreach ($LoggedInUser in $LoggedInUsers) {
        if ($LoggedInUser) {schtasks /create /sc hourly /tn "Start Datto RMM Agent Browser as $LoggedInUser" /tr `''$PF\Centrastage\gui.exe`'' /st $TaskStartTime /et $TaskEndTime /ru "$LoggedInUser" /f /z }
    }
}
Exit
'
try {Write-Output $GPOScript | Out-File "$InstallFolder\DRMMAgentDeploy.ps1" -Encoding ascii}
catch {Write-ExitMessage "Unable to write GPO script file. Ensure the $UserContext user has`r`nwrite permissions to`r`n$TargetDCFolder"}
Write-Output "$InstallFolder\DRMMAgentDeploy.ps1`r`nhas been created successfully`r`n`r`n"

# Force at least TLS 1.2 connection, get platform and site details from "injected" DC environment variables to generate the download URL, and download the Agent. TLS 1.2 is not always installed, or enabled by default, and download will fail without it
try {[Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([Net.SecurityProtocolType],3072)}
catch {Write-Output "Cannot download Agent due to invalid security protocol. The`r`nfollowing security protocols are installed and available:`r`n$([enum]::GetNames([Net.SecurityProtocolType]))`r`nAgent download requires at least TLS 1.2 to succeed.`r`nPlease install TLS 1.2 and rerun the component." ; exit 1}
$AgentPlatform=$env:CS_CSM_ADDRESS.TrimEnd('/')
$AgentURL="$AgentPlatform/profile/downloadAgent/$env:CS_PROFILE_UID"
Write-Output "Downloading Agent from`r`n$AgentURL..."
$DownloadStart=(Get-Date)
try {(New-Object System.Net.WebClient).DownloadFile($AgentURL, "$InstallFolder\DRMMSetup.exe")}
catch {Write-ExitMessage "Agent installer download failed. Ensure the $UserContext user is able to`r`ndownload from $AgentPlatform via $env:COMPUTERNAME and write to`r`n$TargetDCFolder"}
Write-Output "Agent downloaded to $InstallFolder"
Write-Output "Agent download completed in $((Get-Date).Subtract($DownloadStart).Seconds) seconds" ; Write-Output "`r`n"

$ComponentFolder=(Get-Location).Path

# Unzip the GPO
Write-Output "Creating folder for Immediate Scheduled Task GPO and unzipping..."
New-Item "GPO" -ItemType Directory | Out-Null
try {$GPOZip=(New-Object -ComObject shell.application).namespace("$ComponentFolder\DRMMAgentGPO.zip")}
catch {Write-ExitMessage "Cannot unzip GPO file."}
(New-Object -ComObject shell.application).namespace("$ComponentFolder\GPO").CopyHere($GPOZip.items(),20)

# Replace the strings in the immediate scheduled task file to point to the current domain's FQDN
Write-Output "Repointing GPO to $InstallFolder..."
$XMLFilePath="$ComponentFolder\GPO\{59897AEB-1A2A-49B8-B66E-74B2BDFF47A4}\DomainSysvol\GPO\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml"
$XMLContent = [System.IO.File]::ReadAllText($XMLFilePath).Replace("\\InstallPathOverwrite","$InstallFolder")
[System.IO.File]::WriteAllText("$XMLFilePath", $XMLContent)

# Check if GPO exists from previous run and delete if so, in order to delete all previous links from anywhere in the domain
Remove-DRMMGPO

# Create the GPO by importing the unzipped and customised GPO folder. If the import fails, the script exits with an advisory to rerun with site-level credentials of an appropriate user
Write-Output "Importing and creating repointed GPO for domain $DomainFQDN..."
try {$NewGPO=Import-GPO -BackupGpoName $GPOName -TargetName $GPOName -Path "$ComponentFolder\GPO" -CreateIfNeeded}
catch {Write-ExitMessage "GPO import failed. If the $UserContext user does not have privileges`r`nto create and modify GPOs on $DomainFQDN,`r`nrerun using site-level credentials of a user that does."}
Write-Output "GPO imported successfully with ID $($NewGPO.Id)`r`n`r`n"

# Link GPO at either domain root or OU level.
if ($env:UseOUTargeting -eq "true") {
    Write-Output "Linking GPO at OU level using CSV lookup file..."
    try {$DNLookup=Import-Csv $CSVFile -UseCulture | Where-Object {($_.PSObject.Properties | ForEach-Object {$_.Value}) -ne ""} } # Filter out any blank lines
    catch {Write-ExitMessage "Unable to read CSV file $CSVFile.`r`nEnsure the $UserContext user has read access to`r`n$TargetDCFolder"}
    foreach ($Lookup in $DNLookup) {
        Write-Output "Attempting GPO link at OU $($Lookup.DistinguishedName)`r`nwith RMM site ID $($Lookup.SiteID)..."
        if ($Lookup.SiteID -notmatch '[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}') {
            Write-ExitMessage "The site ID configured for OU $($Lookup.FQDN) is invalid.`r`nPlease check and retry. Site ID found is`r`n$($Lookup.SiteID)"
        }
        try {New-GPLink -Name "$GPOName" -Target $Lookup.DistinguishedName -LinkEnabled Yes -Enforced No | Out-Null}
        catch {Write-ExitMessage "GPO link creation failed on OU $($Lookup.FQDN).`r`n"}
        Write-Output "GPO link created successfully"
    }
    Write-Output ""
} else {
    Write-Output "Linking GPO at domain root level..."
    $DomainDN=(([ADSI]'').DistinguishedName).ToString()
    Write-Output "Attempting GPO link at domain root $DomainDN, all computers`r`nwill go to site with ID $env:CS_PROFILE_UID and name`r`n$env:CS_PROFILE_NAME..."
    try {New-GPLink -Name "$GPOName" -Target $DomainDN -LinkEnabled Yes -Enforced No | Out-Null}
    catch {Write-ExitMessage "GPO link creation failed."}
    Write-Output "GPO link created successfully`r`n`r`n"
}

# Force SYSVOL share replication for Agent download, GPO script and GPO
Write-Output "Forcing SYSVOL replication..."
repadmin /syncall /APeq

# If immediate GPUpdate is required, run immediate and silent Specops GPUpdate
if ($env:ImmediateGPUpdate -eq "true") {
    Write-Output "Attempting immediate and silent Specops GPUpdate..."
    # First check we are not running as the local SYSTEM account as this will fail
    # SYSTEM account determined at SID level due to naming inconsistencies in different languages
    $UserSID=([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    if ($UserSID -eq "S-1-5-18") {
        $host.ui.WriteErrorLine("You cannot run immediate and silent GPUpdate as $UserContext`r`nIf you do not want to wait until next automatic GPUpdate,`r`nconfigure this component to use site credentials and`r`nset them up in the site settings, then rerun")
        exit }
    Write-Output "User $UserContext confirmed as non-SYSTEM account"

    # Create Specops GPUpdate registration with dynamic update for current component folder, if it's not already installed
    $SpecopsReg="HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellSnapIns\Specops.Gpupdate"
    if (-not (Test-Path $SpecopsReg)) {
        Write-Output "Specops GPUpdate not installed. Registering PowerShell module..."
        try {New-Item -Path $SpecopsReg -Force | Out-Null
            New-ItemProperty -Path $SpecopsReg -Type string -Name "ApplicationBase" -Value "$ComponentFolder" -Force | Out-Null
            New-ItemProperty -Path $SpecopsReg -Type string -Name "AssemblyName" -Value "Specopssoft.GPUpdate.Command, Version=2.2.20063.1, Culture=neutral, PublicKeyToken=2e907a53c2033d96" -Force | Out-Null
            New-ItemProperty -Path $SpecopsReg -Type string -Name "Description" -Value "Specops Gpupdate includes commands to start, stop and restart computers. It also includes commands for running gpupdate and Windows Update." -Force | Out-Null
            New-ItemProperty -Path $SpecopsReg -Type string -Name "ModuleName" -Value "$ComponentFolder\Specopssoft.GPUpdate.Command.dll" -Force | Out-Null
            New-ItemProperty -Path $SpecopsReg -Type string -Name "PowerShellVersion" -Value "1.0" -Force | Out-Null
            New-ItemProperty -Path $SpecopsReg -Type string -Name "Vendor" -Value "Specops Software" -Force | Out-Null
            New-ItemProperty -Path $SpecopsReg -Type string -Name "Version" -Value "2.2.20063.1" -Force | Out-Null
            $SpecopsRevert=$true
        }
        catch {
            $host.ui.WriteErrorLine("Unable to register the Specops GPUpdate PowerShell module.`r`nCannot run immediate and silent GPUpdate.")
            Remove-Item $SpecopsReg -Force
            exit }
    } else {Write-Output "Specops GPUpdate installed, PowerShell module already registered."
        $SpecopsRevert=$false}

    # Import modules and run immediate and silent GPUpdate
    Import-Module .\Specopssoft.Adx.dll
    Import-Module .\Specopssoft.GPUpdate.Command.dll
    try {Import-Module ActiveDirectory}
    catch [System.IO.FileNotFoundException] {
        $host.ui.WriteErrorLine("ActiveDirectory Powershell module not found. You need to install the ADDS or`r`nRSAT ADDS feature on $env:COMPUTERNAME before you can run immediate and silent GPUpdate.")
        exit }
    catch {
        $host.ui.WriteErrorLine("Cannot run immediate and silent GPUpdate because ActiveDirectory Powershell`r`nmodule import failed. If the $UserContext user does not have privileges to import`r`nthe ActiveDirectory Powershell module on $env:COMPUTERNAME, rerun using site-level`r`ncredentials of a user that does, or wait until next automated policy refresh.")
        exit }
    Write-Output "Getting list of domain-joined computers and applying immediate GPUpdate..."
    
    try {
        if ($env:UseOUTargeting -eq "true") {
            $ADComputers=@()
            $DNLookup | ForEach-Object {$ADComputers+=Get-ADComputer -Filter * -SearchBase $_.DistinguishedName -SearchScope 2}
        } else {$ADComputers=Get-ADComputer -Filter *}
    }
    catch {$host.ui.WriteErrorLine("Extraction of AD computer object names failed.") ; exit}

    $Error.Clear() # Clear the error stream so it can be output later
    $ADComputersSuccess=($ADComputers | ForEach-Object {$_.Name} | Update-SpecopsGroupPolicy -NoPing -Force -PassThru -ErrorAction SilentlyContinue)
        
    # Write success and fail results to StdOut and StdErr respectively
    Write-Output "`r`nThe following computer objects successfully ran immediate silent GPUpdate:"
    Write-Output $ADComputersSuccess.name
    $Iteration=0
    foreach ($Message in $Error) {
        if ($Iteration -eq 0) {$host.ui.WriteErrorLine("`r`nThe following computer objects failed to run immediate silent GPUpdate:")}
        $host.ui.WriteErrorLine($error[$Iteration].ToString())
        $Iteration++
    }
    # Revert Specops GPUpdate PowerShell module registration if applicable
    if ($SpecopsRevert) {Remove-Item HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellSnapIns\Specops.Gpupdate -Force
        Write-Output "Specops GPUpdate Powershell module registration removed"}
    Write-Output "`r`n`r`nScript completed. Your Agents should check in soon"
}   else {Write-Output "Immediate silent GPUpdate not required. Script completed"}
Exit