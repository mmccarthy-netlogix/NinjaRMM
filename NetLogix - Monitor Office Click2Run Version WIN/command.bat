function Write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "Alert=$message"
    Write-Host '<-End Result->'
    }
$Alert=0

if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun")) {Write-DRMMAlert "Healthy. Office C2R Not Installed"; Exit 0}

$ReportedVersion=$((Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration").VersionToReport)
$BuildMajor=$ReportedVersion.Split(".")[2]
$BuildMinor=$ReportedVersion.Split(".")[3]

if ($BuildMajor -lt $ENV:usrBuildMajor) {$Alert++}
if (($BuildMajor -eq $ENV:usrBuildMajor) -and ($BuildMinor -lt $ENV:usrBuildMinor)) {$Alert++}

if (!$Alert){
  Write-DRMMAlert "Healthy. Minimum version has been met. Reported version is $BuildMajor.$BuildMinor. Minimum version is $ENV:usrBuildMajor.$ENV:usrBuildMinor"
} else {
  Write-DRMMAlert "Not healthy - Reported version is $BuildMajor.$BuildMinor. Minimum version is $ENV:usrBuildMajor.$ENV:usrBuildMinor"
  Exit 1
}