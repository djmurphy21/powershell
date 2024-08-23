<#
.SYNOPSIS
    Copy and install certs in server Cert Stores
.NOTES
    
#>

# Define mandatory parameters for the script
param (
    [Parameter(Mandatory = $true)]
    [string]$SourceFile, # Source file path of the certificate

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath, # Destination path on the remote servers

    [Parameter(Mandatory = $true)]
    [string]$ServersFile, # Path to the file containing server names

    [Parameter(Mandatory = $true)]
    [string]$CertPath, # Path to the certificate file on the remote server

    [Parameter(Mandatory = $true)]
    [securestring]$CertPass          # Secure password for the certificate
)


# Function to copy file to a server
function Copy-FileToServer {
    param (
        [string]$server,
        [string]$source,
        [string]$destination
    )
    try {
        Copy-Item -Path $source -Destination $destination -Force
        Write-Host "File copied to $server successfully."
    }
    catch {
        Write-Host "Failed to copy file to $server -- $($_.ToString())"
    }
}

# Function to install certificate on a server
function Install-Certificate {
    param (
        [string]$server,
        [string]$path,
        [securestring]$password
    )
    try {
        Invoke-Command -ComputerName $server -ScriptBlock {
            param($path, [SecureString]$password)
            $cert = Import-PfxCertificate -FilePath $path -CertStoreLocation Cert:\LocalMachine\My -Password $password
            return $cert.FriendlyName
        } -ArgumentList $path, $password
        Write-Host "Certificate installed on $server with Friendly Name: $result"
    }
    catch {
        Write-Host "Failed to install the cert on $server -- $($_.ToString)"
    }
}

# Loop through each server and copy the file
foreach ($server in $servers) {
    $destination = "\\$server\$destinationPath"
    Copy-FileToServer -server $server -source $sourceFile -destination $destination
}

# Loop through each server and install the certificate
foreach ($server in $servers) {
    Install-Certificate -server $server -path $certPath -password $certPass
}

Write-Host "Script execution completed"