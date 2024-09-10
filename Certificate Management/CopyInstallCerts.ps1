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
    [securestring]$service
)

# Functions
function Write-Log {
    param (
        [string]$LogName,
        [string]$Message
    )

    # Check if D:\Logs is available, otherwise use C:\Logs
    if (Test-Path -Path "D:\Logs") {
        $LogFolderPath = "D:\Logs"
    }
    else {
        $LogFolderPath = "C:\Logs"
    }

    # Ensure the log folder exists
    if (-not (Test-Path -Path $LogFolderPath)) {
        New-Item -Path $LogFolderPath -ItemType Directory -Force
    }

    # Combine the folder path and log file name
    $LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $LogFileName

    # Get the current date and time
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Format the log entry
    $logEntry = "$timestamp - $Message"

    # Write the log entry to the file
    Add-Content -Path $LogFilePath -Value $logEntry
}

# Function to copy file to a server
function Copy-FileToServer {
    param (
        [string]$server,
        [string]$source,
        [string]$destination
    )
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
    try {
        Invoke-Command -ComputerName $server -ScriptBlock {
            param($path, [SecureString]$password)
            $cert = Import-PfxCertificate -FilePath $path -CertStoreLocation Cert:\LocalMachine\My -Password $password
            return $cert.FriendlyName
        } -ArgumentList $path, $password
        Write-Log -LogName $service -message "Certificate installed on $server with Friendly Name: $result"
    }
    catch {
        Write-Log -LogName $service -messaget "Failed to install the cert on $server -- $($_.ToString)"
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