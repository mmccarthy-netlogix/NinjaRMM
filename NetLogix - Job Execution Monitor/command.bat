# Monitors the Datto RMM Centrastage log files to determin when the last job ran. 
# The monitor will create an alert if it has been over X days since the last job ran.
# The number of days is based on the date entries found in the logs and not calendar dates. This allows the monitor to 
# function on laptops and other devices that may be turned off or offline periodically.Get-Date 

# The date string from the centrastage log files.
$DatePattern='(?<=\|)(\d\d\d\d-\d\d-\d\d.*?)(?=\|)'
$OnlinePattern='CsControlConnection: Response to (.*) is Http - 200'
$JobRunPattern="Software: Running job"
$JobDisabledPattern='runjob - Incoming jobs are disabled by an agent policy'
$Days=$ENV:Days

$LogFolders=[System.Collections.ArrayList]@()

if ([IntPtr]::Size -eq 4){
    # 32 bit
    $CentrastageRoot="${env:ProgramFiles}\Centrastage"
} else {
    # 64 bit
    $CentrastageRoot="${env:ProgramFiles(x86)}\Centrastage"
}

# Add log.txt
[void]$LogFolders.add("$CentrastageRoot\log.txt")

# Add log archives
[void]$LogFolders.add("$CentrastageRoot\Archives\log.*.txt")

$LogFiles=Get-ChildItem $LogFolders | Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-$Days)}

# Build a list of dates where the agent has been online.
$FoundDates=[System.Collections.ArrayList]@()
Write-Host "<-Start Diagnostic->"
Write-Host "Processing log files..."
foreach ($Log in ($logfiles | Sort-Object -property LastWriteTime -Descending)) {
    Write-Host "`tParsing $($log.name)."
    $Content=Get-Content $Log.fullname
    # This first run builds the list of dates.
    foreach ($line in $Content){
        if ($line -match $DatePattern){
            $Date=Get-Date $Matches[0] -Format yyyy-MM-dd
            if ($line -match $OnlinePattern){
                if ($FoundDates.date -notcontains $Date){
                    $entry=[pscustomobject]@{
                        Date = $Date
                        JobExecuted = $null
                    }
                    [void]$FoundDates.add($entry)
                }
            }
        }
    }

    # This second run updates the dates where jobs were executed.
    foreach ($line in $Content){
        if ($line -match $JobRunPattern){
            $null=$line -match $DatePattern
            $JobDate=Get-Date $Matches[0] -Format yyyy-MM-dd
            $UpdateItem=$FoundDates | Where-Object {$_.Date -eq $JobDate}
            if ($null -eq $UpdateItem.JobExecuted){
                $UpdateItem.JobExecuted = $true
            }
        } elseif ($line -match $JobDisabledPattern){
            $null=$line -match $DatePattern
            $JobDate=Get-Date $Matches[0] -Format yyyy-MM-dd
            $UpdateItem=$FoundDates | Where-Object {$_.Date -eq $JobDate}
            if ($null -eq $UpdateItem.JobExecuted){
                $UpdateItem.JobExecuted = 'Disabled'
            }
        }
    }
}
$SortedDates=$FoundDates | Sort-Object -property Date -Descending

Write-Host "`nChecking results for recent job activity..."
$ActiveJobs=$false
$MostRecent=$null

# Assume no job has run.
$Alert=$true
$Status='ERROR'

# Find the most recent job execution.
foreach ($entry in $SortedDates) {
    if ($null -ne $entry.JobExecuted) {
        if ($null -eq $MostRecent){
            $MostRecent=$entry.Date
        }
    }
}

# Check if there have been any jobs in the last $Days dates.

for ($i=0; $i -lt $Days; $i++) {
    Write-Host "`t$($SortedDates[$i].Date)..." -NoNewline
    if ($SortedDates[$i].JobExecuted){
        if ('Disabled' -eq $SortedDates[$i].JobExecuted){
            Write-Host "disabled by policy."
        }
        else {
            Write-Host "detected."
        }
        $ActiveJobs=$true
        $Alert=$false
        $Status='OK'
    } else {
        Write-Host "missing."
    }
}


if ($null -eq $MostRecent){
    Write-Host "`nWARNING: No job execution activity has been detected in the agent logs."
} else {
    Write-Host "`nThe most recent job activity was on $MostRecent."
}
Write-Host "<-End Diagnostic->"

# Create monitor results and alert state.
Write-Host "<-Start Result->"
Write-Host "JobProcessing=$status"
Write-Host "<-End Result->"
if ($alert){
    Exit 1
}
else {
    Exit 0
}