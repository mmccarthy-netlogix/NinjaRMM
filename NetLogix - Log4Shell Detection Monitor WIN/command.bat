if (Test-Path "$env:FileToBeFound") 
{
    $detection = Select-String -Path $ENV:PROGRAMDATA\CentraStage\L4Jdetections.txt -pattern 'ALERT\:'
    if ($detection.count -ge 1)
    {
        Write-Host "<-Start Result->"
        Write-Host "-=File found: $env:FileToBeFound"
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