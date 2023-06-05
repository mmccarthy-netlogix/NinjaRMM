$vms = Get-VM

foreach ($vm in $vms) {
  Write-Host "VM: $($vm.name) Automatic CheckPoints: $($vm.AutomaticCheckpointsEnabled)"
}

Write-Host "-"

$i=0
foreach ($vm in $vms) {
  if ($vm.AutomaticCheckpointsEnabled) {
    Write-Host "Disabling Automatic Checkpoints on $($vm.name)"
    Set-VM $vm -AutomaticCheckpointsEnabled $false
    $i++
  }
}

Write-Host "-"

if ($i) {
  foreach ($vm in $vms) {
    Write-Host "VM: $($vm.name) Automatic CheckPoints: $($vm.AutomaticCheckpointsEnabled)"
  }
}