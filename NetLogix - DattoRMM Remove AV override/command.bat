if (Test-Path $ENV:ProgramData\CentraStage\AEMAgent\antivirus.json) {
  Remove-Item $ENV:ProgramData\CentraStage\AEMAgent\antivirus.json -Force
}