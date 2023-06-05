if (!(Test-Path HKCU:\Software\Microsoft\Exchange)) { New-Item -Path HKCU:\Software\Microsoft\Exchange -Force }
if (!(Test-Path HKCU:\Software\Microsoft\Office\15.0\Common\Identity\)) { New-Item -Path HKCU:\Software\Microsoft\Office\15.0\Common\Identity -Force }

Set-ItemProperty -Path HKCU:\Software\Microsoft\Exchange\ -Name AlwaysUseMSOAuthForAutoDiscover -Value 1 -Type DWORD
Set-ItemProperty -Path HKCU:\Software\Microsoft\Office\15.0\Common\Identity\ -Name EnableADAL -Value 1 -Type DWORD
Set-ItemProperty -Path HKCU:\Software\Microsoft\Office\15.0\Common\Identity\ -Name Version -Value 1 -Type DWORD