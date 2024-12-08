<#
.SYNOPSIS
    Copy and installs SSL Certs into Windows Server Cert Stores
.Description
    Each parameter is required and if the script is ran without any set it will prompt for them.
.NOTES

#>

# Define mandatory parameters for the script
param (
    # Source file path of the certificate
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceFile,
    # Destination path on the remote servers
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath,
    # Path to the file containing server names
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServersFile,
    # Path to the certificate file on the remote server
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CertPath,
    # Secure password for the certificate
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [securestring]$CertPass,
    # Service for the LogName
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$service
)

# Functions
function Write-Log {
    param (
        [string]$LogName,
        [string]$Message
    )

    $LogFolderPath = "D:\Logs"
    if (-not (Test-Path -Path $LogFolderPath)) {
        $LogFolderPath = "C:\Logs"
    }

    if (-not (Test-Path -Path $LogFolderPath)) {
        New-Item -Path $LogFolderPath -ItemType Directory -Force
    }

    $LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $LogFileName

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $logEntry = "$timestamp - $Message"

    try {
        Add-Content -Path $LogFilePath -Value $logEntry
    }
    catch {
        Write-Host "Error writing to log file: $($_.ToString())"
    }
}

# Function to copy file to a server
function Copy-FileToServer {
    param (
        [string]$server,
        [string]$source,
        [string]$destination
    )
    Write-Log -LogName $service -message "Attempting to copy the file to $server"

    try {
        Copy-Item -Path $source -Destination $destination -Force
        Write-Log -LogName $service -message "File copied to $server successfully."
    }
    catch {
        Write-Log -LogName $service -message "Failed to copy file to $server -- $($_.ToString())"
    }
}

# Function to install certificate on a server
function Install-Certificate {
    param (
        [string]$server,
        [string]$path,
        [securestring]$password
    )
    Write-Log -LogName $service -message "Attempting to install the certificate on $server"

    try {
        $cert = Invoke-Command -ComputerName $server -ScriptBlock {
            param($path, [SecureString]$password)
            $cert = Import-PfxCertificate -FilePath $path -CertStoreLocation Cert:\LocalMachine\My -Password $password
            return $cert.FriendlyName
        } -ArgumentList $path, $password
        Write-Log -LogName $service -message "Certificate installed on $server with Friendly Name: $cert"
    }
    catch {
        Write-Log -LogName $service -message "Failed to install the cert on $server -- $($_.ToString())"
    }
}

# Loop through each server and copy the file
Write-Log -LogName $service -message "Reading servers from $ServersFile"
if (Test-Path -Path $ServersFile) {
    $servers = Get-Content -Path $ServersFile
    foreach ($server in $servers) {
        $destination = "\\$server\$destinationPath"
        Copy-FileToServer -server $server -source $sourceFile -destination $destination
    }
}
else {
    Write-Log -LogName $service -message "ServersFile not found at $ServersFile"
}

# Loop through each server and install the certificate
if ($servers) {
    foreach ($server in $servers) {
        Install-Certificate -server $server -path $certPath -password $certPass
    }
}

Write-Host "Script execution completed"

