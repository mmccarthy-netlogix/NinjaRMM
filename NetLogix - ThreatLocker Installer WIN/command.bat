#threatLocker installer :: based on code by threatlocker, inc :: build 3/seagull

write-host "ThreatLocker Installer"
write-host "==========================="

# FUNCTIONS :: copyrighted code by datto, inc. used with permission

function getProxyData {
    if (([IntPtr]::size) -eq 4) {$configLoc="$env:SystemDrive\Program Files\CentraStage\CagService.exe.config"} else {$configLoc="$env:SystemDrive\Program Files (x86)\CentraStage\CagService.exe.config"}
	[xml]$varPlatXML= get-content "$configLoc" -ErrorAction SilentlyContinue
	$script:varProxyLoc=($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | Where-Object {$_.Name -eq 'ProxyIp'}).value
    $script:varProxyPort=($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | Where-Object {$_.Name -eq 'ProxyPort'}).value
}

function downloadFile { #downloadFile build 31/seagull :: copyright datto, inc.

    param (
        [parameter(mandatory=$false)]$url,
        [parameter(mandatory=$false)]$whitelist,
        [parameter(mandatory=$false)]$filename,
        [parameter(mandatory=$false,ValueFromPipeline=$true)]$pipe
    )

    function setUserAgent {
        $script:WebClient = New-Object System.Net.WebClient
    	$script:webClient.UseDefaultCredentials = $true
        $script:webClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
        $script:webClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)');
    }

    if (!$url) {$url=$pipe}
    if (!$whitelist) {$whitelist="the required web addresses."}
	if (!$filename) {$filename=$url.split('/')[-1]}
	
    try { #enable TLS 1.2
		[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    } catch [system.exception] {
		write-host "- ERROR: Could not implement TLS 1.2 Support."
		write-host "  This can occur on Windows 7 devices lacking Service Pack 1."
		write-host "  Please install that before proceeding."
		exit 1
    }
	
	write-host "- Downloading: $url"
    if ($env:CS_PROFILE_PROXY_TYPE -eq "0" -or !$env:CS_PROFILE_PROXY_TYPE) {$useProxy=$false} else {$useProxy=$true}

	if ($useProxy) {
        setUserAgent
        getProxyData
        write-host ": Proxy location: $script:varProxyLoc`:$script:varProxyPort"
	    $script:WebClient.Proxy = New-Object System.Net.WebProxy("$script:varProxyLoc`:$script:varProxyPort",$true)
	    $script:WebClient.DownloadFile("$url","$filename")
		if (!(test-path $filename)) {$useProxy=$false}
    }

	if (!$useProxy) {
		setUserAgent #do it again so we can fallback if proxy fails
		$script:webClient.DownloadFile("$url","$filename")
	} 

    if (!(test-path $filename)) {
        write-host "- ERROR: File $filename could not be downloaded."
        write-host "  Please ensure you are whitelisting $whitelist."
        write-host "- Operations cannot continue; exiting."
        exit 1
    } else {
        write-host "- Downloaded:  $filename"
    }
}

function verifyPackage ($file, $certificate, $thumbprint, $name, $url) {
    $varChain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try {
        $varChain.Build((Get-AuthenticodeSignature -FilePath "$file").SignerCertificate) | out-null
    } catch [System.Management.Automation.MethodInvocationException] {
        write-host "- ERROR: $name installer did not contain a valid digital certificate."
        write-host "  This could suggest a change in the way $name is packaged; it could"
        write-host "  also suggest tampering in the connection chain."
        write-host "- Please ensure $url is whitelisted and try again."
       write-host "  If this issue persists across different devices, please file a support ticket."
    }

    $varIntermediate=($varChain.ChainElements | ForEach-Object {$_.Certificate} | Where-Object {$_.Subject -match "$certificate"}).Thumbprint

    if ($varIntermediate -ne $thumbprint) {
        write-host "- ERROR: $file did not pass verification checks for its digital signature."
        write-host "  This could suggest that the certificate used to sign the $name installer"
        write-host "  has changed; it could also suggest tampering in the connection chain."
        write-host `r
        if ($varIntermediate) {
            write-host ": We received: $varIntermediate"
            write-host "  We expected: $thumbprint"
            write-host "  Please report this issue."
        }
        write-host "- Installation cannot continue. Exiting."
        exit 1
    } else {
        write-host "- Digital Signature verification passed."
    }
}

# CODE

#download/verify the right installer for the right architecture
if ([intptr]::Size -eq 8) {
    downloadFile "https://api.threatlocker.com/updates/installers/threatlockerstubx64.exe" "https://api.threatlocker.com" "ThreatLockerStub.exe"
} else {
    downloadFile "https://api.threatlocker.com/updates/installers/threatlockerstubx86.exe" "https://api.threatlocker.com" "ThreatLockerStub.exe"
}

verifyPackage "ThreatLockerStub.exe" "DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1" "7B0F360B775F76C94A12CA48445AA2D2A875701C" "ThreatLocker" "www.threatlocker.com"

#verify that a serial number has been supplied and is of a valid length
if (($env:usrTLSerialSITE -as [string]).length -gt 0) {
    write-host "- Using Site-level ThreatLocker serial code."
    $varSerial=$env:usrTLSerialSITE
} elseif (($env:usrTLSerial -as [string]).length -gt 0) {
    write-host "- Using Component-level ThreatLocker serial code."
    $varSerial=$env:usrTLSerial
} else {
    write-host "! ERROR: No serial code provided."
    write-host "  Please re-run this Component with a valid ThreatLocker serial."
}

if ($varSerial) {
    if (($varSerial -as [string]).Length -ne 36) {
        write-host "- ERROR: ThreatLocker serial code is invalid."
        write-host "  The code is thirty-six characters long including dashes, with no quote marks."
        write-host "  Please verify the Site- or Account-level usrTLSerial value."
        exit 1
    }
} else {
    write-host "- ERROR: No serial number for ThreatLocker has been supplied."
    write-host "  Please define a variable at the Site- or Account-level called `'usrTLSerial`'"
    write-host "  with your 36-character ThreatLocker serial before re-attempting installation."
    exit 1
}

#install
try {
    write-host "- Serial key: $varSerial"
    $CompanyName=($env:CS_PROFILE_NAME -split(" - "))[0]
    Start-Process ThreatLockerStub.exe -argumentList "key=`"$varSerial`" Company=`"$CompanyName`""
    write-host "- Installation succeeded!"
} catch {
    Write-host "- Installation Failed. Your serial code may be invalid."
    Exit 1
}