# Function to pull all IIS sites that having bindings and an SSL cert
function Get-RemoteIISCertInfo {
    param (
        [string]$RemoteServerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    $script = {
        Import-Module -Name WebAdministration

        Get-ChildItem -Path IIS:SSLBindings | ForEach-Object -Process {
            if ($_.Sites) {
                $thumbprint = $_.Thumbprint
                $certificate = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object -Property Thumbprint -EQ -Value $thumbprint
                
                [PSCustomObject]@{
                    Sites                   = $_.Sites.Value
                    CertificateFriendlyName = $certificate.FriendlyName
                    CertificateThumbprint   = $certificate.Thumbprint
                    CertificateDNSNameList  = $certificate.DnsNameList
                    CertificateNotAfter     = $certificate.NotAfter
                    CertificateIssuer       = $certificate.Issuer
                }
            }
        }
    }

    Invoke-Command -ComputerName $RemoteServerName -ScriptBlock $script -Credential $Credential
}

# Variables
$servers = Get-Content "C:\servers.txt"
$outputPath = "C:\Temp\Certs.csv"
$cred = Get-Credential

# Array
$allCerts = @()

# Pull the data
try {
    foreach ($server in $servers) {
        $certs = Get-RemoteIISCertInfo -RemoteServerName $server -Credential $cred
        $allCerts += $certs
    }
}
catch {
    Write-Host "Failed to pull IIS information from $Server -- $($_.ToString)"
    Continue
}

# Export all the data to a CSV
$allCerts | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "Script execution completed"