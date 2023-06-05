function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { write-host $message.WriterName,"|",$message.StateID,"|",$message.StateDesc,"|",$message.LastError }
    write-host '<-End Diagnostic->'
} 


function write-DRMMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}

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

$FailedWriters = $Writers | Where {$_.StateID -notin 1,5}

if ($FailedWriters) {
    write-DRMMAlert  "Some VSS writers are not in a stable state. Please investigate"
    write-DRMMDiag $FailedWriters
    exit 1
} else {
    write-DRMMAlert "Healthy - All VSS Writers Stable"
    write-DRMMDiag $Writers
}