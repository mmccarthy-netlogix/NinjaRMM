# Init Variables
$PowerProfilePath="$ENV:Programdata\Centrastage\NetLogix"
$PowerProfileFile="\PowerProfile.pow"
$PowerProfile=$PowerProfilePath+$PowerProfileFile
$SubGroupGUID="238c9fa8-0aad-41ed-83f4-97be242c8f20"
$SleepGUID="29f6c1db-86da-48c5-9fdb-f2b67b1f44da"
$HibernateGUID="9d7815a6-7ee4-497e-8888-515a05f02364"
$HybridSleepGUID="94ac6d29-73ce-41a6-809f-6363ba21b47e"

# Get the GUID of the current active power scheme
$activeScheme = cmd /c "powercfg /getactivescheme"
$regEx = '(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}'
$asGuid = [regex]::Match($activeScheme,$regEx).Value
$PowerProfileGUID=$asGuid

# Check that PowerProfilePath exists, create if it does not
Write-Host "Checking if $PowerProfilePath exists"
if (!(Test-Path -Path $PowerProfilePath)) {
  Write-Host "$PowerProfilePath does not exist, creating"
  New-Item -Path $PowerProfilePath -ItemType Directory -Force | Out-Null
}

# Export the current power profile
if (!(Test-Path $PowerProfile)) {
  Write-Host "Saving current power profile to $PowerProfile"
  Start-Process -FilePath $ENV:Windir\system32\powercfg.exe -Wait -NoNewWindow -ArgumentList "/EXPORT $PowerProfile $PowerProfileGUID"
} else {
  Write-Host "Power Profile already saved to $PowerProfile"
}

# Disable sleep
Write-Host "Disabling sleep"
Start-Process -FilePath $ENV:Windir\system32\powercfg.exe -Wait -NoNewWindow -ArgumentList "/setacvalueindex $PowerProfileGUID $SubGroupGUID $SleepGUID 0"
Start-Process -FilePath $ENV:Windir\system32\powercfg.exe -Wait -NoNewWindow -ArgumentList "/setacvalueindex $PowerProfileGUID $SubGroupGUID $HibernateGUID 0"
Start-Process -FilePath $ENV:Windir\system32\powercfg.exe -Wait -NoNewWindow -ArgumentList "/setacvalueindex $PowerProfileGUID $SubGroupGUID $HybridSleepGUID 0"