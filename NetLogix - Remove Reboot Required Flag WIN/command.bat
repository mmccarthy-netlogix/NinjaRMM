# Remove Windows Update RebootRequired registry key
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired\" -Name "abcd1234-1234-1234-1234-abcd12345678" -Force
