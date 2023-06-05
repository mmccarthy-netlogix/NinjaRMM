#MS office 365 deployment utility :: configuration tool ::  build 8/seagull
#user variables: $env:usrChannel $env:usrEdition $env:usrLangID $env:usrExclusion $env:usrCompanyName

<#
    this script is copyrighted property and cannot be shared or redistributed, even with alterations.
    this includes on the web or within other products.
#>

#furnish some information
$varPath=split-path -parent $MyInvocation.MyCommand.Definition
if (($env:usrCompanyName -as [string]).Length -le 1) {$env:usrCompanyName=$env:CS_PROFILE_NAME}
[int]$varKernel = ([System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Windows\system32\kernel32.dll")).FileBuildPart
if (!(test-path "C:\Windows\Temp\OfficeInstall" -ErrorAction SilentlyContinue)) {
    mkdir "C:\Windows\Temp\OfficeInstall" | Out-null
}

if (!$env:usrBitness) {
    if ([intptr]::Size -eq '4') {$env:usrBitness='32'} else {$env:usrBitness='64'}
}

write-host "Create a parameter XML for Office 365 Deployment"
write-host "========================================================="
write-host "- Chosen deployment parameters:"
write-host ": Edition:     $env:usrEdition ($env:usrBitness-bit)"
write-host ": Channel:     $env:usrChannel"
write-host ": Lang ID/s:   $env:usrLangID"
write-host ": Exclusion/s: $env:usrExclusion"
write-host ": Company:     $env:usrCompanyName"

write-host "========================================================="

if (test-path "C:\Windows\Temp\OfficeInstall\DRMMConfig.xml") {
    Remove-Item "C:\Windows\Temp\OfficeInstall\DRMMConfig.xml" -Force
    write-host "- Existing DRMMConfig.xml file has been deleted."
}

#convert language and exclusion IDs into arrays
$arrLangID=$env:usrLangID.split(',') -as [array]
$arrExclID=$env:usrExclusion.split(',') -as [array]

[xml]$varConfig = New-Object System.Xml.XmlDocument
$varConfigRoot = $varConfig.CreateNode("element","Configuration",$null)

#configuration:/info
$xConfigInfo = $varConfig.CreateNode("element","Info",$null)
$xConfigInfo.SetAttribute("Description","Datto RMM auto-generated Office 365 deployment XML")
$varConfigRoot.AppendChild($xConfigInfo) | out-null

#configuration:/add
$xConfigAdd = $varConfig.CreateNode("element","Add",$null)
$xConfigAdd.SetAttribute("OfficeClientEdition","$env:usrBitness")
$xConfigAdd.SetAttribute("Channel","$env:usrChannel")
$xConfigAdd.SetAttribute("MigrateArch","TRUE")
$varConfigRoot.AppendChild($xConfigAdd) | out-null

#configuration:/add/product
$xConfigAddProduct = $varConfig.CreateNode("element","Product",$null)
$xConfigAddProduct.SetAttribute("ID","$env:usrEdition")
$xConfigAdd.AppendChild($xConfigAddProduct) | out-null

#configuration:/add/product/language
foreach ($iteration in $arrLangID) {
    $xConfigAddProductLang = $varConfig.CreateNode("element","Language",$null)
    $xConfigAddProductLang.SetAttribute("ID","$iteration")
    $xConfigAddProduct.AppendChild($xConfigAddProductLang) | out-null
}
$xConfigAddProductLang = $varConfig.CreateNode("element","Language",$null)
$xConfigAddProductLang.SetAttribute("ID","MatchOS")
$xConfigAddProduct.AppendChild($xConfigAddProductLang) | out-null

#configuration:/add/product/excludeApp
foreach ($iteration in $arrExclID) {
    $xConfigAddProductExc = $varConfig.CreateNode("element","ExcludeApp",$null)
    $xConfigAddProductExc.SetAttribute("ID","$iteration")
    $xConfigAddProduct.AppendChild($xConfigAddProductExc) | out-null
}

#configuration:/property :: various
function writeProperty ($name, $value) {
    $xConfigProperty = $varConfig.CreateNode("element","Property",$null)
    $xConfigProperty.SetAttribute("Name","$name")
    $xConfigProperty.SetAttribute("Value","$value")
    $varConfigRoot.AppendChild($xConfigProperty) | out-null
}

writeProperty SharedComputerLicensing 0
writeProperty PinIconsToTaskbar FALSE
writeProperty SCLCacheOverride 0
writeProperty AUTOACTIVATE 0
writeProperty FORCEAPPSHUTDOWN FALSE
writeProperty DeviceBasedLicensing 0

#two others
$xConfigProperty = $varConfig.CreateNode("element","Updates",$null)
$xConfigProperty.SetAttribute("Enabled","TRUE")
$varConfigRoot.AppendChild($xConfigProperty) | out-null
$xConfigProperty = $varConfig.CreateNode("element","RemoveMSI",$null)
$varConfigRoot.AppendChild($xConfigProperty) | out-null

#configuration:/AppSettings/Setup
$xConfigAppSet = $varConfig.CreateNode("element","AppSettings",$null)
$varConfigRoot.AppendChild($xConfigAppSet) | out-null
$xConfigAppSetSet = $varConfig.CreateNode("element","Setup",$null)
$xConfigAppSetSet.SetAttribute("Name","Company")
$xConfigAppSetSet.SetAttribute("Value","$env:usrCompanyName")
$xConfigAppSet.AppendChild($xConfigAppSetSet) | out-null

#configuration:/display & logging
$xConfigDisplay = $varConfig.CreateNode("element","Display",$null)
$xConfigDisplay.SetAttribute("Level","None")
$xConfigDisplay.SetAttribute("AcceptEULA","TRUE")
$varConfigRoot.AppendChild($xConfigDisplay) | out-null
$xConfigLogging = $varConfig.CreateNode("element","Logging",$null)
$xConfigLogging.SetAttribute("Level","Standard")
$xConfigLogging.SetAttribute("Path","C:\Windows\Temp\OfficeInstall")
$varConfigRoot.AppendChild($xConfigLogging) | out-null

#closeout
$varConfig.AppendChild($varConfigRoot) | out-null
$varConfig.Save("C:\Windows\Temp\OfficeInstall\DRMMConfig.xml")

write-host "- Deployment XML saved as DRMMConfig.xml in C:\Windows\Temp\OfficeInstall."
write-host "  Subsequent Office 365-via-Component deployments will use these settings."