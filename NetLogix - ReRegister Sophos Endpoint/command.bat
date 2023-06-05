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

if ($ENV:SophosCustToken -eq $null) {
  Write-Host "--Customer Token Not Set or Missing"
  Exit 1
} else {
  Write-Host "--CustomerToken = "$ENV:SophosCustToken""
}

Invoke-WebRequest -Uri "https://central.sophos.com/api/partners/download/windows/v1/$ENV:SophosCustToken/SophosSetup.exe" -OutFile SophosSetup.exe

$Arguments="--products=intercept --registeronly --quiet"
Start-Process .\Sophossetup.exe $Arguments

Start-Sleep 60

if ($TP) {
  Write-Host "Re-enabling tamper protection"
  &$sedcli -ResumeTP $ENV:UDF_24
}

Remove-Item SophosSetup.exe -Force