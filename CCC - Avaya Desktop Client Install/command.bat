# .net 4.6.2		
Write-Host "Installing .NET Framework 4.6.2"
Start-Process -FilePath "\\INF01AGW1P\Software\Avaya\New ACCS\AAAD Prerequisites\Microsoft Dot NET Framework 4.6.2\NDP462-KB3151800-x86-x64-AllOS-ENU.exe" -Wait -ArgumentList "/q /norestart /log ""%WINDIR%\Temp\DotNET462-Install.log"""

# .net 4.8		
Write-Host "Installing .NET Framework 4.8"
Start-Process -FilePath "\\INF01AGW1P\Software\Avaya\New ACCS\AAAD Prerequisites\Microsoft Dot NET Framework 4.8\ndp48-x86-x64-allos-enu.exe" -Wait -ArgumentList "/q /norestart /log ""%WINDIR%\Temp\DotNET48-Install.log"""

# Remove WebView2
$swList=Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*WebView2*"}
foreach ($sw in $swList) {
  $swName=$sw.DisplayName
  Write-Host "- Uninstalling $swName..."
  Start-Process "C:\Windows\System32\cmd.exe" "/c $($sw.UninstallString) --force-uninstall" -Wait -NoNewWindow
}

# Edge WebView2		
Write-Host "Installing Microsoft Edge WebView2"
Start-Process -FilePath "\\INF01AGW1P\Software\Avaya\New ACCS\AAAD Prerequisites\Microsoft Edge WebView2 Runtime Installer X86\MicrosoftEdgeWebView2RuntimeInstallerX86.exe" -Wait -ArgumentList "/silent /install"

# VC++ 2017 redist	
Write-Host "Installing Visual C++ Redistributable"
Start-Process -FilePath "\\INF01AGW1P\Software\Avaya\New ACCS\AAAD Prerequisites\Microsoft Visual C++ 2017 Redistributable Package x86\VC_redist.x86.exe" -Wait -ArgumentList "/install /quiet /norestart /log ""%WINDIR%\Temp\VC2015-2019x86.log"""

# ActiveX Controls	
Write-Host "Installing Avaya CCMA ActiveX Controls"
Start-Process -FilePath "\\INF01AGW1P\Software\Avaya\New ACCS\ActiveX Controls\ActiveX Controls\ActiveX Controls.msi" -Wait -ArgumentList "/qn /norestart"

# AvayaAgentDesktopClient	
Write-Host "Installing Avaya Desktop Client"
Start-Process -FilePath "\\INF01AGW1P\Software\Avaya\New ACCS\AvayaAgentDesktopClient.msi" -Wait -ArgumentList "/quiet /log ""products.log"" AAADSOFTPHONE=0 MMSERVERNAME=172.16.20.24 AAADUSEHTTPS=FALSE"
