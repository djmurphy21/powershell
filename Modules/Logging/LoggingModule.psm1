<#
.SYNOPSIS
    Logs messages to a specified log file with timestamps.
.DESCRIPTION
    The Write-Log function logs messages by creating or appending to a log file in a specified directory. 
    It checks for the existence of the D:\Logs directory and defaults to C:\Logs if not found. It ensures 
    the log file ends with .log and creates the necessary directories and files if they do not exist. 
    Each log entry is prefixed with the current date and time in the format yyyy-MM-dd HH:mm:ss.
.PARAMETER LogName
    The name of the log file.
.PARAMETER Message
    The message to be logged.
.NOTES
    Directory Check: The function checks for the existence of D:\Logs and defaults to C:\Logs if not found.
    Log File Creation: Ensures the log file ends with .log and creates the file if it doesn't exist.
    Timestamp: Each log entry is prefixed with the current date and time in the format yyyy-MM-dd HH:mm:ss.
    Error Handling: The function includes error handling for directory and file creation, as well as for writing log entries.
#>

function Write-Log {
    param (
        [string]$LogName,
        [string]$Message
    )

    # Determine the log folder path
    if (Test-Path -Path "D:\Logs") {
        $LogFolderPath = "D:\Logs"
    }
    else {
        $LogFolderPath = "C:\Logs"
    }

    # Ensure the log name ends with .log
    if (-not $LogName.EndsWith(".log")) {
        $LogName = "$LogName.log"
    }

    # Combine the folder path and log file name
    $LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $LogName

    # Ensure the log folder exists
    if (-not (Test-Path -Path $LogFolderPath)) {
        try {
            New-Item -Path $LogFolderPath -ItemType Directory -Force -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to create log directory: $LogFolderPath. Error: $_"
            return
        }
    }

    # Get the current date and time
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Format the log entry
    $logEntry = "$timestamp - $Message"

    # Check if the file exists, and create it if it doesn't
    if (-not (Test-Path -Path $LogFilePath)) {
        try {
            New-Item -Path $LogFilePath -ItemType File -Force -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to create log file: $LogFilePath. Error: $_"
            return
        }
    }

    # Try to write the log entry to the file
    try {
        Add-Content -Path $LogFilePath -Value $logEntry -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write to log file: $LogFilePath. Error: $_"
    }
}