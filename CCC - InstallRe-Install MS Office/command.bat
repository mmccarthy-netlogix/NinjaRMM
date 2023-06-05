#run uninstall if variable true
#run install with config file specified

if ($ENV:Uninstall -eq "true") {
  Start-Process .\Setup.exe -Argumentlist "/configure .\uninstall.xml" -Wait -NoNewWindow
}
Start-Sleep 60

Write-Host "Installing using $ENV:InstallOptions"
Start-Process .\Setup.exe -Argumentlist "/configure $ENV:InstallOptions" -Wait -NoNewWindow