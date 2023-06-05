function UninstallSW ($swList) {
  foreach ($sw in $swList) {
      $swName=$sw.DisplayName
      $cmd=$sw.UninstallString.Split(" ",2)[0]
      $arguments=$sw.UninstallString.Split(" ",2)[1]+" /qn"
      write-host "- Uninstalling $swName..."
      Start-Process $cmd -ArgumentList $arguments -NoNewWindow
  }
}

# Find installed software
$swList1=Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Kite Student Portal*"}
$swList2=Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "Kite Student Portal*"}

# Uninstall it
UninstallSW($swList1)
UninstallSW($swList2)

# Create file to trigger install after restart
if (!(Test-Path -Path $ENV:Programdata\CentraStage\NetLogix)) {
  Write-Host "$ENV:Programdata\CentraStage\NetLogix does not exist, creating"
  New-Item -Path $ENV:Programdata\CentraStage\NetLogix -ItemType Directory -Force | Out-Null
}  
$NULL > $ENV:Programdata\CentraStage\NetLogix\kite.install

Remove-Item C:\Users\sciencelab\AppData\Roaming\ATS -Recurse -Force
Remove-Item C:\Users\sciencelab\AppData\Roaming\KiteStudentPortal -Recurse -Force

# Restart the computer
Write-Host "Restarting computer"
shutdown /r /t 30