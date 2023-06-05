function checkWriters {

  $Writers = @()
  $RawWriters = Invoke-Command -ErrorAction Stop -ScriptBlock {VssAdmin List Writers} 

  for ($i=0; $i -lt $RawWriters.Count; $i++) {
     if ($RawWriters[$i] -Match "Writer name") {
        $Writer = New-Object -TypeName psobject
        $Writer| Add-Member -MemberType NoteProperty -Name WriterName -Value $RawWriters[$i].Split("'")[1]
        $Writer| Add-Member -MemberType NoteProperty -Name StateID -Value $RawWriters[($i+3)].SubString(11,1)
        $Writer| Add-Member -MemberType NoteProperty -Name StateDesc -Value $RawWriters[($i+3)].SubString(14,$RawWriters[($i+3)].Length - 14)
        $Writer| Add-Member -MemberType NoteProperty -Name LastError -Value $RawWriters[($i+4)].SubString(15,$RawWriters[($i+4)].Length - 15)
        $Writers += $Writer 
     }
  }
return $Writers
}

$Writers = checkWriters
$FailedWriters = $Writers | Where {$_.StateID -notin 1,5}

if ($FailedWriters.count) {
  Write-Host "Failed writers:"
  $FailedWriters.WriterName
} else {
  Write-Host "No failed VSS writers found"
  $Writers

switch ($FailedWriters.WriterName) {
  "ASR Writer" { Restart-Service VSS -Force }
  "BITS Writer" { Restart-Service BITS -Force }
  "Certificate Authority" { Restart-Service CertSvc -Force }
  "COM+ REGDB Writer" { Restart-Service VSS -Force }
  "DFS Replication service writer" { Restart-Service DFSR -Force }
  "DHCP Jet Writer" { Restart-Service DHCPServer -Force }
  "FRS Writer" { Restart-Service NtFrs -Force }
  "FSRM writer" { Restart-Service srmsvc -Force }
  "IIS Config Writer" { Restart-Service AppHostSvc -Force }
  "IIS Metabase Writer"	{ Restart-Service IISADMIN -Force }
  "Microsoft Exchange Replica Writer" { Restart-Service MSExchangeRepl -Force }
  "Microsoft Exchange Writer"	{ Restart-Service MSExchangeIS -Force }
  "Microsoft Hyper-V VSS Writer" { Restart-Service vmms -Force }
  "MSMQ Writer (MSMQ)" { Restart-Service MSMQ -Force }
  "MSSearch Service Writer" { Restart-Service WSearch -Force }
# Stopping the NTDS service will stop Active Directory authentication and possibly require users to re-authenticate
#  "NTDS" { Restart-Service NTDS -Force }
  "OSearch VSS Writer" { Restart-Service OSearch -Force }
  "OSearch14 VSS Writer" { Restart-Service OSearch14 -Force }
  "Registry Writer" { Restart-Service VSS -Force }
  "Shadow Copy Optimization Writer"	{ Restart-Service VSS -Force }
  "SPSearch VSS Writer"	{ Restart-Service SPSearch -Force }
  "SPSearch4 VSS Writer" { Restart-Service SPSearch4 -Force }
  "SqlServerWriter" { Restart-Service SQLWriter -Force }
  "System Writer"	{ Restart-Service CryptSvc -Force }
  "TermServLicensing" { Restart-Service TermServLicensing -Force }
  "WIDW Writer" { Restart-Service WIDWriter -Force }
  "WINS Jet Writer" { Restart-Service WINS -Force }
  "WMI Writer" { Restart-Service Winmgmt -Force }
}