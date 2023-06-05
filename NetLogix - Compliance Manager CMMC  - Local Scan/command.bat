#$ENV:CMConnectorID = Variable set within DattoRMM with the Network Detective Connector ID for the site.
$OS64 = [Environment]::Is64BitOperatingSystem
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"


##Check Variables
  ##Variables
  Write-Host "Checking Connector ID..."
  if ($ENV:CMConnectorID -match '^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$') {Write-Host 'Using connector:' $ENV:CMConnectorID}
    else {Write-Host 'Invalid connector:' $ENV:CMConnectorID;Exit 1}

$locNL = "C:\NetLogix\packages"
$locCM = "$locNL\CM"
$locNDConnector = "$locNL\NDConnector"
$locCMScans = "$locNL\CMScans"

New-Item -ItemType "directory" -Path $locNL -Force | Out-Null
New-Item -ItemType "directory" -Path $locCM -Force | Out-Null
New-Item -ItemType "directory" -Path $locNDConnector -Force | Out-Null
New-Item -ItemType "directory" -Path $locCMScans -Force | Out-Null

##Download Network Detective
  ##Download
  Write-Host "Downloading Rapid Fire Tools CMMC Local Data Collector..."
  $webclient = New-Object System.Net.WebClient
  $DLsource = "https://networkdetective.s3.amazonaws.com/download/ComplianceManagerDataCollector.exe"
  $DLdestination = "$locNL\CM.zip"
  $webclient.DownloadFile($DLsource,$DLdestination)

  ##Extract
  Write-Host "Extracting Rapid Fire Tools CMMC Local Data Collector..."
  if (Test-Path $locCM) {Remove-Item $locCM -Recurse -ErrorAction SilentlyContinue}
  [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
  #Unzip the file
  [System.IO.Compression.ZipFile]::ExtractToDirectory($DLdestination, $locCM)

  #check for $locCM\nddc.exe and $locCM\sddc.exe
  if (!(Test-Path "$locCM\cmlocaldc.exe")) {Write-Host "Extract of $DLDestination failed"; Exit 1}

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
  $outbase =  'CM-'+$computername+'-'+$date

  #Run Computer Scan
  Write-Host "Running CMMC Local Data Collector..."
  if ($ENV:CMDeepScan -eq "true") {
    Write-Host "Running Deep Scan"
    Start-Process -FilePath "$locCM\cmlocaldc.exe" -ArgumentList "-outbase $outbase","-outdir $locCMScans","-deep" -Wait -NoNewWindow
  }
    else {
      Write-Host "Running Quick Scan"
    Start-Process -FilePath "$locCM\cmlocaldc.exe" -ArgumentList "-outbase $outbase","-outdir $locCMScans" -Wait -NoNewWindow
    }

#check for NL-$COMPUTERNAME$-$DATE$.cdf and ND-$COMPUTERNAME$-$DATE$.sdf files
  if (!(Test-Path $locCMScans\$outbase.zip)) {Write-Host "$outbase.zip missing"; Exit 1}

#Upload files with ND Connector utility
  Write-Host "Uploading data using NDConnector Utility..."
  Start-Process -FilePath "$locNDConnector\ndconnector.exe" -ArgumentList "-cm","-id $ENV:CMConnectorID","-d $locCMScans" -Wait -NoNewWindow

#Clean Up
  Remove-Item $locCM -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNDConnector -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locCMScans -Recurse -ErrorAction SilentlyContinue
  Remove-Item $locNL\CM.zip -ErrorAction SilentlyContinue
  Remove-Item $locNL\NDConnector.zip -ErrorAction SilentlyContinue