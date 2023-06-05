# Set regex match parameters
$regExScheme='(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}'
$regExPowerIndex='0x([A-Fa-f0-9]{8})'

# Get the active power state GUID
$activeScheme=cmd /c "powercfg /getactivescheme"
$asGuid=[regex]::Match($activeScheme,$regExScheme).Value

# Get the current power settings for the SUB_SLEEP GUID
$sleepConfig=powercfg /query $asGuid 238c9fa8-0aad-41ed-83f4-97be242c8f20
$sleepTimeHex=[regex]::Match($sleepConfig,$regExPowerIndex).Value

# For Windows 7/Server 2008 R2 compatibility the output from powercfg must be looped through to find the values that we need.  powercfg on Windows 10 allows you to query the subGUID directly
$i=0
foreach ($entry in $sleepConfig) {
  if ($entry -like "*29f6c1db-86da-48c5-9fdb-f2b67b1f44da*") {
    for (($j=1); $j -le 7; $j++) {
      if ($sleepConfig[$i+$j] -like "*Current AC Power Setting*") {
        $sleepTimeHex=[regex]::Match($sleepConfig[$i+$j],$regExPowerIndex).Value
        Break
      }
    }

    Break
  }
  $i++
}

# Convert seconds to minutes
$sleepTime=([System.Convert]::ToInt64($sleepTimeHex, 16))/60

# Check that a value was obtained and output, otherwise error.
if ($sleepTime -ge 0) {
  Write-Output "Current AC sleep timeout: $sleepTime"

  if([bool]$ENV:usrWriteUDF -eq $true){
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v $ENV:usrCustomUDF /t REG_SZ /d $sleepTime /f
  }
} else {
  Write-Output "Current sleep timeout is not available"
}