$driveletter="S"
$user="scan"
$pass="5anning2022!"
$sharepath="\\172.22.113.179\scanning"
$filepath="$ENV:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\mapscan.bat"

"@ECHO OFF`r`nnet use /d ${driveletter}:`r`nnet use ${driveletter}: $sharepath /user:$user $pass" | Out-File -Encoding ASCII $filepath