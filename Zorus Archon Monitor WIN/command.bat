# -----------------------------------------------------------------------------------------------
# Component: Zorus Archon Monitor
# Author: Mike Lamoureux
# Purpose: Installation Monitor for Zorus Archon Agents
# Based on the Sophos Central Monitor
# Version 1.0
# -----------------------------------------------------------------------------------------------

#


#Define Functions

function ZorusInstalled {

$Global:installed = (gp HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -contains "Archon Agent"
$Global:archonagent = Get-Service -name "ZorusDeploymentService" -ea SilentlyContinue
}

function ZorusAlert
{
param([string]$alert)
Write-Host "<-Start Result->"
Write-Host "Zorus Archon Agent Status="$alert
Write-Host "<-End Result->"
exit 1
}

function ZorusStatus
{
param([string]$status)
Write-Host "<-Start Result->"
Write-Host "Zorus Archon Agent Status="$status
Write-Host "<-End Result->"
exit 0
}

Function AgentMonitors
{
ZorusInstalled
if ((!$installed -eq "True") -and (!$archonagent.Status -eq "Running")) {
	ZorusAlert "Not Installed"
	}
}

try
{
    AgentMonitors
}
catch
{
    ZorusAlert $_.Exception.Message
}
finally
{
if ($installed -eq "True") {
	ZorusStatus "Installed"
	}
}