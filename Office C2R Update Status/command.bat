# Unifying the Office C2R scripts into a single one.

# This script identifies the Office C2R channel in use and reports weather or not the
# installed Office version is up-to-date or not.

# First, get the update channel
$UpdateChannel = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -Name "UpdateChannel") -split "/" | Select-Object -Last 1
$ReportedVersion = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -Name "VersionToReport"

$MaxAge=$env:MaxAge
$FailUnsupported=$env:FailUnsupported
$FailNonC2R=$env:FailNonC2R

# Uncomment and hard-code channel guid and reported version to test script for other configurations.
# $MaxAge=10
# $FailUnsupported="True"
# $FailNonC2R="True"
# $UpdateChannel='5440fd1f-7ecb-4221-8110-145efaa6372f'
# $ReportedVersion= '16.0.16227.20094'

# Microsoft does not support the ciphers available with older operating systems with TLS 1.2. This means that Server 2012 R2/Windows 8.1 and older are unsupported.
# Check OS
if ([version](Get-WmiObject Win32_OperatingSystem).version -lt [version]"10.0"){
    Write-Host "This script is not supported on Windows 8.1/Server 2012 R2 or prior due to cipher support on learn.microsoft.com."
    exit 1
}


# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
function Get-Channel {
    param (
        [Parameter(Mandatory=$true)]
        $GUID
    )
    switch ($GUID){
        "492350f6-3a01-4f97-b9c0-c7c6ddf67d60"  {
            # Current ("Monthly")
            $Channel='Current ("Monthly")'
            $URL='https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date'
            $Format='CombinedTable'
            $Split="H3"
            $TableSection=2
        }
        "64256afe-f5d9-4f86-8936-8840a6a4f5be"  {
            # Current Preview ("Monthly Targeted"/"Insiders")
            $Channel="Current Preview (`"Monthly Targeted`"/`"Insiders`")"
            $URL='https://learn.microsoft.com/en-us/officeupdates/update-history-current-channel-preview'
            $Format='List'
            $Split="H2"
            $TableSection=2
        }
        "7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"  {
            # Semi-Annual Enterprise ("Broad")
            $Channel="Semi-Annual Enterprise (`"Broad`")"
            $URL='https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date'
            $Format='CombinedTable'
            $Split="H3"
            $TableSection=2
        }
        "b8f9b850-328d-4355-9145-c59439a0c4cf"  {
            # Semi-Annual Enterprise Preview ("Targeted")
            $Channel="Semi-Annual Enterprise Preview (`"Targeted`")"
            $URL='https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date'
            $Format='CombinedTable' 
            $Split="H3"
            $TableSection=2
        }
        "55336b82-a18d-4dd6-b5f6-9e5095c314a6"  {
            # Monthly Enterprise
            $Channel="Monthly Enterprise"
            $URL='https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date'
            $Format='CombinedTable'
            $Split="H3"
            $TableSection=2
        }
        "5440fd1f-7ecb-4221-8110-145efaa6372f"  {
            # Beta
            $Channel="Beta"
            $URL='https://learn.microsoft.com/en-us/officeupdates/update-history-beta-channel'
            $Format='List'
            $Split="H2"
            $TableSection=2
        }
        "f2e724c1-748f-4b47-8fb8-8e0d210e9208"  {
            # LTSC
            $Channel="LTSC"
            $URL="https://learn.microsoft.com/en-us/officeupdates/update-history-office-2019"
            $Split="H2"
            $Format='Table'
            $TableSection=2
        }
        "2e148de9-61c8-4051-b103-4af54baffbb4"  {
            # LTSC Preview
            $Channel="LTSC Preview"
            $URL=$null
        }
        "5030841d-c919-4594-8d2d-84ae4f96e58e"  {
            # LTSC 2021
            $Channel="LTSC 2021"
            $URL='https://learn.microsoft.com/en-us/officeupdates/update-history-office-2021'
            $Split="H2"
            $Format='Table'
            $TableSection=2
        }
        default {
            throw "Unknown update channel $GUID. Please contact script maintainer."
        }
    }
    [PSCustomObject]@{
        Channel=$Channel
        URL=$URL
        Split=$Split
        Format=$Format
        TableSection=$TableSection
    }
}

