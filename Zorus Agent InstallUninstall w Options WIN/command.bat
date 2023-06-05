$tls = "Tls";
[System.Net.ServicePointManager]::SecurityProtocol = $tls;

If ($env:HideTrayIcon -eq $TRUE) {
    $trayIcon = 1;
} Else {
    $trayIcon = 0;
}

If ($env:HideAddRemove -eq $TRUE) {
    $addRemove = 1;
} Else {
    $addRemove = 0;
}

#Check for the Site Variables
Write-Host ""
Write-Host "Checking the Variables"

if ($ENV:ArchonToken -eq $null)
	{Write-Host "--Customer Token Not Set or Missing"
	Exit 1}
else
	{Write-Host "Token = "$ENV:ArchonToken""}


If ($env:Install -eq $TRUE) {
    $source = "http://static.zorustech.com.s3.amazonaws.com/downloads/ZorusInstaller.exe";
    $destination = "$env:TEMP\ZorusInstaller.exe";

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($source, $destination)

    Write-Host "Downloading Zorus Archon Agent..."

    If ([string]::IsNullOrEmpty($env:Password)) {
        Write-Host "Installing Zorus Archon Agent..."
        Start-Process -FilePath $destination -ArgumentList "/qn","ARCHON_TOKEN=$env:ArchonToken","HIDE_TRAY_ICON=$trayIcon","HIDE_ADD_REMOVE=$addRemove"  -Wait
    } Else {
        Write-Host "Installing Zorus Archon Agent with password..."
        Start-Process -FilePath $destination -ArgumentList "/qn","ARCHON_TOKEN=$env:ArchonToken","UNINSTALL_PASSWORD=$env:Password","HIDE_TRAY_ICON=$trayIcon","HIDE_ADD_REMOVE=$addRemove"  -Wait
    }

    Write-Host "Removing Installer..."
    Remove-Item -recurse $destination
    Write-Host "Job Complete!"
} Else {
    $source = "http://static.zorustech.com.s3.amazonaws.com/downloads/ZorusAgentRemovalTool.exe";
    $destination = "$env:TEMP\ZorusAgentRemovalTool.exe";

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($source, $destination)

    Write-Host "Downloading Zorus Agent Removal Tool..."

    If ([string]::IsNullOrEmpty($env:Password)) {
        Write-Host "Uninstalling Zorus Archon Agent..."
        Start-Process -FilePath $destination -ArgumentList "-s" -Wait
    } Else {
        Write-Host "Uninstalling Zorus Archon Agent with password..."
        Start-Process -FilePath $destination -ArgumentList "-s", "-p $env:Password"  -Wait
    }

    Write-Host "Removing Uninstaller..."
    Remove-Item -recurse $destination
    Write-Host "Job Complete!"
}