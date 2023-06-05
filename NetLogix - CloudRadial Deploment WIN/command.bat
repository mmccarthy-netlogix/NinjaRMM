$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

##Check for previous install
$Service = Get-Service -Name "CloudRadial" -ErrorAction SilentlyContinue
if ($Service) {
  Write-Host "Cloud Radial Agent already installed"
  Exit 5
}

##Initialize variables
$Failure = 0
if (($ENV:CRDownloadURLSite -eq $null) -or ($ENV:SiteOverride -eq "true")) {
  $DownloadURL = $ENV:CRDownloadURL
}
else {
  $DownloadURL = $ENV:CRDownloadURLSite
}

if ((($ENV:CRCompanyIDSite -eq $null) -or ($ENV:SiteOverride -eq "true")) -and ($ENV:CRCompanyID -ne "0")) {
  $CompanyID = $ENV:CRCompanyID
}
else {
  $CompanyID = $ENV:CRCompanyIDSite
}

Write-Host "Site Variables:"
Write-Host "Download URL: $ENV:CRDownloadURLSite"
Write-Host "Company ID: $ENV:CRCompanyIDSite"
Write-Host ""
Write-Host "Component Variables:"
Write-Host "Download URL: $ENV:CRDownloadURL"
Write-Host "Company ID: $ENV:CRCompanyID"
Write-Host ""
Write-Host "Variables used:"
Write-Host "Download URL: $DownloadURL"
Write-Host "Company ID: $CompanyID"
Write-Host ""

if ($DownloadURL -notmatch "https://itmedia.azureedge.net") {
  Write-Host "Invalid URL: $DownloadURL"
  ++$Failure
}

if ($CompanyID -lt 1) {
  Write-Host "Invalid Company ID: $CompanyID"
  ++$Failure
}

if ($Failure) {Exit $failure}


##Download Cloud Radial Installer
  ##Download
  Write-Host "Downloading Cloud Radial Agent Installer..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = $DownloadURL
  $DLdestination = "$ENV:Temp\CloudRadial.exe"
  $webclient.DownloadFile($DLsource,$DLdestination)

##Install Cloud Radial Installer
  ##Install
  Write-Host "Installing Cloud Radial Agent..."
  Start-Process -FilePath $DLdestination -ArgumentList "/verysilent","/companyid=$CompanyID" -Wait -NoNewWindow

Remove-Item $DLdestination -Force

Start-Sleep 30

$Service = Get-Service -Name "CloudRadial" -ErrorAction SilentlyContinue

if ($Service.Status -eq "Running") {
  Write-Host "Installation of Cloud Radial Agent Completed Successfully.."
  Exit 0
}
else {
  Write-Host "Installation of Cloud Radial Agent Failed.."
  Exit 1
}