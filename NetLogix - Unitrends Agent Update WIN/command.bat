[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$ProgressPreference = 'SilentlyContinue'
$OS64 = [Environment]::Is64BitOperatingSystem
$DLSource = ""
$DLDestination = "C:\Windows\TEMP\Unitrends_Agent.msi"
$msi_args = "-i",$DLDestination,"-q","-norestart","-l*v C:\Windows\temp\UnitrendsAgent.txt"

$Process = @()
$Process = Get-Process | where ProcessName -in "WBPS","UTBlockAgent"
$uninstallGUID = (Get-WmiObject Win32_Product | Where-Object -Property Name -match 'Unitrends Agent').IdentifyingNumber
$uninstallCBTGUID = (Get-WmiObject Win32_Product | Where-Object -Property Name -match 'Unitrends Volume CBT Driver').IdentifyingNumber

if (Test-Path C:\PCBP\auth.dat) {
  Write-Host "Unitrends agent installed is for Direct-to-Cloud (UCB) backups."
  $DLSource = "https://direct.backup.net/download/Unitrends_Agentx64.msi"
  $msi_args += "SVC=d2c"
} else {
  Write-Host "Unitrends agent installed is UEB backups."
  if ($OS64 -eq $True) {
    $DLSource = "https://bpagent.s3.amazonaws.com/latest/windows/Unitrends_Agentx64.msi"
  } else {
    $DLSource = "https://bpagent.s3.amazonaws.com/latest/windows/Unitrends_Agentx86.msi"
  }
}

if ($Process.count -eq 0) {

  Write-Host "Downloading latest Unitrends Agent from $DLSource"

  iwr -uri $DLSource -outfile $DLDestination

# Uninstall should not be necessary for an update
#  if ($uninstallGUID -ne $null) {
#    Write-Host "Removing Unitrends Agent"
#    $msi = Start-Process -FilePath $ENV:WINDIR\System32\msiexec.exe -Wait -NoNewWindow -PassThru -ArgumentList "/x $uninstallGUID /qn /norestart"
#    Write-Host "Removal of Unitrends Agent completed with exit code: $($msi.ExitCode)"
#  }

  Write-Host "Installing latest Unitrends Agent"
  $msi = Start-Process -FilePath $ENV:WINDIR\System32\msiexec.exe -Wait -NoNewWindow -PassThru -ArgumentList $msi_args
  Write-Host "Installing of Unitrends agent completed with exit code: $($msi.ExitCode)"
  Remove-Item $DLDestination -Force

  $Server = ((Get-WMIObject win32_operatingsystem).name -contains "Server")
  $VMMS = ((Get-Service -Name "VMMS" -ErrorAction SilentlyContinue).Status -eq "Running")

  #Uninstall if there is a CBT GUID to uninstall, and the system is not a Server OS running Hyper-V
  if (($uninstallCBTGUID -ne $null) -and !($Server -and $VMMS)) {
    Write-Host "Installing CBT Driver"
    $msi = Start-Process -FilePath $ENV:WINDIR\System32\msiexec.exe -Wait -NoNewWindow -PassThru -ArgumentList "/i C:\PCBP\Installers\uvcbt.msi /quiet /norestart /l*v C:\Windows\temp\UnitrendsCBT.txt"
    Write-Host "Installing of Unitrends CBT driver completed with exit code: $($msi.ExitCode)"
  }
} else {
  Write-Host "Backup currently in progress, exiting"
  Exit 1
}