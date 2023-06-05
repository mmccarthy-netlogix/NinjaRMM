#!/bin/bash
#
# After downloading this installer, be sure and modify the execute attribute:
#
#     chmod +x cloudradial-agent-installer.sh
#
# Then, run the command with elevated access:
#
#     sudo ./cloudradial-agent-installer.sh
#
# This script installs a daemon that runs in the background and checks in on startup and every 24 hours.
#
# You can check the status of the daemon:
#
#     sudo launchctl list cloudradial.mac.agent
#
# Status and diagnostic information is kept in the log file:
#
#     /Library/Logs/cloudradial.mac.agent.log
#
# An uninstall script is provided. To uninstall:
#
#     sudo /Library/LaunchDaemons/cloudradial.mac.agent/uninstall.sh
#
# After installation, the daemon is started. Please allow up to an hour to see the endpoint in the company's infrastructure.
#
# Please note, the security key is set in the CloudRadial portal and if it not set, should be left blank.
#
#

if [ -z "$ServiceEndpoint" ]; then
    echo "Please enter a valid service endpoint URL."
    exit 1
fi
if [ -z "$PartnerURL" ]; then
    echo "Please enter a valid partner URL."
    exit 1
fi
if [ -z "$CRCompanyIDSite" ]; then
    echo "Please enter a valid company ID using the CRCompanyIDSite site variable"
    exit 1
fi

echo "CloudRadial Mac Agent Installer"
echo ""
echo "Service Endpoint: $ServiceEndpoint"
echo "Partner Url:      $PartnerURL"
echo "Company Id:       $CRCompanyIDSite"
echo "Security Key:     "
echo ""

# Stop daemon if already running
launchctl unload /Library/LaunchDaemons/com.cloudradial.mac.agent.plist
plutil -remove KeepAlive /Library/LaunchDaemons/com.cloudradial.mac.agent.plist

# Download current package
if [[ $(uname -p) == 'arm' ]]; then
    echo "Installing for Apple M1"
    curl https://cloudradialagent.blob.core.windows.net/macagent/cloudradial.mac.agent-arm64.pkg --output cloudradial.mac.agent-arm64.pkg
    installer -pkg cloudradial.mac.agent-arm64.pkg -target /
else
    echo "Installing for Intel"
    curl https://cloudradialagent.blob.core.windows.net/macagent/cloudradial.mac.agent-x64.pkg --output cloudradial.mac.agent-x64.pkg
    installer -pkg cloudradial.mac.agent-x64.pkg -target /
fi

# Update plist with correct settings for partner and company
plutil -remove ProgramArguments /Library/LaunchDaemons/com.cloudradial.mac.agent.plist > /dev/null
plutil -insert ProgramArguments -xml "<array><string>/Library/LaunchDaemons/CloudRadial.Mac.Agent/CloudRadial.Mac.Agent</string><string>$ServiceEndpoint</string><string>$PartnerURL</string><string>$CRCompanyIDSite</string><string></string></array>" /Library/LaunchDaemons/com.cloudradial.mac.agent.plist

# Set to always run
plutil -remove KeepAlive /Library/LaunchDaemons/com.cloudradial.mac.agent.plist
plutil -insert KeepAlive -bool true /Library/LaunchDaemons/com.cloudradial.mac.agent.plist

# Load the daemon
launchctl load /Library/LaunchDaemons/com.cloudradial.mac.agent.plist

# Display daemon status
launchctl list cloudradial.mac.agent
