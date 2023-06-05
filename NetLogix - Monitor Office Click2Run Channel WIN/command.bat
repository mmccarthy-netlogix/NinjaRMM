function Write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
    }

$Channel = $((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration").UpdateChannel)

If(!$Channel) { 
    if (!(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun")) {
        if (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Office")) {
            $Channel = "MS Office Not Installed"
        } else {
            $Channel = "VLSC"
        }
    } else {
        $Channel = "No Channel selected."
    }
} else {
    switch ($Channel) { 
        "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60" {$Channel = "Monthly Channel"} 
        "http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be" {$Channel = "Monthly Channel (Targeted)"} 
        "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114" {$Channel = "Semi-Annual Channel"} 
        "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf" {$Channel = "Semi-Annual Channel (Targeted)"} 
        "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6" {$Channel = "Monthly Channel"}
    }
}

switch ($Channel) {
    $ENV:Channel {Write-DRMMAlert "Healthy. Channel set to $Channel"}
    "VLSC" {Write-DRMMAlert "Healthy. VLSC installed"}
    "MS Office Not Installed" {Write-DRMMAlert "Healthy. $Channel"}
    Default {Write-DRMMAlert "Not healthy - Channel set to $Channel"; Exit 1}
}