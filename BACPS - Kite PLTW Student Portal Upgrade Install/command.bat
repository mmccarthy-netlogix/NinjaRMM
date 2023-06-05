# Create the download path if it does not exist
New-Item -Path "$ENV:ProgramData\CentraStage\NetLogix\Kite" -ItemType Directory -Force | Out-Null

# Download the installer to a known path
# Download URL: https://files.kiteaai.org/installers/pltwstudentportal/2023/PLTW%20Kite%20Student%20Portal.msi
  Write-Host "Downloading Kite Installer..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://files.kiteaai.org/installers/pltwstudentportal/2023/PLTW%20Kite%20Student%20Portal.msi"
  $DLdestination = "$ENV:ProgramData\CentraStage\NetLogix\Kite\PLTW Kite Student Portal.msi"
  $webclient.DownloadFile($DLsource,$DLdestination)

# Install
Write-Host "Installing Kite Student Portal"
msiexec /i "$ENV:ProgramData\CentraStage\NetLogix\Kite\PLTW Kite Student Portal.msi" /qn /norestart

# Allow time for install to complete
Start-Sleep 30

# Cleanup
Remove-Item $ENV:Programdata\Centrastage\NetLogix\PLTWkite.install -Force
Remove-Item $ENV:ProgramData\CentraStage\NetLogix\Kite -Recurse -Force

# Verify the install
$swList=Get-WmiObject -Class Win32_Product -Filter "name like `"PLTW Kite Student Portal`""

if ($swList.Version -ne "4.0.0") {
  Write-Host "Installation Failed, Reported version: $swList.Version"
  Exit 1
}