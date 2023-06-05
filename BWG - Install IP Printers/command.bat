function InstallPrinter ($Name, $Driver, $IPAddress) {
  Write-Host "Driver: "$Driver
  Write-Host "Name: "$Name
  Write-Host "IP: "$IPAddress
  Add-PrinterDriver -Name $Driver
  Add-PrinterPort -Name "IP_$IPAddress" -PrinterHostAddress $IPAddress
  Add-Printer -DriverName $Driver -Name $Name -PortName "IP_$IPAddress"
}

Expand-Archive .\Drivers.zip .\Drivers
pnputil /a ".\Drivers\PCL\EN\Win_x64\KOAXPJ__.INF"

# Worcester

InstallPrinter "Office Printer - Worcester" "KONICA MINOLTA C658SeriesPCL" "192.168.7.30"

# Millbury

InstallPrinter "Office Printer - Millbury" "KONICA MINOLTA C368SeriesPCL" "192.168.2.70"

# Leominster

InstallPrinter "Office Printer - Leominster" "KONICA MINOLTA C368SeriesPCL" "192.168.4.60"
