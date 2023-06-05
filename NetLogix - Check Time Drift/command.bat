function Write-DRMMDiag ($messages) {
    Write-Host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    Write-Host '<-End Diagnostic->'
} 

function Write-DRMMAlert ($message) {
    Write-Host '<-Start Result->'
    Write-Host "Alert=$message"
    Write-Host '<-End Result->'
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

#accuracy of system time ---------------------------------------------------------------------
Write-Host `r

$varServerTime=([DateTimeOffset]::Parse((getHTTPHeaders http://www.google.com | Where-Object {$_.Key -eq "Date"}).Value)).UtcDateTime
$varServerEpoch=[int64](($varServerTime)-(Get-Date "1/1/1970")).TotalSeconds

if ($varServerEpoch -lt 0) {
    Write-DRMMDiag "! FAILED: Unable to gather system time from Google.com to gauge time offset. Time may be incorrect."
    Exit 1
} else {
    $varLocalEpoch=[int64](([datetime]::UtcNow)-(get-date "1/1/1970")).TotalSeconds
    [int]$varTimeOffset = $varServerEpoch - $varLocalEpoch
    if ($varTimeOffset -lt 0) {$varTimeOffset=0-$varTimeOffset}

    Write-Host "= System Clock Verification (Local: $varLocalEpoch :: Remote: $varServerEpoch)"

    if (($varTimeOffset).tostring().length -ge 4) {
            Write-DRMMAlert "FAILED: Time drift >15 minutes"
            Write-DRMMDiag " ! FAILED: System clock is more than 15 minutes out."
            Exit 1
        } elseif ($varTimeOffset -ge 600) {
            Write-DRMMAlert "FAILED: Time drift >10 minutes"
            Write-DRMMDiag " ! FAILED: System clock is more than 10 minutes out."
            Exit 1
        } elseif ($varTimeOffset -ge 121) {
            Write-DRMMAlert "FAILED: Time drift >2 minutes"
            Write-DRMMDiag " - NOTICE: System clock is more than 2 minutes out."
            Exit 1
        } elseif ($varTimeOffset -le 120) {
            Write-DRMMAlert "PASSED: Time is accurate within 2 minutes"
            Exit 0
    }
}