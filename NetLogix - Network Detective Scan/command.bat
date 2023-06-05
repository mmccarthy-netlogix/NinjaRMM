##Variables used
##NDConnectorID
##NDExternalDomains
##NDIPRanges
##NDSNMPCommunityStrings

##Input Variables
##NDSkipAD
##NDSkipEventLogs
##NDSkipSQL
##NDSkipInternetAvailability
##NDSkipInternetSpeedTest
##NDSkipDHCP
##NDSkipWHOIS
##NDSkipIPScan

$OS64 = [Environment]::Is64BitOperatingSystem
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

##Check Connector ID
  Write-Host "Checking Connector ID..."
  if ($ENV:NDConnectorID -match '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$') {Write-Host 'Using connector:' $ENV:NDConnectorID}
    else {Write-Host 'Invalid connector:' $ENV:NDConnectorID;Exit 1}

##Check if running on PDC Emulator
  Import-Module ActiveDirectory -ErrorAction SilentlyContinue
  if ((Get-Module -Name ActiveDirectory) -eq $null) {
    Write-Host "ActiveDirectory PowerShell module not installed"
    $ADModule = $False
  }
  else {$ADModule = $True}

  if ($ADModule) {
    $PDCEmulator = ((Get-ADDomain | Select PDCEmulator).pdcemulator).split(".")[0]
    if ($PDCEmulator -eq $ENV:computername) {
      Write-Host "Running on detected PDC Emulator:" $PDCEmulator
      $PDC = $True
    }
    else {
      Write-Host "Not running on detected PDC Emulator:" $PDCEmulator
      $PDC = $False
    }
  }

$locNL = "C:\NetLogix\packages"
$locND = "$locNL\ND"
$locNDConnector = "$locNL\NDConnector"
$locNDScans = "$locNL\NDScans"

New-Item -ItemType "directory" -Path $locNL -Force | Out-Null
New-Item -ItemType "directory" -Path $locND -Force | Out-Null
New-Item -ItemType "directory" -Path $locNDConnector -Force | Out-Null
New-Item -ItemType "directory" -Path $locNDScans -Force | Out-Null

