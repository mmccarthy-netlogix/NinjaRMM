$Disks=.\smartctl --scan

foreach ($item in $Disks) {
  if ($item -like '/dev/sd*') {
    .\smartctl -a $item.split(" ")[0]
  }
}