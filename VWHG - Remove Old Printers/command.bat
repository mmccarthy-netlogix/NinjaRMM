$Server = "VWHG-DC01"
$Printers = Get-Printer | Where {$_.Name -Like "*$Server*"}
foreach ($Printer in $Printers) {
Write-Host ""Removing printer: ($Printer).Name""
Remove-Printer -InputObject $Printer
}