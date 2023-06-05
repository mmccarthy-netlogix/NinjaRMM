Write-Host "Component started at:" (Get-Date)
$ProgressPreference = 'SilentlyContinue'
#[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$p = [Enum]::ToObject([System.Net.SecurityProtocolType], 3072);
[System.Net.ServicePointManager]::SecurityProtocol = $p;

##Download Logger Pro 3 Installer
  ##Download
  Write-Host "Downloading Logger Pro 3 Installer..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://support.netlogix.com/LabTech/Transfer/LoggerPro3.msi"
  $DLdestination = "$ENV:Temp\LoggerPro3.msi"
  $webclient.DownloadFile($DLsource,$DLdestination)

##Install Logger Pro 3Installer
  ##Install
  Write-Host "Installing Logger Pro 3..."
  $msi_args = "/i",$DLDestination,"/qn","/norestart"
  Start-Process -FilePath $ENV:WINDIR\System32\msiexec.exe -Wait -NoNewWindow -PassThru -ArgumentList $msi_args

Remove-Item $DLdestination -Force

Write-Host "Component completed at:" (Get-Date)