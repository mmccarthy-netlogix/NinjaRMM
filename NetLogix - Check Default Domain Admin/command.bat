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

# Load Active Directory PowerShell module
Import-Module ActiveDirectory

# Get Domain SID
$domainSID=(Get-AdDomain).DomainSID

# Default Administrator SID is the domain sid with -500 for the account identifier
$userSID="$domainSID-500"

# Enumerate SID to Username
$objSID = New-Object System.Security.Principal.SecurityIdentifier($userSID)
$objUser = $objSID.Translate( [System.Security.Principal.NTAccount])

# Split Username from full NETBIOS Name
$adUser=(($objUser).Value).Split("\")[1]

# Check if enabled
$adminEnabled=(Get-AdUser $adUser).Enabled

# Output
$userOutput=@()
$userOutput+="Username: $objUser"
$userOutput+="Enabled: $adminEnabled"


if ($adminEnabled) {
  Write-DRMMAlert "Admin Enabled"
  Write-DRMMDiag $userOutput
  Exit 1
} else {
  Write-DRMMAlert "OK"
  Write-DRMMDiag $userOutput
  Exit 0
}