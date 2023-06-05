$Adapters = Get-NetAdapter | Where -Property Status -eq "Up"

$DHCP = Get-NetIPInterface -InterfaceIndex $Adapters.InterfaceIndex -AddressFamily IPv4
$IPAddress = Get-NetIPAddress -InterfaceIndex $Adapters.InterfaceIndex -AddressFamily IPv4

$DHCP, $IPAddress | Select InterfaceAlias,DHCP,IPAddress