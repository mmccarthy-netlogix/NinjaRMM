$driveletter="M"
$user="october\mhxcoaccess"
$pass="Pokanuv?31"
$sharepath="\\192.168.41.88\acctng\MHXCO\General"
$filepath="$ENV:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\mapscan.bat"

"@ECHO OFF`r`nnet use /d ${driveletter}:`r`nnet use ${driveletter}: $sharepath /user:$user $pass" | Out-File -Encoding ASCII $filepath