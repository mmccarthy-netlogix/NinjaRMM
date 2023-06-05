#####################################################################
$APIKEy = $ENV:ITGlueAPIKey
$APIEndpoint = $ENV:ITGlueURL
$orgID = $env:orgID
$TagRelatedDevices = $ENV:TagRelated
$FlexAssetName = "ITGLue AutoDoc - Network overview v2"
$Description = "a network one-page document that shows the current configuration found."
#####################################################################

$Nuget = get-packageprovider -ListAvailable -Name "Nuget"
If (!$nuget) {
    write-host "Package Provider Nuget is not available. Please run the Enable NuGet PowerShell Provider [WIN] Component before running this component."
    exit 1
}

$ConnectedNetworks = Get-NetIPConfiguration -Detailed | Where-Object { $_.Netadapter.status -eq "up" }
write-host "Loading IT-Glue Module. You may ignore any notifcation about adding the API key."
If (Get-Module -ListAvailable -Name "ITGlueAPI") { Import-module ITGlueAPI } Else { install-module ITGlueAPI -Force; import-module ITGlueAPI }
write-host "Loading the PSNMAP module"
If (Get-Module -ListAvailable -Name "PSnmap") { Import-module "PSnmap" } Else { install-module "PSnmap" -Force; import-module "PSnmap" }
write-host "Setting IT-Glue logon information"
Add-ITGlueBaseURI -base_uri $APIEndpoint
Add-ITGlueAPIKey $APIKEy
write-host "Looping through all Connected Networks."
foreach ($Network in $ConnectedNetworks) { 
    $DHCPServer = (Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -eq $network.IPv4Address }).DHCPServer
    $Subnet = "$($network.IPv4DefaultGateway.nexthop)/$($network.IPv4Address.PrefixLength)"
    $NetWorkScan = Invoke-PSnmap -ComputerName $subnet -Port 80, 443, 3389, 21, 22, 25, 587 -Dns -NoSummary 
    $HTMLFrag = $NetworkScan | Where-Object { $_.Ping -eq $true } | convertto-html -Fragment -PreContent "<h1> Network scan of $($subnet) <br/><table class=`"table table-bordered table-hover`" >" | out-string
    write-host "Tagging all related devices."
    $DeviceAsset = @()
    If ($TagRelatedDevices -eq $true) {
        Write-Host "Finding all related resources - Matching on IP at local side, Primary IP on IT-Glue side."
        foreach ($hostfound in $networkscan | Where-Object { $_.Ping -ne $false }) {
            $DeviceAsset += (Get-ITGlueConfigurations -page_size "1000" -organization_id $orgID).data | Where-Object { $_.Attributes."Primary-IP" -eq $($hostfound.ComputerName) }
        }
    }

    $FlexAssetBody = 
    @{
        type       = 'flexible-assets'
        attributes = @{
            name   = $FlexAssetName
            traits = @{
                "subnet-network"      = "$Subnet"
                "subnet-gateway"      = $network.IPv4DefaultGateway.nexthop
                "subnet-dns-servers"  = $network.dnsserver.serveraddresses
                "subnet-dhcp-servers" = $DHCPServer
                "scan-results"        = $HTMLFrag
                "tagged-devices"      = $DeviceAsset.ID
            }
        }
    }


    write-host "Checking if the Flexible asset exists in IT-Glue"
    $FilterID = (Get-ITGlueFlexibleAssetTypes -filter_name $FlexAssetName).data
    if (!$FilterID) { 
        write-host "Flexble Asset Does not exists. Creating."
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
                                name            = "Subnet Network"
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
                                name           = "Subnet Gateway"
                                kind           = "Text"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 3
                                name           = "Subnet DNS Servers"
                                kind           = "Text"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 4
                                name           = "Subnet DHCP Servers"
                                kind           = "Text"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 5
                                name           = "Tagged Devices"
                                kind           = "Tag"
                                "tag-type"     = "Configurations"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 6
                                name           = "Scan Results"
                                kind           = "Textbox"
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
    write-host "Checking if existing flexible asset is present in IT-Glue for this client."
    $ExistingFlexAsset = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $Filterid.id -filter_organization_id $orgID).data | Where-Object { $_.attributes.name -eq $Subnet }
    #If the Asset does not exist, we edit the body to be in the form of a new asset, if not, we just upload.
    write-host "Uploading to IT-Glue."
    if (!$ExistingFlexAsset) {
        $FlexAssetBody.attributes.add('organization-id', $orgID)
        $FlexAssetBody.attributes.add('flexible-asset-type-id', $FilterID.id)
        Write-Host "Creating new flexible asset"
        New-ITGlueFlexibleAssets -data $FlexAssetBody
    }
    else {
        Write-Host "Updating Flexible Asset"
        $ExistingFlexAsset = $ExistingFlexAsset | Select-Object -last 1
        Set-ITGlueFlexibleAssets -id $ExistingFlexAsset.id  -data $FlexAssetBody
    }
}

write-host "Process has been completed. Please check IT-Glue -> Global -> $($FlexAssetName)"