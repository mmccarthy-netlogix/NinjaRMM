$SwitchLIst = gci -path HKLM:\SYSTEM\CurrentControlSet\Services\vmsmp\parameters\SwitchList
$timestamp = (Get-Date -UFormat %s).Split(".")[0]

New-Item -Path "$ENV:ProgramData\CentraStage" -Name "NetLogix" -ItemType "Directory" -Force -ErrorAction SilentlyContinue
REG export HKLM\SYSTEM\CurrentControlSet\Services\vmsmp\parameters\SwitchList $ENV:Programdata\CentraStage\NetLogix\switchlist-$timestamp.reg

foreach ($Switch in $SwitchList) {
  $PortList = gci $Switch.PSPath

  foreach ($Port in $PortList) {
    $Entry = Get-ItemProperty -Path $Port.PSPath
    if ($Entry -eq $NULL) {
      Write-Output "Removing " $Port.Name
      Remove-Item $Port.PSPath -Recurse
    }
  }
}