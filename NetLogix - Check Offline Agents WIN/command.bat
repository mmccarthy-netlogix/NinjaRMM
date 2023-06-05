Import-Module DattoRMM

$Key=$ENV:DRMMKey
$SecretKey=$ENV:DRMMSecretKey
$AccessKey=$ENV:CWCAccessKey

## Debug output of variables
#Write-Host $ENV:DRMMKey
#Write-Host $ENV:DRMMSecretKey
#Write-Host $ENV:CWCAccessKey

Set-DrmmApiParameters -Url https://concord-api.centrastage.net -Key $Key -SecretKey $SecretKey

function CheckOfflineAgents {
  $OfflineAgents=@()
  $Agents=@()
  $sc_url="https://support.netlogix.com:8040/App_Extensions/8e78224d-79db-4dbb-b62a-833276b46c6e/Service.ashx/IsOnline"

  ForEach ($site in Get-DrmmAccountSites -noDeletedDevices)
  {
      Foreach ($device in Get-DrmmSiteDevices $site.uid)
      {
        $AgentObj = New-Object -TypeName PSObject
        $AgentObj | Add-Member -MemberType NoteProperty -Name SiteName -Value $device.siteName
        $AgentObj | Add-Member -MemberType NoteProperty -Name SiteUID -Value $device.siteUid
        $AgentObj | Add-Member -MemberType NoteProperty -Name HostName -Value $device.hostname
        $AgentObj | Add-Member -MemberType NoteProperty -Name HostUID -Value $device.uid

        if (!$device.Online) {
          $CWCConnectTime=-1
          $sc_guid=$device.udf.udf5 -replace '^.*([a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}).*$', '$1'
          if ($sc_guid -ne "") {
            try {
              $CWCConnectTime=Invoke-RestMethod -Method Post -Uri $sc_url -Body "[""$AccessKey"", ""$sc_guid""]" -ContentType 'application/json' -Headers @{Origin='support.netlogix.com'}
            } catch {
              $RestError=$_
            }

            $AgentObj | Add-Member -MemberType NoteProperty -Name sc_guid -Value $sc_guid
            $AgentObj | Add-Member -MemberType NoteProperty -Name CWCConnectTime -Value $CWCConnectTime
            $AgentObj | Add-Member -MemberType NoteProperty -Name CWCOutput -Value $CWCOutput
          }

          if ($CWCConnectTime -ge 600) {
            $OfflineAgents+=$AgentObj
          }
        }
        $Agents+=$AgentObj
      }
  }
  return $OfflineAgents,$Agents
}

function StartOfflineAgents ($CheckAgents) {
  $sc_url="https://support.netlogix.com:8040/App_Extensions/8e78224d-79db-4dbb-b62a-833276b46c6e/Service.ashx/ExecuteCommand"

  foreach ($agent in $CheckAgents) {
    Write-Host $agent.HostName"Offline in Datto, Online in Control"
    $agent.CWCOutput=Invoke-RestMethod -Method Post -Uri $sc_url -Body "[""$AccessKey"", ""$($agent.sc_guid)"", ""sc start cagservice"", ""300""]" -ContentType 'application/json' -Headers @{Origin='support.netlogix.com'} -TimeoutSec 300
    $agent.CWCOutput
  }
  return $CheckAgents
}

function ReStartOfflineAgents ($CheckAgents) {
  $sc_url="https://support.netlogix.com:8040/App_Extensions/8e78224d-79db-4dbb-b62a-833276b46c6e/Service.ashx/ExecuteCommand"

  foreach ($agent in $CheckAgents) {
    Write-Host $agent.HostName"Offline in Datto, Online in Control"
    $agent.CWCOutput=Invoke-RestMethod -Method Post -Uri $sc_url -Body "[""$AccessKey"", ""$($agent.sc_guid)"", ""net stop cagservice && net start cagservice"", ""300""]" -ContentType 'application/json' -Headers @{Origin='support.netlogix.com'} -TimeoutSec 300
    $agent.CWCOutput
  }
  return $CheckAgents
}

Write-Host "Offline Agents:"
$Offline,$AllAgents=CheckOfflineAgents
Write-Host ($Offline | Out-String)

if ($ENV:Action -eq "Start") {
  Write-Host "Starting Offline Agents:"
  StartOfflineAgents($Offline)
#  Write-Host ($Offline | Out-String)
}

if ($ENV:Action -eq "Restart") {
  Write-Host "Restarting Offline Agents:"
  ReStartOfflineAgents($Offline)
#  Write-Host ($Offline | Out-String)
}