function Get-HTMLSection {
    # Splits the raw HTML into sections using header tag as a split.
    param (
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [ValidateSet("H2","H3")]
        [string]$Split,
        [Parameter(Mandatory=$true)]
        [array]$RawHTML
    )
    
    switch ($split){
        "H2" {$pattern='(<h2.*>)(.*)(?=<\/h2>)'}
        "H3" {$pattern='(<h3.*>)(.*)(?=<\/h3>)'}
    }
    $Sections=[System.Collections.ArrayList]@()
    $Part=[System.Collections.ArrayList]@()
    foreach ($line in $RawContent){
        if ($line -match $Pattern){
            # Add the lines to the part section
            [void]$Sections.Add($part)
            # Clear the existing part when the H2 header is detected
            $Part=[System.Collections.ArrayList]@()
        }
        [void]$part.Add($line.Trim())
    }
    # Finally, add any remaining parts.
    [void]$Sections.Add($part)
    # Now return the sections.
    $Sections
}

function Get-TableFromSection ($html){
    $table=[System.Collections.ArrayList]@()
    $TableStartPattern='<table'
    $tableEndPattern='</table>'
    $addline=$false
    foreach ($line in $html){
        if ($line -match $TableStartPattern){
            $TableSection=[System.Collections.ArrayList]@()
            $Addline=$true
        }
        if ($addline){
            [void]$TableSection.Add($line)
        }
        if ($line -match $tableEndPattern){
            [void]$Table.Add($TableSection)
            $Addline=$false
        }
    }
    $Table
}

function Get-FakeTableFromSection ($html){
    $CleanedHtml=[System.Collections.ArrayList]@()
    $DatePattern='<p><strong>(.*)<\/strong><br\/>'
    $VersionPattern='(Version\s.*\))'
    foreach ($line in $html){
        if ($line -match $Datepattern){
            [void]$Cleanedhtml.Add($Matches[1])
        }
        if ($line -match $Versionpattern){
            [void]$Cleanedhtml.Add($Matches[0])
        }
    }
    $CleanedHtml
}
function Get-TableRowFromRawTable ($table){
    $Row=[System.Collections.ArrayList]@()
    $RowStartPattern='<tr'
    $RowEndPattern='</tr>'
    $addline=$false
    foreach ($line in $table){
        if ($line -match $RowStartPattern){
            $RowSection=[System.Collections.ArrayList]@()
            $Addline=$true
        }
        if ($addline){
            [void]$RowSection.Add($line)
        }
        if ($line -match $RowEndPattern){
            [void]$Row.Add($RowSection)
            $Addline=$false
        }
    }
    $Row
}

function Get-Td ($RawTd){
    $pattern='(<td.*?>)(.*)(?=<\/td>)'
    $RawTd -match $Pattern | Out-Null
    if ($null -ne $Matches[2]){
        $Matches[2].Replace('<br/>','').Trim()
    }
    else {
        $null
    }
}


function Get-Build ($string) {
    $pattern1='(?<=\(Build.)(.*)(?=\)<\/a>)'
    $pattern2='(?<=\(Build.)(.*)(?=\))'
    if ($string -match $pattern1){
        $build='16.0.'+$Matches[0].Replace(') (Rolled back','').Trim()
        $build
    }
    elseif ($String -match $pattern2){
        $build='16.0.'+$Matches[0].Replace(') (Rolled back','').Trim()
        $build
    }
}
function Get-Version ($string) {
    $pattern1='(?<=>Version)(.*)(?=\(Build)'
    $pattern2='(?<=Version)(.*)(?=\(Build)'
    if ($string -match $pattern1){
        $Version=$Matches[0].Trim()
        $Version
    }
    elseif ($String -match $pattern2){
        $Version=$Matches[0].Trim()
        $Version
    }
}


# If the UpdateChannel value isn't defined exit. This is likely a non-C2R install of Office.
if ($null -eq $UpdateChannel){
    Write-Host "ERROR: No UpdateChannel or non-C2R Office version detected."
    if ($FailNonC2R -eq $true){
        exit 1
    }
    else {
        exit 0
    }
}


$Details=Get-Channel $UpdateChannel

if ($null -eq $Details.URL){
    Write-Host "The Office C2R channel $($Details.Channel) is not currently supported by this script."
    if ($FailUnsupported -eq $true){
        exit 1
    }
    else {
        exit 0
    }
}

$Webrequest=Invoke-WebRequest -Uri $Details.URL -UseBasicParsing
$RawContent=($Webrequest.RawContent).Split([Environment]::NewLine,[System.StringSplitOptions]::RemoveEmptyEntries)
$Sections=Get-HTMLSection -RawHTML $RawContent -Split $Details.Split


