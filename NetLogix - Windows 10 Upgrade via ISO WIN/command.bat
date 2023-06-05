<#
    Windows 10 install-from-ISO by seagull - 2020 redux build 13 :: thanks to jon north
    This script is copyrighted property and cannot be shared or redistributed, even with alterations.
    This includes on the web or within other products.
#>

# Check for $ENV:Public\cleanup.bat which indicates that this component has run but the system has not been restarted
if (Test-Path "$ENV:Public\cleanup.bat") {
  Write-Host "Reboot pending from previous run of this component.  Exiting"
  Exit 1
} 

[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

function generateSHA256 ($executable, $storedHash) {
    $fileBytes = [io.File]::ReadAllBytes("$executable")
    $bytes = [Security.Cryptography.HashAlgorithm]::Create("SHA256").ComputeHash($fileBytes) 
    $varCalculatedHash=-Join ($bytes | ForEach {"{0:x2}" -f $_})
    if ($storedHash -match $varCalculatedHash) {
        write-host "+ Filehash verified for file $executable`: $storedHash"
    } else {
        write-host "! ERROR: Filehash mismatch for file $executable."
        write-host "  Expected value: $storedHash"
        write-host "  Received value: $varCalculatedHash"
        write-host "  Please report this error."
        exit 1
    }
}

function verifyPackage ($file, $certificate, $thumbprint1, $thumbprint2, $name, $url) { #special two-thumbprint edition
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
    } catch [System.Management.Automation.MethodInvocationException] {
        write-host "- ERROR: $name installer did not contain a valid digital certificate."
        write-host "  This could suggest a change in the way $name is packaged; it could"
        write-host "  also suggest tampering in the connection chain."
        write-host "- Please ensure $url is whitelisted and try again."
       write-host "  If this issue persists across different devices, please file a support ticket."
    }

    $varIntermediate=($varChain.ChainElements | ForEach-Object {$_.Certificate} | Where-Object {$_.Subject -match "$certificate"}).Thumbprint

    if ($varIntermediate -ne $thumbprint1 -and $varIntermediate -ne $thumbprint2) {
        write-host "- ERROR: $file did not pass verification checks for its digital signature."
        write-host "  This could suggest that the certificate used to sign the $name installer"
        write-host "  has changed; it could also suggest tampering in the connection chain."
        write-host `r
        if ($varIntermediate) {
            write-host ": We received: $varIntermediate"
            write-host "  We expected: $thumbprint1"
            write-host "      -OR-   : $thumbprint2"
            write-host "  Please report this issue."
        }
        write-host "- Installation cannot continue. Exiting."
        exit 1
    } else {
        write-host "- Digital Signature verification passed."
    }
}

function quitOr {
    if ($env:usrOverrideChecks -match 'true') {
        write-host "! This is a blocking error and should abort the process; however, the usrOverrideChecks"
        write-host "  flag has been enabled, and the error will thus be ignored."
        write-host "  Support will not be able to assist with issues that arise as a consequence of this action."
    } else {
        write-host "! This is a blocking error; the operation has been aborted."
        Write-Host "  If you do not believe the error to be valid, you can re-run this Component with the"
        write-host "  `'usrOverrideChecks`' flag enabled, which will ignore blocking errors and proceed."
        write-host "  Support will not be able to assist with issues that arise as a consequence of this action."
        Stop-Process setupHost -ErrorAction SilentlyContinue
        exit 1
    }
}

