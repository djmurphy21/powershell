<#
.SYNOPSIS
    Copy and installs SSL Certs into Windows Server Cert Stores
.Description
    Each parameter is required and if the script is ran without any set it will prompt for them.
.NOTES

#>

# Import logging module
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\Modules\Logging\LoggingModule.psm1"
if (Test-Path -Path $modulePath) {
    Import-Module -Name $modulePath -Force
}
else {
    throw "Logging module not found at: $modulePath"
}

# Define mandatory parameters for the script
param (
    # Source file path of the certificate
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path $_})]
    [string]$SourceFile,
    
    # Destination path on the remote servers
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationPath,
    
    # Path to the file containing server names
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({Test-Path $_})]
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

# Set error action preference
$ErrorActionPreference = 'Stop'

# Functions
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogName,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information'
    )

    # Check if D:\Logs is available, otherwise use C:\Logs
    if (Test-Path -Path "D:\Logs") {
        $LogFolderPath = "D:\Logs"
    }
    else {
        $LogFolderPath = "C:\Logs"
        if (-not (Test-Path -Path $LogFolderPath)) {
            try {
                New-Item -Path $LogFolderPath -ItemType Directory -Force | Out-Null
            }
            catch {
                Write-Error "Failed to create log directory: $_"
                return
            }
        }
    }

<<<<<<< HEAD
    $LogFileName = "{0}_{1:yyyy-MM-dd}.log" -f $LogName, (Get-Date)
    $LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $LogFileName
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Severity] - $Message"

    try {
        Add-Content -Path $LogFilePath -Value $logEntry
        if ($Severity -eq 'Error') {
            Write-Error $Message
        }
        elseif ($Severity -eq 'Warning') {
            Write-Warning $Message
        }
        else {
            Write-Verbose $Message
        }
    }
    catch {
        Write-Error "Error writing to log file: $_"
    }
}

# Function to test server connectivity
function Test-ServerConnection {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServerName
    )
    
    try {
        $result = Test-Connection -ComputerName $ServerName -Count 1 -Quiet
        if (-not $result) {
            Write-Log -LogName $service -Message "Server $ServerName is not reachable" -Severity 'Error'
        }
        return $result
    }
    catch {
        Write-Log -LogName $service -Message "Error testing connection to ${ServerName}: $_" -Severity 'Error'
        return ${false} -eq $false
    }
=======
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
>>>>>>> parent of b818a26 (Updates)
}

# Function to copy file to a server
function Copy-FileToServer {
    param (
        [Parameter(Mandatory = $true)]
        [string]$server,
        
        [Parameter(Mandatory = $true)]
        [string]$source,
        
        [Parameter(Mandatory = $true)]
        [string]$destination
    )
<<<<<<< HEAD
    
    Write-Log -LogName $service -Message "Attempting to copy the file to $server" -Severity Information

    if (-not (Test-ServerConnection -ServerName $server)) {
        return $false
    }

=======
>>>>>>> parent of b818a26 (Updates)
    try {
        $destinationFolder = Split-Path -Path $destination -Parent
        if (-not (Test-Path -Path $destinationFolder)) {
            New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
        }
        
        Copy-Item -Path $source -Destination $destination -Force
        Write-Log -LogName $service -Message "File copied to $server successfully." -Severity Information
        return $true
    }
    catch {
        Write-Log -LogName $service -Message "Failed to copy file to ${server}: $_" -Severity Error
        return $false
    }
}

# Function to install certificate on a server
function Install-Certificate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$server,
        
        [Parameter(Mandatory = $true)]
        [string]$path,
        
        [Parameter(Mandatory = $true)]
        [securestring]$password
    )
<<<<<<< HEAD
    
    Write-Log -LogName $service -Message "Attempting to install the certificate on $server" -Severity Information

    if (-not (Test-ServerConnection -ServerName $server)) {
        return $false
    }

=======
>>>>>>> parent of b818a26 (Updates)
    try {
        Invoke-Command -ComputerName $server -ScriptBlock {
            param($path, [SecureString]$password)
            
            if (-not (Test-Path -Path $path)) {
                throw "Certificate file not found at: $path"
            }
            
            $cert = Import-PfxCertificate -FilePath $path -CertStoreLocation Cert:\LocalMachine\My -Password $password
            return @{
                FriendlyName = $cert.FriendlyName
                Thumbprint = $cert.Thumbprint
                Subject = $cert.Subject
                NotAfter = $cert.NotAfter
            }
        } -ArgumentList $path, $password
<<<<<<< HEAD

        Write-Log -LogName $service -Message "Certificate installed on $server successfully:" -Severity Information
        Write-Log -LogName $service -Message "Friendly Name: $($cert.FriendlyName)" -Severity Information
        Write-Log -LogName $service -Message "Thumbprint: $($cert.Thumbprint)" -Severity Information
        Write-Log -LogName $service -Message "Subject: $($cert.Subject)" -Severity Information
        Write-Log -LogName $service -Message "Expires: $($cert.NotAfter)" -Severity Information
        return $true
    }
    catch {
        Write-Log -LogName $service -Message "Failed to install the cert on ${server}: $_" -Severity Error
        return $false
    }
}

# Main execution block
try {
    Write-Log -LogName $service -Message "Script execution started" -Severity Information
    Write-Log -LogName $service -Message "Reading servers from $ServersFile" -Severity Information

    if (-not (Test-Path -Path $ServersFile)) {
        throw "ServersFile not found at $ServersFile"
    }

    $servers = Get-Content -Path $ServersFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($servers.Count -eq 0) {
        throw "No servers found in $ServersFile"
    }

    Write-Log -LogName $service -Message "Found $($servers.Count) servers to process" -Severity Information

    $results = @{
        Successful = @()
        Failed = @()
    }

    foreach ($server in $servers) {
        $server = $server.Trim()
        Write-Log -LogName $service -Message "Processing server: $server" -Severity Information
        
        $destination = "\\$server\$destinationPath"
        $copySuccess = Copy-FileToServer -server $server -source $sourceFile -destination $destination
        
        if ($copySuccess) {
            $installSuccess = Install-Certificate -server $server -path $certPath -password $certPass
            if ($installSuccess) {
                $results.Successful += $server
            }
            else {
                $results.Failed += $server
            }
        }
        else {
            $results.Failed += $server
            Write-Log -LogName $service -Message "Skipping certificate installation on $server due to copy failure" -Severity Warning
        }
    }

    # Summary
    Write-Log -LogName $service -Message "=== Execution Summary ===" -Severity Information
    Write-Log -LogName $service -Message "Successful servers: $($results.Successful.Count)" -Severity Information
    Write-Log -LogName $service -Message "Failed servers: $($results.Failed.Count)" -Severity Information
    
    if ($results.Failed.Count -gt 0) {
        Write-Log -LogName $service -Message "Failed servers list: $($results.Failed -join ', ')" -Severity Warning
    }
}
catch {
    Write-Log -LogName $service -Message "Critical error in script execution: $_" -Severity Error
    throw
}
finally {
    Write-Log -LogName $service -Message "Script execution completed" -Severity Information
}
=======
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
>>>>>>> parent of b818a26 (Updates)
