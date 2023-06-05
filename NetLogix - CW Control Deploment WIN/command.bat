$ProgressPreference = 'SilentlyContinue'
#[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$p = [Enum]::ToObject([System.Net.SecurityProtocolType], 3072);
[System.Net.ServicePointManager]::SecurityProtocol = $p;

##Download ConnectWise Control Installer
  ##Download
  Write-Host "Downloading ConnectWise Control Installer..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://support.netlogix.com:8040/Bin/ConnectWiseControl.ClientSetup.exe?h=support.netlogix.com&p=8041&k=BgIAAACkAABSU0ExAAgAAAEAAQD%2FhfAUwGpQnX4t6myglhK4bbzzi0jGe4XT1%2BAfVAC3duXKO0aaNqfq1MekzOgVI4ESms4e5vyTSl9PHXhb49oXbYTT6MX1TX1m5i8%2BuEgnGiRScD3GLdQPEZq1y89MJ1CLtE5AL2hFIs0gcPsmtdmoZtS3ngChqqnhF%2Fxhf4NoI7DImPdlUdSxC4y6iXVzJylzy95dom46slaE%2Fd8KBTzG%2FlqpHR9rSmfohWX0aB6r3g3IUcmw0uewUpJY4lhAy2wdsJv6viZC0mTnAnmgcbPEILnKGbWPQ%2FK7we4iwWNUSCwFr5i1UjKufIBuqwgAauAIns%2BeeY7Y7Cem7J%2BHydzj&e=Access&y=Guest&t=&c=$ENV:CS_PROFILE_NAME&c=&c=&c=&c=&c=&c=&c="
  $DLdestination = "$ENV:Temp\CWCInstaller.exe"
  $webclient.DownloadFile($DLsource,$DLdestination)

##Install ConnectWise Control Installer
  ##Install
  Write-Host "Installing ConnectWise Control..."
  Start-Process -FilePath $DLdestination -Wait -NoNewWindow

Remove-Item $DLdestination -Force

$CWService = Get-Service -Name "ScreenConnect Client (7130ec5c02345159)" -ErrorAction SilentlyContinue

if ($CWService.Status -eq "Running") {
  Write-Host "Installation of ConnectWise Control Completed Successfully.."
  Exit 0
}
else {
  Write-Host "Installation of ConnectWise Control Failed.."
  Exit 1
}