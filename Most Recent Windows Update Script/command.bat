# Check age of most recent cumulative update for Windows.

# The Microsoft Update Catalog will be checked first and the age determined by Patch Tuesday.
# If the cumulative update cannot be determined, the script will fall back to any update and use the local install date rather than Patch Tuesday.
# If no hotfix information is returned, the script will fallback to the OS install date.

$MaxAge=$env:MaxAge
$Alert=$false

function Get-MSUpdateList {    
    param (
        $MSQueryList
    )
    [System.Collections.ArrayList]$links = @()
    # Write-Host "`nProcessing Microsoft Update Catalog query results."
        Foreach ($entry in $MSQueryList){
        if ($debug -eq $true){
            Write-Host "`tProcessing: $entry"
        }
        $Webdata=Invoke-WebRequest -uri $entry -UseBasicParsing

        ForEach ($link in $Webdata.links | Where-Object id -like '*_link') {
            #Basic parsing does not pull the innerText data, so we have to convert outerHTML into the innerText manually.
            [xml]$ParseHTML=$link.outerHTML
            $innerText=($ParseHTML.a.'#Text').trim()
            $GUID=$link.id -replace '_link',''
            $Architecture=switch ($innerText){
                {$_ -match 'x86'} {'x86'}
                {$_ -match 'x64'} {'x64'}
                {$_ -match 'ARM64'} {'ARM64'}
                default {"x86"}
            }
            # Splits the description into the three main sections. The update release and type, the platform, and the system type and KB number.
            $split1=($innerText) -split " for ", 4
            
            # Splits the first section into the release year and month, and the type of update.
            $split2=$split1[0] -split " ", 2
            $product = $split1[1]

            if ($split1[1] -match "Windows"){
                $platform = ($split1[1] -split ' \(KB',2)[0]
            }
            else {
                $platform = ($split1[2] -split ' \(KB',2)[0]
            }
            #Extract the KB number out of the last split string
            $pattern="\((.*?)\)"
            $count=($split1.count - 1)
            $KB=$split1[$count] | Select-String -Pattern $pattern -AllMatches| ForEach-Object {$_.Matches} | ForEach-Object {$_.Groups[1].Value}
            $MSUpdateLink = [PSCustomObject]@{
                GUID = $GUID
                Architecture = $Architecture
                Release = $split2[0].trim()
                Type = $split2[1].trim()
                Product = $product.trim()
                Platform = $platform.trim()
                KB = $KB
            }
            [void]$links.add($MSUpdateLink)
            
        }
    }
    return $links
}

Function Get-OSVersion {

    $signature = @"
   
    [DllImport("kernel32.dll")]
   
    public static extern uint GetVersion();
   
"@
   
   Add-Type -MemberDefinition $signature -Name "Win32OSVersion" -Namespace Win32Functions -PassThru
}

function Get-SystemType {
    param (
        
    )
    switch ($varDomainRole) {
        0 {Return "Workstation"}
        1 {Return "Workstation"}
        2 {Return "Server"}
        3 {Return "Server"}
        4 {Return "Server"}
        5 {Return "Server"}
        Default {Return "Unknown"}
    }
    
}

function Get-OSLabel {
    switch (Get-SystemType){
        Workstation {
            switch ($varKernel){
                7601 {Return "windows 7"}
                9200 {Return "Windows 8"}
                9600 {Return "Windows 8.1"}
                10240 {Return "Windows 10 Version 1507"}
                10586 {Return "Windows 10 Version 1511"}
                14393 {Return "Windows 10 Version 1607"}
                15063 {Return "Windows 10 Version 1703"}
                16299 {Return "Windows 10 Version 1709"}
                17134 {Return "Windows 10 Version 1803"}
                17763 {Return "Windows 10 Version 1809"}
                18362 {Return "Windows 10 Version 1903"}
                18363 {Return "Windows 10 Version 1909"}
                19041 {Return "Windows 10 Version 2004"}
                19042 {Return "Windows 10 Version 20H2"}
                19043 {Return "Windows 10 Version 21H1"}
                19044 {Return "Windows 10 Version 21H2"}
                19045 {Return "Windows 10 Version 22H2"}
                22000 {Return "Windows 11"}
                22621 {Return "Windows 11 Version 22H2"}
                default {Return "Unknown"}
            }
        } # Workstation
        Server {
            switch ($varKernel) {
                7601 {Return "Windows Server 2008 R2"}
                9200 {Return "Windows Server 2012"}
                9600 {Return "Windows Server 2012 R2"}
                14393 {Return "Windows Server 2016"}
                17134 {Return "Windows Server 2016 (1803)"}
                17763 {Return "Windows Server 2019"}
                18362 {Return "Windows Server, version 1903"}
                18363 {Return "Windows Server, version 1909"}
                19041 {Return "Windows Server, version 2004"}
                19042 {Return "Windows Server, version 20H2"}
                default {Return "Unknown"}
            }
        }
        default {Return "Unknown"}
    }
}


