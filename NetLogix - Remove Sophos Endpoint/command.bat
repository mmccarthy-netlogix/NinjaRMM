$sedcli = "$ENV:ProgramFiles\Sophos\Endpoint Defense\SEDcli.exe"

if (($ENV:UDF_24 -ne $null) -or ($ENV:UDF_24 -ne "")) {
  Write-Host "Disabling tamper protection using $ENV:UDF_24"
  $TP=$True
  &$sedcli -OverrideTPoff $ENV:UDF_24
}

$TamperProtection = &$sedcli -status

if ($TamperProtection -like "*enabled") {
  Write-Host "Tamper Protection still enabled"
  Exit 1
}

if (Test-Path "$ENV:ProgramFiles\Sophos\Sophos Endpoint Agent\SophosUninstall.exe") {
  $Arguments="--quiet"
  Start-Process "$ENV:ProgramFiles\Sophos\Sophos Endpoint Agent\SophosUninstall.exe" $Arguments
} else {
  Start-Process "$ENV:ProgramFiles\Sophos\Sophos Endpoint Agent\uninstallcli.exe"
}

Start-Sleep 60