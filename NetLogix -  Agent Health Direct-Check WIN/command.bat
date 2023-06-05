<# the datto RMM health check - component version :: build 75/seagull, apr '23
   uses code by [artem mikryukov] [geoff varosky]

   this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
   it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for 
   any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM is the one exception to this rule.
   the moment you edit this script it becomes your own risk and support will not provide assistance with it. 
   kaseya. #>

write-host "                                Datto RMM Agent Health Check :: Direct-Check"
write-host "============================================================================================================"
write-host "Using Direct-Check is a great way to ensure an endpoint's Agent installation is running properly without any"
write-host "hindrances; however, it isn't the only way to check Agent health. The offline version can also diagnose"
write-host "issues with Agents not connecting or installing. More @ https://rmm.datto.com/help/en/Default_CSH.htm#5133"
write-host "============================================================================================================"

##############################################################################################
#            PARAMETER SETTINGS / FUNCTIONS / NON-OPERATIVE COMMANDS
##############################################################################################

#parameters ----------------------------------------------------------------------------------

[int]$varKernel=(get-wmiObject win32_operatingSystem buildNumber).buildNumber
$arrServerSKU=((7..10),(12..15),(17..25),(29..46),(50..56),(59..64),72,76,77,79,80,95,96,109,110,120,(143..148),159,160,168,169)
$varCount=$arrServerSKU | ? {$_ -match '^' + [regex]::escape($((Get-WmiObject -Class win32_operatingsystem -Property OperatingSystemSKU).OperatingSystemSKU)) +'$'}
if ($varCount -ge 1) {
    $varServer=$true
}

