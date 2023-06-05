#modify variables accordingly 
$fileExtension = "*.lnk"
$folder = $ExecutionContext.InvokeCommand.ExpandString($ENV:SearchFolder)
$originalPath = $ExecutionContext.InvokeCommand.ExpandString($ENV:originalPath)
$newPath = $ExecutionContext.InvokeCommand.ExpandString($ENV:newPath)
$commit = ($ENV:Commit -eq "Yes")
$csv = ($ENV:ExportCSV -eq "Yes")

$fileExtension = $fileExtension.ToLower()
$folder = $folder.ToLower()
$originalPath = $originalPath.ToLower()
$newPath = $newPath.ToLower()

$list = Get-ChildItem -Path $folder -Filter $fileExtension -Recurse  | Where-Object { $_.Attributes -ne "Directory"} | select -ExpandProperty FullName 
$links = @()
$alllinks = @()
 
ForEach($lnk in $list) 
{ 
      $obj = New-Object -ComObject WScript.Shell 
      $link = $obj.CreateShortcut($lnk)
      $alllinks += $link
      $path = $link.TargetPath.ToLower()
      if ($path.Contains($originalPath)) {
        $link.IconLocation = $link.IconLocation.ToLower().Replace($originalpath,$newPath) 
        $link.TargetPath = $link.TargetPath.ToLower().Replace($originalpath,$newPath) 
        $link.WorkingDirectory = $link.WorkingDirectory.ToLower().Replace($originalpath,$newPath) 
        if ($commit) { $link.Save() }
        $links += $link
      }
}

if ($csv) {
  $links | Select FullName, IconLocation, TargetPath, WorkingDirectory | Export-CSV "C:\ProgramData\CentraStage\links.csv"
}

$links | Select FullName, IconLocation, TargetPath, WorkingDirectory

Write-Host "All link targets:"
$alllinks.targetpath