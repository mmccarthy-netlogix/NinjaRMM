if (!((gp HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -contains "Sophos Endpoint Agent")) {
    Write-Host "Sophos Central Agent not installed"
    Exit 0
}

$CustomUDF=$ENV:CustomUDF
$latest=(Get-ItemProperty -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority).Latest
$deviceId=(Get-ItemProperty -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority\$latest).deviceId
$tenantId=(Get-ItemProperty -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority\$latest).tenantId

#PS5+ only
#Expand-Archive .\SophosAPI.zip .\

[System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory("$(Get-Location)\SophosAPI.zip", "$(Get-Location)")
Import-Module .\SophosAPI

Set-SophosApiParameters -Key $ENV:SophosApiKey -SecretKey $ENV:SophosApiSecretKey

$attempt=0

while (($tenant -eq $null) -and ($attempt -le 5)) {
  $tenant=Get-SophosTenantID | Where {$_.id -eq $tenantId}
  $attempt++
  if (($tenant.id -eq $null) -and ($attempt -le 6)) {
    $random = Get-Random -Minimum 60 -Maximum 1200
    Write-Host "Sleeping for $random seconds"
    Start-Sleep $random
  }
}

if ($tenant.id -eq $null) {
  Write-Host "Could not verify tenant ID, exiting"
  Exit 1
}

Set-SophosTenantId -TenantId $tenant.id -ApiHost $tenant.apihost

$attempt=0

while (($TPpassword -eq $null) -and ($attempt -le 5)) {
  $TPpassword=Get-SophosEndpointTamperProtection $deviceId
  $attempt++
  if (($TPpassword.password -eq $null) -and ($attempt -le 6)) {
    $random = Get-Random -Minimum 60 -Maximum 1200
    Write-Host "Sleeping for $random seconds"
    Start-Sleep $random
  }
}

if ($Tppassword.password -eq $null) {
  Write-Host "Unable to retrieve Tamper Protection Password, exiting"
  Exit 1
}

Write-Host "Tamper Protection password: $($TPpassword.password)"

if ($CustomUDF -ne "None") {
  Write-Host "Writing Tamper Protection password to $CustomUDF"
  New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $CustomUDF -PropertyType String -Value "$($TPpassword.password)"
}