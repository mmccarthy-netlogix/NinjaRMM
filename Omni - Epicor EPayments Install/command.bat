# Variables
$swName="Epicor EPayments"

# Install
Write-Host "Installing $swName"
msiexec /i EPaymentsSetup.msi /qn /norestart

# Allow time for install to complete
Start-Sleep 10

# Verify the install
$swList=Get-WmiObject -Class Win32_Product -Filter "name like `"$swName`""

if ($swList.Name -eq $swName) {
  Write-Host "Installation Successful"
} else {
  Write-Host "Installation Failed"
  Exit 1
}