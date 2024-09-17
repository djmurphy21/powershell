<#
.SYNOPSIS
This script retrieves IP configuration details from a list of remote servers and exports the information to an HTML file.
.DESCRIPTION
The script reads a list of server names from a specified text file and uses PowerShell to remotely connect to each server. 
It retrieves the IP configuration details, including the IPv4 address, subnet mask, default gateway, and DNS servers. 
The collected information is then formatted into an HTML table and saved to a specified file path.

Key features:
- Reads server names from a text file.
- Uses CIM sessions for remote connections.
- Retrieves and formats IP configuration details.
- Exports the data to an HTML file with a custom table style.
.NOTES
Dependencies:
- PowerShell 5.1 or later
- CIM sessions enabled on remote servers

Usage:
- Ensure the servers file and log file path are correctly specified.
- Run the script with appropriate permissions to access remote servers.

Example:
.\Get-ServerIPInfoRemotely.ps1 -serversfile "C:\path\to\servers.txt" -logFilePath "C:\path\to\log"
#>

# Parameters
param (
    # Path and file containing server information
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $serversfile,
    # Full path to place the HTML file that contains the IP information for the servers in the servers txt file
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $logFilePath
)

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

# Function to pull IP information from the remote server
function Get-IPInfo {
    param (
        [string]$ServerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        # Create a CIM session
        $session = New-CimSession -ComputerName $ServerName -Credential $Credential
        Write-Log -logName "Get Server IP Information" -message "Created CIM session for $ServerName"

        # Get network information
        $netInfo = Get-CimInstance -CimSession $session -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } | ForEach-Object {
            [PSCustomObject]@{
                ServerName         = $ServerName
                IPv4Address        = if ($_.IPAddress) { $_.IPAddress[0] } else { "N/A" }
                IPv4SubnetMask     = if ($_.IPSubnet) { $_.IPSubnet[0] } else { "N/A" }
                IPv4DefaultGateway = if ($_.DefaultIPGateway) { $_.DefaultIPGateway[0] } else { "N/A" }
                DNSServers         = if ($_.DNSServerSearchOrder) { ($_.DNSServerSearchOrder -join ", ") } else { "N/A" }
                
            }
        }

        # Remove the CIM session
        Remove-CimSession -CimSession $session
        Write-Log -logName "Get Server IP Information" -message "Removed CIM session for $ServerName"

        return $netInfo
    }
    catch {
        Write-Log -logName "Get Server IP Information" -message "Failed to retrieve network information from $ServerName -- $($_.Exception.Message)"
        return $null
    }
}

# Variables
$service = "Get Server IP Information"
$servers = Get-Content -Path $serversfile
$cred = Get-Credential
$date = Get-Date -Format MMddyyyy

# Array
$remoteIPInfo = @()

# Pull the data
try {
    foreach ($server in $servers) {
        Write-Log -logName $service -message "Pull IP information from $server"
        $IPInfo = Get-IPInfo -ServerName $server -Credential $cred
        if ($IPInfo) {
            $remoteIPInfo += $IPInfo
        }
        else {
            Write-Log -logName $service -message "No IP information retrieved from $server"
        }
    }
}
catch {
    Write-Log -logName $service -message "Failed to pull IP information from $server -- $($_.ToString())"
    Continue
}

# Check if the HTML file exists
try {
    if (-not (Test-Path -Path $logFilePath)) {
        New-Item -Path $logFilePath -ItemType Directory
        Write-Log -logName $service -message "Directory created"
    }
    else {
        Write-Log -logName $service -message "Directory already exists"
    }
}
catch {
    Write-Log -logName $service -message "Unable to create directory"
}

# Append the date to the specified log file path
$logFilePath = $logFilePath + "\$($service)_$date.html"

# Export all the data to an HTML file with custom table formatting
$remoteIPInfo | 
ConvertTo-Html -Head "<style>table { width: 100%; border-collapse: collapse; } th, td { border: 1px solid black; padding: 8px; text-align: left; } th { background-color: #f2f2f2; }</style>" -Property ServerName, IPv4Address, IPv4SubnetMask, IPv4DefaultGateway, DNSServers | 
Out-File -FilePath $logFilePath

Write-Log -logName $service -message "Script execution completed"