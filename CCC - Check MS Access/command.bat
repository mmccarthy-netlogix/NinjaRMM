$Office64="${ENV:ProgramFiles}\Microsoft Office\root\Office16\MSACCESS.exe"
$Office32="${ENV:ProgramFiles(x86)}\Microsoft Office\root\Office16\MSACCESS.exe"
if ((Test-Path $Office64) -or (Test-Path $Office32)) {$AccessEXE=$TRUE}

$swList=Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Access Runtime*"}
$swList2=Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Access Runtime*"}

$AccessRuntimeCount=0

foreach ($sw in $swlist) {
  if (($sw.DisplayName -like '*Access Runtime*') -and ($sw.DisplayName -notlike '*MUI*')) {$AccessRuntimeCount++}
}

foreach ($sw in $swlist2) {
  if (($sw.DisplayName -like '*Access Runtime*') -and ($sw.DisplayName -notlike '*MUI*')) {$AccessRuntimeCount++}
}

if ($AccessEXE -and ($AccessRuntimeCount -le 0)) {
  Write-Host '<-Start Result->'
  Write-Host "Result=Full MS Access Installed"
  Write-Host '<-End Result->'
  Exit 1
} else {
  Write-Host '<-Start Result->'
  Write-Host "Result=MS Access Runtime Installed"
  Write-Host '<-End Result->'
  Exit 0
}