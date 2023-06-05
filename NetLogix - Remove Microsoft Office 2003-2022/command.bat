$processes=@("lync", "winword", "excel", "msaccess", "mstore", "infopath", "setlang", "msouc", "ois", "onenote", "outlook", "powerpnt", "mspub", "groove", "visio", "winproj", "graph", "teams")

# Download and extract the latest SARA for Office removal
$WebClient = New-Object System.Net.WebClient; $WebClient.DownloadFile("https://aka.ms/SaRA_CommandLineVersionFiles","$ENV:Windir\TEMP\SARA.zip"
)
Expand-Archive "$ENV:Windir\TEMP\SARA.zip" "$ENV:Programdata\CentraStage\NetLogix\SARA" -Force

# Verify files extracted
if (!(Test-Path -Path "$ENV:Programdata\CentraStage\NetLogix\SARA\SaRACmd.exe")) {
  Write-Host "Extraction of archive failed!"
  Exit 1
}

# Stop all running MS Office applications
Write-Host "Terminating running MS Office applications"
foreach ($process in $processes) {
  Write-Host "Attempting to terminate $process.exe"
  Stop-Process -Name "$process.exe" -Force -ErrorAction:SilentlyContinue
}

# Run SARA to remove all MS Office applications
$Command="$ENV:Programdata\CentraStage\NetLogix\SARA\SaRACmd.exe"
$Parameters="-S OfficeScrubScenario –AcceptEula"
Start-Process -FilePath $Command -ArgumentList $Parameters -NoNewWindow -PassThru

# Cleanup
Remove-Item $ENV:ProgramData\CentraStage\NetLogix\SARA -Recurse -Force
Remove-Item $ENV:Windir\TEMP\SARA.zip -Force

<#
.\Remove-PreviousOfficeInstalls.ps1 -quiet $true -Remove2016Installs $true -RemoveClickToRunVersions $true
#>