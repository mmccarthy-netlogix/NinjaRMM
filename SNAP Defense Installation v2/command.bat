#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
#.______    __          ___       ______  __  ___ .______     ______    __  .__   __. .___________.##  
#|   _  \  |  |        /   \     /      ||  |/  / |   _  \   /  __  \  |  | |  \ |  | |           |## 
#|  |_)  | |  |       /  ^  \   |  ,----'|  '  /  |  |_)  | |  |  |  | |  | |   \|  | `---|  |----`##  
#|   _  <  |  |      /  /_\  \  |  |     |    <   |   ___/  |  |  |  | |  | |  . `  |     |  |####### 
#|  |_)  | |  `----./  _____  \ |  `----.|  .  \  |  |      |  `--'  | |  | |  |\   |     |  |#######         
#|______/  |_______/__/     \__\ \______||__|\__\ | _|       \______/  |__| |__| \__|     |__|#######         
#####################################################################################################                                                                                                
####################################╔═╗╔╗╔╔═╗╔═╗///╔╦╗╔═╗╔═╗╔═╗╔╗╔╔═╗╔═╗#############################
####################################╚═╗║║║╠═╣╠═╝/// ║║║╣ ╠╣ ║╣ ║║║╚═╗║╣ #######Ver 2.0 09/05/2019####
####################################╚═╝╝╚╝╩ ╩╩/////═╩╝╚═╝╚  ╚═╝╝╚╝╚═╝╚═╝#############################

#Installer Name
$InstallerName = "snap_installer.exe"
#InstallsLocation
$InstallerPath =  Join-Path $env:TEMP $InstallerName
#Service Name
$SnapServiceName = "Snap"
#$Windows10 = "Microsoft Windows 10"
$SITES_Enabled = "$env:SNAP_AllowSites"

If ($SITES_Enabled -eq 1) {
#Account UID found in URL 
$AccountUID = "$env:SNAP_UID"
#Snap Installer name
$CompanyEXE = "$env:SNAP_FILE" 
#Snap URL
$DownloadURL = "https://portal.blackpointcyber.com/installer/$AccountUID/$CompanyEXE"
#Added for customers who do note use sites. 
}
If ($SITES_Enabled -eq 0){
    $DownloadURL = "$env:SNAP_DOWNLOAD"
}


#Enable Debug with 1
$DebugMode = 1 

#Failure message
$Failure = "Snap was not installed Successfully. Contact support@blackpointcyber.com if you need more help."

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}


#Checking if the Service is Running
function Snap-Check($service)
{
    if (Get-Service $service -ErrorAction SilentlyContinue)
    {
        return $true
    }
    return $false
}

#Debug 
function Debug-Print ($message)
{
    if ($DebugMode -eq 1)
    {
        Write-Host "$(Get-TimeStamp) [DEBUG] $message"
    }
}

#Checking .NET Ver 4.6.1
function Net-Check {
    #Left in to help with troubleshooting
    #$$cimreturn = (Get-CimInstance Win32_Operatingsystem | Select-Object -expand Caption -ErrorAction SilentlyContinue) 
    #$windowsfull =  $cimreturn
    #$WindowsSmall = $windowsfull.Split(" ")
    #[string]$WindowsSmall[0..($WindowsSmall.Count-2)]
    #If ($WindowsSmall -eq $Windows10) {  
    
    Debug-Print("Checking for .NET 4.6.1+...") 
    #Calls Net Ver 
        If (! (Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -gt 394254){
                   

        $NetError = "SNAP needs 4.6.1+ of .NET...EXITING" 
        Write-Host "$(Get-TimeStamp) $NetError"
        exit 0
        }
        
        {
        Debug-Print ("4.6.1+ Installed...")
        }
           
}

      

#Downloads file
function Download-Installer {
    Debug-Print("Downloading from provided $DownloadURL...")
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Client = New-Object System.Net.Webclient
    try
    {
        $Client.DownloadFile($DownloadURL, $InstallerPath)
    }
    catch
    {
    $ErrorMsg = $_.Exception.Message
    Write-Host "$(Get-TimeStamp) $ErrorMsg"
    }
    If ( ! (Test-Path $InstallerPath) ) {
        $DownloadError = "Failed to download the SNAP Installation file from $DownloadURL"
        Write-Host "$(Get-TimeStamp) $DownloadError" 
        throw $Failure
    }
    Debug-Print ("Installer Downloaded to $InstallerPath...")


}

#Installation 
function Install-Snap {
    Debug-Print ("Verifying AV did not steal exe...")
    If (! (Test-Path $InstallerPath)) {
    {
        $AVError = "Something, or someone, deleted the file."
        Write-Host "$(Get-TimeStamp) $AVError"
        throw $Failure
    }
    }
    Debug-Print ("Unpackaginging and Installing agent...")
    Start-Process -NoNewWindow -FilePath $InstallerPath -ArgumentList "-y"    
    
}


function runMe {
    Debug-Print("Starting...")
    Debug-Print("Checking if SNAP is already installed...")
    If ( Snap-Check($SnapServiceName) )
    {
        $ServiceError = "SNAP is Already Installed...Bye." 
        Write-Host "$(Get-TimeStamp) $ServiceError"
        exit 0
    }
    Net-Check
    Download-Installer
    Install-Snap
  # Error-Test
    Write-Host "$(Get-TimeStamp) Snap Installed..."
}

try
{
    runMe
}
catch
{
    $ErrorMsg = $_.Exception.Message
    Write-Host "$(Get-TimeStamp) $ErrorMsg"
    exit 1
}
