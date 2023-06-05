$filepath="$ENV:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\mapscan.bat"

"@ECHO OFF`r`nnet use /d M:`r`nnet use M: \\MPS-DC01\Data2\MPSData " | Out-File -Encoding ASCII $filepath
"net use /d W:`r`nnet use W: \\MPS-DC01\working " | Out-File -Append -Encoding ASCII $filepath