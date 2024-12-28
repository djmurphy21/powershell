# Module manifest information
@{
    ModuleVersion = '1.0'
    Author = 'Daniel Murphy'
    Description = 'PowerShell Logging Module'
}

<#
.SYNOPSIS
    Logs messages to a specified log file with timestamps and severity levels.
.DESCRIPTION
    The Write-Log function logs messages by creating or appending to a log file in a specified directory. 
    It supports multiple severity levels and can automatically rotate log files based on size.
    The function checks for the existence of the D:\Logs directory and defaults to C:\Logs if not found.
    Each log entry includes timestamp, severity level, and optional correlation ID for tracking related events.
.PARAMETER LogName
    The name of the log file (with or without .log extension).
.PARAMETER Message
    The message to be logged.
.PARAMETER Severity
    The severity level of the message (Information, Warning, Error, Debug).
.PARAMETER CorrelationId
    Optional correlation ID for tracking related log entries.
.PARAMETER MaxLogSizeMB
    Maximum log file size in MB before rotation (default: 10MB).
.EXAMPLE
    Write-Log -LogName "MyApp" -Message "Process started" -Severity Information
.EXAMPLE
    Write-Log -LogName "MyApp" -Message "Error occurred" -Severity Error -CorrelationId "123"
.NOTES
    File Names: Logs are automatically suffixed with date (MyApp_2024-12-27.log)
    Log Rotation: Automatically rotates logs when they exceed MaxLogSizeMB
    Error Handling: Includes comprehensive error handling and fallback options
    Correlation: Supports tracking related events through correlation IDs
#>

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error', 'Debug')]
        [string]$Severity = 'Information',

        [Parameter(Mandatory = $false)]
        [string]$CorrelationId,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 1000)]
        [int]$MaxLogSizeMB = 10
    )

    begin {
        # Set strict mode for better error handling
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # Determine the log folder path
        $LogFolderPath = if (Test-Path -Path "D:\Logs") { "D:\Logs" } else { "C:\Logs" }

        # Create date-based log filename
        $Date = Get-Date -Format "yyyy-MM-dd"
        $LogName = $LogName.TrimEnd('.log')
        $LogFileName = "${LogName}_${Date}.log"
        $LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $LogFileName
    }

    process {
        try {
            # Ensure the log folder exists
            if (-not (Test-Path -Path $LogFolderPath)) {
                $null = New-Item -Path $LogFolderPath -ItemType Directory -Force
                Write-Verbose "Created log directory: $LogFolderPath"
            }

            # Check if log rotation is needed
            if (Test-Path -Path $LogFilePath) {
                $logFile = Get-Item -Path $LogFilePath
                if ($logFile.Length/1MB -gt $MaxLogSizeMB) {
                    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
                    $rotatedName = "${LogName}_${Date}_${timestamp}.log"
                    $rotatedPath = Join-Path -Path $LogFolderPath -ChildPath $rotatedName
                    Move-Item -Path $LogFilePath -Destination $rotatedPath -Force
                    Write-Verbose "Rotated log file to: $rotatedPath"
                }
            }

            # Format the log entry
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            $logEntry = "[$timestamp] [$Severity]"
            if ($CorrelationId) {
                $logEntry += " [CorrelationId:$CorrelationId]"
            }
            $logEntry += " - $Message"

            # Write to log file
            $null = Add-Content -Path $LogFilePath -Value $logEntry -Encoding UTF8

            # Output to console based on severity
            switch ($Severity) {
                'Error' { Write-Error $Message }
                'Warning' { Write-Warning $Message }
                'Debug' { Write-Debug $Message }
                default { Write-Verbose $Message }
            }
        }
        catch {
            # Try writing to alternate location if primary fails
            try {
                $fallbackPath = Join-Path -Path $env:TEMP -ChildPath $LogFileName
                $errorMessage = "Failed to write to primary log location. Error: $_"
                $fallbackEntry = "[$timestamp] [Error] - $errorMessage"
                Add-Content -Path $fallbackPath -Value $fallbackEntry -Encoding UTF8
                Write-Error $errorMessage
            }
            catch {
                Write-Error "Critical logging failure: $_"
            }
        }
    }
}

# Export the function
Export-ModuleMember -Function Write-Log