##Download Network Detective
  #Download
  Write-Host "Downloading Rapid Fire Tools Network Detective..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://s3.amazonaws.com/networkdetective/download/NetworkDetectiveDataCollector.exe"
  $DLdestination = "$locNL\ND.zip"
  $webclient.DownloadFile($DLsource,$DLdestination)

  #Extract
  Write-Host "Extracting Rapid Fire Tools Network Detective..."
  if (Test-Path $locND) {Remove-Item $locND -Recurse -ErrorAction SilentlyContinue}
  [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
  #Unzip the file
  [System.IO.Compression.ZipFile]::ExtractToDirectory($DLdestination, $locND)

  #check for $locND\nddc.exe and $locND\sddc.exe
  if (!(Test-Path "$locND\nddc.exe")) {Write-Host "Extract of $DLDestination failed"; Exit 1}

##Download Network Detective Connector
  #Download
  Write-Host "Downloading Rapid Fire Tools Network Detective Connector..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://s3.amazonaws.com/networkdetective/download/NetworkDetectiveConnector.zip"
  $DLdestination = "$locNL\NDConnector.zip"
  $webclient.DownloadFile($DLsource,$DLdestination)

  #Extract
  Write-Host "Extracting Rapid Fire Tools Network Detective Connector..."
  if (Test-Path $locNDConnector) {Remove-Item $locNDConnector -Recurse -ErrorAction SilentlyContinue}
  [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
  #Unzip the file
  [System.IO.Compression.ZipFile]::ExtractToDirectory($DLdestination, $locNDConnector)

  #check for $locNDConnector\ndconnector.exe
  if (!(Test-Path "$locNDConnector\ndconnector.exe")) {Write-Host "Extract of $DLDestination failed"; Exit 1}

##Prepare $outbase to include the computer name and current date
  $computername = $ENV:COMPUTERNAME
  $date = (Get-Date -UFormat "%Y%m%d")
  if ($PDC) {
    $outbase =  'ADND-'+$computername+'-'+$date
  }
  else {
    $outbase =  'ND-'+$computername+'-'+$date
  }


##PDC - Check Variables
  if ($PDC) {
    #-skipadcomputers is used by default because the local scan should be run against individual machines.
    $arguments = "-comment 'Scan performed by NetLogix' -workdir $locNDScans -outbase $outbase -outdir $locNDScans -silent -skipadcomputers " + $arguments

    if ($ENV:NDSNMPCommunityStrings -eq $null) 		{$CommunityStrings = "public,private,notpublic"}
      else {$CommunityStrings = $ENV:NDSNMPCommunityStrings}
    if ($ENV:NDIPRanges -ne $null) 			{$arguments = $arguments + " -net -ipranges $ENV:NDIPRanges -threads 20"}
    if (!($ENV:NDSkipAD -eq "true")) 			{$arguments = $arguments + " -ad -addc $PDCEmulator"}
    if (!($ENV:NDSkipEventLogs -eq "true")) 		{$arguments = $arguments + " -eventlogs"}
    if (!($ENV:NDSkipSQL -eq "true")) 			{$arguments = $arguments + " -sql"}
    if (!($ENV:NDSkipInternetAvailability -eq "true")) 	{$arguments = $arguments + " -internet"}
    if (!($ENV:NDSkipInternetSpeedTest -eq "true")) 	{$arguments = $arguments + " -speedchecks"}
    if (!($ENV:NDSkipDHCP -eq "true")) 			{$arguments = $arguments + " -dhcp"}
    if (!($ENV:NDSkipWHOIS -eq "true")) 		{$arguments = $arguments + " -whois -externaldomains $ENV:NDExternalDomains -idagent"}
    if (!($ENV:NDSkipIPScan -eq "true")) 		{$arguments = $arguments + " -snmp $CommunityStrings"}
  }
  else {
    $arguments = "-comment 'Scan performed by NetLogix' -workdir $locNDScans -outbase $outbase -outdir $locNDScans -local -silent"
  }

##Run ND Scan
  #Run Computer Scan
  Write-Host "Running Network Scan..."
  Write-Host "Using the following arguments: " $arguments
  Start-Process -FilePath "$locND\nddc.exe" -ArgumentList $arguments -Wait -NoNewWindow
  #Run Security Scan
  Write-Host "Running Security Scan..."
  Start-Process -FilePath "$locND\sddc.exe" -ArgumentList "-comment 'Scan performed by NetLogix' -workdir $locNDScans -sdfbase $outbase -sdfdir $locNDScans -testPorts -testUrls -policies -usb -wifi -screensaver -nozip" -Wait -NoNewWindow

#check for NL-$COMPUTERNAME$-$DATE$.cdf and ND-$COMPUTERNAME$-$DATE$.sdf files
  if ($PDC) {
    if (!(Test-Path "$locNDScans\"$outbase.ndf)) {Write-Host "$outbase.ndf missing"; Exit 1}
  }
  else {
    if (!(Test-Path "$locNDScans\"$outbase.cdf)) {Write-Host "$outbase.cdf missing"; Exit 1}
  }  
  if (!(Test-Path "$locNDScans\"$outbase.sdf)) {Write-Host "$outbase.sdf missing"; Exit 1}

#Upload files with ND Connector utility
  Write-Host "Running Computer Scan..."
  Start-Process -FilePath "$locNDConnector\ndconnector.exe" -ArgumentList "-id $ENV:NDConnectorID","-d $locNDScans","-zipname $outbase.zip" -Wait -NoNewWindow

#Clean Up
  Remove-Item $locND -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNDConnector -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNDScans -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNL\ND.zip -ErrorAction SilentlyContinue
  Remove-Item $locNL\NDConnector.zip -ErrorAction SilentlyContinue