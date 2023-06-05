#change device hostname :: build 2/seagull

write-host "- Current hostname: $env:computername"
$changeOver=(Get-WmiObject Win32_ComputerSystem -ComputerName $env:computername).Rename($env:usrNewName)

if ($changeOver.RETURNVALUE -eq 5) {
    write-host "- ERROR: Unable to change device hostname (permission denied)."
    write-host "  Devices joined to an Active Directory Domain cannot change hostnames without"
    write-host "  using Domain-level administrator credentials."
    write-host ": The device has not been altered. Exiting."
    exit 1
} elseif ($changeOver.RETURNVALUE -eq 0) {
    write-host "- Hostname has been changed to $env:usrNewName."
} else {
    write-host "- Unknown error: Code $($changeOver.RETURNVALUE)."
}

if ($env:usrReboot -match 'true') {
   write-host "- Rebooting system..."
   shutdown /t 180 /r /c "Your device is being restarted to change its hostname."
}