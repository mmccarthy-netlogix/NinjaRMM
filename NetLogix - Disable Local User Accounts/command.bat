## Check if DC and exit
if (Get-Service NTDS -ErrorAction SilentlyContinue) {
  Write-Host "Machine is a Domain Controller.  Exiting"
  Exit 0
}

function localUsers {
  $users = $null
  $user = $null
  $enabledUsers = "Locally enabled users: "


## Get local users, parse, and update UDF
  $users = (Get-LocalUser | where {$_.Enabled -eq $True}).Name
  foreach ($user in $users){$enabledUsers += $user +"; "}

  Write-Output "------------------------------"
  Write-Output $enabledUsers
  Write-Output "------------------------------"
}

# Output local enabled users
localUsers

# Disable specified local users
$UsersToDisable=$ENV:usrDisableUsers.Replace(" ","").Split(",")
foreach ($User in $UsersToDisable) {
  Write-Output "Disabling: $User"
  Disable-LocalUser -Name $User
}


# Output updated local enabled users
localUsers