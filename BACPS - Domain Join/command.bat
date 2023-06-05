$password = ConvertTo-SecureString "Deploy2020" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ("BACPS\Administrator", $password)
Add-Computer -DomainName BACPS.local -Restart -Credential $cred