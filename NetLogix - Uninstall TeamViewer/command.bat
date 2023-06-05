if (Test-Path "${ENV:ProgramFiles(x86)}\Teamviewer\Uninstall.exe") {$UninstallPath = "${ENV:ProgramFiles(x86)}\Teamviewer"}
if (Test-Path "${ENV:ProgramFiles}\Teamviewer\Uninstall.exe") {$UninstallPath = "${ENV:ProgramFiles}\Teamviewer"}

Write-Output "Starting Uninstall of Teamviewer"
Write-Output "Uninstall location: $UninstallPath"

Start-Process -FilePath "$UninstallPath\uninstall.exe" -ArgumentList "/S"

Write-Output "Uninstall completed"

if ($ENV:usrRemoveAll -eq 1) {
  $removeItems = @(
    "HKLM:\Software\TeamViewer"
    "HKLM:\Software\Wow6432Node\TeamViewer"
    "$ENV:APPDATA\TeamViewer"
    "$ENV:TEMP\TeamViewer"
  )

  Write-Output "Beginning cleanup"

  foreach ($dir in $removeItems) {
    Write-Output "Attempting to remove $dir"
    Remove-Item $dir -Force -Recurse
  }
}