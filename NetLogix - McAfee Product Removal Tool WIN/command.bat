$Exec="$ENV:ProgramData\CentraStage\Packages\McAfee\mccleanup.exe"

Expand-Archive -Path .\MCCleanup.zip -DestinationPath $ENV:ProgramData\CentraStage\Packages\McAfee

if (Test-Path $Exec) {
  Write-Host "Starting Cleanup of McAfee products"
  $output = Start-Process -FilePath $Exec -Wait -NoNewWindow -PassThru -ArgumentList "-p StopServices,MFSY,PEF,MXD,CSP,Sustainability,MOCP,MFP,APPSTATS,Auth,EMproxy,FWdiver,HW,MAS,MAT,MBK,MCPR,McProxy,McSvcHost,VUL,MHN,MNA,MOBK,MPFP,MPFPCU,MPS,SHRED,MPSCU,MQC,MQCCU,MSAD,MSHR,MSK,MSKCU,MWL,NMC,RedirSvc,VS,REMEDIATION,MSC,YAP,TRUEKEY,LAM,PCB,Symlink,SafeConnect,MGS,WMIRemover,RESIDUE -v -s"
  Write-Host $output
  Write-Host "Cleanup complete"
} else {
  Write-Host "$Exec not found exiting"
  Exit 1
}