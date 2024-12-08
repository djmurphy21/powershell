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
    [string] $outputPath
)

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
$outputPathParam = Read-Host "If this is the correct path $($outputPath) for the folders, INF file and CSR file to be placed, then type yes to proceed(case sensitive)"
if ($outputPathParam -ceq "yes") {
    Write-Log -logName $Service -message "$($outputPath) set correctly."
}
else {
    Write-Log -logName $Service -message "You entered $($outputPathParam) which does not match yes - restart script to try again"; exit
}

# Prompt for Cert Subject information
Write-Host "Please enter the remaining subject information"
$organizationalUnit = Read-Host: "Please provide the Organization Unit for the INF - Example IT : "
$organization = Read-Host: "Please provide the Organization for the INF - Example DanTest Inc : "
$location = Read-Host: "Please provide the Location for the INF - Example New You City : "
$state = Read-Host: "Please provide the State for the INF - Example New York : "
$country = Read-Host: "Please provide the Country for the INF - Example US : "

# Function to create the necessary folders and files
function New-CSR {
    param (
        [string] $certName,
        [string] $certFolder,
        [string] $csrPath,
        [string] $infPath
    )

    # Create Cert folders for file placements
    try {
        New-Item -ItemType Directory -Force -Path $outputPath\$certFolder
        Write-Log -logName $service -message "Successfully created $($certFolder) folder."
    }
    catch {
        Write-Log -logName $service -message "Failed to create folder -- $($_.ToString())"
        return
    }

    # Split the SANs variable if multiple SANs are provided
    $dnsSANs = ""
    foreach ($itmSANs in $SANs) {
        $dnsSANs += '_continue_ = "DNS=' + $itmSANs + '&"' + [System.Environment]::NewLine
    }

    # Create INF variable for the INF files
    $inf = @"
    [Version]
    Signature= "$Signature NT$"

    [NewRequest]
    Subject = "CN=$certName,OU=$organizationalUnit,O=$organization,L=$location,S=$state,C=$country"
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
        $inf | Out-File -FilePath $infPath -Force
    }
    catch {
        Write-Log -logName $service -message "Failed to create the INF file -- $($_.ToString())"
        return
    }

    # Create the CSR based off the information in the INF file
    try {
        certreq.exe -new $infPath $csrPath
    }
    catch {
        Write-Log -logName $service -message "Failed to create the CSR file -- $($_.ToString())"
        return
    }
}

# Iterate through the CSV file and create the necessary folders and files
foreach ($row in $CSV) {
    $certName = $row.certName
    $SANs = $row.SANs -split ','
    $certFolder = "$($certName)_$($date)"
    $csrPath = "$($outputPath)\$($certFolder)\$($certName).csr"
    $infPath = "$($outputPath)\$($certFolder)\$($certName).inf"

    Create-CSR -certName $certName -certFolder $certFolder -csrPath $csrPath -infPath $infPath
}

Write-Log -logName $service -message "Script execution completed"
