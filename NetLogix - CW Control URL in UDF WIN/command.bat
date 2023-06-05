write-host "======================================="

$CWReg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\ScreenConnect Client ($ENV:usrCCInstance)"

if ($CWReg -eq $NULL) {
  Write-Host "CW Control service not found"
  Exit 1
}

$CWSettings = $CWReg.ImagePath -Split "&"

foreach ($setting in $CWSettings) {
  $SplitSetting = $setting.split("=")
  if ($SplitSetting[0] -eq "h") {$CWHost = $SplitSetting[1]}
  if ($SplitSetting[0] -eq "p") {$CWPort = $SplitSetting[1]}
  if ($SplitSetting[0] -eq "s") {$CWGUID = $SplitSetting[1]}
}

$CWURL = "https://$CWhost`:8040/Host#Access/All Machines//$CWGUID/JoinWithOptions"
$CWURL = $CWURL.Replace(" ","%20")

REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage" /v Custom$env:usrUDF /t REG_SZ /d "$CWURL" /f

#===================================================

write-host "- Value: $CWURL"
write-host "- UDF:   $env:usrUDF"
write-host "- Operation Completed."
