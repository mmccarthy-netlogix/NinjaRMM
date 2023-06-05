# Create the download path if it does not exist
New-Item -Path "$ENV:ProgramData\CentraStage\NetLogix\WebEx" -ItemType Directory -Force | Out-Null

# Download the installer to a known path
# Download URL: https://binaries.webex.com/WebexTeamsDesktop-Windows-Gold/Webex.msi
  Write-Host "Downloading Kite Installer..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://binaries.webex.com/WebexTeamsDesktop-Windows-Gold/Webex.msi"
  $DLDestination = "$ENV:ProgramData\CentraStage\NetLogix\WebEx\WebEx.msi"
  $webclient.DownloadFile($DLsource,$DLdestination)

# Install
$msi_args = "/i",$DLDestination,"/quiet","ACCEPT_EULA=TRUE","ALLUSERS=1","AUTOSTART_WITH_WINDOWS=true"
Write-Host "Installing WebEx App"
Start-Process -FilePath $ENV:WINDIR\System32\msiexec.exe -Wait -NoNewWindow -PassThru -ArgumentList $msi_args
#msiexec /i "$ENV:ProgramData\CentraStage\NetLogix\WebEx\WebEx.msi" /qn /norestart

# Cleanup

# Verify the install
$swList=Get-WmiObject -Class Win32_Product -Filter "name like `"WebEx`""
