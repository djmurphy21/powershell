<#
.SYNOPSIS
    The Write-Log function is a PowerShell script designed to log messages to a specified log file. It ensures the log file is created in the appropriate directory and appends log entries with timestamps.
.DESCRIPTION
    The Write-Log function takes two parameters: LogName and Message. It checks if the D:\Logs directory is available; if not, it defaults to C:\Logs. 
    The function ensures the log file name ends with .log and combines the folder path with the log file name. 
    It creates the log directory if it doesn't exist and writes the log entry with a timestamp to the log file. 
    If the log file doesn't exist, it creates a new one.
.NOTES
    Parameters:
        - LogName: The name of the log file.
        - Message: The message to be logged.
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

    # Check if D:\Logs is available, otherwise use C:\Logs
    if (Test-Path -Path "D:\Logs") {
        $LogFolderPath = "D:\Logs"
    }
    else {
        $LogFolderPath = "C:\Logs"
    }

    # Log the folder path for debugging
    Write-Output "Log Folder Path: $LogFolderPath"

    # Ensure the log name ends with .log
    if (-not $LogName.EndsWith(".log")) {
        $LogName = "$LogName.log"
    }

    # Combine the folder path and log file name
    $LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $LogName

    # Log the file path for debugging
    Write-Output "Log File Path: $LogFilePath"

    # Ensure the log folder exists
    if (-not (Test-Path -Path $LogFolderPath)) {
        try {
            New-Item -Path $LogFolderPath -ItemType Directory -Force -ErrorAction Stop
            Write-Output "Log folder created: $LogFolderPath"
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
            # Create the file and add a header (optional)
            Write-Output "Creating new log file: $LogFilePath"
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
        Write-Output "Log entry written successfully to $LogFilePath."
    }
    catch {
        Write-Error "Failed to write to log file: $LogFilePath. Error: $_"
    }
}