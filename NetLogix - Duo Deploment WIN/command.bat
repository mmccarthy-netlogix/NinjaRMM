$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

## Variable init
$SiteOverride		= $ENV:SiteOverride

if ($SiteOverride="True") {
  Write-Host "Using run-time variables" 
  Write-Host ""
  $IKey			= $ENV:IntegrationKey
  $SKey			= $ENV:SecretKey
  $APIHostname		= $ENV:APIHostname
  $AutoPush		= $ENV:AutoPush
  $FailOpen		= $ENV:FailOpen
  $RDPOnly		= $ENV:RDPOnly
  $SmartCard		= $ENV:SmartCard
  $WrapSmartCard	= $ENV:WrapSmartCard
  $EnableOffline	= $ENV:EnableOffline
  $UsernameFormat	= $ENV:UsernameFormat
  $UAC_ProtectedMode	= $ENV:UAC_ProtectedMode
  $UAC_Offline		= $ENV:UAC_Offline
  $UAC_Offline_Enroll	= $ENV:UAC_Offline_Enroll
}
else {
  Write-Host "Using site variables"
  Write-Host ""
  $IKey			= $ENV:DuoIntegrationKey
  $SKey			= $ENV:DuoSecretKey
  $APIHostname		= $ENV:DuoAPIHostname
  $AutoPush		= $ENV:DuoAutoPush
  $FailOpen		= $ENV:DuoFailOpen
  $RDPOnly		= $ENV:DuoRDPOnly
  $SmartCard		= $ENV:DuoSmartCard
  $WrapSmartCard	= $ENV:DuoWrapSmartCard
  $EnableOffline	= $ENV:DuoEnableOffline
  $UsernameFormat	= $ENV:DuoUsernameFormat
  $UAC_ProtectedMode	= $ENV:DuoUAC_ProtectedMode
  $UAC_Offline		= $ENV:DuoUAC_Offline
  $UAC_Offline_Enroll	= $ENV:DuoUAC_Offline_Enroll
}

## Check and set defaults
# Defaults:
$DefaultAutopush=0 #(0,1)
$DefaultFailOpen=1 #(0,1)
$DefaultRDPOnly=0 #(0,1)
$DefaultSmartCard=0 #(0,1)
$DefaultWrapSmartCard=0 #(0,1)
$DefaultEnableOffline=1 #(0,1)
$DefaultUsernameFormat=1 #(0,1,2)
$DefaultUAC_ProtectedMode=0 #(0,1,2)
$DefaultUAC_Offline=1 #(0,1)
$DefaultUAC_Offline_Enroll=1 #(0,1)

if ($AutoPush -notin 0,1) {$AutoPush=$DefaultAutoPush}
if ($FailOpen -notin 0,1) {$FailOpen=$DefaultFailOpen}
if ($RDPOnly -notin 0,1) {$RDPOnly=$DefaultRDPOnly}
if ($SmartCard -notin 0,1) {$SmartCard=$DefaultSmartCard}
if ($WrapSmartCard -notin 0,1) {$WrapSmartCard=$DefaultWrapSmartCard}
if ($EnableOffline -notin 0,1) {$EnableOffline=$DefaultEnableOffline}
if ($UsernameFormat -notin 0,1,2) {$UsernameFormat=$DefaultUsernameFormat}
if ($UAC_ProtectedMode -notin 0,1,2) {$UAC_ProtectedMode=$DefaultUAC_ProtectedMode}
if ($UAC_Offline -notin 0,1) {$UAC_Offline=$DefaultUAC_Offline}
if ($UAC_Offline_entroll -notin 0,1) {$UAC_Offline_Enroll=$DefaultUAC_Offline_Enroll}


## Variable Check
Write-Host "--Variables--"
Write-Host "Integraton Key: $IKey"
Write-Host "Secret Key: $SKey"
Write-Host "API Hostname: $APIHostname"
Write-Host ""
Write-Host "AutoPush: $AutoPush"
Write-Host "FailOpen: $FailOpen"
Write-Host "RDPOnly: $RDPOnly"
Write-Host "SmartCard: $SmartCard"
Write-Host "WrapSmartCard: $WrapSmartCard"
Write-Host "EnableOffline: $EnableOffline"
Write-Host "UsernameFormat: $UsernameFormat"
Write-Host "UAC_ProtectedMode: $UAC_ProtectedMode"
Write-Host "UAC_Offline: $UAC_Offline"
Write-Host "UAC_Offline_Enroll: $UAC_Offline_Enroll"

if ("" -in $IKey,$SKey,$APIHostname) {
  Write-Host "Integration Key, Secret Key, or API Hostname not set"
  Exit 1
}

if ($NULL -in $IKey,$SKey,$APIHostname) {
  Write-Host "Integration Key, Secret Key, or API Hostname not set"
  Exit 1
}

## Download Duo Installer
  ## Download
  Write-Host "Downloading Duo Installer..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://dl.duosecurity.com/duo-win-login-latest.exe"
  $DLdestination = "$ENV:Temp\DuoInstaller.exe"
  $webclient.DownloadFile($DLsource,$DLdestination)

## Install Duo
  ##Install
  Write-Host "Installing Duo..."
  Start-Process -FilePath $DLdestination -Wait -NoNewWindow -ArgumentList "/S /V"" /qn IKEY=$IKey SKEY=$SKey HOST=$APIHostname AUTOPUSH=""#$AutoPush"" FAILOPEN=""#$FailOpen"" RDPONLY=""#$RDPOnly"" SMARTCARD=""#$Smartard"" ENABLEOFFLINE=""#$EnableOffline"" UAC_PROTECTMODE=""#$UAC_ProtectedMode"" UAC_OFFLINE=""#$UAC_Offline"" UAC_OFFLINE_ENROLL=""#$UAC_Offline_Enroll"""

Remove-Item $DLdestination -Force

$Install = Get-ItemProperty -Path "HKLM:\SOFTWARE\Duo Security\DuoCredProv"

if ($Install -ne $NULL) {
  Write-Host "Installation of Duo Completed Successfully.."
  Exit 0
}
else {
  Write-Host "Installation of Duo Failed.."
  Exit 1
}