function makeHTTPRequest ($tempHost) { #makeHTTPRequest v5: make an HTTP request and ensure a status code (any) is returned
    $tempRequest = [System.Net.WebRequest]::Create($tempHost)
    try {
        $tempResponse=$tempRequest.getResponse()
        $TempReturn=($tempResponse.StatusCode -as [int])
    } catch [System.Exception] {
        $tempReturn=$_.Exception.Response.StatusCode.Value__
    }

    if ($tempReturn -match '200') {
        write-host "- Confirmed file at $tempHost is ready for download."
    } else {
        write-host "! Error Code SGL8: No file was found at $temphost."
        write-host "  This usually means Datto have removed the Windows 10 ISO for this version"
        write-host "  Datto only host the last two versions of Windows 10 before the latest; when"
        write-host "  a new version is made available, the oldest is removed."
        write-host `r
        write-host "  You may need to update your Component in order to show the latest versions"
        write-host "  made available to you. If updating does not work, try deleting and re-adding."
        exit 1
    }
}

#===================================================================================================================================================

#kernel data
[int]$varKernel = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Windows\system32\kernel32.dll")).FileBuildPart
$varArch=[intptr]::Size*8

#user text
write-host `r
write-host "Windows 10 Upgrade Tool: Upgrade and Update Windows 7+ to 10"
write-host "================================================================"
write-host "`: Upgrading from: Build $varKernel /" (get-WMiObject -computername $env:computername -Class win32_operatingSystem).caption

if ($env:usrBuild -notmatch "NotDefined") { #if user has told the script to download from us...

    # make sure user has not ALSO defined their own image path
    if ($env:usrImagePath -match '/' -or $env:usrImagePath -match '\\') {
       write-host "! Error code SGL8:"
       write-host "  User has defined both an image path and a build; these settings disagree with each other."
       write-host "  If you are supplying an image path, please also set the usrBuild variable to read `"Use usrImagePath`"."
       write-host "  Alternatively, to download an ISO from Datto, leave the usrImagePath field blank."
       exit 1
    }

    #make sure the device is running a build we can update
    $varProList=@('1','2','3','5','11','26','28','47','48','49','66','67','68','69','71','98','99','100','101','103')
    [int]$varSKU=(Get-WmiObject -Class win32_operatingsystem -Property OperatingSystemSKU).OperatingSystemSKU
    if ($varProList | ? {$_ -eq $varSKU}) {
        write-host "`+ Device Windows SKU ($varSKU) is supported."
    } else {
        write-host "`! Error code SGL2: The edition of Windows on this device is neither `'Professional`' nor `'Home`'."
        write-host "  This Component has been instructed to download Windows 10 from Datto, which restricts compatibility"
        write-host "  to Windows 10 Home and Professional versions only for legal reasons. (Device SKU: $varSKU)"
        write-host "  To update Windows 10 Enterprise, please use the `"Upgrade or Update`" Component from the ComStore."
        write-host "  To update Windows 10 Education, Pro for Workstations, &c., a custom image will need to be supplied."
        quitOr
    }

    #get which version of english to use
    $varLangCode=(Get-ItemProperty hklm:\system\controlset001\control\nls\language -name InstallLanguage).InstallLanguage
    $varLangCode=(cmd /c set /a 0x$varLangCode)
    if ($varLangCode -eq '2057') {$varLanguage='UK'} else {$varLanguage='US'}

    # dialogue
    write-host "`: Upgrading to:   Microsoft Windows 10, version $env:usrBuild, Professional $varArch-bit, English ($varLanguage)"
    $env:usrImagePath = 'https://storage.centrastage.net/Win10Pro3264-%-;.iso' -replace("%","$env:usrBuild") -replace (";","$varLanguage")
} else {
    write-host "`: Upgrading to:   Microsoft Windows 10 with user-supplied image path."
    write-host "                  Architecture, Edition, Language &c. defined by image."
}


if (($env:usrImagePath -as [string]).Length -lt 2) {
    write-host "`! Error code SGL7:"
    write-host "  Component has been instructed to use a custom image (usrBuild unset), but the usrImagePath variable"
    write-host "  has not been furnished with usable information (Contents: `"$env:userImagePath`")."
    write-host "  Please re-run this Component with different parameters."
    quitOr
}

write-host "`: ISO download path is: $env:usrImagePath"

#services pipe timeout
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control" /v ServicesPipeTimeout /t REG_DWORD /d "300000" /f 2>&1>$null
write-host ": Device service timeout period configured to five minutes."

#check for minimum W7 SP1
if ($varKernel -lt 7601) {
    write-host "`! Error code SGL1:"
    write-host "  This component requires Microsoft Windows 7 SP1 or higher to proceed."
    quitOr
}

write-host "+ Target device OS is Windows 7 SP1 or greater."

#make sure it's licensed (v2)
$varLicence = Get-WmiObject SoftwareLicensingProduct | Where-Object { $_.LicenseStatus -eq 1 } | Select-Object -ExpandProperty Description | select "Windows"
if (!$varLicence) {
    write-host "`! Error code SGL3:"
    write-host "  Windows 10 can only be installed on devices with an active Windows licence."
    quitOr
}

write-host "+ Target device has a valid Windows licence."

#make sure we have enough disk space - installation plus iso hosting
$varSysFree = [Math]::Round((Get-WMIObject -Class Win32_Volume |Where-Object {$_.DriveLetter -eq $env:SystemDrive} | Select -expand FreeSpace) / 1GB)
if ($varSysFree -lt 20) {
    write-host "`! Error code SGL4:"
    write-host "  System drive requires at least 20GB: 13 for installation, 7 for the disc image."
    quitOr
}

write-host "+ Target device has at least 20GB of free hard disk space."

#check for RAM: ge 1GB/x86; ge 2GB/x64
$varRAM=(Get-WmiObject -class "cim_physicalmemory" | Measure-Object -Property Capacity -Sum).Sum / 1024 / 1024 / 1024

if ($varArch -eq '32') {
    #1gb for x86
    if ($varRAM -lt 1) {
        write-host "`! Warning: This machine may not have enough RAM installed."
        write-host "  Windows 10 32-bit requires at least 1GB of system RAM to be installed."
        write-host "  In case of errors, please check this device's RAM."
    } else {
        write-host "+ Target device has at least 1GB of RAM installed (32-bit)."
    }
} else {
    #2gb for x64
    if ($varRAM -lt 2) {
        write-host "`! Warning: This machine may not have enough RAM installed."
        write-host "  Windows 10 64-bit requires at least 2GB of system RAM to be installed."
        write-host "  In case of errors, please check this device's RAM."
    } else {
        write-host "+ Target device has at least 2GB of RAM installed (64-bit)."
    }
}

#download the image
#import-module BitsTransfer -Force

#if (!$?) {
#	write-host "`! Error code SGL6:"
#	write-host "  Import of PowerShell module BitsTransfer - used to transfer the ISO - failed for an unknown reason."
#    write-host "  The command given was: `'import-module BitsTransfer -force`'"
#    write-host "  Please run this command on the local system to see why the module could not be imported."
#    write-host "  Operations aborted: cannot proceed."
#    quitOr
#}

if ($env:usrImagePath -match 'storage.centrastage') {
    makeHTTPRequest $env:usrImagePath
}

#write-host "+ BitsTransfer PowerShell module applied; downloading ISO using BITS."
#write-host "+ Downloading ISO."
#Start-BitsTransfer "$env:usrImagePath" "$env:PUBLIC\Win10.iso"
$WebClient = New-Object System.Net.WebClient;
$WebClient.DownloadFile($env:usrImagePath,"$env:PUBLIC\Win10.iso")
write-host "+ ISO Downloaded to $env:PUBLIC\Win10.iso"

#extract the image
generateSHA256 7z.dll "DB2897EEEA65401EE1BD8FEEEBD0DBAE8867A27FF4575F12B0B8A613444A5EF7"
generateSHA256 7z.exe "A20D93E7DC3711E8B8A8F63BD148DDC70DE8C952DE882C5495AC121BFEDB749F"
.\7z.exe x -y "$env:PUBLIC\Win10.iso" `-o"$env:PUBLIC\Win10Extract" -aoa -bsp0 -bso0
#verify extraction
[int]$varExtractErrors=0
if (!(test-path "$env:PUBLIC\Win10Extract\setup.exe" -ErrorAction SilentlyContinue)) {
    write-host "! Error code SGL5: Extraction of Windows 10 ISO failed."
    write-host "  Please ensure the ISO is not damaged and that the download completed on the device."
    write-host "  Operations aborted: cannot proceed."
    quitOr
}

start-sleep -Seconds 15
Remove-Item "$env:PUBLIC\Win10.iso" -Force
write-host "+ ISO extracted to $env:PUBLIC\Win10Extract. ISO file deleted."

#make a cleanup script to remove the win10 folder post-install :: ps2 compat
@"
@echo off
REM This is a cleanup script. For more information, consult your systems administrator.
rd `"$env:PUBLIC\Win10Extract`" /s /q
del `"$env:PUBLIC\cleanup.bat`" /s /q /f
"@ | set-content -path "$env:PUBLIC\cleanup.bat" -Force

#verify the windows 10 setup.exe -- just to make sure it's legit
verifyPackage "$env:PUBLIC\Win10Extract\setup.exe" 'Microsoft Code Signing PCA' "8BFE3107712B3C886B1C96AAEC89984914DC9B6B" "3CAF9BA2DB5570CAF76942FF99101B993888E257" "Windows 10 Setup" "your network location"

#install
start-sleep -Seconds 30
if ($env:usrReboot -match 'true') {
    & "$env:PUBLIC\Win10Extract\setup.exe" /auto upgrade /quiet /compat IgnoreWarning /PostOOBE "$env:PUBLIC\cleanup.bat" /showOOBE $env:usrShowOOBE
} else {
    & "$env:PUBLIC\Win10Extract\setup.exe" /auto upgrade /quiet /compat IgnoreWarning /PostOOBE "$env:PUBLIC\cleanup.bat" /showOOBE $env:usrShowOOBE /NoReboot
}

#close
write-host "================================================================"
write-host "`- The Windows 10 Setup executable has been instructed to begin installation."
write-host "  This Component has performed its job and will retire, but the task is still ongoing`;"
write-host "  if errors occur with the installation process, you will need to triage them using"
write-host "  Microsoft SetupDiag: https://docs.microsoft.com/en-gb/windows/deployment/upgrade/setupdiag."
if ($env:usrReboot -match 'true') {
    write-host "  Please be aware that several hours may pass before the device shows visible signs."
} else {
    write-host "  Please allow ~4 hours for the setup preparation step to conclude and then reboot the"
    write-host "  device to begin the upgrade process."
}