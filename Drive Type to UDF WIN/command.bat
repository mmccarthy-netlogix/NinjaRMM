$Volumes = Get-Volume | Where DriveType -eq "Fixed"
$Drives="Drive"

foreach ($Volume in $Volumes) {
  if ($Volume.driveletter) {
    $DriveType=($volume | Get-Partition | Get-Disk | Get-Physicaldisk).MediaType
    $Drives+="-$($Volume.DriveLetter)-$DriveType"
  }
}
if (!$Drives) {
  Write-Host "No Physical Disk(s)"
}
else {
  $Drives
}

New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $ENV:CustomUDF -PropertyType String -Value "$Drives"