switch ($Details.Format){
    "CombinedTable" {
        $RawVersionTable=(Get-TableFromSection $Sections[$Details.TableSection]).Split([Environment]::NewLine,[System.StringSplitOptions]::RemoveEmptyEntries)
        $Rows=Get-TableRowFromRawTable $RawVersionTable
        $TableData=[System.Collections.ArrayList]@()
        for ($i=1; $i -lt $Rows.count; $i++){
            $year=$null
            $MonthDay=$null
            $Date=""
            $Current=$null
            $Enterprise=$null
            $Targeted=$null
            $Broad=$null
            for ($m=1; $m -lt 7; $m++){
                switch ($m){
                    1   {$year=Get-TD $rows[$i][$m]}
                    2   {$MonthDay=Get-TD $rows[$i][$m]}
                    3   {$Current=Get-TD $rows[$i][$m]}
                    4   {$Enterprise=Get-TD $rows[$i][$m]}
                    5   {$Targeted=Get-TD $rows[$i][$m]}
                    6   {$Broad=Get-TD $rows[$i][$m]}
                    # 7 is apparently always empty
                }
            }
            $entry=[PSCustomObject]@{
                Year = $year
                MonthDay = $MonthDay
                Date = $Date
                Current = $Current
                Enterprise = $Enterprise
                Targeted = $Targeted
                Broad = $Broad
            }
            [void]$TableData.Add($entry)
        }
        
        foreach ($entry in $TableData){
            if ([string]::IsNullOrWhiteSpace($entry.year)){
                $year=$null
                foreach ($property in $entry.PSObject.Properties){
                    switch ($property.Value){
                        {$_ -match "-2017"} {$year="2017"}
                        {$_ -match "-2018"} {$year="2018"}
                        {$_ -match "-2019"} {$year="2019"}
                        {$_ -match "-2020"} {$year="2020"}
                        {$_ -match "-2021"} {$year="2021"}
                        {$_ -match "-2022"} {$year="2022"}
                        {$_ -match "-2023"} {$year="2022"}
                    }
                    if ($year){
                        $entry.Year=$year
                        break
                    }
                }
            }
        }
        # Create a standardized date for all entries.
        foreach ($entry in $TableData){
            try {
                $entry.Date=Get-Date "$($entry.MonthDay), $($entry.year)" -format "MMMM d, yyyy" -ErrorAction Stop
            }
            catch {
                $entry.date=$null
            }
            
        }
        
        # If any entries have multiple links, put them on their own line.
        foreach ($entry in $TableData){
            foreach ($property in $entry.PSObject.Properties){
                switch ($property.name){
                    "Year"  {}
                    "MonthDay"  {}
                    "Date"  {}
                    default {
                        $property.Value=($property.Value -replace '\s+',' ').Replace('</a> <a','</a>@<a').Replace('</a><a','</a>@<a').Split('@')
                    }
                }
            }    
        }
        $CurrentList=[System.Collections.ArrayList]@()
        $MonthlyEnterpriseList=[System.Collections.ArrayList]@()
        $TargetedList=[System.Collections.ArrayList]@()
        $BroadList=[System.Collections.ArrayList]@()
        foreach ($entry in $TableData){
            $date=$entry.Date
            foreach ($item in $entry.Current){
                if (!([string]::IsNullOrWhiteSpace($item))){
                    $Version=Get-Version $item
                    $Build=Get-build $item
                    $object=[PSCustomObject]@{
                        Date = $Date
                        Version=$version
                        Build=$Build
                    }
                    [void]$CurrentList.Add($object)
                }
            }
            foreach ($item in $entry.Enterprise){
                if (!([string]::IsNullOrWhiteSpace($item))){
                    $Version=Get-Version $item
                    $Build=Get-build $item
                    $object=[PSCustomObject]@{
                        Date = $Date
                        Version=$version
                        Build=$Build
                    }
                    [void]$MonthlyEnterpriseList.Add($object)
                }
            }
            foreach ($item in $entry.Targeted){
                if (!([string]::IsNullOrWhiteSpace($item))){
                    $Version=Get-Version $item
                    $Build=Get-build $item
                    $object=[PSCustomObject]@{
                        Date = $Date
                        Version=$version
                        Build=$Build
                    }
                    [void]$TargetedList.Add($object)
                }
            }
            foreach ($item in $entry.Broad){
                if (!([string]::IsNullOrWhiteSpace($item))){
                    $Version=Get-Version $item
                    $Build=Get-build $item
                    $object=[PSCustomObject]@{
                        Date = $Date
                        Version=$version
                        Build=$Build
                    }
                    [void]$BroadList.Add($object)
                }
            }
        }
        $CurrentList=$CurrentList | sort-object -property Version -Descending
        $MonthlyEnterpriseList=$MonthlyEnterpriseList | sort-object -property Version -Descending
        $TargetedList=$TargetedList | sort-object -property Version -Descending
        $Broadlist=$BroadList | sort-object -property Version -Descending
        switch ($Details.Channel){
            'Current ("Monthly")'   {
                $VersionList=$CurrentList
            }
            'Monthly Enterprise'    {
                $VersionList=$MonthlyEnterpriseList
            }
            'Semi-Annual Enterprise Preview ("Targeted")'   {
                $VersionList=$TargetedList
            }
            'Semi-Annual Enterprise ("Broad")'  {
                $VersionList=$BroadList
            }
        }
    }
    "Table"         {
        $RawVersionTable=(Get-TableFromSection $Sections[$Details.TableSection]).Split([Environment]::NewLine,[System.StringSplitOptions]::RemoveEmptyEntries)
        $Rows=Get-TableRowFromRawTable $RawVersionTable
        $TableData=[System.Collections.ArrayList]@()
        $TDPattern='(<td.*">)(.*)(<\/td>)'
        foreach ($entry in $rows){
            foreach ($line in $entry){
                if ($line -match $TDPattern){
                    $field=$Matches[2]
                    try {
                        $field | get-date -ErrorAction Stop | Out-Null
                        $Date=$field
                    }
                    catch {
                        $RawVersion=$field
                    }
                    if (($null -ne $date) -and ($null -ne $RawVersion)){
                        $Row=[PSCustomObject]@{
                            Date = $date
                            RawVersion = $RawVersion
                            Version = $null
                            Build = $null
                        }
                        [void]$TableData.Add($row)
                        $Date=$null
                        $RawVersion=$null
                    }
                }
            }
        }
        if (($TableData | measure-object).count -ge 1){
            # Version match pattern
            $VersionPattern="Version\s.*(?=.\(Build)"
            # Build match pattern
            $BuildPattern="(?<=\(Build\s).*(?=\))"
            foreach ($item in $Tabledata){
                $Version=$null
                $Build=$null
                if ($item -match $VersionPattern){
                    $Version=($Matches[0]).Replace('Version','').Trim()
                    $item.version=$version
                }
                if ($item -match $BuildPattern){
                    $Build="16.0."+$Matches[0]
                    $item.build=$Build
                }
            }
        }
        $VersionList=$TableData | select-object Date,Version,Build


    }
    "List"          {
        $FilteredData=Get-FakeTableFromSection $Sections[$Details.TableSection]
        $TableData=[System.Collections.ArrayList]@()
        for ($i=0; $i -lt $FilteredData.count ; $i=$i+2){
            $Date=$FilteredData[$i]
            $RawVersion=$FilteredData[$i+1]
            $Row=[PSCustomObject]@{
                Date = $date
                RawVersion = $RawVersion
                Version = Get-Version $RawVersion
                Build = Get-Build $RawVersion
            }
            [void]$TableData.Add($Row)
        }
        $VersionList=$TableData | select-object Date,Version,Build
    }
}


