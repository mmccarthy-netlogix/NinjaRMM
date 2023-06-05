# Define the URLs of the Amazon Trust Services Root CA certificates
$certUrls = @(
    "https://www.amazontrust.com/repository/AmazonRootCA1.pem",
    "https://www.amazontrust.com/repository/SFSRootCAG2.pem"
)

# Define the paths where the certificates will be downloaded and saved
$certPaths = @(
    "C:\Temp\AmazonRootCA1.pem",
    "C:\Temp\SFSRootCAG2.pem"
)

# Download the certificates
for ($i = 0; $i -lt $certUrls.Length; $i++) {
    Invoke-WebRequest $certUrls[$i] -OutFile $certPaths[$i]
}

# Install the certificates in the local machine certificate store
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreName]::Root, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
for ($i = 0; $i -lt $certPaths.Length; $i++) {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPaths[$i])
    $store.Add($cert)
}
$store.Close()

# Clean up the downloaded certificate files
foreach ($path in $certPaths) {
    Remove-Item $path
}
