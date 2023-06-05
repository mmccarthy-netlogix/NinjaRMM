#####################################################################
$APIKEy = $ENV:ITGlueAPIKey
$APIEndpoint = $ENV:ITGlueURL
$orgID = $ENV:OrgID
$FlexAssetName = "ITGLue AutoDoc - Printers"
$Description = "All configuration settings for printers and a backup of their respective drivers"
$InstallPrintManagement = $true
$BackupDriver = $true
#####################################################################
If (Get-Module -ListAvailable -Name "ITGlueAPI") { Import-module ITGlueAPI } Else { install-module ITGlueAPI -Force; import-module ITGlueAPI }
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
#Checking if the FlexibleAsset exists. If not, create a new one.
$FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
if (!$FilterID) { 
    $NewFlexAssetData = 
    @{
        type          = 'flexible-asset-types'
        attributes    = @{
            name        = $FlexAssetName
            icon        = 'sitemap'
            description = $description
        }
        relationships = @{
            "flexible-asset-fields" = @{
                data = @(
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order           = 1
                            name            = "Printer Name"
                            kind            = "Text"
                            required        = $true
                            "show-in-list"  = $true
                            "use-for-title" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 2
                            name           = "Printer Config"
                            kind           = "Text"
                            required       = $false
                            "show-in-list" = $true
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 3
                            name           = "Port Config"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 4
                            name           = "Printer Properties"
                            kind           = "Textbox"
                            required       = $false
                            "show-in-list" = $false
                        }
                    },
                    @{
                        type       = "flexible_asset_fields"
                        attributes = @{
                            order          = 5
                            name           = "Driver backup"
                            kind           = "Upload"
                            required       = $false
                            "show-in-list" = $false
                        }
                    }
                )
            }
        }
                 
    }
    New-ITGlueFlexibleAssetTypes -Data $NewFlexAssetData
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
} 
 
$PrintManagementInstalled = get-windowsfeature -name 'RSAT-Print-Services' -ErrorAction SilentlyContinue
if ($InstallPrintManagement -and !$PrintManagementInstalled) {
    Add-WindowsFeature -Name 'RSAT-Print-Services'
}
import-module PrintManagement
$PrinterList = Get-Printer
 
$PrinterConfigurations = foreach ($Printer in $PrinterList) {
    $PrinterConfig = Get-PrintConfiguration -PrinterName $printer.Name
    $PortConfig = get-printerport -Name $printer.PortName
    $PrinterProperties = Get-PrinterProperty -PrinterName $printer.Name
    if ($BackupDriver) {
        $Driver = Get-PrinterDriver -Name $printer.DriverName | ForEach-Object { $_.InfPath; $_.ConfigFile; $_.DataFile; $_.DependentFiles } | Where-Object { $_ -ne $null }
        $BackupPath = new-item -path "$($ENV:TEMP)\$($printer.name)" -ItemType directory -Force
        $Driver | foreach-object { copy-item -path $_ -Destination "$($ENV:TEMP)\$($printer.name)" -Force }
        Add-Type -assembly "system.io.compression.filesystem"
        [io.compression.zipfile]::CreateFromDirectory("$($ENV:TEMP)\$($printer.name)", "$($ENV:TEMP)\$($printer.name).zip")
        $ZippedDriver = ([convert]::ToBase64String(([IO.File]::ReadAllBytes("$($ENV:TEMP)\$($printer.name).zip"))))
        remove-item "$($ENV:TEMP)\$($printer.name)" -force -Recurse
        remove-item "$($ENV:TEMP)\$($printer.name).zip" -force -Recurse
    }
    [PSCustomObject]@{
        PrinterName       = $printer.name
        PrinterConfig     = $PrinterConfig | select-object DuplexingMode, PapierSize, Collate, Color | convertto-html -Fragment | Out-String
        PortConfig        = $PortConfig  | Select-Object Description, Name, PortNumber, PrinterHostAddress, snmpcommunity, snmpenabled | convertto-html -Fragment | out-string
        PrinterProperties = $PrinterProperties | Select-Object PropertyName, Value | convertto-html -Fragment | out-string
        ZippedDriver      = $ZippedDriver
    }
}
 
foreach ($printerconf in $PrinterConfigurations) {
    $FlexAssetBody = 
    @{
        type       = 'flexible-assets'
        attributes = @{
            name   = $FlexAssetName
            traits = @{
                "printer-name"       = $printerconf.Printername
                "printer-config"     = $printerconf.printerconfig
                "port-config"        = $printerconf.portconfig
                "printer-properties" = $printerconfig.properties
                "driver-backup"      = @{
                    "content"   = $printerconf.ZippedDriver
                    "file_name" = "Driver Backup.zip"
                }
            }
        }
    }
     
 
    #Upload data to IT-Glue. We try to match the Server name to current computer name.
    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object { $_.attributes.traits.name -eq $printerconf.PrinterName }
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    if (!$ExistingFlexAsset) {
        $FlexAssetBody.attributes.add('organization-id', $orgID)
        $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
        Write-Host "Creating new flexible asset"
        $NewID = New-ITGlueFlexibleAssets -data $FlexAssetBody
        Set-ITGlueFlexibleAssets -id $newID.ID -data $Attachment
    }
    else {
        Write-Host "Updating Flexible Asset"
        $ExistingFlexAsset = $ExistingFlexAsset | select-object -last 1
        Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
    }
}