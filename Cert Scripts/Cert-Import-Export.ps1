<#
.SYNOPSIS
    This script helps you manage your certificates by importing various certificate types, linking them with their private keys, and setting a friendly name based on the certificate's common name (CN) and validity dates. 
    It then exports these certificates as .PFX files with randomly generated passwords, logging all the details in a CSV file.
.DESCRIPTION
    The script performs the following tasks:
    - Imports certificates from a specified directory.
    - Sets a friendly name for each certificate based on its CN and date range.
    - Exports the certificates as .PFX files with generated passwords.
    - Logs the certificate details and passwords in a CSV file for reference.
.NOTES
    Ensure you have the necessary permissions to access the certificate store and export certificates.
    VS Code, PowerShell or PowerShell ISE need to be ran from an elevated command prompt.
    The script requires the Zywave module for logging purposes.
    Parameter example:
        Supply values for the following parameters:
        certPath: D:\Certificates
        pfxOutputPath: D:\Certificates
        logFilePath: D:\Certificates
#>


# Parameters
param (
    # Full Path for where the cert files are located
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $certPath,
    # Full Path to place the PFX files that are being exported
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $pfxOutputPath,
    # Full path to place the CSV file that contains the PFX names and passwords
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $logFilePath
)

# Function to generate a random password
function New-RandomPassword {
    param(
        [Parameter()]
        [int]$MinimumPasswordLength = 24,
        [Parameter()]
        [int]$MaximumPasswordLength = 26,
        [Parameter()]
        [int]$NumberOfNonAlphaNumericCharacters = 5,
        [Parameter()]
        [switch]$ConvertToSecureString
    )

    Add-Type -AssemblyName 'System.Web'
    $length = Get-Random -Minimum $MinimumPasswordLength -Maximum $MaximumPasswordLength
    $password = [System.Web.Security.Membership]::GeneratePassword($length, $NumberOfNonAlphaNumericCharacters)
    if ($ConvertToSecureString.IsPresent) {
        ConvertTo-SecureString -String $password -AsPlainText -Force
    }
    else {
        $password
    }
}

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

#Requires -RunAsAdministrator

# Variables
$service = "Certificate Import and Export"
$date = Get-Date -Format MMddyyyy
$headers = "Certificate, Password"

# Confirm all paths provided
Write-Host "Please verify all paths are correct"
$certPathParam = Read-Host "If this is the correct path $($certPath) for the certificates being imported, then type yes to proceed(case sensitive)"
if ($certPathParam -ceq "yes") {
    Write-Log -logName $Service -message "Path to certificates verified - $($certPath)"
}
else {
    Write-Log -logName $Service -message "You entered $($certPathParam) which does not match yes - restart script to try again"; exit
}
$pfxOutputPathParam = Read-Host "If this is the correct path $($pfxOutputPath) for the PFX Certificates to be exported, then type yes to proceed(case sensitive)"
if ($pfxOutputPathParam -ceq "yes") {
    Write-Log -logName $service -message "Path to export the PFX certificates verified - $($pfxOutputPath)"
}
else {
    Write-Log -logName $Service -message "You entered $($pfxOutputPathParam) which does not match yes - restart script to try again"; exit
}
$logFilePathParam = Read-Host "If this is the correct path $($logFilePath) for the Cert information to be logged, type yes to proceed(case sensitive)"
if ($logFilePathParam -eq "yes") {
    Write-Log -logName $service -message "Path to generate the log file verified - $($logFilePath)"
}
else {
    Write-Log -logName $Service -message "You entered $($logFilePathParam) which does not match yes - restart script to try again"; exit
}

# Append the date to the specified log file path
$logFilePath = $logFilePath + "\PFXExportLog_" + $date + ".csv"

# Check if the CSV file exists and add headers if it doesn't
if (-not (Test-Path -Path $logFilePath)) {
    Add-Content -Path $logFilePath -Value $headers
}

# Import the downloaded certificate files from DigiCert
Get-ChildItem -Path $certPath -Include *.p7b, *.crt, *.cer -Recurse | ForEach-Object {
    $certFile = $_.FullName
    Write-Log -logName $service -message "Processing file: $certFile"
    $certs = Import-Certificate -FilePath $certFile -CertStoreLocation Cert:\LocalMachine\My

    foreach ($cert in $certs) {

        # Clear variables from previous run to avoid undiagnosed failures
        $cn = $null
        $issueDate = $null
        $expiryDate = $null
        $friendlyName = $null
        $thumbprint = $null
        $password = $null
        $filename = $null
        $pfxFile = $null

        if ($cert.HasPrivateKey) {
            $cn = $cert.Subject -replace '.*CN=([^,]+).*', '$1'
            # Log the CN value for debugging
            Write-Log -logName $service -message "Certificate CN: $cn"

            $issueDate = $cert.NotBefore.ToString("yyyyMMdd")
            $expiryDate = $cert.NotAfter.ToString("yyyyMMdd")
            $friendlyName = "$cn-$issueDate-$expiryDate"

            if ($friendlyName -like '*') {
                $friendlyName = $friendlyName.Replace("*", "wc")
            }

            $fileName = $friendlyName

            Write-Log -logName $service -message "Generated friendly name: $friendlyName"
            Write-Log -logName $service -message "Generated file name: $fileName"

            if ($cert.Issuer -ne $cert.Subject) {
                try {
                    $cert.FriendlyName = $friendlyName
                    $thumbprint = $cert.Thumbprint
                    (Get-ChildItem -Path Cert:\LocalMachine\My\$thumbprint).FriendlyName = "$friendlyName"
                    Write-Log -logName $service -message "Set friendly name: $friendlyName"
                }
                catch {
                    Write-Log -logName $service -message "Failed to set friendly name for certificate: $($cert.Subject) -- $($_.ToString())"
                }
            }
            else {
                Write-Log -logName $service -message "Skipping root/intermediate certificate: $($cert.Subject)"
            }
                      
            # Check if CN contains "DigiCert" before exporting
            if ($cn -like '*DigiCert*') {
                Write-Log -logName $service -message "Skipping export for certificate with CN containing 'DigiCert': $($cert.Subject)"
                continue
            }
            else {
                $password = New-RandomPassword
                $pfxFile = Join-Path -Path $pfxOutputPath -ChildPath "$fileName.pfx"
                Export-PfxCertificate -Cert $cert -FilePath $pfxFile -Password (ConvertTo-SecureString -String $password -Force -AsPlainText)
                Write-Log -logName $service -message "Exported PFX file: $pfxFile"
                Add-Content -Path $logFilePath -Value "$friendlyName, $password"
                Write-Log -logName $service -message "Logged password for: $friendlyName"

                # Path to the zip file
                $zipFilePath = Join-Path -Path $pfxOutputPath -ChildPath "$fileName.zip"

                # Compress the .pfx file into a zip file
                Compress-Archive -Path $pfxFile -DestinationPath $zipFilePath
                Write-Log -logName $service -message "Compressed PFX file into: $zipFilePath"
            }

        }
    }
}

Write-Log -logName $service -message "Script execution completed"