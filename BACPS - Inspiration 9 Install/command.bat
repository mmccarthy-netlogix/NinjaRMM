#Expand the Inspiration installer
Write-Host "Expanding Archive"
Expand-Archive -Path ".\Inspiration 9.zip" -DestinationPath "."
Set-Location ".\Inspiration 9"

#Create the path in C:\ProgramData
Write-Host "Creating C:\ProgramData\Inspiration 9"
New-Item -Path "C:\ProgramData\Inspiration 9" -ItemType Directory

#Copy over license file
Write-Host "Copying license file"
Copy-Item ".\Inspiration NOS" -Destination "C:\ProgramData\Inspiration 9\Inspiration NOS"

#Start Installation
Write-Host "Starting installation"
Start-Process -FilePath ".\Inspiration 9 Installer.exe" -ArgumentList "-p: settings.ini" -Wait -NoNewWindow