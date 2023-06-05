#software monitor :: build 2/seagull :: based on code by alex b., datto

if ($env:usrSearch -match 'Custom') {
    $varString=$env:usrString
} else {
    $varString=$env:usrSearch
}

("HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall") | % {
    if (gci -Path $_ | % { Get-ItemProperty $_.PSPath } | ? { $_.DisplayName -match "$varString" } | select DisplayName) {
        $varSuccess++
    }
}

$chkServices=$ENV:usrServiceName.Replace(" ","").Split(",")

if ($ENV:usrServiceCheck -ne "FALSE") {
  foreach ($service in $chkServices) {
    if (Get-Service $service) {$srvSuccess++}
  }
}

if ($ENV:usrServiceCheck -eq "OR") {$varSuccess=$varSuccess+$srvSuccess}
if ($ENV:usrServiceCheck -eq "AND") {
  if ($varSuccess -and $srvSuccess) {$varSuccess=$varSuccess+$srvSuccess}
    else {$varSuccess=$FALSE}
}

if ($varSuccess) {
    write-host '<-Start Result->'
    write-host "X=Software ($varString) is installed."
    write-host '<-End Result->'
    exit 0
} else {
    write-host '<-Start Result->'
    write-host "X=Software ($varString) is not installed. If a response Job has been configured properly, it will now install."
    write-host '<-End Result->'
    exit 1
}