$Service=Get-Service $ENV:ServiceName

Write-Host "---------------------------------------------"
Write-Host "Component run started at: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss")"
Write-Host "$ENV:ServiceName status: $($Service.Status)"
Write-Host "---------------------------------------------"

if ($Service.Status -eq "Stopped") {
  if ($ENV:StartIfStopped -eq "TRUE") { 
    Write-Host "Starting Service $ENV:ServiceName"
    Start-Service $ENV:ServiceName
  }
}

if ($Service.Status -eq "Running") {
  Write-Host "Restarting service $ENV:ServiceName"
  Restart-Service $ENV:ServiceName
}

$Service=Get-Service $ENV:ServiceName

Write-Host "---------------------------------------------"
Write-Host "$ENV:ServiceName status: $($Service.Status)"
Write-Host "Component run ended at: $(Get-Date -Format "MM/dd/yyyy HH:mm:ss")"
Write-Host "---------------------------------------------"
