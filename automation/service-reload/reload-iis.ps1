<#
.SYNOPSIS
    Reload IIS bindings after certificate deployment
.DESCRIPTION
    Monitors for certificate deployment events and updates IIS bindings
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$true)]
    [string]$SiteName,
    
    [Parameter(Mandatory=$true)]
    [string]$CertificateThumbprint
)

$LogFile = "C:\Logs\iis-reload-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "Starting IIS binding update for $ServerName\$SiteName"
Write-Log "New certificate thumbprint: $CertificateThumbprint"

# Import WebAdministration module
Import-Module WebAdministration -ErrorAction Stop

try {
    # Get certificate from store
    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    
    if (-not $cert) {
        Write-Log "ERROR: Certificate with thumbprint $CertificateThumbprint not found in LocalMachine\My"
        exit 1
    }
    
    Write-Log "Certificate found: $($cert.Subject)"
    
    # Get existing HTTPS binding
    $binding = Get-WebBinding -Name $SiteName -Protocol https
    
    if ($binding) {
        Write-Log "Existing HTTPS binding found"
        
        # Update certificate
        $binding.AddSslCertificate($CertificateThumbprint, "My")
        
        Write-Log "Certificate binding updated successfully"
    } else {
        Write-Log "No existing HTTPS binding found. Creating new binding..."
        
        # Create new HTTPS binding
        New-WebBinding -Name $SiteName -Protocol https -Port 443 -IPAddress "*"
        
        $newBinding = Get-WebBinding -Name $SiteName -Protocol https
        $newBinding.AddSslCertificate($CertificateThumbprint, "My")
        
        Write-Log "New HTTPS binding created with certificate"
    }
    
    # Restart IIS site (optional, usually not needed)
    # Restart-WebAppPool -Name $SiteName
    
    # Verify binding
    $certInBinding = Get-ChildItem "IIS:\SslBindings\*" | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
    
    if ($certInBinding) {
        Write-Log "SUCCESS: Certificate binding verified"
        
        # Test HTTPS endpoint
        $testUrl = "https://localhost"
        try {
            $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
            Write-Log "HTTPS endpoint test successful (Status: $($response.StatusCode))"
        } catch {
            Write-Log "WARNING: HTTPS endpoint test failed: $_"
        }
    } else {
        Write-Log "ERROR: Certificate binding verification failed"
        exit 1
    }
    
    Write-Log "IIS binding update completed successfully"
    exit 0
    
} catch {
    Write-Log "ERROR: $_"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

