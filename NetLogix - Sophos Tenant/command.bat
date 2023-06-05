function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 

function write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

$latest=(Get-ItemProperty -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority).Latest
$deviceId=(Get-ItemProperty -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority\$latest).deviceId
$tenantId=(Get-ItemProperty -Path HKLM:\SOFTWARE\Sophos\Management\Policy\Authority\$latest).tenantId

if ($tenantId -eq $null) {
  write-DRMMAlert "Sophos tenant ID could not be found"
  exit 0
}

if ($tenantId -eq $ENV:SophosTenantId) {
  write-DRMMAlert "Registry and Site Tenant IDs match"
} else { 
  write-DRMMAlert "Tenant IDs do not match!"
  $diag="Registry: $tenantId`n"
  $diag+="Site: $ENV:SophosTenantId`n"
  write-DRMMDiag $diag
  Exit 1
}