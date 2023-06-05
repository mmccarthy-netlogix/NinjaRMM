# Init Variables
$PowerProfilePath="$ENV:Programdata\Centrastage\NetLogix"
$PowerProfileFile="\PowerProfile.pow"
$PowerProfile=$PowerProfilePath+$PowerProfileFile

# Check that PowerProfilePath exists, create if it does not
Write-Host "Checking if $PowerProfilePath exists"
if (!(Test-Path -Path $PowerProfile)) {
  Write-Host "$PowerProfile does not exist, Exiting"
  Exit 1
}

# Import the current power profile
if (Test-Path $PowerProfile) {
  Write-Host "Restoring saved power profile from $PowerProfile"
  Start-Process -FilePath $ENV:Windir\system32\powercfg.exe -Wait -NoNewWindow -ArgumentList "/IMPORT $PowerProfile"
} else {
  Write-Host "Exported Power Profile does not exist"
  Exit 1
}