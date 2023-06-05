$arguments = "--silent --desktop_shortcut --gsuite_shortcuts=false"
$ProgressPreference = 'SilentlyContinue'

#Force PowerShell to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Download of the Google Drive Desktop Installer
Write-Host ""
Write-Host "Downloading Google Drive Desktop Installer"
Invoke-WebRequest -Uri "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe" -OutFile GoogleDriveSetup.exe
if ((Test-Path GoogleDriveSetup.exe) -eq "True"){
		Write-Host "--Google Drive Desktop Installer Downloaded Successfully"
}
else {
	Write-Host "--Google Drive Desktop Installer Did Not Download - Please check Firewall or Web Filter"
	Exit 1
}

# This Section starts the installer using the arguments defined above
Write-Host ""
Write-Host "Installing Google Drive Desktop:"
Write-Host ""
Write-Host "GoogleDriveSetup.exe "$arguments""
Write-Host ""

Start-Process GoogleDriveSetup.exe $arguments

$timeout = new-timespan -Minutes 5
$install = [diagnostics.stopwatch]::StartNew()
while ($install.elapsed -lt $timeout){
    if ((Get-Process "GoogleDriveFS" -ea SilentlyContinue)){
	Write-Host "Google Drive Running - Breaking the Loop"
	Break
	}
    start-sleep -seconds 60
}

if (!(Get-Process "GoogleDriveFS" -ea SilentlyContinue)){Exit 1}

Write-Host ""
Write-Host "Google Drive Setup Completed"