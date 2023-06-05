$AntispywareStatus=$((get-itemproperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender").DisableAntiSpyware)

if ($AntiSpywareStatus) {
  Write-Host '<-Start Result->'
  Write-Host "Alert=Antispyware registry setting set."
  Write-Host '<-End Result->'
  Exit 1
} else {
  Write-Host '<-Start Result->'
  Write-Host "Alert=Antispyware enabled."
  Write-Host '<-End Result->'
  Exit 0
}