# Sort VersionList by Date, then version.
$VersionList=$VersionList | Sort-Object -property @{Expression={[System.DateTime]::ParseExact(((Get-date ($_.date) -Format MM-dd-yyyy)),"MM-dd-yyyy",$null)}; Descending=$true},@{Expression={$_.Version}; Descending=$true}


# exit

# Get index value of reported version.
$VersionIndex=$Versionlist.Build.IndexOf($ReportedVersion)

# Get the release date for the installed version.
$ReleaseDate=($Versionlist[$VersionIndex]).Date
$UniqueDates=$VersionList.date | select-object -Unique
$Now=Get-Date

# Go through the release dates until we find one that is older than the max age.
# This will let new release not be counted as "current" until they are at least $MaxDays old.
for ($i=0;$i -lt $UniqueDates.count; $i++){
    $CurrentReleaseDate=($UniqueDates[$i])
    $CurrentReleaseAge=($Now-(Get-Date $CurrentReleaseDate)).Days
    if (($CurrentReleaseAge - $MaxAge) -gt 0){
        break
    }
}
if ((Get-Date($ReleaseDate)) -lt (Get-Date($CurrentReleaseDate))){
    # 
    $CurrentAge=((Get-Date($CurrentReleaseDate))-(Get-Date($ReleaseDate))).Days
    $UpToDate=$false
}
else {
    $UpToDate=$true
}

Write-Output "`n       Office Click-To-Run Details"
Write-Output "========================================="
Write-Output "`n     Update Channel: $($Details.Channel)"
Write-Output "  Installed Version: $ReportedVersion"
Write-Output "       Release Date: $ReleaseDate"
Write-Output "Latest Release Date: $($UniqueDates[0])"
Write-Output "         Up-To-Date: $UpToDate"
if ($UpToDate -eq $false){
    Write-Output "   Days Out Of Date: $CurrentAge"
}

Write-Output "`n`n`nLast 10 updates for update channel:"
for ($i=0;$i -lt 10;$i++) {Write-Output $($VersionList[$i])}

if ($UptoDate){
    exit 0
}
else {
    exit 1
}