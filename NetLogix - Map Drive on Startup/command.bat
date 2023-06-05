$driveletter="$ENV:usrDrive"
$user="$ENV:usrUser"
$pass="$ENV:usrPassword"
$sharepath="$ENV:usrSharePath"
$filepath="$ENV:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\mapdrive.bat"

"@ECHO OFF`r`nnet use /d ${driveletter}:`r`nnet use ${driveletter}: $sharepath /user:$user $pass" | Out-File -Encoding ASCII $filepath