<# map network drives :: build 3b/seagull, august 2022
   script variables: usrDriveLetter/str :: usrDriveLocation/str :: usrOverwrite/bln

   this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
   it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for 
   any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM is the one exception to this rule.
   	
   the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

write-host "Map Network Drive"
write-host "============================"

#get logged-in user :: adapted from build 9 :: "one single incomprehensible line" edition
(((query user) -replace '>', '') -replace '\s{2,}', ',' | ConvertFrom-Csv).$(($((((query user) -replace '>', '') -replace '\s{2,}', ',' | ConvertFrom-Csv)) -as [string]).split('=')[0] -replace '@{','') | % {
    if ($_) {
        $varCurrentUser=$_
    }
}

#if the user said "ANY", find a free disk letter
if ($env:usrDriveLetter -eq 'ANY') {
    $varCharCount=90
    while (!$varLetterFound) {
        #count backwards through ASCII characters from #90 (Z)
        if (!(Get-WmiObject win32_logicaldisk | ? {$_.DeviceID -eq [char]$varCharCount})) {
            $env:usrDriveLetter=[char]$varCharCount
            $varLetterFound=$true
        }

        $varCharCount--

        #we've thought of everything from D to Z
        if ($varCharCount -lt 68) { #stop at D, since A-C are reserved
            write-host "! ERROR: Could not find a suitable drive letter on this device."
            write-host "  It would appear all drive letters are occupied."
            exit 1
        }
    }
    write-host ": Letter to map: ANY ($env:usrDriveLetter`:)"
    write-host "  (No physical disk is using this letter. If a mapped drive is already occupying this"
    write-host "  letter, this check will not catch it; that check is performed later against the value"
    write-host "  given for the usrOverwrite variable.)"
} else {
    write-host ": Letter to map: $env:usrDriveLetter`:"
}

write-host ": Network path:  $env:usrDriveLocation"
write-host ": Current user:  $varCurrentUser"
write-host `r

#check auxiliary data (user, variables) =======================================================================================

if (!$varCurrentUser) {
    write-host "! ERROR: Could not intuit name of logged-in user. Please ensure a user is logged into this device."
    write-host "  (Network drives are mapped at the user-level, so a user must be logged in to map the drive to them)"
    exit 1
}

#check user variables
('usrDriveLetter','usrDriveLocation','usrOverwrite') | % {
    $varCurrent=$_
    if (($((ls env: | ? {$_.Name -eq $varCurrent}).Value) -as [string]).Length -lt 1) {
        write-host "! ERROR: Input variable $varCurrent is not defined."
        write-host "  Please define it before running this Component."
        exit 1
    }
}

if (($env:usrDriveLetter -as [string]).Length -gt 1) {
    write-host "! ERROR: Invalid drive-letter input."
    write-host "  Please state the desired drive letter as an uppercase letter."
    write-host "  Do not supply a colon or any other punctuation."
    exit 1
}

#ensure the drive letter given is upper-case
$varDriveLetter=($env:usrDriveLetter -as [string]).ToUpper()

<#ensure the drive letter in question isn't already mapped to a physical disk
  (while this code, when run in a non-administrative powershell session, will show network drives, it won't when run via a
  component; as network drives are mapped at the user-level, even so much as running the query with administrative credentials
  is enough to throw the mapping off. while that can be ameliorated with the enableLinkedConnections registry value, that
  won't permit NT AUTHORITY\SYSTEM to see network drives as this context is its own user; besides, nobody has that value set.)#>

Get-WmiObject win32_logicaldisk | % {
    if (($_.DeviceID -replace ':','') -eq $varDriveLetter) {
        write-host "! ERROR: The letter given to map the network location to is already represented."
        write-host "  Please choose a free drive letter for usrDriveLetter; alternatively, type 'ANY'"
        write-host "  to instruct the Component to use the first free disk letter it sees."
        exit 1
    }
}

#map the drive ================================================================================================================

#loop through user hives until we find the one matching the logged-in user
Get-ChildItem "Registry::HKEY_USERS\" | ? { $_.PSIsContainer } | % {
    if ((Get-ItemProperty "Registry::$_\Volatile Environment" -Name USERNAME -ErrorAction SilentlyContinue).USERNAME -match $varCurrentUser) {
        #map some data
        $varNode="Registry::$_"
        write-host "- User: $varCurrentUser"
        write-host "- Path: $varNode"
        
        #ensure drive letter is not already mapped to a different network drive (this is not conclusive)
        if (test-path "$varNode\Network\$env:usrDriveLetter" -ea 0) {
            if ($env:usrOverwrite -ne 'true') {
                write-host "! ERROR: Drive letter $env:usrDriveLetter`: is already mapped."
                write-host "  Cannot proceed. To overwrite previous values, set the usrOverwrite flag to TRUE."
                exit 1
            }
        } else {
            write-host "- Drive letter $env:usrDriveLetter does not appear to be mapped."
            write-host "  This is not a guarantee; there may be programs on the user-level occupying this"
            write-host "  drive letter. Please scrutinise devices closely after running this script to ensure"
            write-host "  devices are able to use the network drive that has been mapped."
        }

        #map it :: https://www.anoopcnair.com/managing-network-drive-mappings-with-intune/
        New-Item         "$varNode\Network"                 -Name "$varDriveLetter"                                                        | out-null #make the key
        New-ItemProperty "$varNode\Network\$varDriveLetter" -Name "ConnectionType" -PropertyType Dword  -Value 1                           | out-null #drive redirection, as opposed to printer redirection
        New-ItemProperty "$varNode\Network\$varDriveLetter" -Name "DeferFlags"     -PropertyType Dword  -Value 4                           | out-null #mapped-drive creds are the same as the logged-in user's
        New-ItemProperty "$varNode\Network\$varDriveLetter" -Name "ProviderFlags"  -PropertyType Dword  -Value 0                           | out-null #drive is not a DFS root
        New-ItemProperty "$varNode\Network\$varDriveLetter" -Name "ProviderName"   -PropertyType String -Value "Microsoft Windows Network" | out-null #boilerplate
        New-ItemProperty "$varNode\Network\$varDriveLetter" -Name "ProviderType"   -PropertyType Dword  -Value 131072                      | out-null #microsoft lanman (0x20000)
        New-ItemProperty "$varNode\Network\$varDriveLetter" -Name "RemotePath"     -PropertyType String -Value $env:usrDriveLocation       | out-null #URI
        New-ItemProperty "$varNode\Network\$varDriveLetter" -Name "UserName"       -PropertyType String -Value 0                           | out-null #do not interfere with usernames
    }
}

write-host "- Mapped drive $varDriveLetter to location $env:usrDriveLocation for user $varCurrentUser."
write-host "  They will not be able to use this drive until the device has been rebooted."