function Get-SecondTuesday ($date){
    $FindNthDay=2
    $WeekDay='Tuesday'
    [datetime]$Today=Get-Date $date
    $todayM=$Today.Month.ToString()
    $todayY=$Today.Year.ToString()
    [datetime]$StrtMonth=$todayM+'/1/'+$todayY
    while ($StrtMonth.DayofWeek -ine $WeekDay ) { $StrtMonth=$StrtMonth.AddDays(1) }
    Get-Date($StrtMonth.AddDays(7*($FindNthDay-1))) -format "MMMM, dd, yyyy"
}

Write-Output "<-Start Diagnostic->"

# Device information
$OSArch=if ([IntPtr]::Size -eq 4){"x86"} else {"x64"}
$os = [System.BitConverter]::GetBytes((Get-OSVersion)::GetVersion())
$majorVersion = $os[0]
$minorVersion = $os[1]
$build = [byte]$os[2],[byte]$os[3]
$buildNumber = [System.BitConverter]::ToInt16($build,0)
"`nWindows Version is {0}.{1} build {2}" -F $majorVersion,$minorVersion,$buildNumber
[int]$varKernel = $buildNumber
# 0/1 = Workstation 2+ = Server
[int]$varDomainRole=(Get-WmiObject -Class Win32_ComputerSystem).DomainRole
$varOSCaption=(get-WMiObject -computername $env:computername -Class win32_operatingSystem).caption
$varOSLabel=Get-OSLabel
$varOSInstallDate=(Get-CimInstance -class Win32_OperatingSystem).InstallDate
Write-Output "OS Label: $varOSLabel"
Write-Output "OS Caption: $varOSCaption"
Write-Output "OS Architecture: $OSArch"

# Set the label to filter out the KBQuery results.
switch ($varOSCaption) {
    {$_ -match "Server 2012"} {$Label='Security Monthly Quality Rollup'}
    {$_ -match "Windows 8"} {$Label='Security Monthly Quality Rollup'}
    default {$Label="Cumulative Update"}
}

Write-Output "Hotfix Label: $Label"

$Hotfix=Get-HotFix
if ($null -eq $Hotfix){
    # If no hotfixes are listed, it's possible the OS has installed a feature update recently.
    # Use the OS Install date in these instances as the most recent update age.
    Write-Output "`nWARNING: No hotfix install data returned. Using the OS install date as a fallback."
    $ReleaseAge=((Get-Date)-(Get-Date($varOSInstallDate))).days
}
else {
    Write-Output "`nInstalled Updates:"
    $Hotfix | Format-Table
    
    Write-Output "`n`r"
    $BaseKBURL='https://catalog.update.microsoft.com/v7/site/Search.aspx?q='
    [System.Collections.ArrayList]$UpdatesRaw = @()
    foreach ($entry in $Hotfix){
        $CatalogLink=$BaseKBURL+$entry.HotfixID
        Write-Output "Querying MS Update Catalog for $($entry.HotfixID)..."
        $Response=Get-MSUpdateList $CatalogLink
        foreach ($value in $Response){
            [void]$UpdatesRaw.add($value)
        }
    }
    
    $Updates=$UpdatesRaw | where-object {(($_.Product -eq $varOSLabel) -and ($_.Architecture -eq $OSArch) -and ($_.Type -eq $Label))}
    if ($null -eq $Updates){
        # If there aren't any cumulative updates identified via the MS Update Catalog, use the most recent hotfix install date.
        Write-Output "`nWARNING: No monthly cumulative updates detected via MS Update Catalog. Using local hotfix data as fallback."
        Write-Output "`nList of installed Hotfixes:"
        $LatestHotfix=$Hotfix | sort-object -Property InstalledOn -Descending -ErrorAction SilentlyContinue | select-object -first 1
        $ReleaseAge=((Get-Date)-(Get-Date($LatestHotfix.InstalledOn))).days
    }
    else {
        $MostRecentUpdate=$Updates | sort-object -Property "Release" -Descending | select-object -First 1
    
        Write-Output "`nLatest OS Update:"
        $MostRecentUpdate | Format-Table
        
        $HotfixReleaseDate=Get-SecondTuesday $MostRecentUpdate.Release
        $ReleaseAge=((Get-Date)-(Get-Date($HotfixReleaseDate))).days
        Write-Host "`nMost recent system update is $($MostRecentUpdate.KB) released on $HotfixReleaseDate."
        $UDFData="$($MostRecentUpdate.Release) $($MostRecentUpdate.Type) for $($MostRecentUpdate.Product)"
    }
    
    

    Write-Host "System update released $ReleaseAge days ago."
}

if ($ReleaseAge -gt $MaxAge){
    Write-Host "WARNING: The most recent update is older than $MaxAge days!"
    $Alert=$true
}

if ($ENV:CustomUDF -ne "None") {
    New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $ENV:CustomUDF -PropertyType String -Value $UDFData
}

Write-Output "<-End Diagnostic->"
Write-Output "<-Start Result->"
Write-Output "UpdateAge=$ReleaseAge"
Write-Output "<-End Result->"
if ($alert){
    Exit 1
}
else {
    Exit 0
}