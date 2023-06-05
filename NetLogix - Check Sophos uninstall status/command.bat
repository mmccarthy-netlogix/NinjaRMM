$AutoUpdate=Test-Path "$ENV:ProgramFiles\Sophos\AutoUpdate\SAUcli.exe"
$SEDcli=Test-Path "$ENV:ProgramFiles\Sophos\Endpoint Defense\SEDCLI.exe"

if ($AutoUpdate -and $SEDcli) {Write-Host "Uninstall needed"}
if (!$AutoUpdate -and $SEDcli) {Write-Host "Uninstall incomplete"}
if (!$AutoUpdate -and !$SEDcli) {Write-Host "Uninstall complete"}
