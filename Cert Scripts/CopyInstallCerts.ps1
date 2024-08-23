Remotely Copy and install certs into Windows Cert Stores

<#
.SYNOPSIS
    Copy and install certs in server Cert Stores
.NOTES
#>

# Variables
# Define the source file and the list of destination servers. Change the cert name as needed
$sourceFile = "C:\Temp\CERTNAMEHERE"
$destinationPath = "C$\Temp\"
$servers = Get-Content "C:\TEMP\servers.txt"

# Certificate needs to already be on the server in the temp folder and change the cert name as needed
$certPath = "C:\temp\CERTNAMEHERE"
$certPass = Read-Host -Prompt "Enter the certificate password" -AsSecureString

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