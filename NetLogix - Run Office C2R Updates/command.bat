#if ($ENV:ChangeUpdateChannel -eq "true") {
#  Start-Process -WindowStyle hidden -FilePath "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" -ArgumentList "/changesetting UpdateChannel=$ENV:UpdateChannel" -Wait
#}

Start-Process -WindowStyle hidden -FilePath "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe" -ArgumentList "/update user updatepromptuser=false forceappshutdown=true displaylevel=false" -Wait