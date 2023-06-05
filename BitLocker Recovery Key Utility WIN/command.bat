$TPMStatusInfo = Get-WmiObject -Class Win32_TPM -EnableAllPrivileges -Namespace "root\CIMV2\Security\MicrosoftTpm"
$TPMActive=$false
$TPMEnabled=$false
$TPMVersion=$null
$CustomUDF=$env:CustomUDF

$bitlockerrecovery = (get-bitlockervolume -mountpoint C).keyprotector | foreach {$_.recoverypassword} | where {$_ -ne ""}

if (!$bitlockerrecovery){
	write-host "C Drive not encrypted."
    
    #Check for TPM Status
    if ($null -eq $TPMStatusInfo){
        write-host "No TPM detected."
        New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name "$CustomUDF" -PropertyType String -Value "No TPM Detected."
    }
    else {
        #Verify TPM is Enabled
        if ((Get-WmiObject -Namespace ROOT\CIMV2\Security\MicrosoftTpm -Class Win32_Tpm).IsEnabled().isenabled -eq $true){
            write-host "TPM is enabled."
            $TPMEnabled=$true
        }
        else {
            write-host "TPM is not enabled."
        }
    
        #Verify TPM is activated
        if ((Get-WmiObject -Namespace ROOT\CIMV2\Security\MicrosoftTpm -Class Win32_Tpm).IsActivated().isactivated -eq $true){
            write-host "TPM is active."
            $TPMActive=$true
        }
        else {
            write-host "TPM is not active."
        }
        #Check TPM Version
        if ($TPMStatusInfo.SpecVersion | select-string -Pattern '1.2') {
            write-host "Found version 1.2 TPM."
            $TPMVersion="1.2"
        }
        if ($TPMStatusInfo.SpecVersion | select-string -Pattern '2.0') {
            write-host "Found version 2.0 TPM."
            $TPMVersion="2.0"
        }
        if (($TPMEnabled -eq $true) -AND ($TPMActive -eq $true) -AND ($null -ne $TPMVersion)){
            write-host "Ready for Bitlocker."
            New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $CustomUDF -PropertyType String -Value "Ready for Bitlocker."
        }
        else {
            #This combination shouldn't be possible...
            if (($TPMActive -eq $true) -AND ($null -eq $TPMVersion)){
                write-host "Unknown TPM version detected."
                New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $CustomUDF -PropertyType String -Value "Unknown TPM version detected."
            }
            else {
                if ($TPMActive -eq $false) {
                    write-host "TPM not active."
                    New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $CustomUDF -PropertyType String -Value "TPM not active."
                }
                else {
                    #If the script actually makes it here, log the status.  This will only happen if the script encounters some weird combination of values.
                    write-host "Anomalous status. Check me."
                    New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $CustomUDF -PropertyType String -Value "Anomalous status. Check me."
                }
            }
        }
    
    }
}

else {
	write-host "Encrypted"
        write-host "Bitlocker key is: $bitlockerrecovery"
	New-ItemProperty -Path HKLM:\SOFTWARE\CentraStage\ -Name $CustomUDF -PropertyType String -Value "$bitlockerrecovery"
}


