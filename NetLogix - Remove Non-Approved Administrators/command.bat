function Get-AdminUsers {
  $Group = "Administrators"
  $AdminUsers = @(
  ([ADSI]"WinNT://./$Group").psbase.Invoke('Members') |
  % { 
  $_.GetType().InvokeMember('AdsPath','GetProperty',$null,$($_),$null) 
   }
  ) -match '^WinNT'

  $Admin = $AdminUsers.Replace('WinNT://','')
  return $Admin
}

$AdminUsers = Get-AdminUsers
$Approved = $ENV:ApprovedAdmins.Split(',')

foreach ($user in $AdminUsers) {
  $username = $user.Split('/')[1]
  $user = $user.Replace('/','\')
  if ($username -notin $Approved) { Remove-LocalGroupMember -Group $Group -Member $user }
}

$AdminUsers = Get-AdminUsers

Write-Host "Current Local Admins: "
$AdminUsers