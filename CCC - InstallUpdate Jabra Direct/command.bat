$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

$DLname="Jabra Direct"
$DLdestination = "$ENV:Temp\JabraDirectSetup.exe"

##Download Installer
  ##Download
  Write-Host "Downloading $DLname Installer..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://jabraxpressonlineprdstor.blob.core.windows.net/jdo/JabraDirectSetup.exe"
  $webclient.DownloadFile($DLsource,$DLdestination)

##Run the Installer
  ##Install
  Write-Host "Installing $DLname..."
  Start-Process -FilePath $DLdestination -Wait -NoNewWindow -Argumentlist "/install /passive /norestart"

Remove-Item $DLdestination -Force