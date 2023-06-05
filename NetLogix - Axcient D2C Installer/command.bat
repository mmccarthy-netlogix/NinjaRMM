$AgentDownloadURL="https://rb-edandt1.rb.slc.efscloud.net/agent/agentInstaller.msi"
$AgentInstaller=".\agentInstaller.msi"
$Arguments="/i agentInstaller /quiet "

[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
$WebClient = New-Object System.Net.WebClient; $WebClient.DownloadFile($AgentDownloadURL,$AgentInstaller)

if (!(Test-Path $AgentInstaller)) {
  Write-Host "Download failed"
  Exit 1
}

if ($ENV:usrTokenID.Length -eq 32) {$Arguments += "TOKENID=$ENV:usrTokenID "}

if ($ENV:usrPassword -ne "none") {$Arguments += " PASSWORD=$ENV:usrPassword "}

if ($ENV:usrVolumes -ne "all") {$Arguments += " BACKUP_VOLUMES=$ENV:usrVolumes "}

Write-Host "Starting Axcient D2C Agent Installer...."
Write-Host "Using arguments: $Arguments"

Start-Process $ENV:WinDir\System32\msiexec.exe -ArgumentList $Arguments -NoNewWindow -Wait

Start-Sleep 10

Write-Host "----------------------------------------"
Write-Host "Checking for Axcient Services"

if ((Get-Service ReplibitAgentService) -and (Get-Service ReplibitUpdaterService) -and (Get-Service ReplibitManagementService)) {
  Write-Host "Install complete"
  Exit 0
} else {
  Write-Host "Installation incomplete"
  Exit 1
}