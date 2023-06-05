if ([intptr]::Size -eq 4) {
    $varRegNode="HKLM:\Software"
} else {
    $varRegNode="HKLM:\Software\Wow6432Node"
}

$swList=Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.HelpLink -like "*cloudradial.com"}

foreach ($sw in $swList) {
    $swName=$sw.DisplayName
    write-host "- Uninstalling $swName..."
    Start-Process $sw.UninstallString -ArgumentList "/SILENT" -NoNewWindow
}
