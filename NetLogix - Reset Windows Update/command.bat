Remove-Item $ENV:windir\system32\catroot2.bak -Force -Recurse
Remove-Item $ENV:windir\SoftwareDistribution.bak -Force -Recurse

Stop-Service bits
Stop-Service wuauserv
Stop-Service appidsvc
Stop-Service cryptsvc

if ((Get-Service wuauserv).Status -ne "Stopped") {
  taskkill /F /FI "SERVICES eq wuauserv"
  Start-Sleep 5
}

if ((Get-Service wuauserv).Status -ne "Stopped") {
  Write-Host "Windows Update service could not be stopped"
  Exit 1
}


Remove-Item $ENV:SystemRoot\winsxs\pending.xml
Remove-Item $ENV:ALLUSERSPROFILE\Microsoft\Network\Downloader\qmgr*.dat
Remove-Item "$ENV:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat"
Rename-Item -Path "$ENV:windir\system32\catroot2" -NewName "catroot2.bak"
Rename-Item -Path "$ENV:windir\SoftwareDistribution" -NewName "SoftwareDistribution.bak"

Set-Service -Name wuauserv -StartupType Disabled
Set-Service -Name wuauserv -StartupType Manual

Start-Service bits
Start-Service wuauserv
Start-Service appidsvc
Start-Service cryptsvc