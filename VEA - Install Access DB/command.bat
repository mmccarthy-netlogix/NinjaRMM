$DBName = "ValleyEducation V2.9"

Write-Host "Component Started at: " (Get-Date)
Write-Host "--"

Write-Host "Installing ODBC Driver"
$args = "/i","msodbcsql.msi","IACCEPTMSODBCSQLLICENSETERMS=YES","/qn","/norestart"
Start-Process -FilePath $ENV:WINDIR\System32\msiexec.exe -Wait -NoNewWindow -PassThru -ArgumentList $args
$sw = Get-WmiObject -Class Win32_Product -Filter "name like `"Microsoft ODBC Driver 18 for SQL Server`""
if ($sw -eq $null) {
  Write-Host "Installation of ODBC Driver Failed"
  Exit 1
}

Write-Host "Importing ODBC Connection"
#$args = "IMPORT .\VEAAzureAccessApp.reg"
#Start-Process -FilePath $ENV:WINDIR\System32\reg.exe -Wait -NoNewWindow -PassThru -ArgumentList $args
Add-OdbcDsn -Name "VEAAzureAccessApp" -DriverName "ODBC Driver 18 for SQL Server" -Platform "64-bit" -DsnType "System" -SetPropertyValue @("Server=vea-prod-sql-1.database.windows.net","Database=VEA_Prod","TrustServerCertificate=No","Authentication=ActiveDirectoryPassword")
Set-ItemProperty -Path HKLM:SOFTWARE\ODBC\ODBC.INI\VEAAzureAccessApp\ -Name LastUser -Value "vea-app@valleyeducational.org" -Type String
$CheckDSN = Get-ItemProperty -Path HKLM:SOFTWARE\ODBC\ODBC.INI\VEAAzureAccessApp
if ($CheckDSN -eq $NULL) {
  Write-Host "Failed to create ODBC System DSN"
  Exit 1
}

if (Test-Path -Path C:\ValleyEducation*.accdb) {
  Write-Host "Removing previous DB"
  Remove-Item C:\ValleyEducation*.accdb -Force
}

Write-Host "Moving Access Database to C:\"
Move-Item ".\$DBName.accdb" C:\

if (!(Test-Path "C:\$DBName.accdb")) {
  Write-Host "Unable to move database to C:\"
  Exit 1
}

if (Test-Path -Path C:\Users\Public\Desktop\ValleyEducation*.lnk) {
  Write-Host "Removing previous Links"
  Remove-Item C:\Users\Public\Desktop\ValleyEducation*.lnk -Force
}

Write-Host "Creating Shortcut on Public Desktop"
$obj = New-Object -ComObject WScript.Shell 
$link = $obj.CreateShortcut("C:\Users\Public\Desktop\$DBName.lnk")
$link.TargetPath = "C:\$DBName.accdb" 
$link.WorkingDirectory = "C:\"
$link.Save()
Write-Host "--"
Write-Host "Component Finished at: " (Get-Date)
if (!(Test-Path "C:\Users\Public\Desktop\$DBName.lnk")) {
  Write-Host "Link Creation failed"
  Exit 1
}
