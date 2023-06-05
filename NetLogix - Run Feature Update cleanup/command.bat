# File Creation Time
$CheckFile=$ExecutionContext.InvokeCommand.ExpandString($ENV:usrCheckFile)
$FileCreate=[datetime](Get-ChildItem $CheckFile).CreationTime
if ($FileCreate -eq $Null) {
  Write-Host "$CheckFile does not exist"
  Exit 1
}

# Last Startup Time
$StartupTime=[datetime](Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

#OS Build version
$OSBuild=[environment]::OSVersion.Version.Build

Write-Host "$CheckFile creation date: $FileCreate"
Write-Host "Last Startup time: $StartupTime"
Write-Host "OS Build $OSBuild installed"
Write-Host ""

if (($OSBuild -ge $ENV:usrOSBuild) -or ($StartupTime -ge $FileCreate)) {
  Write-Host "Running cleanup.bat"
  Start-Process "$ENV:Windir\System32\cmd.exe" "/c $CheckFile"
}
else {
  Write-Host "Setting Reboot Required flag"
  $NULL > $ENV:Programdata\CentraStage\reboot.flag
}