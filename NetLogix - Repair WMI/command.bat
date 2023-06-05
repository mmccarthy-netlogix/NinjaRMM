# Checks to see if WMI is working and if not, attempts to reset it.
$RepairAttempted=$false
$WMIWorking=$false
try {
    Get-WmiObject Win32_ComputerSystem -ErrorAction Stop | out-null
    $WMIWorking=$true
}
catch {
    write-host "WMI appears to be broken. Attempting reset of WMI repository."
    net stop winmgmt /y
    Winmgmt /resetrepository
    $RepairAttempted=$true
}

if ($RepairAttempted -eq $true){
    write-host "Retesting system..."
    start-sleep 10
    try {
        Get-WmiObject Win32_ComputerSystem -ErrorAction Stop | out-null
        $WMIWorking=$true
    }
    catch {

    }
}


if ($WMIWorking -eq $true){
    write-host "WMI appears to be working."
    exit 0
}
else {
    write-host "Unable to repair WMI. Please troubleshoot this system manually."
    exit 1
}
