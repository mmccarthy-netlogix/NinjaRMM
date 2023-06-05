#$ENV:NDConnectorID = Variable set within DattoRMM with the Network Detective Connector ID for the site.
$OS64 = [Environment]::Is64BitOperatingSystem
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"


##Check Variables
  ##Variables
  Write-Host "Checking Connector ID..."
  if ($ENV:NDConnectorID -match '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$') {Write-Host 'Using connector:' $ENV:NDConnectorID}
    else {Write-Host 'Invalid connector:' $ENV:NDConnectorID;Exit 1}

$locNL = "C:\NetLogix\packages"
$locND = "$locNL\ND"
$locNDConnector = "$locNL\NDConnector"
$locNDScans = "$locNL\NDScans"

New-Item -ItemType "directory" -Path $locNL -Force | Out-Null
New-Item -ItemType "directory" -Path $locND -Force | Out-Null
New-Item -ItemType "directory" -Path $locNDConnector -Force | Out-Null
New-Item -ItemType "directory" -Path $locNDScans -Force | Out-Null

##Download Network Detective
  ##Download
  Write-Host "Downloading Rapid Fire Tools Network Detective..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://s3.amazonaws.com/networkdetective/download/NetworkDetectiveDataCollector.exe"
  $DLdestination = "$locNL\ND.zip"
  $webclient.DownloadFile($DLsource,$DLdestination)

  ##Extract
  Write-Host "Extracting Rapid Fire Tools Network Detective..."
  if (Test-Path $locND) {Remove-Item $locND -Recurse -ErrorAction SilentlyContinue}
  [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
  #Unzip the file
  [System.IO.Compression.ZipFile]::ExtractToDirectory($DLdestination, $locND)

  #check for $locND\nddc.exe and $locND\sddc.exe
  if (!(Test-Path "$locND\nddc.exe")) {Write-Host "Extract of $DLDestination failed"; Exit 1}

##Download Network Detective Connector
  ##Download
  Write-Host "Downloading Rapid Fire Tools Network Detective Connector..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://s3.amazonaws.com/networkdetective/download/NetworkDetectiveConnector.zip"
  $DLdestination = "$locNL\NDConnector.zip"
  $webclient.DownloadFile($DLsource,$DLdestination)

  ##Extract
  Write-Host "Extracting Rapid Fire Tools Network Detective Connector..."
  if (Test-Path $locNDConnector) {Remove-Item $locNDConnector -Recurse -ErrorAction SilentlyContinue}
  [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
  #Unzip the file
  [System.IO.Compression.ZipFile]::ExtractToDirectory($DLdestination, $locNDConnector)

  #check for $locNDConnector\ndconnector.exe
  if (!(Test-Path "$locNDConnector\ndconnector.exe")) {Write-Host "Extract of $DLDestination failed"; Exit 1}


#Run ND Scan
  #Prepare $outbase to include the computer name and current date
  $computername = $ENV:COMPUTERNAME
  $date = (Get-Date -UFormat "%Y%m%d")
  $outbase =  'ND-'+$computername+'-'+$date

  #Run Computer Scan
  Write-Host "Running Computer Scan..."
  Start-Process -FilePath "$locND\nddc.exe" -ArgumentList "-comment 'Scan performed by NetLogix'","-workdir $locNDScans","-outbase $outbase","-outdir $locNDScans","-local","-silent" -Wait -NoNewWindow
  #Run Security Scan
  Write-Host "Running Security Scan..."
  Start-Process -FilePath "$locND\sddc.exe" -ArgumentList "-comment 'Scan performed by NetLogix'","-workdir $locNDScans","-sdfbase $outbase","-sdfdir $locNDScans","-testPorts","-testUrls","-policies","-usb","-wifi","-screensaver","-nozip" -Wait -NoNewWindow

#check for NL-$COMPUTERNAME$-$DATE$.cdf and ND-$COMPUTERNAME$-$DATE$.sdf files
  if (!(Test-Path "$locNDScans\"$outbase.cdf)) {Write-Host "$outbase.cdf missing"; Exit 1}
  if (!(Test-Path "$locNDScans\"$outbase.sdf)) {Write-Host "$outbase.sdf missing"; Exit 1}

#Upload files with ND Connector utility
  Write-Host "Running Computer Scan..."
  Start-Process -FilePath "$locNDConnector\ndconnector.exe" -ArgumentList "-id $ENV:NDConnectorID","-d $locNDScans","-zipname ND-$computername-$date.zip" -Wait -NoNewWindow

#Clean Up
  Remove-Item $locND -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNDConnector -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNDScans -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNL\ND.zip -ErrorAction SilentlyContinue
  Remove-Item $locNL\NDConnector.zip -ErrorAction SilentlyContinue