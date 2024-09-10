<#
.SYNOPSIS
The `GenerateCSR.ps1` script generates Certificate Signing Requests (CSRs) for multiple domains listed in a CSV file. 
It creates necessary folders, INF files, and CSR files, allowing the automation of CSR generation for various certificates.

.DESCRIPTION
This PowerShell script automates the creation of CSRs by reading domain information from a provided CSV file. 
For each domain, it generates the corresponding INF configuration and CSR file. The script prompts for additional 
certificate subject details, including Organizational Unit, Organization, Location, State, and Country, and logs 
progress and any errors encountered.

Key functionality includes:
- Parsing a CSV file with columns `certName` (common name) and `SANs` (Subject Alternative Names).
- Creating folders and files based on the domain information.
- Writing INF configuration files and generating CSRs using `certreq.exe`.
- Logging all actions, including success and error messages, to a log file.

.NOTES
- Run this script from an elevated PowerShell console.
- Ensure you have a CSV file with headers `certName` and `SANs`. The format should look like this:
- certName, SANs dmtest.test.com, dmtest1.test.com dmtest2.test.com
- The script uses `certreq.exe` to generate CSRs, and logs are stored in either `D:\Logs` or `C:\Logs`
depending on the availability of the directory.
#>

# Parameters

param (
    # Full Path for .csv import
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $csvData,
    # Full Path to create the folders, INFs and CSRs
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Path
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

# Variables
$date = Get-Date -Format MMddyyyy
$service = "Generate CSR"

# Log Creation
Write-Log -logName $service -message "Starting $service process for $($date)"

# Confirm all paths provided and import CSV
Write-Host "Please verify all paths are correct"
$csvDataParam = Read-Host "If this is the correct path $($csvData) for the CSV File being used to generate the data, then type yes to proceed(case sensitive)"
if ($csvDataParam -ceq "yes") {
    # Import corrected CSV
    Write-Log -logName $Service -message "Importing CSV"
    $CSV = Import-Csv -Path $csvData
}
else {
    Write-Log -logName $Service -message "You entered $($csvDataParam) which does not match yes - restart script to try again"; exit
}
$PathParam = Read-Host "If this is the correct path $($Path) for the folders, INF file and CSR file to be placed, then type yes to proceed(case sensitive)"
if ($PathParam -ceq "yes") {
    Write-Log -logName $Service -message "$($Path) set correctly."
}
else {
    Write-Log -logName $Service -message "You entered $($PathParam) which does not match yes - restart script to try again"; exit
}

# Prompt for Cert Subject information
Write-Host "Please enter the remaining subject information"
$OU = Read-Host: "Please provide the Organization Unit for the INF - Example IT : "
$Org = Read-Host: "Please provide the Organization for the INF - Example DanTest Inc : "
$Location = Read-Host: "Please provide the Location for the INF - Example New You City : "
$State = Read-Host: "Please provide the State for the INF - Example New York : "
$Country = Read-Host: "Please provide the Country for the INF - Example US : "

foreach ($row in $CSV) {

    # Clear variables from previous run to avoid undiagnosed failures
    $certName = $null
    $SANs = $null
    $certFolder = $null
    $CSRPath = $null
    $INFPath = $null
    $certNameWC = $null
    $certFolderWC = $null
    $CSRPathWC = $null
    $INFPathWC = $null
    $Signature = $null

    # Define variables for each CSR inside of the CSV
    $certName = $row.certName
    $SANs = $row.SANs -split ','
    $SANs = if ($row.SANs) { $row.SANs.Replace(' ', ',') -split ',' } else { @() }
    $certFolder = "$($certName)_$($date)"
    $CSRPath = "$($Path)\$($certFolder)\$($certName).csr"
    $INFPath = "$($Path)\$($certFolder)\$($certName).inf"
    $Signature = '$Windows'

    # Create Cert folders for file placements
    try {
        if ($certName -like '*') {
            $certNameWC = $certName.Replace("*", "wc")
            $certFolderWC = "$($certNameWC)_$($date)"
            $CSRPathWC = "$($Path)\$($certFolderWC)\$($certNameWC).csr"
            $INFPathWC = "$($Path)\$($certFolderWC)\$($certNameWC).inf"
            New-Item -ItemType Directory -Force -Path $Path\$certFolderWC
            Write-Log -logName $service -message "Successfully created $($certFolderWC) folder."
        }
        else {
            New-Item -ItemType Directory -Force -Path $Path\$certFolder
            Write-Log -logName $service -message "Successfully created $($certFolder) folder"
        }
    }
    catch {
        Write-Log -logName $service -message "Failed to create folder -- $($_.ToString())"
        continue
    }

    # Split the SANs variable if multiple SANs are provided
    $dnsSANs = ""
    foreach ($itmSANs in $SANs) {
        $dnsSANs += '_continue_ = "DNS=' + $itmSANs + '&"' + [System.Environment]::NewLine
    }

    # Create INF variable for the INF files
    $INF = @"
    [Version]
    Signature= "$Signature NT$"

    [NewRequest]
    Subject = "CN=$certName,OU=$OU,O=$Org,L=$Location,S=$State,C=$Country"
    KeySpec = 1
    KeyLength = 2048
    Exportable = TRUE
    MachineKeySet = TRUE
    SMIME = False
    PrivateKeyArchive = FALSE
    UserProtected = FALSE
    UseExistingKeySet = FALSE
    ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    ProviderType = 12
    RequestType = PKCS10
    KeyUsage = 0xa0

    [EnhancedKeyUsageExtension]
    OID=1.3.6.1.5.5.7.3.1

    [Extensions]
    2.5.29.17 = "{text}"
    _continue_ = "dns=$certName &" 
    ${dnsSANs}

"@

    # Create the INF file 
    try {
        if ([string]::IsNullOrEmpty($certNameWC) -eq $false) {
            Write-Log -logName $service -message "Creating the INF file for the $($certNameWC)"
            $INF | Out-File -FilePath $INFPathWC -Force
        }
        else {
            Write-Log -logName $service -message "Creating the INF file for the $($certName)"
            $INF | Out-File -FilePath $INFPath -Force
        }
    }
    catch {
        Write-Log -logName $service -message "Failed to create the INF file for the $($certName) -- $($_.ToString())"
        Continue
    } 

    # Create the CSR based off the information in the INF file
    try {
        if ([string]::IsNullOrEmpty($certNameWC) -eq $false) {
            Write-Log -logName $service -message "Creating the CSR for $($certNameWC) based on the INF file"
            certreq.exe -new $INFPathWC $CSRPathWC
        }
        else {
            Write-Log -logName $service -message "Creating the CSR for $($certName) based on the INF file"
            certreq.exe -new $INFPath $CSRPath
        }
    }
    catch {
        Write-Log -logName $service -message "Failed to create the CSR file for $($certName) -- $($_.ToString())"
        Continue
    }
}

Write-Log -logName $service -message "Script execution completed"