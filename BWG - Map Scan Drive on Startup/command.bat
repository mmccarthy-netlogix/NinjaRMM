$user="BWG\bwg"
$pass="*FallMigration2022*"
$filepath="$ENV:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\mapscan.bat"

"@ECHO OFF" | Out-File -Encoding ASCII $filepath
"net use /d R:" | Out-File -Encoding ASCII $filepath -Append
"net use /d S:" | Out-File -Encoding ASCII $filepath -Append
"net use /d T:" | Out-File -Encoding ASCII $filepath -Append
"net use /d W:" | Out-File -Encoding ASCII $filepath -Append
"net use R: \\192.168.7.8\rackwin /user:$user $pass" | Out-File -Encoding ASCII $filepath -Append
"net use S: \\192.168.7.8\scans /user:$user $pass" | Out-File -Encoding ASCII $filepath -Append
"net use T: \\192.168.7.8\winrater /user:$user $pass" | Out-File -Encoding ASCII $filepath -Append
"net use W: \\192.168.7.8\workcomp /user:$user $pass" | Out-File -Encoding ASCII $filepath -Append
