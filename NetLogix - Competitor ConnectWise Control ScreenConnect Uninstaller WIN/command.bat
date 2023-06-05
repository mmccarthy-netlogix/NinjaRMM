#screenconnect/connectwise control uninstaller :: build 1/seagull
$doNotRemove="7130ec5c02345159"

if ([intptr]::Size -eq 4) {
    $varRegNode="HKLM:\Software"
} else {
    $varRegNode="HKLM:\Software\Wow6432Node"
}

function getGUID ($swName) {
  $list=@()
  $swList=Get-WmiObject -Class Win32_Product -Filter "name like `"$swName%`""

  foreach ($sw in $swList) {
    if ($sw.Name -notlike "*$doNotRemove*") {$list+=$sw.IdentifyingNumber}
  }
  return $list
}

$arrGUIDList = getGUID "ScreenConnect Client"

foreach ($guid in $arrGUIDList) {
    $varSCUID=(Get-ItemProperty "$varRegNode\Microsoft\Windows\CurrentVersion\Uninstall\$GUID" -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
    write-host "- Uninstalling $varSCUID..."
    msiexec /x$guid /qn
}