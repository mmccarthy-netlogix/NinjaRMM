$FileToBeFound=$ExecutionContext.InvokeCommand.ExpandString($ENV:FileToBeFound)

if (Test-Path -Path $FileToBeFound) {
  if ($ENV:usrCheckReboot -eq "true") {
    $FileCreate=[datetime](Get-ChildItem $FileToBeFound).CreationTime
    $StartupTime=[datetime](Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

    if ($FileCreate -gt $StartupTime) {
      Write-Host "<-Start Result->"
      Write-Host "-=$FileToBeFound created after boot"
      Write-Host "<-End Result->"
      $Null > $ENV:Programdata\Centrastage\reboot.flag
      Exit 0
    }
    else {
      Write-Host "<-Start Result->"
      Write-Host "-=$FileToBeFound created before boot"
      Write-Host "<-End Result->"
      Exit 1
    }      
  }
  else {
    Write-Host "<-Start Result->"
    Write-Host "-=$FileToBeFound found"
    Write-Host "<-End Result->"
    Exit 1
  }
}
else
{
  Write-Host "<-Start Result->"
  Write-Host "-=File not found"
  Write-Host "<-End Result->"
  Exit 0
}