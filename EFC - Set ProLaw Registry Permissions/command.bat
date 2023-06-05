# Permissions to be set
$person = [System.Security.Principal.NTAccount]"BuiltIn\Users"          
$access = [System.Security.AccessControl.RegistryRights]"FullControl"
$inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$propagation = [System.Security.AccessControl.PropagationFlags]"None"
$type = [System.Security.AccessControl.AccessControlType]"Allow"
$rule = New-Object System.Security.AccessControl.RegistryAccessRule($person,$access,$inheritance,$propagation,$type)

# Set permissions on HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\dfshim.dll
$acl = Get-Acl 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\dfshim.dll' 
$acl.SetAccessRule($rule)
$acl | Set-Acl

# Set permissions on HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\dfshim.dll
$aclWOW64 = Get-Acl 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\dfshim.dll' 
$aclWOW64.SetAccessRule($rule)
$aclWOW64 | Set-Acl