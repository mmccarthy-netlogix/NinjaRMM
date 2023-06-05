Expand-Archive .\SophosAPI.zip .\ -Force
Import-Module .\SophosAPI

Set-SophosApiParameters -Key $ENV:SophosApiKey -SecretKey $ENV:SophosApiSecretKey

$latest=Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority -Name Latest
$deviceId=Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority\$latest -Name deviceId
$tenantId=Get-ItemPropertyValue -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority\$latest -Name tenantId

$TenantSettings=Get-SophosTenantID | Where {$_.id -eq $tenantId}

Write-Host "Tenant settings"
$TenantSettings