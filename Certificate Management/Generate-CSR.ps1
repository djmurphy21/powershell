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
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (Test-Path $_ -PathType Leaf) { $true } else { throw "CSV file not found at: $_" }
    })]
    [string] $csvData,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not (Test-Path $_)) { New-Item -Path $_ -ItemType Directory -Force | Out-Null }
        $true
    })]
    [string] $outputPath
)

# Variables
$date = Get-Date -Format MMddyyyy
$service = "Generate CSR"
$ErrorActionPreference = 'Stop'

try {
    Write-Log -LogName "CertificateManagement" -Message "Starting CSR generation process" -Severity Information
    
    # Log Creation
    Write-Log -logName $service -message "Starting $service process for $($date)"

    # Import and validate CSV
    try {
        $CSV = Import-Csv -Path $csvData
        if ($CSV.Count -eq 0) {
            throw "CSV file is empty"
        }
        
        # Validate required columns exist
        $requiredColumns = @('certName', 'SANs', 'organizationalUnit', 'organization', 'location', 'state', 'country')
        $missingColumns = $requiredColumns | Where-Object { -not ($CSV | Get-Member -Name $_) }
        
        if ($missingColumns) {
            throw "CSV file is missing required columns: $($missingColumns -join ', ')"
        }
        
        Write-Log -logName $service -message "Successfully imported CSV with $($CSV.Count) certificate requests"
    }
    catch {
        Write-Log -logName $service -message "Failed to import CSV: $($_.Exception.Message)"
        throw
    }

    # Function to create the necessary folders and files
    function New-CSR {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string] $certName,
            [Parameter(Mandatory)]
            [string] $certFolder,
            [Parameter(Mandatory)]
            [string] $csrPath,
            [Parameter(Mandatory)]
            [string] $infPath,
            [Parameter(Mandatory)]
            [string] $organizationalUnit,
            [Parameter(Mandatory)]
            [string] $organization,
            [Parameter(Mandatory)]
            [string] $location,
            [Parameter(Mandatory)]
            [string] $state,
            [Parameter(Mandatory)]
            [string] $country
        )

        try {
            # Create Cert folders for file placements
            if (-not (Test-Path -Path "$outputPath\$certFolder")) {
                New-Item -ItemType Directory -Force -Path "$outputPath\$certFolder" | Out-Null
                Write-Log -logName $service -message "Created folder: $certFolder"
            }

            # Split and clean the SANs
            $dnsSANs = $SANs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
                '_continue_ = "DNS=' + $_.Trim() + '&"' + [System.Environment]::NewLine
            }

            # Create INF variable for the INF files
            $inf = @"
[Version]
Signature= "`$Windows NT`$"

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
            $inf | Out-File -FilePath $infPath -Force -Encoding UTF8
            Write-Log -logName $service -message "Created INF file for $certName"

            # Create the CSR based off the information in the INF file
            $result = certreq.exe -new $infPath $csrPath
            if ($LASTEXITCODE -eq 0) {
                Write-Log -logName $service -message "Successfully created CSR for $certName"
            }
            else {
                throw "certreq.exe failed with exit code $LASTEXITCODE. Output: $result"
            }
        }
        catch {
            Write-Log -logName $service -message "Error processing certificate $certName : $($_.Exception.Message)"
            throw
        }
    }

    # Process each certificate request
    $total = $CSV.Count
    $current = 0

    foreach ($row in $CSV) {
        $current++
        Write-Progress -Activity "Generating CSRs" -Status "Processing $($row.certName)" -PercentComplete (($current / $total) * 100)
        
        try {
            $params = @{
                certName = $row.certName.Trim()
                certFolder = "$($row.certName.Trim())_$date"
                csrPath = "$outputPath\$($row.certName.Trim())_$date\$($row.certName.Trim()).csr"
                infPath = "$outputPath\$($row.certName.Trim())_$date\$($row.certName.Trim()).inf"
                organizationalUnit = $row.organizationalUnit.Trim()
                organization = $row.organization.Trim()
                location = $row.location.Trim()
                state = $row.state.Trim()
                country = $row.country.Trim()
            }
            
            $SANs = $row.SANs -split ',' | ForEach-Object { $_.Trim() }
            New-CSR @params
        }
        catch {
            Write-Log -logName $service -message "Failed to process $($row.certName): $($_.Exception.Message)"
            continue
        }
    }

    Write-Progress -Activity "Generating CSRs" -Completed
    Write-Log -logName $service -message "Script execution completed"
    Write-Log -LogName "CertificateManagement" -Message "CSR generated successfully at: $OutputPath" -Severity Information
}
catch {
    Write-Log -LogName "CertificateManagement" -Message "Failed to generate CSR: $_" -Severity Error
    throw
}
finally {
    Write-Log -LogName "CertificateManagement" -Message "CSR generation process completed" -Severity Information
}
