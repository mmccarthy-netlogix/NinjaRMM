## Initialize Variables
$CustomUDF=$env:CustomUDF
$users = $null
$user = $null
$enabledUsers = "Locally enabled users: "

## Check if DC and exit
if (Get-Service NTDS -ErrorAction SilentlyContinue) {
  Write-Host "Machine is a Domain Controller.  Exiting"
  Exit 0
}

## Get local users, parse, and update UDF
$users = (Get-LocalUser | where {$_.Enabled -eq $True}).Name
foreach ($user in $users){$enabledUsers += $user +"; "}

$enabledUsers

if([bool]$ENV:UDFOutput -eq $true){
    New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $CustomUDF -PropertyType String -Value "$enabledUsers" | Out-Null
}