function isGUID {
  $args[0] -match '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'
}

$companyID=$ENV:CSCompanyID
$clientID=$ENV:CSClientID
$clientSecret=$ENV:CSClientSecret
$err=0
$serviceName = '*cybercns*'

if (!(isGUID $companyID)) {Write-Host "Invalid Company ID $companyID"; $err++}
if (!(isGUID $clientID)) {Write-Host "Invalid Client ID $companyID"; $err++}
if (!(isGUID $clientSecret)) {Write-Host "Invalid Client Secret $companyID"; $err++}

if ($err) {Exit 1}

switch ($ENV:DeploymentType) {
  "Probe" {$arguments = "-i Probe"}
  "Lightweight" {$arguments = "-i LightWeight"}
  "Scan" {$arguments = "-m Scan"}
}

Write-Host "Company ID: $companyID"
Write-Host "Client ID: $clientID"
Write-Host "----------------------------"

if (Get-Service $serviceName -ErrorAction SilentlyContinue) {
  if ((Get-Service $serviceName).Status -eq 'Running') {
    Write-Host "$serviceName found and running."
  } else { 
    Write-Host "$serviceName found, but it is not running."
  }    
} else {
  Write-Host "Downloading ConnectSecure $ENV:DeploymentType Installer"
  $ProgressPreference = 'SilentlyContinue'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $source = (Invoke-RestMethod -Method "Get" -URI "https://configuration.mycybercns.com/api/v3/configuration/agentlink?ostype=windows")
  $destination = 'cybercnsagent.exe'
  Invoke-WebRequest -Uri $source -OutFile $destination

  Write-Host "Installing/running ConnectSecure"
  Start-Process -FilePath ./cybercnsagent.exe -ArgumentList "-c $companyID -a $clientID -s $clientSecret -b portaluseast2.mycybercns.com -e netlogix $arguments" -Wait -NoNewWindow
}