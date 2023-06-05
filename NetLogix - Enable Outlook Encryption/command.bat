New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS

$LocalUserSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
$DomainUserSID = 'S-1-12-1-\d+-\d+\-\d+\-\d+$'
 
# Get Username, SID, and location of ntuser.dat for all users
$ProfileList = gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object {($_.PSChildName -match $LocalUserSID) -or ($_.PSChildName -match $DomainUserSID)} | 
    Select  @{name="SID";expression={$_.PSChildName}}, 
            @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}}, 
            @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])', ''}}

foreach ($Profile in $ProfileList) {
  $sid = $Profile.sid
  $userhive = $Profile.userhive
  Write-Host "Loading Registry for $($Profile.username) to HKEY_CURRENT_USER\$sid"
  reg load HKU\$sid $userhive

  if (!(Test-Path HKU:$sid\Software\Microsoft\Office\16.0\Common\Identity\)) { New-Item -Path HKU:$sid\Software\Microsoft\Office\16.0\Common\Identity -Force | Out-Null }

  Write-Host "Setting registry values"

  Set-ItemProperty -Path HKU:$sid\Software\Microsoft\Office\16.0\Common\Identity\ -Name NoDomainUser -Value 1 -Type DWORD | Out-Null

  [gc]::collect()
  Start-Sleep -Seconds 2
  Write-Host "Unloading Registry hive HKEY_CURRENT_USER\$sid"
  reg unload HKU\$sid
}

Remove-PSDrive -PSProvider Registry -Name HKU