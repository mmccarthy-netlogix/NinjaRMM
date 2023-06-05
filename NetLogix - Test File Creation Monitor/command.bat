$FileToBeFound=$ExecutionContext.InvokeCommand.ExpandString($ENV:FileToBeFound)
Write-Host $ENV:FileToBeFound
Write-Host $ExecutionContext.InvokeCommand.ExpandString($ENV:FileToBeFound)
Write-Host $FileToBeFound
if (Test-Path -Path $FileToBeFound)
{
    Write-Host "<-Start Result->"
    Write-Host "-=$FileToBeFound found"
    Write-Host "<-End Result->"
    Exit 1
}
else
{
    Write-Host "<-Start Result->"
    Write-Host "-=File not found"
    Write-Host "<-End Result->"
    Exit 0
}