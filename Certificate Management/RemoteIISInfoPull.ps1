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
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if(-Not (Test-Path -Path $_ -IsValid)) {
            throw "Output path is invalid: $_"
        }
        $parent = Split-Path -Path $_ -Parent
        if(-Not (Test-Path -Path $parent)) {
            throw "Parent directory does not exist: $parent"
        }
        return $true
    })]
    [string]$outputPath, # Destination path for the CSV output

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if(-Not (Test-Path -Path $_)) {
            throw "Servers file does not exist: $_"
        }
        return $true
    })]
    [string]$ServersFile, # Path to the file containing server names

    [Parameter(Mandatory = $false)]
    [int]$WarningDays = 30, # Number of days before certificate expiration to warn about

    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Script Variables
$script:LogFileName = "IISCertificateInfo_$(Get-Date -Format 'yyyyMMdd').log"

try {
    Write-Log -LogName "IISManagement" -Message "Starting certificate information collection process" -Severity Information
    
    # Verify servers file content
    $servers = Get-Content -Path $ServersFile -ErrorAction Stop
    if ($servers.Count -eq 0) {
        Write-Log -LogName "IISManagement" -Message "The servers file is empty: $ServersFile" -Severity Error
        exit 1
    }

    Write-Log -LogName "IISManagement" -Message "Starting certificate information collection for $($servers.Count) servers" -Severity Information

    # Get credentials once for all servers
    $cred = Get-Credential -Message "Enter credentials for remote server access"

    # Array to store all certificates
    $allCerts = @()

    # Function to write logs
    function Write-Log {
        param (
            [string]$Message,
            [ValidateSet('Information', 'Warning', 'Error')]
            [string]$Level = 'Information'
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
            New-Item -Path $LogFolderPath -ItemType Directory -Force | Out-Null
        }

        # Combine the folder path and log file name
        $LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $script:LogFileName

        # Get the current date and time
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Format the log entry
        $logEntry = "$timestamp [$Level] - $Message"

        # Write the log entry to the file
        Add-Content -Path $LogFilePath -Value $logEntry

        # If verbose, also write to console
        if ($Verbose) {
            switch ($Level) {
                'Warning' { Write-Warning $Message }
                'Error' { Write-Error $Message }
                default { Write-Verbose $Message }
            }
        }
    }

    # Function to pull all IIS sites that having bindings and an SSL cert
    function Get-RemoteIISCertInfo {
        param (
            [string]$RemoteServerName,
            [System.Management.Automation.PSCredential]$Credential
        )

        $script = {
            Import-Module -Name WebAdministration -ErrorAction Stop

            Get-ChildItem -Path IIS:SSLBindings | ForEach-Object -Process {
                if ($_.Sites) {
                    $thumbprint = $_.Thumbprint
                    $certificate = Get-ChildItem -Path Cert:\LocalMachine\My | 
                        Where-Object -Property Thumbprint -EQ -Value $thumbprint

                    if ($certificate) {
                        [PSCustomObject]@{
                            ServerName              = $env:COMPUTERNAME
                            Sites                   = $_.Sites.Value
                            CertificateFriendlyName = $certificate.FriendlyName
                            CertificateThumbprint   = $certificate.Thumbprint
                            CertificateSubject      = $certificate.Subject
                            CertificateDNSNameList  = ($certificate.DnsNameList -join '; ')
                            CertificateNotBefore    = $certificate.NotBefore
                            CertificateNotAfter     = $certificate.NotAfter
                            CertificateIssuer       = $certificate.Issuer
                            DaysUntilExpiration     = ($certificate.NotAfter - (Get-Date)).Days
                        }
                    }
                }
            }
        }

        try {
            $result = Invoke-Command -ComputerName $RemoteServerName -ScriptBlock $script -Credential $Credential -ErrorAction Stop
            Write-Log -LogName "IISManagement" -Message "Successfully retrieved certificate information from $RemoteServerName" -Severity Information
            return $result
        }
        catch {
            Write-Log -LogName "IISManagement" -Message "Failed to retrieve certificate information from ${RemoteServerName}: ${$_.Exception.Message}" -Severity Error
            return ${null}
        }
    }

    # Pull the data
    $serverCount = $servers.Count
    $currentServer = 0

    foreach ($server in $servers) {
        $currentServer++
        $progressParams = @{
            Activity = "Retrieving SSL Certificate Information"
            Status = "Processing server $currentServer of $serverCount"
            PercentComplete = ($currentServer / $serverCount * 100)
        }
        Write-Progress @progressParams

        Write-Log -LogName "IISManagement" -Message "Processing server: $server" -Severity Information
        
        $certs = Get-RemoteIISCertInfo -RemoteServerName $server -Credential $cred
        if ($certs) {
            $allCerts += $certs
            
            # Check for certificates nearing expiration
            foreach ($cert in $certs) {
                if ($cert.DaysUntilExpiration -le $WarningDays) {
                    Write-Log -LogName "IISManagement" -Message "Certificate on $($cert.ServerName) for site(s) $($cert.Sites) will expire in $($cert.DaysUntilExpiration) days" -Severity Warning
                }
            }
        }
    }

    Write-Progress -Activity "Retrieving SSL Certificate Information" -Completed

    # Export all the data to a CSV
    try {
        $allCerts | Export-Csv -Path $outputPath -NoTypeInformation -ErrorAction Stop
        Write-Log -LogName "IISManagement" -Message "Successfully exported certificate information to $outputPath" -Severity Information
    }
    catch {
        Write-Log -LogName "IISManagement" -Message "Failed to export certificate information to CSV: $($_.Exception.Message)" -Severity Error
        exit 1
    }

    Write-Log -LogName "IISManagement" -Message "IIS information collected successfully" -Severity Information
}
catch {
    Write-Log -LogName "IISManagement" -Message "Failed to collect IIS information: $_" -Severity Error
    throw
}
finally {
    Write-Log -LogName "IISManagement" -Message "IIS information collection process completed" -Severity Information
}