$ENV:usrServer="localhost"
$ENV:usrInterval=60

$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if($Version -lt "6.3") {
  Write-Host '<-Start Result->'
  Write-Host "Error: Unsupported OS. This component requires at least Server 2012R2"
  Write-Host '<-End Result->'
  Exit 1
}
Function Get-PrivilegedGroupChanges {
  Param(
    $Server = "$ENV:usrServer",
    $Minutes = $ENV:usrInterval
  )

  $ProtectedGroups = Get-ADGroup -Filter 'AdminCount -eq 1' -Server $Server
  $Members = @()

  ForEach ($Group in $ProtectedGroups) {
    $Members += Get-ADReplicationAttributeMetadata -Server $Server `
    -Object $Group.DistinguishedName -ShowAllLinkedValues |
    Where-Object {$_.IsLinkValue} |
    Select-Object @{name='GroupDN';expression={$Group.DistinguishedName}}, `
    @{name='GroupName';expression={$Group.Name}}, *
  }

  $Members |
  Where-Object {$_.LastOriginatingChangeTime -gt (Get-Date).AddMinutes(-1 * $Minutes)}
}

$ListOfChanges = Get-PrivilegedGroupChanges
Write-Host "<-Start Diagnostic->"

foreach($Change in $ListOfChanges){
  if($Change.LastOriginatingDeleteTime -gt "1-1-1601 01:00:00"){ $ChangeType = "removed"  } else { $ChangeType = "added"}
  Write-Host "$($Change.groupname) has been edited. $($Change.AttributeValue) has been $ChangeType"
}

Write-Host "<-End Diagnostic->"
if($ListOfChanges -eq $Null) {
  Write-Host "<-Start Result->"
  Write-Host "GroupChanges=Healthy"
  Write-Host "<-End Result->"
} else {
  if($ListOfChanges.count -gt 1){
    Write-Host "<-Start Result->"
    Write-Host "GroupChanges=Multiple changes have been made. Please check diagnostic data"
    Write-Host "<-End Result->"
#    Exit 1
  }else{
    if($listofchanges.LastOriginatingDeleteTime -gt "1-1-1601 01:00:00"){ $ChangeType = "removed"  } else { $ChangeType = "added"}
    Write-Host "<-Start Result->"
    Write-Host "GroupChanges=$($ListOfChanges.groupname) has been edited. $($listofchanges.AttributeValue) has been $ChangeType"
    Write-Host "<-End Result->"
#    Exit 1
  }
}