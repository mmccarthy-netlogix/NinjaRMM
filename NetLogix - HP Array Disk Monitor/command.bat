#requires -version 3
<#
.SYNOPSIS
Get-ProliantDiskDrives - Get HP ProLiant disk drive status
.DESCRIPTION 
Reads the status of HP ProLiant Smart Array disk drives via WMI and HP WBEM
http://www.hp.com/go/HPwbem
.OUTPUTS
Numeric status per channel as per $statusDMTF and $statusHPExtended below
.LINK
http://daniel.streefkerkonline.com/monitoring-hp-proliant-via-powershell-wmi-drive-health/
.NOTES
Written By: Daniel Streefkerk
Website:	http://daniel.streefkerkonline.com
Twitter:	http://twitter.com/dstreefkerk
Todo:       Nothing at the moment
Change Log
https://gist.github.com/dstreefkerk/10224178
#>

function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} 

function write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

$statusDMTF = @{
                    '0' = 'Unknown'
                    '1' = 'Other'
                    '2' = 'OK'
                    '3' = 'Degraded'
                    '4' = 'Stressed'
                    '5' = 'Predictive Failure'
                    '6' = 'Error'
                    '7' = 'Non-Recoverable Error'
                    '8' = 'Starting'
                    '9' = 'Stopping'
                    '10' = 'Stopped'
                    '11' = 'In Service'
                    '12' = 'No Contact'
                    '13' = 'Lost Communication'
                    '14' = 'Aborted'
                    '15' = 'Dormant'
                    '16' = 'Supporting Entity in Error'
                    '17' = 'Completed'
                    '18' = 'Power Mode'
                    '19' = 'Relocating'
                }

$statusHPExtended = @{
                    '32768' = 'Queued for Secure Erase'
                    '32769' = 'Erase in Progress'
                    '32770' = 'Erase Completed'
                    '32771' = 'Physical Path In Error'
                    '32772' = 'Transient Data Drive'
                    '32773' = 'Rebuild'
                    '32774' = 'SSDWearOut'
                    '32775' = 'Not Authenticated'
                }

# First, test that we can use WMI
$wmiErrorVariable = @()
try {
    $computerSystem = Get-WmiObject -Namespace ROOT\CIMV2 -Class Win32_ComputerSystem -ErrorAction Stop -WarningAction SilentlyContinue -ErrorVariable wmiErrorVariable
    }
catch [System.UnauthorizedAccessException] {
    $wmiError = $true
    $wmiErrorMessage = "WMI Access denied. Error: $($_.Exception.Message)"
}
catch [System.Runtime.InteropServices.COMException] {
    $wmiError = $true
    $wmiErrorMessage = "Couldn't query WMI. Error: $($_.Exception.Message)"
}
catch {
    $wmiError = $true
    $wmiErrorMessage = $_.Exception.Message
}
finally {
    if ($wmiError -eq $true) {
        "$wmiErrorMessage $($_.Exception.Message)"
        Exit 1
    }
}

# Get all disks via WMI
$disks = Get-WmiObject -Namespace ROOT\HPQ -Class HPSA_DiskDrive -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable wmiError

# If the ROOT\HPQ WMI query failed, throw an error.
if ($wmiError.Count -gt 0) {
    "The Insight WBEM Management Providers don't seem to be installed. Error: $($wmiError.Exception.Message)"
    Exit 1
}

$diskObjectCollection = @()

foreach ($disk in $disks) {
    $thisDisk = New-Object psobject

    # Display name for the channel
    $diskName = "$($disk.ElementName) - $($disk.Description) Disk $($disk.Name)"

    # Base operational status in textual form
    $baseStatus = $disk.OperationalStatus[0]

    # Extended operational status in textual form
    $extendedStatus = $disk.OperationalStatus[1]

    # Set some properties we'll use later
    $thisDisk | Add-Member -MemberType "NoteProperty" -Name "Name" -Value $diskName

    #Uncomment the below line, and comment out the line below it to get a textual representation of the status instead of a number
    $thisDisk | Add-Member -MemberType "NoteProperty" -Name "OperationalStatus" -Value $statusDMTF["$baseStatus"]
    #$thisDisk | Add-Member -MemberType "NoteProperty" -Name "OperationalStatus" -Value $baseStatus

    #Uncomment the below line, and comment out the line below it to get a textual representation of the status instead of a number
    #$thisDisk | Add-Member -MemberType "NoteProperty" -Name "ExtendedOperationalStatus" -Value $statusHPExtended["$extendedStatus"]
    $thisDisk | Add-Member -MemberType "NoteProperty" -Name "ExtendedOperationalStatus" -Value "$extendedStatus"
    
    # If the Operational Status of the disk isn't equal to 2 (OK), we'll be setting the whole PRTG sensor to error
    if ($baseStatus -ne 2) {
        $thisDisk | Add-Member -MemberType NoteProperty -Name "Error" -Value $true
        $thisDisk | Add-Member -MemberType NoteProperty -Name "StateMessage" -Value "$diskName has the following operational status: $($statusDMTF["$baseStatus"])/$($statusHPExtended["$extendedStatus"])). "
    } else {
        $thisDisk | Add-Member -MemberType NoteProperty -Name "Error" -Value $false
        $thisDisk | Add-Member -MemberType NoteProperty -Name "StateMessage" -Value $null
    }

    # Add this custom object to the collection
    $diskObjectCollection += $thisDisk
}


$diskError = 0

foreach ($disk in $diskObjectCollection) {
  if ($disk.Error -eq $True) { $diskError += 1 }
}

if ($diskError) {
  write-DRMMAlert "Unhealthy - Disk errors found"
  write-DRMMDiag $diskObjectCollection.StateMessage
  Exit 1
} else {
  write-DRMMAlert "Healthy - No disk errors found"
}