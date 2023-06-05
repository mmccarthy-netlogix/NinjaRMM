#Dell Digital Delivery Services
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{CF95CED4-3A1E-4486-B7FA-428C25D617ED}
Write-Host "Removing Dell Digital Delivery Services"
Start-Process -FilePath "$ENV:SystemRoot\System32\MsiExec.exe" -ArgumentList "/X{CF95CED4-3A1E-4486-B7FA-428C25D617ED} -qn -norestart" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Dell Display Manager 2.0
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Dell Display Manager 2.0
Write-Host "Removing Dell Display Manager 2.0"
Start-Process "C:\Program Files\Dell\Dell Display Manager 2.0\uninst.exe" -ArgumentList "/S" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Dell Optimizer
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{1344E072-D68B-48FF-BD2A-C1CCCC511A50}
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{E27862BD-4371-4245-896A-7EBE989B6F7F}
Write-Host "Removing Dell Optimizer"
Start-Process -FilePath "$ENV:SystemRoot\System32\MsiExec.exe" -ArgumentList "/X{1344E072-D68B-48FF-BD2A-C1CCCC511A50} -qn -norestart" -Wait -NoNewWindow
Start-Process -FilePath "$ENV:SystemRoot\System32\MsiExec.exe" -ArgumentList "/X{E27862BD-4371-4245-896A-7EBE989B6F7F} -qn -norestart" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Dell Optimizer Service
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{286A9ADE-A581-43E8-AA85-6F5D58C7DC88}
Write-Host "Removing Dell Optimizer Service"
Start-Process -FilePath "C:\Program Files (x86)\InstallShield Installation Information\{286A9ADE-A581-43E8-AA85-6F5D58C7DC88}\DellOptimizer.exe" -ArgumentList "-remove -runfromtemp -silent" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Dell Peripheral Manager
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Dell Peripheral Manager
Write-Host "Removing Dell Peripheral Manager"
Start-Process -FilePath "C:\Program Files\Dell\Dell Peripheral Manager\Uninstall.exe" -ArgumentList "/S" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Dell SupportAssist
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{82B84211-71FD-4AB7-87D1-68568646860F}
Write-Host "Removing Dell SupportAssist"
Start-Process -FilePath "$ENV:SystemRoot\System32\MsiExec.exe" -ArgumentList "/X{82B84211-71FD-4AB7-87D1-68568646860F} -qn -norestart" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Dell SupportAssist OS Recovery Plugin for Dell Update
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{5B678BC6-D551-458B-893D-B442B21ECD21}
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{dc44ee3f-d6c1-444d-a660-b0f1ac90b51d}
Write-Host "Removing Dell SupportAssist OS Recovery Plugin for Dell Update"
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$app = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty | Where-Object {$_.DisplayName -match "Dell SupportAssist OS Recovery Plugin for Dell Update" }
Start-Process -FilePath "$ENV:SystemRoot\System32\MsiExec.exe" -ArgumentList "/X$($app.PSChildName) -qn -norestart" -Wait -NoNewWindow
$RegPath = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$app = Get-ChildItem -Path $RegPath | Get-ItemProperty | Where-Object {$_.DisplayName -match "Dell SupportAssist OS Recovery Plugin for Dell Update" }
$uninstall=$app.QuietUninstallString.Split("/")
Start-Process -FilePath $uninstall[0] -ArgumentList "/$($uninstall[1]) /$($uninstall[2])" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Dell SupportAssist Remediation -
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{DEF2160E-12B6-477C-9D55-DF4B100E3E2B} 
#Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{9dd30d6d-7999-4e32-9295-a2d7ece703ba}
Write-Host "Removing Dell SupportAssist Remediation"
Start-Process -FilePath "$ENV:SystemRoot\System32\MsiExec.exe" -ArgumentList "/X{DEF2160E-12B6-477C-9D55-DF4B100E3E2B} -qn -norestart" -Wait -NoNewWindow
Start-Process -FilePath "C:\ProgramData\Package Cache\{9dd30d6d-7999-4e32-9295-a2d7ece703ba}\DellSupportAssistRemediationServiceInstaller.exe" -ArgumentList "/uninstall /quiet" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Microsoft OneDrive - 
Write-Host "Removing Microsoft OneDrive"
Start-Process -FilePath "$ENV:systemroot\System32\taskkill.exe" -ArgumentList "/im OneDrive.exe /f" -Wait -NoNewWindow
Start-Process -FilePath "$ENV:systemroot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait -NoNewWindow
Write-Host "----------------------------------------"

#Microsoft 365 (Office) - 
Write-Host "Removing Microsoft 365 (Office)"
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.MicrosoftOfficeHub"} | Remove-ProvisionedAppxPackage -Online
Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq "Microsoft.MicrosoftOfficeHub"} | Remove-AppxPackage -AllUsers
Write-Host "----------------------------------------"

#OneNote for Windows 10 - 
Write-Host "Removing OneNote for Windows 10"
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.Office.OneNote"} | Remove-ProvisionedAppxPackage -Online
Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq "Microsoft.Office.OneNote"} | Remove-AppxPackage -AllUsers
Write-Host "----------------------------------------"

#Dell Optimizer - 
Write-Host "Removing Dell Optimizer"
Get-AppxPackage | where {$_.Name -match "DellInc.DellOptimizer"} | Remove-AppxPackage
Write-Host "----------------------------------------"

#Dell Digital Delivery - 
Write-Host "Removing Dell Digital Delivery"
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "DellInc.DellDigitalDelivery"} | Remove-ProvisionedAppxPackage -Online
Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq "DellInc.DellDigitalDelivery"} | Remove-AppxPackage -AllUsers
Write-Host "----------------------------------------"

#Partner Promo - 
Write-Host "Removing Partner Promo"
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "DellInc.PartnerPromo"} | Remove-ProvisionedAppxPackage -Online
Get-AppxPackage -AllUsers | Where-Object {$_.Name -eq "DellInc.PartnerPromo"} | Remove-AppxPackage -AllUsers
Write-Host "----------------------------------------"

#SupportAssist - 
Write-Host "Removing SupportAssist"
Get-AppxPackage | where {$_.Name -match "SupportAssist"} | Remove-AppxPackage
Write-Host "----------------------------------------"
