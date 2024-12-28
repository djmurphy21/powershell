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

# Import logging module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\Logging\LoggingModule.psm1"
if (Test-Path -Path $modulePath) {
    Import-Module -Name $modulePath -Force
}
else {
    throw "Logging module not found at: $modulePath"
}

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

# Function to pull IP information from the remote server
function Get-IPInfo {
    param (
        [string]$ServerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    try {
        # Create a CIM session
        $session = New-CimSession -ComputerName $ServerName -Credential $Credential
        Write-Log -LogName "Get Server IP Information" -Message "Created CIM session for $ServerName" -Severity Information

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
        Write-Log -LogName "Get Server IP Information" -Message "Removed CIM session for $ServerName" -Severity Information

        return $netInfo
    }
    catch {
        Write-Log -LogName "Get Server IP Information" -Message "Error getting IP information from $ServerName : $($_.Exception.Message)" -Severity Error
        return $null
    }
}

# Variables
$service = "Get Server IP Information"
$date = Get-Date -Format MMddyyyy
$correlationId = [guid]::NewGuid().ToString()

try {
    Write-Log -LogName $service -Message "Starting IP information collection process" -Severity Information -CorrelationId $correlationId
    
    # Validate input file
    if (-not (Test-Path -Path $serversfile)) {
        throw "Servers file not found: $serversfile"
    }

    $servers = Get-Content -Path $serversfile
    if ($servers.Count -eq 0) {
        throw "No servers found in file: $serversfile"
    }

    Write-Log -LogName $service -Message "Found $($servers.Count) servers to process" -Severity Information -CorrelationId $correlationId

    # Get credentials
    $cred = Get-Credential -Message "Enter credentials for remote server access"

    # Array for results
    $remoteIPInfo = @()

    # Pull the data
    $serverCount = $servers.Count
    $currentServer = 0

    foreach ($server in $servers) {
        $currentServer++
        $progressParams = @{
            Activity = "Retrieving Server IP Information"
            Status = "Processing server $currentServer of $serverCount"
            PercentComplete = ($currentServer / $serverCount * 100)
        }
        Write-Progress @progressParams

        Write-Log -LogName $service -Message "Processing server: $server" -Severity Information -CorrelationId $correlationId
        $IPInfo = Get-IPInfo -ServerName $server -Credential $cred
        
        if ($IPInfo) {
            $remoteIPInfo += $IPInfo
        }
        else {
            Write-Log -LogName $service -Message "No IP information retrieved from $server" -Severity Warning -CorrelationId $correlationId
        }
    }

    Write-Progress -Activity "Retrieving Server IP Information" -Completed

    # Export the data
    if ($remoteIPInfo.Count -gt 0) {
        $outputPath = Join-Path -Path $logFilePath -ChildPath "ServerIPInfo_$date.html"
        $remoteIPInfo | 
        ConvertTo-Html -Head "<style>table { width: 100%; border-collapse: collapse; } th, td { border: 1px solid black; padding: 8px; text-align: left; } th { background-color: #f2f2f2; }</style>" -Property ServerName, IPv4Address, IPv4SubnetMask, IPv4DefaultGateway, DNSServers | 
        Out-File -FilePath $outputPath
        Write-Log -LogName $service -Message "Successfully exported IP information to $outputPath" -Severity Information -CorrelationId $correlationId
    }
    else {
        Write-Log -LogName $service -Message "No IP information collected from any servers" -Severity Warning -CorrelationId $correlationId
    }

    Write-Log -LogName $service -Message "Script execution completed successfully" -Severity Information -CorrelationId $correlationId
}
catch {
    Write-Log -LogName $service -Message "Critical error in script execution: $_" -Severity Error -CorrelationId $correlationId
    throw
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
