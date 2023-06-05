for ($i=1; $i -le 30; $i++) {
  Write-Host "Step: $i"
  $regValue = (Get-Item "ENV:\UDF_$i").value -split ','
  Write-Host $regValue
}