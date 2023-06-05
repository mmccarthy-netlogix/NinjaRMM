#set time via internet :: build 16/seagull

#==================================================================

function getHTTPHeaders { # by geoff varosky/sharepointyankee.com
    param( 
        [Parameter(ValueFromPipeline=$true)] 
        [string] $Url 
    )

    $request = [System.Net.WebRequest]::Create( $Url ) 
    try {
        $headers = $request.GetResponse().Headers
        $headers.AllKeys | Select-Object @{ Name = "Key"; Expression = { $_ }}, @{ Name = "Value"; Expression = { $headers.GetValues( $_ ) } }
    } catch {
        write-host "! ERROR: Unable to contact remote server for time information."
        return 99999999999
    }
}

function getTime ($location) {
    start-sleep -Seconds 10
    write-host "- Getting time (in UTC) from $location..."
    $varLocalEpoch=[int64](([datetime]::UtcNow)-(get-date "1/1/1970")).TotalSeconds
    $varServerTime=([DateTimeOffset]::Parse((getHTTPHeaders $location | Where-Object {$_.Key -eq "Date"}).Value)).UtcDateTime
    $varServerEpoch=[int64](($varServerTime)-(get-date "1/1/1970")).TotalSeconds
    [int]$varTimeOffset = $varServerEpoch - $varLocalEpoch
    if ($varTimeOffset -lt 0) {$varTimeOffset=0-$varTimeOffset}
    write-host ": Local/Server time offset is $varTimeOffset seconds."
    $varTimeOffset
}

function setTime ($isDomain) {
    if ($isDomain) {
        write-host "- Synching with Domain Controller..."
        w32tm /config /syncfromflags:DOMHIER /update
    } else {
        w32tm /config /syncfromflags:manual /manualpeerlist:$varServer /update
    }
    w32tm /resync
}

function Yes {$true}  # if it's stupid and it works...
function No  {$false} # ...then it's not stupid

#==================================================================

write-host "Set time via Internet"
write-host "==================================="

if ($env:usrServer) {
    write-host ": Using user-defined NTP server at $env:usrServer"
    $varServer=$env:usrServer
} else {
    write-host ": No NTP server defined by user; using default (0.pool.ntp.org)."
    $varServer='0.pool.ntp.org'
}

#configure w32time service
w32tm /register 2>&1>$null
Set-Service -Name w32Time -Status Running -StartupType Automatic
start-sleep -seconds 3
if (!(get-service w32time)) {
    Start-Service w32time
    start-sleep -seconds 10
}

#is this device a domain controller?
if (Get-Service NTDS -ErrorAction SilentlyContinue) {
  write-host "- This computer is a domain controller, using internet for time source"
  $varJoined=$false
}
else {
  #is this device part of a domain/joined to a DC?
  $varJoined=$false
  Invoke-Item "$env:systemroot\system32\dsregcmd.exe" -ErrorAction silentlycontinue
  if ($?) {
    #dsregcmd found. pipe its output to an object and run a conditional on it
    $Dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue} # github.com/Diagg
      if ((& $($Dsregcmd.AzureADJoined)) -or (& $($Dsregcmd.EnterpriseJoined)) -or (& $($Dsregcmd.DomainJoined))) {
          write-host "- DSRegCMD reports that this device is part of a domain."
          write-host "  This domain will be attempted for time receipt."
          $varJoined=$true
      }
  } else {
      #no dsregcmd. use more-compatible but less-accurate method to ascertain domain connectivity status
      if ((Get-WmiObject win32_computersystem).partofdomain) {
          $varJoined=$true
          write-host "- The WMI reports that this device is part of a domain."
          write-host "  This domain will be attempted for time receipt."
      }
  }
}

write-host "==================================="

$varAttempts=0
$varSite=@("https://www.google.com","https://www.wikipedia.org","https://www.cnn.com","https://www.yahoo.com")
@"
- Some errors may occur during time synchronisation.
  If the script has exited successfully, they can be disregarded.
===============================================================
"@ | % {$host.ui.WriteErrorLine($_)}

while ($true) {
    switch ($varAttempts) {
        3 {
            write-host "- Final attempt. If device is joined, skipping domain time check."
            setTime $false
            $varLastOffset=$(getTime $varSite[$varAttempts])
            if ($varLastOffset -lt 59) {
                write-host "- Device is accurate to server time within one minute."
                write-host "  No further adjustment required -- exiting."
                exit
            } else {
                write-host "- Four fruitless attempts have been made to adjust the local device's time."
                if ($varLastOffset -gt 86400) {
                    write-host "  The local/server offset was more than 24 hours. The device may be unable to connect."
                }
                write-host "  Please attend to the device in person."
                exit 1
            }
        } default {
            if ($(getTime $varSite[$varAttempts]) -lt 59) {
                write-host "- Device is accurate to server time within one minute."
                write-host "  No further adjustment required -- exiting."
                exit
            } else {
                $varAttempts++
                write-host "- Attempt $varAttempts"
                setTime $varJoined

                write-host "-------"
            }
        }
    }
}