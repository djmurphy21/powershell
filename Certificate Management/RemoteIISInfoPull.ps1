<#
.SYNOPSIS
    Retrieves SSL certificate information from multiple remote IIS servers and exports the data to a CSV file.

.DESCRIPTION
    This script connects to a list of remote servers provided in a file, retrieves SSL binding and certificate 
    information from IIS on those servers, and exports the gathered data to a specified CSV file. The script 
    uses the WebAdministration module to interact with IIS and logs important events and errors throughout 
    the process.

    The script takes two mandatory parameters:
    - `outputPath`: Path where the CSV containing SSL certificate details will be saved.
    - `ServersFile`: Path to the file that contains the names of the remote servers to connect to.

    Logs are written to either `D:\Logs` or `C:\Logs` depending on availability. The log includes messages about 
    successful operations and errors encountered during script execution.

.NOTES
    - Requires the `WebAdministration` PowerShell module to interact with IIS on the remote servers.
    - Credentials for accessing the remote servers are prompted during script execution.
    - Error handling is implemented to continue retrieving data from the remaining servers in case of failures.
    - Tested on environments with PowerShell 5.1 and IIS.
#>

# Define mandatory parameters for the script
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$outputPath, # Destination path on the remote servers

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServersFile # Path to the file containing server names
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

# Function to pull all IIS sites that having bindings and an SSL cert
function Get-RemoteIISCertInfo {
    param (
        [string]$RemoteServerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    $script = {
        Import-Module -Name WebAdministration

        Get-ChildItem -Path IIS:SSLBindings | ForEach-Object -Process {
            if ($_.Sites) {
                $thumbprint = $_.Thumbprint
                $certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object -Property Thumbprint -EQ -Value $thumbprint
                
                [PSCustomObject]@{
                    Sites                   = $_.Sites.Value
                    CertificateFriendlyName = $certificate.FriendlyName
                    CertificateThumbprint   = $certificate.Thumbprint
                    CertificateDNSNameList  = $certificate.DnsNameList
                    CertificateNotAfter     = $certificate.NotAfter
                    CertificateIssuer       = $certificate.Issuer
                }
            }
        }
    }

    Invoke-Command -ComputerName $RemoteServerName -ScriptBlock $script -Credential $Credential
}

# Variables
$servers = Get-Content -Path $ServersFile
$cred = Get-Credential

# Array
$allCerts = @()

# Pull the data
try {
    foreach ($server in $servers) {
        $certs = Get-RemoteIISCertInfo -RemoteServerName $server -Credential $cred
        $allCerts += $certs
    }
}
catch {
    Write-Log -LogName $service -Message "Failed to pull IIS information from $Server -- $($_.ToString)"
    Continue
}

# Export all the data to a CSV
$allCerts | Export-Csv -Path $outputPath -NoTypeInformation

Write-Log -LogName $service -Message "Script execution completed"