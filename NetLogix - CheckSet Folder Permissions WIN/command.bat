$AR = New-Object System.Security.AccessControl.FileSystemAccessRule($ENV:IdentityReference, $ENV:FileSystemRights, $ENV:InheritanceFlags, $ENV:PropagationFlags, $ENV:AccessControlType)

$ACL = Get-ACL $ENV:Folder

foreach ($AC in $ACL.access) {if (!(Compare-Object -ReferenceObject $AC -DifferenceObject $AR -Property FileSystemRights,IdentityReference,InheritanceFlags,PropagationFlags)) {$ACLMatch = $True}}

if (!($ACLMatch)) {
  $ACL.AddAccessrule($AR)
  Set-ACL $ENV:Folder $ACL
}

Get-ACL $ENV:Folder | FL