try { #enable TLS 1.2
	[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
} catch [system.exception] {
	write-host "- ERROR: Could not implement TLS 1.2 Support."
	write-host "  This can occur on Windows 7 devices lacking Service Pack 1."
	write-host "  Please install that before proceeding."
	exit 1
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

if (([IntPtr]::size) -eq 4) {
    $varProgramFiles='C:\Program Files'
    $varRegNode='HKLM:\Software'
} else {
    $varProgramFiles='C:\Program Files (x86)'
    $varRegNode='HKLM:\Software\WOW6432Node'
}

$varDataLog=get-content "$env:ProgramData\CentraStage\AEMAgent\DataLog\aemagent.log" -encoding UTF8

if (!($varDataLog -match 'INFO')) {
    write-host "! FAILURE : Unable to gather AEMAgent log contents."
    write-host "  The contents may be corrupted, or the encoding may be of a type used by older Agents."
    write-host "  Please contact Support; the AEMAgent binary on this device may be out-of-date."
    write-host "  Checks will proceed as normal."
    write-host `r
}

try {
    $varLogCurrent=$varDataLog | Select-Object -Skip ((($varDataLog | Select-String -Pattern 'SYSTEM START')[-1].LineNumber) - 1) #a section of the previous command's output focussing just on the most recent active connection
} catch {
    $varLogCurrent=$varDataLog #if the `SYSTEM START` has rolled over (extended uptime), treat whatever we have as 'current' :: thanks luke w., datto labs
}
$varLog50=$varLogCurrent | select -Last 50 -ErrorAction SilentlyContinue

$varProgLog=get-content "$varProgramFiles\CentraStage\log.txt" -encoding Unicode

#functions -----------------------------------------------------------------------------------

function makeUDFString ($addition) {
    if ($script:varUDFString -notmatch "$addition") {
        $script:varUDFString+=" $addition"
    }
}

function getProxy {
    [xml]$varPlatXML= get-content "$varProgramFiles\CentraStage\CagService.exe.config" -ErrorAction SilentlyContinue
    $script:varProxyLoc=($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | Where-Object {$_.Name -eq 'ProxyIp'}).value
    $script:varProxyPort=($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | Where-Object {$_.Name -eq 'ProxyPort'}).value
}

function downloadString ($tempHost) { #downloadString: create a webClient with pre-populated proxy data and pull a string from the web through it
    $tempWebClient = New-Object System.Net.WebClient
    $tempwebClient.UseDefaultCredentials = $true
    $tempwebClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
    $tempwebClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)');
    if ($env:CS_PROFILE_PROXY_TYPE -ge '1') {
        getProxy
        $tempWebClient.Proxy = New-Object System.Net.WebProxy("$script:varProxyLoc`:$script:varProxyPort",$true)
    }
    $tempWebClient.DownloadString("$tempHost")
}

function makeHTTPRequest ($tempHost, $tempName) { #makeHTTPRequest v6: make an HTTP request and ensure a status code (any) is returned
    $tempRequest = [System.Net.WebRequest]::Create($tempHost)
    if ($env:CS_PROFILE_PROXY_TYPE -ge '1') {
        getProxy
        $tempRequest.Proxy = New-Object System.Net.WebProxy("$script:varProxyLoc`:$script:varProxyPort",$true)
    }
    try {
        $tempResponse=$tempRequest.getResponse()
        $TempReturn=($tempResponse.StatusCode -as [int])
    } catch [System.Exception] {
        $tempReturn=$_.Exception.Response.StatusCode.Value__
    }

    if ($tempReturn -match '[0-9]{3}') {
        write-host " + PASSED: $tempName $tempHost"
    } else {
        write-host " ! FAILED: $tempName $tempHost"
        makeUDFString "(CON-1)"
    }
}

function makeIPRequest ($tempHostArray, $showProviso) { #makeIPRequest: check an IP/host (array) for connectivity via TCP. does not support proxy servers.
    $arrResults=@{}
    foreach ($tempHost in $tempHostArray) {
        $tempIPRequest = New-Object net.sockets.tcpclient
        $tempIPRequest.BeginConnect("$tempHost",443,$Null,$Null ) | Out-Null
        While (-not $tempIPRequest.Connected) {
            $attempts++
            start-sleep -seconds 1
            if ($attempts -ge 5) {break}
        }
        if ($tempIPRequest.Connected) {
            $arrResults+=@{$tempHost=" + PASSED:"}
        } else {
            $arrResults+=@{$tempHost=" ! NOTICE:"} #don't increment failures
            $tempFailures++
        }
        $tempIPRequest.close()
        Clear-Variable $attempts -ea 0
    }
    #because the first column has to contain unique values, we make the first column the IP address and the second the result, but format & display it the opposite way for consistency
    ($arrResults | ft @{n='James';e={$_.'value'}},@{n='Heather';e={$_.'Name'}} -HideTableHeaders | out-string) -replace '(?m)^\s*?\n'
    if ($tempFailures) {
        if ($showProviso) {
            write-host "- Some (7-10) IP check failures ($tempFailures failures/$(($tempHostArray | Measure-Object).count) total checks) are typical; not all IPs are in constant use." #most users will see this
            write-host `r #weirdness to prettify script output
        }
    }
}

function getHTTPHeaders { # by geoff varosky/sharepointyankee.com
    param( 
        [Parameter(ValueFromPipeline=$true)] 
        [string] $Url 
    )

    $request = [System.Net.WebRequest]::Create( $Url ) 
    $headers = $request.GetResponse().Headers 
    $headers.AllKeys | 
         Select-Object @{ Name = "Key"; Expression = { $_ }}, 
         @{ Name = "Value"; Expression = { $headers.GetValues( $_ ) } }
}

## Original code using certutil
#function checkCert ($name, $thumbprint) {
#    ($thumbprint,$($thumbprint -replace ' ')) | % { #since certutil sometimes uses spaces and sometimes doesn't :: THANKS MICROSOFT
#        try {
#            if ((certutil -store authroot | select-string "$_" | Measure-Object).count -ge 1) {
#                if ((certutil -store authroot | select-string "$_" -Context 8,2) -as [string] | select-string $name -quiet) {
#		            $script:varCertPass++
#                }
#            }
#        } catch {
#            #do nothing
#        }
#    }
#}

## New function using PowerShell instead of certutil
function checkCert ($name, $thumbprint) {
    ($thumbprint,$($thumbprint -replace ' ')) | % { #since certutil sometimes uses spaces and sometimes doesn't :: THANKS MICROSOFT
        try {
            if ((Get-ChildItem Cert:LocalMachine\AuthRoot | select-string $_ | Measure-Object).count -ge 1) {
                if ((Get-ChildItem Cert:LocalMachine\AuthRoot | select-string $_) -replace ('"') | select-string $name -quiet) {
		            $script:varCertPass++
                }
            }
        } catch {
            #do nothing
        }
    }
}

#platform data -------------------------------------------------------------------------------

#ascertain platform from user's CC
$varPlatform=$env:CS_CC_HOST.split('.')[0]

#grand switch
switch -regex ($varPlatform) {
      '^01cc' {
        $varCC_Name=   "Pinotage"
        $varCC_NameAlt=$null
        $arrCC_CC=     "01cc"
        $arrTS=      @("eu-west-1-1","eu-west-1-2","eu-west-1-3","me-south-1-1")
    } '^02cc' {
        $varCC_Name=   "Merlot"
        $varCC_NameAlt="-merlot"
        $arrCC_CC=     "02cc"
        $arrTS=      @("eu-west-1-1","eu-west-1-2","eu-west-1-3","me-south-1-1") #merlot and pinotage use the same TS
    } '^03cc' {
        $varCC_Name=   "Zinfandel"
        $varCC_NameAlt="-zinfandel"
        $arrCC_CC=     "03cc"
        $arrTS=      @("us-west-1-1","us-west-1-2")
    } 'syrah' {
        $varCC_Name=   "Syrah"
        $varCC_NameAlt="-syrah"
        $arrCC_CC=   @("syrahcc","01syrahcc")
        $arrTS=      @("ap-southeast-2-1","ap-southeast-2-2")
    } 'concord' {
        $varCC_Name=   "Concord"
        $varCC_NameAlt="-concord"
        $arrCC_CC=   @("concordcc","01concordcc")
        $arrTS=      @("us-east-1-1","us-east-1-2")
    } 'vidal' {
        $varCC_Name=   "Vidal"
        $varCC_NameAlt="-vidal"
        $arrCC_CC=   @("vidalcc","01vidalcc")
        $arrTS=      @("us-east-1-1","us-east-1-2") #vidal and concord use the same TS
    } default {
        write-host "! ERROR: No platform selection was passed across."
        write-host "  PARTNERS:  Please report this error."
        write-host "  EMPLOYEES: The tool doesn't work on internal servers."
        exit 1
    }
}

##############################################################################################
#            OPERATIVE COMMANDS: STATUS
##############################################################################################

#ascii art header ----------------------------------------------------------------------------

write-host `r

write-host '------                              @@@@ @@  @@  @@@@ @@@@ @@@@@ @@   @@                              ------'
write-host '------                      @@@    @@    @@  @@ @@     @@  @@    @@@ @@@    @@@                       ------'
write-host '------                      :::     @@@   @@@@   @@@   @@  @@@@  @@@@@@@    :::                       ------'
write-host '------                      @@@       @@   @@      @@  @@  @@    @@ @ @@    @@@                       ------'
write-host '------                             @@@@    @@   @@@@   @@  @@@@@ @@   @@                              ------'

write-host `r

#boilerplate ---------------------------------------------------------------------------------

write-host " : Device hostname:                $env:COMPUTERNAME"
write-host " : Windows edition caption:        $((get-WMiObject -computername $env:computername -Class win32_operatingSystem).caption) ($([intptr]::Size*8)-bit)"
write-host " : Windows version number:         $varKernel"
write-host " : PowerShell Interpreter version: $((get-host).version -as [string])"
write-host " : Local time on Endpoint:         $(get-date)"

#uptime --------------------------------------------------------------------------------------

$varLastBootTime=[Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootupTime) | New-TimeSpan
if (($varLastBootTime.Days -as [String]).Length -eq 3) {
    $varBootString='{0}D ' -f $varLastBootTime.Days
} elseif (($varLastBootTime.Days -as [String]).Length -eq 2) {
    $varBootString=' {0}D ' -f $varLastBootTime.Days
} else {
    $varBootString=' 0{0}D ' -f $varLastBootTime.Days
}
if (($varLastBootTime.Hours -as [String]).Length -eq 1) {
    $varBootString+='0{0}H ' -f $varLastBootTime.Hours
} else {
    $varBootString+='{0}H ' -f $varLastBootTime.Hours
}
if (($varLastBootTime.Minutes -as [String]).Length -eq 1) {
    $varBootString+='0{0}M ' -f $varLastBootTime.Minutes
} else {
    $varBootString+='{0}M ' -f $varLastBootTime.Minutes
}
write-host " : Uptime (since last full boot): $varBootString"

#os support ----------------------------------------------------------------------------------

if ($varKernel -lt 10240) {
    switch -regex ($varKernel) {
        '^2' {
            write-host " : Windows Support Status:         Obsolete (Windows XP EOL Apr 2009/ESU 2014)"
        } '^3' {
            write-host " : Windows Support Status:         Obsolete (Windows XP x64/Server 2003 EOL 2010/ESU 2015)"
        } '^6' {
            if ($varServer) {
                write-host " : Windows Support Status:         Moribund (Server 2008 EOL Jan 2023/Azure Jan 2024)"
            } else {
                write-host " : Windows Support Status:         Obsolete (Windows Vista EOL 2012/ESU 2017)"
            }
        } '^7' {
            if ($varServer) {
                write-host " : Windows Support Status:         Moribund (Server 2008 R2 EOL Jan 2023/Azure Jan 2024)"
            } else {
                write-host " : Windows Support Status:         Obsolete (Windows 7 EOL Jan 2015/ESU Jan 2023)"
            }
        } '^9' {
            if ($varServer) {
                if ($([int][double]::Parse((Get-Date -UFormat %s))) -gt 1696896000) {
                    #10 october 2023
                    write-host " : Windows Support Status:         Moribund (Server 2012/R2 EOL Oct 2023/ESU Oct 2026)"
                } elseif ($([int][double]::Parse((Get-Date -UFormat %s))) -gt 1791590400) {
                    #10 october 2026
                    write-host " : Windows Support Status:         Obsolete (Server 2012/R2 EOL Oct 2023/ESU Oct 2026)"
                } else {
                    write-host " : Windows Support Status:         Caution (Server 2012/R2 EOL Oct 2023/ESU Oct 2026)"
                }
            } else {
                write-host " : Windows Support Status:         Obsolete (Windows 8 EOL Jan 2016/Windows 8.1 EOL Jan 2023)"
            }
        } default {
            write-host " : Windows Support Status:         Obsolete (Operating systems older than Windows 10/Server 2016 no longer supported)"
        }
    }
} else {
    #running 10/11/server 2016
    write-host " : Windows Support Status:         Supported"
}

##############################################################################################
#            OPERATIVE COMMANDS: CONNECTIVITY
##############################################################################################

#ascii art header ----------------------------------------------------------------------------

write-host `r

write-host '------               @@@   @@@  @@  @@ @@  @@ @@@@@  @@@  @@@@ @@ @@   @@ @@ @@@@ @@  @@              ------'
write-host '------       @@@    @@ @@ @@ @@ @@@ @@ @@@ @@ @@    @@ @@  @@  @@ @@   @@ @@  @@  @@  @@    @@@       ------'
write-host '------       :::    @@    @@ @@ @@@@@@ @@@@@@ @@@@  @@     @@  @@  @@ @@  @@  @@   @@@@     :::       ------'
write-host '------       @@@    @@ @@ @@ @@ @@ @@@ @@ @@@ @@    @@ @@  @@  @@  @@ @@  @@  @@    @@      @@@       ------'
write-host '------               @@@   @@@  @@  @@ @@  @@ @@@@@  @@@   @@  @@   @@@   @@  @@    @@                ------'


write-host `r

#TLS cipher checks ---------------------------------------------------------------------------

[int]$varCipherSuccess=0
"HKLM:\Software\WOW6432Node","HKLM:\Software" | % {
    try {
        ((get-itemproperty "$_\Policies\Microsoft\Cryptography\Configuration\SSL\00010002" -Name Functions -ea stop).Functions) -split ',' | % {
            switch -regex ($_) {
                '^TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384($|_)' {
                    $varCipherSuccess++
                } '^TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256$($|_)' {
                    $varCipherSuccess++
                } '^TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256$($|_)' {
                    $varCipherSuccess++
                } '^TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384$($|_)' {
                    $varCipherSuccess++
                }
            }
        }
    } catch {
        $varCipherSuccess+=4 #if nothing's been configured, the defaults will see us through
    }
}
    
if ($varCipherSuccess -lt 1) {
    #no good cipher enabled
    write-host "! FAILURE: Device does not have appropriate Ciphers enabled to facilitate a TLS connection to the Control Channel."
    write-host "  Please ensure this device is still supported by Microsoft and has the latest updates and patches installed."
    write-host "  If this error persists after doing this, please speak with Support and/or (re-)enable the Ciphers with the IISCrypto tool."
} else {
    #at least one good cipher enabled
    if ($varCipherSuccess -lt 8) {
        if ([intptr]::Size -eq 4) {$varCipherSuccess-=4} #cosmetic compensation for the four erroneous WOW6432NODE passes on x86
        write-host ": NOTICE: Device does not have all Ciphers enabled to facilitate a TLS connection to the Control Channel."
        write-host "  The total amount of necessary Ciphers that were enabled was $varCipherSuccess out of a possible $([intptr]::Size)."
        write-host "  If the Agent is not connecting reliably or at all, please speak with Support and/or re-enable the Ciphers with the IISCrypto tool."
    } else {
        write-host "+ SUCCESS: Device has necessary TLS Ciphers installed to facilitate Control Channel connection."
    }
}

write-host `r

#HTTP connectivity checks --------------------------------------------------------------------

write-host "= Platform URL Checks"
write-host " : Datto RMM Platform:                  $varCC_Name ($($arrTS[0].split('-')[0])-$($arrTS[0].split('-')[1]))"
makeHTTPRequest                                "https://$varCC_Name.centrastage.net"  "Web Portal I                "
makeHTTPRequest                        $("https://$varCC_Name"+"rmm.centrastage.net") "Web Portal II               "
makeHTTPRequest               "https://$varCC_Name-agent.centrastage.net/cs/version"  "Agent Service               "
makeHTTPRequest                    "https://$varCC_Name-agent-comms.centrastage.net"  "Agent Communications        "
makeHTTPRequest            "https://$varCC_Name-agent-notifications.centrastage.net"  "Agent Notifications         "
makeHTTPRequest               "https://$varCC_Name-audit.centrastage.net/cs/version"  "Audit Service               "
makeHTTPRequest                          "https://cpt$varCC_NameAlt.centrastage.net"  "Component Repository I      "
makeHTTPRequest         "https://cpt$varCC_NameAlt.centrastage.net.s3.amazonaws.com"  "Component Repository II     "
makeHTTPRequest "https://$varCC_Name-monitoring.centrastage.net/device/1234/monitor"  "Monitoring Service          "
makeHTTPRequest    "https://$varCC_Name-realtime.centrastage.net/notifications/test"  "Realtime Service            "
makeHTTPRequest                "https://update.centrastage.net/cagupdate/Update.dll"  "Update Server               "
makeHTTPRequest                    "https://agent-gateway.$varCC_Name.rmm.datto.com"  "Agent Gateway               "

#443 connectivity checks ---------------------------------------------------------------------

write-host `r

write-host "= Platform & Tunnel Server IP + TCP Checks"
if ($env:CS_PROFILE_PROXY_TYPE -ge '1') {
    write-host "- Direct-Check cannot route these requests through a proxy server."
    write-host "  This may cause failures to register where no connectivity issues exist."
}

write-host " > Tunnel Server & Control Channel"
makeIPRequest ("$varPlatform.centrastage.net","ts.centrastage.net") $false
if ($($varPlatform.substring(0,1)) -ne '0') {
    makeIPRequest "01$varPlatform.centrastage.net" $false
}

#dynamique platform IP check
$arrPlatIPs=@()
write-host " > Platform IPs ($varCC_Name-ips.centrastage.net)"
try {
    [System.Net.Dns]::GetHostAddresses("$varCC_Name-ips.centrastage.net") | % {
        $arrPlatIPs+=$($_.IPAddressToString)
    }
    makeIPRequest $arrPlatIPs $true
} catch {
    write-host " ! FAILED: Could not get platform IP list from $varCC_Name-ips.centrastage.net."
    write-host "   Please allowlist this URL to get the list of IPs to check for connectivity to."
    makeUDFString "(CON-1)"
    write-host `r
}

#dynamique tunnel-server IP check
$arrTSIPs2=@()
write-host " > Tunnel Server IPs"
try {
    $arrTS | % {
        [System.Net.Dns]::GetHostAddresses("tunnel-$_.rmm.datto.com") | % {
            $arrTSIPs2+=$($_.IPAddressToString)
        }
    }
    makeIPRequest $arrTSIPs2 $true
} catch {
    write-host " ! FAILED: Could not pull Tunnel Server IP list."
    write-host "   Please check the StdErr to see where connectivity failed and double-check allowlisting."
    makeUDFString "(CON-1)"
    write-host `r
}

write-host "============================================"
write-host " A note on connectivity:"
write-host " This information is useful for testing allowlisting that has already been performed."
write-host " The IP addresses listed here should not be used to initiate or bolster allowlisting efforts."
write-host " Instead, please use the addresses listed in the Datto RMM documentation, available here:"
write-host " https://rmm.datto.com/help/en/Content/1INTRODUCTION/Requirements/AllowListRequirements.htm"
write-host "============================================"
write-host `r

#windows update ------------------------------------------------------------------------------

write-host "= Windows Update Service Connectivity"
makeHTTPRequest "https://windowsupdate.microsoft.com"  "Windows Update I            "
makeHTTPRequest "https://update.microsoft.com"         "Windows Update II           "
makeHTTPRequest "http://dl.delivery.mp.microsoft.com"  "Windows Update III          "
makeHTTPRequest "http://download.windowsupdate.com"    "WU: Download Hub            "
makeHTTPRequest "https://download.microsoft.com"       "MS: Download Hub            "
makeHTTPRequest "http://ctldl.windowsupdate.com"       "Certificate Revocation      "
makeHTTPRequest "https://go.microsoft.com"             "MS: General                 "

#defender checks :: custom non-function code to only alert if both fail ----------------------

foreach ($iteration in ("https://wdcp.microsoft.com","https://wdcpalt.microsoft.com")) {
    $defRequest = [System.Net.WebRequest]::Create($iteration)
    if ($env:CS_PROFILE_PROXY_TYPE -ge '1') {
        getProxy
        $defRequest.Proxy = New-Object System.Net.WebProxy("$script:varProxyLoc`:$script:varProxyPort",$true)
    }
    try {
        $defResponse=$defRequest.getResponse()
        $defReturn=($defResponse.StatusCode -as [int])
    } catch [System.Exception] {
        $defReturn=$_.Exception.Response.StatusCode.Value__
        start-sleep -seconds 5
    }

    if ($defReturn -match '[0-9]{3}') {
        write-host " + PASSED: Defender Cloud Protection   ($iteration)"
    } else {
        write-host " ! NOTICE: Defender Cloud Protection   ($iteration)"
        $varDefFail++
    }

    clear-variable def*
}

if ($varDefFail -eq 1) {
    write-host "   (PASSED: One Defender pass is sufficient to pass this check.)"
} elseif ($varDefFail -eq 2) {
    write-host " ! FAILED: Both Defender URLs failed connection checks."
    makeUDFString "(CON-1)"
}

#accuracy of system time ---------------------------------------------------------------------
write-host `r

$varServerTime=([DateTimeOffset]::Parse((getHTTPHeaders http://www.google.com | Where-Object {$_.Key -eq "Date"}).Value)).UtcDateTime
$varServerEpoch=[int64](($varServerTime)-(get-date "1/1/1970")).TotalSeconds

if ($varServerEpoch -lt 0) {
    write-host "! FAILED: Unable to gather system time from Google.com to gauge time offset. Time may be incorrect."
    makeUDFString "(CFG-1c)"
} else {
    $varLocalEpoch=[int64](([datetime]::UtcNow)-(get-date "1/1/1970")).TotalSeconds
    [int]$varTimeOffset = $varServerEpoch - $varLocalEpoch
    if ($varTimeOffset -lt 0) {$varTimeOffset=0-$varTimeOffset}

    write-host "= System Clock Verification (Local: $varLocalEpoch :: Remote: $varServerEpoch)"

    if (($varTimeOffset).tostring().length -ge 4) {
            write-host " ! FAILED: System clock is more than 15 minutes out. SSL connectivity will be impacted."
            makeUDFString "(CFG-1c)"
        } elseif ($varTimeOffset -ge 600) {
            write-host " ! FAILED: System clock is more than 10 minutes out. SSL connectivity will be impacted."
            makeUDFString "(CFG-1b)"
        } elseif ($varTimeOffset -ge 121) {
            write-host " - NOTICE: System clock is more than 2 minutes out. SSL connectivity may be impacted."
            makeUDFString "<CFG-1a>"
        } elseif ($varTimeOffset -le 120) {
            write-host " + PASSED: System clock is accurate to within 2 minutes. SSL Connectivity should be fine."
    }
}

write-host `r

##############################################################################################
#            OPERATIVE COMMANDS: SYSTEM STATUS
##############################################################################################

#ascii art header ----------------------------------------------------------------------------
write-host '------               @@@   @@@  @@@@@ @@  @@ @@@@   @@  @@ @@@@@  @@@  @@    @@@@ @@  @@              ------'
write-host '------       @@@    @@ @@ @@    @@    @@@ @@  @@    @@  @@ @@    @@ @@ @@     @@  @@  @@    @@@       ------'
write-host '------       :::    @@@@@ @@ @@ @@@@  @@@@@@  @@    @@@@@@ @@@@  @@@@@ @@     @@  @@@@@@    :::       ------'
write-host '------       @@@    @@ @@ @@  @ @@    @@ @@@  @@    @@  @@ @@    @@ @@ @@     @@  @@  @@    @@@       ------'
write-host '------              @@ @@  @@@  @@@@@ @@  @@  @@    @@  @@ @@@@@ @@ @@ @@@@@  @@  @@  @@              ------'

write-host `r

#agent version -------------------string------------------------------------------------------

write-host "= Version Checks"
[xml]$varAgentVerREMOTE=(downloadString "https://update$varCC_NameAlt.centrastage.net/cagupdate/UpdateState.xml")
if ($varAgentVerREMOTE) {
    [int]$varAgentVerREMOTE=$varAgentVerREMOTE.UpdateStatus.CurrentVersion
    [int]$varAgentVerLOCAL =(([System.Diagnostics.FileVersionInfo]::GetVersionInfo("$varProgramFiles\CentraStage\Core.dll").FileVersion).split(".")[3])
    if ($varAgentVerREMOTE -eq $varAgentVerLOCAL) {
        write-host " + PASSED: Agent Service check:      Up-to-date (Version $varAgentVerREMOTE)"
    } else {
        write-host " ! FAILED: Agent Service check:      Out-of-date (Local: $varAgentverLOCAL/Remote: $varAgentVerREMOTE)"
        makeUDFString "(SW-1)"
    }
} else {
    write-host " ! FAILED: to gather remote version information for Agent Service."
    makeUDFString "(CON-2)"
}

#aemagent version ----------------string------------------------------------------------------

$varAEMAgtVerREMOTE=downloadString "https://update$varCC_NameAlt.centrastage.net/cagupdate/aem-agent/version.json"
if ($varAEMAgtVerREMOTE) {
    $varAEMAgtVerREMOTE=$varAEMAgtVerREMOTE.split('"')[3]
    $varAEMAgtVerLOCAL=((($varDataLog | Select-Object -Last 10 | select-string -Pattern '^[0-9]' | select-object -last 1) -as [string]) -split ("\|"))[0]
    if ($varAEMAgtVerREMOTE -eq $varAEMAgtVerLOCAL) {
        write-host " + PASSED: Monitoring Service check: Up-to-date (Version $varAEMAgtVerREMOTE)"
    } else {
        write-host " ! FAILED: Monitoring Service check: Out-of-date (Local: $varAEMAgtVerLOCAL/Remote: $varAEMAgtVerREMOTE)"     
        makeUDFString "(SW-2)"
    }
} else {
    write-host " ! FAILED: to gather remote version information for Monitoring Service."
    makeUDFString "(CON-3)"
}

#webremote version ---------------just diagnostic output--------------------------------------
write-host " : STATUS: Web Remote version:       $((gci "$env:ProgramData\CentraStage\AEMAgent\RMM.WebRemote" -ErrorAction SilentlyContinue | ? {$_.PSIsContainer} | sort LastWriteTime | select -last 1).name)"

write-host `r

#cagservice health ------------------(no cagservice, no components, but whatever)-------------

write-host "= Agent Checks"
if ((get-process CagService | measure-object).count -lt 1) {
    write-host " ! FAILED: Agent Service check; Agent Service does not appear to be running."
    write-host "   (How is the device running a Component?)"
    makeUDFString "(SW-3)"
} else {
    write-host " + PASSED: Agent Service check: Agent Service is running."
}

#.NET framework architecture misconfiguration-------------------------------------------------
if (test-path "$env:systemRoot\Microsoft.NET\Framework64\v2.0.50727\ldr64.exe" -ea 0) {
    if (((cmd /c "$env:systemRoot\Microsoft.NET\Framework64\v2.0.50727\ldr64.exe query" | select-string '0x0') -as [string]).split('x')[1] -eq '00000000') {
        write-host " ! FAILED: This device has been set to use the 32-bit (Windows-on-Windows) version of the .NET Framework."
        write-host "   Some applications, like CagService, are configured to use the device's native architecture, but a setting"
        write-host "   exists for .NET to use the 32-bit version in all situations. On this device that setting has been enabled."
        write-host "   This override setting is incompatible with the Datto RMM Agent as it is known to cause multiple issues."
        write-host "   ..."
        write-host "   As this is a localised issue, Support cannot assist with it; most likely this setting was either set"
        write-host "   deliberately by the System Administrator or unilaterally during an unrelated software installation."
        write-host "   (The default behaviour of the .NET Framework on 64-bit systems is to use 64-bit wherever possible.)"
        write-host "   In either case, changing it back to the recommended system default could cause unforeseen issues, so the"
        write-host "   command given below should be run on this endpoint only after careful consideration."
        write-host "   ..."
        write-host "   The following Batch command will set the .NET Framework back to its default architecture setting:"
        write-host "   C:\Windows\Microsoft.NET\Framework64\v2.0.50727\ldr64.exe set64"
        write-host "   ..."
        write-host "   This will re-configure the Framework to use 64-bit where possible. This will fix the Datto RMM Agent, but"
        write-host "   it may break whatever else needed things configured that way in the first place. Datto cannot be held"
        write-host "   responsible for issues that arise as a result of changing this setting back to its system default."
        makeUDFString "(CFG-9)"
    } else {
        write-host " + PASSED: Device's .NET Framework architecture setting has not been overridden."
    }
} else {
    write-host " + PASSED: Device's .NET Framework architecture settings cannot be configured."
}


#nlog.dll clashes-----------------------------------------------------------------------------

if ((@(Get-ChildItem -Path "$env:SystemRoot\Microsoft.NET\assembly" -Recurse | Where-Object {$_.Name -match "^nlog\.dll"}) -as [string]).Length -gt 0) {
    write-host " ! NOTICE: Clash check. Copies of Nlog.dll are in the device's .NET GAC (C:\Windows\Microsoft.NET\Assembly)."
    write-host "   If the Agent struggles to start up, this may be the cause; if the Agent is fine, this can be disregarded."
    makeUDFString "<CFG-2>"
} else {
    write-host " + PASSED: Clash check. No extraneous copies of Nlog.dll are interfering with Agent functionality."
}

<# the dotnet check would go here but it's been axed from the component version.
   if a workable build of dotnet isn't installed, the agent won't be either. #>

#FIPS-compliance -----------------------------------------------------------------------------

if ((Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy" -Name Enabled -ea 0).Enabled -eq 1) {
    write-host " ! FAILED: FIPS-compliance check. This device enforces FIPS-compliance which will hinder connectivity."
    makeUDFString "(CFG-3)"
} elseif ((Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy" -Name MDMEnabled -ea 0).MDMEnabled -eq 1) {
    write-host " ! FAILED: FIPS-compliance check. This device enforces FIPS-compliance which will hinder connectivity."
    makeUDFString "(CFG-3)"
} else {
    write-host " + PASSED: FIPS-compliance check. This device does not enforce FIPS-compliance."
}

#free disk space -----------------------------------------------------------------------------

if ([math]::Round((get-WmiObject win32_logicaldisk -Filter "DeviceID='$env:SystemDrive'").FreeSpace /1GB) -lt 1) {
    write-host " ! FAILED: Disk space check. Agent needs at least 1GB free space to work properly."
    makeUDFString "(CFG-4)"
} else {
    write-host " + PASSED: Disk space check. At least 1GB of free space is present on System drive."
}

#software management directory (jim d.) ------------------------------------------------------

if (Get-Childitem "$env:PROGRAMDATA\CentraStage\AEMAgent\Downloads" -Recurse | ? {$_.LastWriteTime -le (get-date).addDays(-1) }) {
    Get-Childitem "$env:PROGRAMDATA\CentraStage\AEMAgent\Downloads" -Recurse | ? {$_.LastWriteTime -le (get-date).addDays(-1) } | % {Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue}
    write-host " ! NOTICE: Software Management: Downloads directory cleared."
    write-host "   If the device had been experiencing issues with Software Management, this may alleviate them."
} else {
    write-host " + PASSED: Software Management: Downloads directory is healthy." 
}

#starfield certificates ----------------------------------------------------------------------

checkCert 'CN=Amazon Root CA 1, O=Amazon, C=US' "8d a7 f9 65 ec 5e fc 37 91 0f 1c 6e 59 fd c1 cc 6a 6e de 16"
checkCert 'CN=Amazon Root CA 2, O=Amazon, C=US' "5a 8c ef 45 d7 a6 98 59 76 7a 8c 8b 44 96 b5 78 cf 47 4b 1a"
checkCert 'CN=Amazon Root CA 3, O=Amazon, C=US' "0d 44 dd 8c 3c 8c 1a 1a 58 75 64 81 e9 0f 2e 2a ff b3 d2 6e"
checkCert 'CN=Amazon Root CA 4, O=Amazon, C=US' "f6 10 84 07 d6 f8 bb 67 98 0c c2 e2 44 c2 eb ae 1c ef 63 be"
checkCert 'OU=Starfield Class 2 Certification Authority, O=Starfield Technologies, Inc.' "ad 7e 1c 28 b0 64 ef 8f 60 03 40 20 14 c3 d0 e3 37 0e b5 8a"

if (!$script:varCertPass) {
    write-host " ! FAILURE: Amazon Root CA certificates. None were valid; platform connectivity will be impossible."
    write-host "   To remedy, visit https://www.amazontrust.com/repository/; then"
    write-host "   download and install the `"Amazon Root CA 1`" certificate in DER or PEM format."
    write-host "   Please ensure certificates are installed at the machine-level and not the user-level!"
    makeUDFString "(CFG-5)"
} else {
    write-host " + PASSED: Amazon Root CA certificates. Relevant certificates for connectivity are installed."
}

write-host `r
write-host "= File Verification"

#aemagent health --------------------(thanks to jim d., datto inc.)---------------------------

$arrError=@{
   'Exception'           ='Connection exception; a connection was attempted but failed without receiving a response.'
   'RE-TRY'              ='Connection retry attempt; a connection failure spawned a subsequent reconnection attempt.'
   'HttpStatusCode": 403'='HTTP 403/Unauthorised. This suggests platform-side device rejection. Check device approvals.'
}

$arrError.GetEnumerator() | % {
    $currentName=$_.Name
    $currentValue=$_.Value
    if ((($varLog50 | ? {$_ -match $currentName} | Measure-Object).count) -gt 4) {
        $varLogIssues=$true
        write-host "- FAILURE: $(($varLog50 | ? {$_ -match $currentName} | measure-object).count) recent errors matching `'$currentName`' detected in AEMAgent log file. (SW-5)"
        write-host "  Error detail: $currentValue"
    }
}

if (($varLogCurrent | where-object {$_ -match "`"HttpStatusCode`": 200"} | measure-object).count -lt 3) {
    write-host " - NOTICE: Monitoring Service health check: AEMAgent.exe did not seem to be responding & has been restarted."
    Stop-Process -Name AEMAgent -Force -ErrorAction SilentlyContinue 2>&1>$null
    start-sleep -seconds 1
    $count=0
} elseif ($varLogIssues) {
    makeUDFString "(SW-5)"
} else {
    write-host " + PASSED: Monitoring Service health check."
}

#key exception

if ($varLogCurrent | ? {$_ -match '(Key platform denied|forbidden|human)'}) {
    write-host " ! FAILED: Agent encryption key check. This device is being held for authorisation due to a key mismatch."
    makeUDFString "(CFG-8)"
} else {
    write-host " + PASSED: Agent encryption key check."
}

#cagservice provisioning ------------(edited slightly from desktop version)-------------------

if ($varProgLog | Select-String -Pattern 'error code 429' -Quiet) {
    write-host " - NOTICE: Provisioning check. Connectivity errors related to provisioning have been logged."
    write-host "   Whilst this device can connect now, the account it is assigned to may be overprovisioned."
    makeUDFString "<CFG-7>"
} else {
    write-host " + PASSED: Provisioning check. This device has not had account-related connectivity issues."
}

#cagservice event log ------------------------------------------------------------------------

$varEvt=Get-EventLog -LogName System -Source 'Service Control Manager' -After (get-date).AddDays(-7) | ? -FilterScript {($_.Message -match 'CentraStage') -and ($_.EventID -notmatch '^(7036|7045)$')} | Format-Table -AutoSize
if (!$varEvt) {
    write-host " + PASSED: Event Log verification. No problematic Event Log entries from within the last week were found."
} else {
    write-host " ! FAILED: Event Log verification. Problematic Event Log entries from within the last week were found; a report is in the StdErr."
    $varEvt | Out-File -Width 512 events.txt
    $host.ui.WriteErrorLine("=================================================================")
    $host.ui.WriteErrorLine("Event Log scan results:")
    get-content "$PWD\events.txt" | % {$host.ui.WriteErrorLine($_)}
    makeUDFString "(SW-6)"
}

#agent xml------------------------------------------------------------------------------------

$varAgentXML=(Get-ChildItem -Path "$env:SYSTEMROOT\System32\config\systemprofile\AppData\Local\CentraStage" -Filter 'user.config' -Recurse -ErrorAction SilentlyContinue -Force | select -last 1).fullname
$varXMLTest=New-Object System.Xml.XmlDocument
try {
    $varXMLTest.load("$varAgentXML")
} catch [System.Xml.XmlException] {
    write-host " ! FAILED: $($_) is corrupted and cannot be read. Please reinstall the Agent."
    $varXMLIssues=$true
}

if (!$varXMLIssues) {
    write-host " + PASSED: Agent configuration file check."
}

# check submittedpatches.json
try {
    $varPatchJSON = get-content "C:\ProgramData\CentraStage\SubmittedPatches.json" -ErrorAction Stop
} catch {
    #no file, no problem
}

if ($varPatchJSON) {
	if ($varPatchJSON.Substring(0,2) -notmatch "^\[\{$" -or $varPatchJSON.Substring($varPatchJSON.Length-2) -notmatch "^\}\]$") {
        write-host " ! FAILED: Agent record check. SubmittedPatches.json is corrupted and cannot be read. Please reinstall the Agent."
        makeUDFString "(CRR-1)"
    } else {
        write-host " + PASSED: Agent record check. SubmittedPatches.json appears valid."
    }
} else {
    write-host " + PASSED: Agent record check. No submitted-patches JSON to verify."
}

#unicode registry ----------------------------------------------------------------------------

('hklm:\Software\Microsoft\Windows\Currentversion\Uninstall','hklm:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall','hkcu:\Software\Microsoft\Windows\CurrentVersion\Uninstall') | % {
    foreach ($iteration in $(gci "$_" -ea 0)) {
        if ($iteration) {
            if (Get-ItemProperty -Path "registry::$iteration" | ? { $_ -match '[^\x00-\xff]'}) { #unicode range U+0000 to U+00FF (NUL to y-umlaut)
                (Get-ItemProperty -Path "registry::$iteration" | ? { $_ -match '[^\x00-\xff]'}) | % {
                    #additional screening to remove characters we know are not problematic
                    $varRegValue=$(((Get-ItemProperty -Path "registry::$iteration").PSObject.Properties | ? {$_ -match '[^\x00-\xff]'}).Value)
                    #u00AE is (R); u2122 is TM; u00A9 is (C) :: https://www.babelstone.co.uk/Unicode/whatisit.html
                    $varRegValue=($varRegValue -as [string]) -replace '\u00AE','' -replace '\u2122','' -replace '\u00A9',''
                    #if it STILL triggers, alert:
                    if ($varRegValue -match '[^\x00-\xff]') {
                        $varRegUni+= "  : $($iteration)`n"
                        $varRegUni+= "   > Name:  $(((Get-ItemProperty -Path "registry::$iteration").PSObject.Properties | ? {$_ -match '[^\x00-\xff]'}).Name)`n"
                        $varRegUni+= "   > Value: $varRegValue`n"
                    }
                }
            }
        }
    }
}

if ($varRegUni) {
    write-host " ! NOTICE: Registry uninstall records with unconventional Unicode found. These may cause Audit issues."
    makeUDFString "<SW-11>"
    write-host $varRegUni
} else {
    write-host " + PASSED: Registry uninstall records. No unconventional unicode found."
}

#web port ok ---------------------------------------------------------------------------------

if ($varProgLog | select-string -Pattern 'web port ok' | Select-Object -last 1 | select-string -pattern 'false' -quiet) {
    Write-Host " ! FAILED: Web Port check. The Agent is having connectivity issues. Please check your allow-lists."
    makeUDFString "(CON-4)"
} else {
    Write-Host " + PASSED: Web Port check. The Agent is connecting to the platform without issue."
}

#current data --------------------------------------------------------------------------------

if ((New-TimeSpan -Start (Get-ChildItem -Path "$env:ProgramData\CentraStage\AEMAgent\DataLog\aemagent.log").LastWriteTime -End ([DateTime]::Now)).Hours -ge 5) {
    write-host " ! FAILED: Monitoring log. The Monitor Service appears to have stopped producing data. Please contact support."
    makeUDFString "(SW-7)"
} else {
    write-host " + PASSED: Monitoring log. Monitor logfile is present and being kept up-to-date."
}

if (!(test-Path "$env:ProgramData\CentraStage\AEMAgent\Monitors.json")) {
    write-host " ! FAILED: Monitor data. The Agent does not seem have received any monitors. Please contact support."
    makeUDFString "(SW-8)"
} elseif ((New-TimeSpan -Start (Get-ChildItem -Path "$env:ProgramData\CentraStage\AEMAgent\Monitors.json").LastWriteTime -End ([DateTime]::Now)).Hours -ge 24) {
    write-host " ! FAILED: Monitor data. The Agent has not received new monitoring data in over 24 hours. Please contact support."
    makeUDFString "(SW-9)"
} else {
    write-host " + PASSED: Monitor data. Monitor data JSON is present and being kept up-to-date."
}

#alert queue ---------------------------------------------------------------------------------

If (Get-ChildItem -Path "$env:ProgramData\CentraStage\AEMAgent\DataLog\*.alert.dat" | ? {$_.LastWriteTime -le (Get-Date).AddMinutes(-5)}) { #ie, it's OLDER than 5 minutes
    Stop-Process -Name AEMAgent -Force -ErrorAction SilentlyContinue 2>&1>$null
    makeUDFString "(SW-10)"
    write-host " ! FAILED: Alert queue. Monitor Service has been restarted to help despatch inert alert data. Consider contacting support."
} else {
    write-host " + PASSED: Alert queue. The queue is moving optimally."
}

#snmp-dot-json -------------------------------------------------------------------------------

$varJsonLast='x'
$varJsonLast=get-content "$env:ProgramData\CentraStage\snmp.json" -ea 0 | Select-Object -Last 1 -ea 0
if ($varJsonLast -notmatch '}') {
    write-host " - FAILED: SNMP File verification. The file has been reconstructed blank."
    makeUDFString "(CRR-2)"
    set-content -Value @'
{
"version": "1",
"group": []
}
'@ -Path "$env:ProgramData\CentraStage\snmp.json" -Force} else {
    write-host " + PASSED: SNMP File verification."   
}

#counterintuitive agent policy ---------------------------------------------------------------

write-host `r
write-host "= Configuration"

[xml]$varSystemXML=Get-Content $varAgentXML
('PolicyEnableIncomingSupport','PolicyEnableAudits') | % {
    if (($varSystemXML.Configuration.userSettings.'CentraStage.Cag.Core.Settings'.setting | where-object {$_.Name -match "$($_)" }).value -match 'false') {
        write-host " - NOTICE: The setting $($_) has been disabled via an Agent Policy. This may be affecting Agent behaviour."
        $varBadPolicy=$true
    }
}

if ($varBadPolicy) {
    makeUDFString "<CFG-6>"
} else {
    write-host " + PASSED: No Agent Policies are present that may cause counterintuitive behaviour."
}

##############################################################################################
#            CLOSEOUT
##############################################################################################

write-host `r
write-host '------                           @@@  @@    @@@   @@@@ @@@@@  @@@  @@ @@ @@@@                         ------'
write-host '------                   @@@    @@ @@ @@   @@ @@ @@    @@    @@ @@ @@ @@  @@     @@@                  ------'
write-host '------                   :::    @@    @@   @@ @@  @@@  @@@@  @@ @@ @@ @@  @@     :::                  ------'
write-host '------                   @@@    @@ @@ @@   @@ @@    @@ @@    @@ @@ @@ @@  @@     @@@                  ------'
write-host '------                           @@@  @@@@  @@@  @@@@  @@@@@  @@@   @@@   @@                          ------'
write-host `r

write-host ": Datto Agent Health Direct-Check is completed!"

if (!$env:usrUDF) {
    write-host "! ERROR: Component does not contain a UDF variable."
    write-host "  Please delete this Component and re-add it from the ComStore."
    write-host "  A new option, usrUDF, should become visible."
}

if ($script:varUDFString) {
    write-host "  Issues or notices were detected on this device. You may wish to:"
    write-host " - Follow up with Support, enclosing this StdOut document"
    write-host " - Try the `"Microsoft .NET Framework Repair Tool`" Component from the ComStore"
    write-host " - Try the offline Agent Health Check tool linked at the top of this StdOut document"
    if ($env:usrUDF -ge 1) {
        New-ItemProperty "HKLM:\Software\CentraStage" -Name "custom$env:usrUDF" -Value "D-C ERROR :: $script:varUDFString" | out-null
        write-host "============================================================================================================"
        write-host "- The output from this tool has been written to UDF $env:usrUDF, as instructed."
        write-host "  The results have been reduced to codes. A key is available at https://dat.to/ahckey."
        write-host "  You can filter on these codes using the API or a Custom Filter to pinpoint devices with specific issues."
        write-host "- Error IDs: $script:varUDFString"
        write-host "============================================================================================================"
    }
    if ($script:varUDFString -match '\<') {
            if ($script:varUDFString -match '\(') {
                write-host "- As failures and notices were found, exiting with failure status."
                exit 1
            } else {
                write-host "- As only notices were found, exiting with success status."
                exit 0
            }
    } else {
        write-host "- As failures were found, exiting with failure status."
        exit 1
    }
} else {
    if ($env:usrUDF -ge 1) {
        New-ItemProperty "HKLM:\Software\CentraStage" -Name "custom$env:usrUDF" -Value "D-C OK!" | out-null
    }
    write-host "  No issues or notices were detected on this device. Everything should be fine."
}