# Write-Log PowerShell Module

## Synopsis

The `Write-Log` function is a PowerShell script designed to log messages to a specified log file. It ensures the log file is created in the appropriate directory and appends log entries with timestamps.

## Description

The `Write-Log` function takes two parameters: `LogName` and `Message`. It checks if the `D:\Logs` directory is available; if not, it defaults to `C:\Logs`. The function ensures the log file name ends with `.log` and combines the folder path with the log file name. It creates the log directory if it doesn't exist and writes the log entry with a timestamp to the log file. If the log file doesn't exist, it creates a new one.

## Parameters

- `LogName`: The name of the log file.
- `Message`: The message to be logged.

## Notes

- **Directory Check**: The function checks for the existence of `D:\Logs` and defaults to `C:\Logs` if not found.
- **Log File Creation**: Ensures the log file ends with `.log` and creates the file if it doesn't exist.
- **Timestamp**: Each log entry is prefixed with the current date and time in the format `yyyy-MM-dd HH:mm:ss`.
- **Error Handling**: The function includes error handling for directory and file creation, as well as for writing log entries.

## Importing the Module

To use the `Write-Log` function, you need to import the module into your PowerShell session. You can do this by saving the function in a `.psm1` file and using the `Import-Module` cmdlet.

1. Save the function in a file named `Write-Log.psm1`.
2. Import the module using the following command:
   ```powershell
   Import-Module -Name "Path\To\Write-Log.psm1"
   ```

## Example

```powershell
Write-Log -LogName "ApplicationLog" -Message "This is a log entry."
```
