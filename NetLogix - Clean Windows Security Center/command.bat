Write-Host "Component Started at: " (Get-Date)
Write-Host "--"
Write-Host "Currently registered AVs:"

$av=Get-WmiObject -Namespace "root/SecurityCenter2" AntiVirusProduct

foreach ($v in $av) {
Write-Host "AV: $($v.displayName)"
Write-Host "Path: $([System.Environment]::ExpandEnvironmentVariables($v.pathToSignedReportingExe))"
if (!(Test-Path $([System.Environment]::ExpandEnvironmentVariables($v.pathToSignedReportingExe)))) { $v.Delete()}
}

Write-Host "--"
Write-Host "Currently registered AVs:"
$av=Get-WmiObject -Namespace "root/SecurityCenter2" AntiVirusProduct

foreach ($v in $av) {
Write-Host "AV: $($v.displayName)"
Write-Host "Path: $([System.Environment]::ExpandEnvironmentVariables($v.pathToSignedReportingExe))"
}