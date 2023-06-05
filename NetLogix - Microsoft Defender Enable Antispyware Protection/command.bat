$AntispywareStatus=$((get-itemproperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender").DisableAntiSpyware)

if ($AntiSpywareStatus) {
  Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Force -ErrorAction SilentlyContinue
}

$AntispywareStatus=$((get-itemproperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender").DisableAntiSpyware)

if ($AntispywareStatus) {
  Write-Host '<-Start Result->'
  Write-Host "ALERT: AntiSpyware registry set"
  Write-Host '<-End Result->'
  Exit 1
} else {
  Write-Host '<-Start Result->'
  Write-Host "HEALTHY: AntiSpyware registry not set"
  Write-Host '<-End Result->'
  Exit 0
}