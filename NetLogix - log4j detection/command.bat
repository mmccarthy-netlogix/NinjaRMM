$fileName = "log4j-core*.jar" 
$list = ""

$drives = [System.IO.DriveInfo]::GetDrives() | Where {$_.DriveType -eq "Fixed"}
foreach ($drive in $drives) {
  $folder = $drive.RootDirectory
  $list += Get-ChildItem -Path $folder -Filter $fileName -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -ne "Directory"} | select -ExpandProperty FullName
}

$list

if (($list.where({ $_ -ne ""})).count -ge 1) {
  Write-Host "log4j binary: Found"
  Exit 1
  }
  else {
    Write-Host "log4j binary: Not Found"
    Exit 0
    }