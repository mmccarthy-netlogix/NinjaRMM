<#Write-Output "Username: $ENV:cs_username"
Write-Output "Password: $ENV:cs_password"
Write-Output "------------------------------------------"
#>

Write-Output "Attempting to create user $ENV:cs_username"
NET USER $ENV:cs_username $ENV:cs_password /ADD /Y

if ($lastexitcode -eq 2) {
  Write-Output "User already exists, changing password"
  NET USER $ENV:cs_username $ENV:cs_password /Y
}

$Admins = NET LOCALGROUP Administrators | Select-String $ENV:cs_username
if ($Admins.count -eq 0) {
  Write-Output "Adding $ENV:cs_username to Administrators group on $ENV:COMPUTERNAME"
  NET LOCALGROUP Administrators $ENV:COMPUTERNAME\$ENV:cs_username /ADD /Y
}