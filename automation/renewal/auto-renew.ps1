<#
.SYNOPSIS
    Automated certificate renewal and deployment
.DESCRIPTION
    Identifies expiring certificates, renews them, and deploys to configured stores.
#>

param(
    [int]$ThresholdDays = 30,
    [switch]$DryRun
)

# Configuration
$KeyfactorHost = $env:KEYFACTOR_HOST
$KeyfactorUsername = $env:KEYFACTOR_USERNAME
$KeyfactorPassword = $env:KEYFACTOR_PASSWORD | ConvertTo-SecureString -AsPlainText -Force
$KeyfactorDomain = $env:KEYFACTOR_DOMAIN

$LogFile = "C:\Logs\keyfactor-renewal-$(Get-Date -Format 'yyyyMMdd').log"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Level - $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

# Create API credential
$credential = New-Object System.Management.Automation.PSCredential(
    "$KeyfactorDomain\$KeyfactorUsername",
    $KeyfactorPassword
)

# Get expiring certificates
function Get-ExpiringCertificates {
    param([int]$Days)
    
    $expiryDate = (Get-Date).AddDays($Days).ToString("yyyy-MM-dd")
    $apiUrl = "$KeyfactorHost/KeyfactorAPI/Certificates"
    
    $params = @{
        'pq.queryString' = "NotAfter<=$expiryDate"
        'pq.pageReturned' = 1
        'pq.returnLimit' = 1000
    }
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl `
            -Method GET `
            -Credential $credential `
            -Body $params `
            -ContentType "application/json"
        
        return $response
    } catch {
        Write-Log "Failed to get expiring certificates: $_" -Level "ERROR"
        return @()
    }
}

# Renew certificate
function Invoke-CertificateRenewal {
    param([string]$CertificateId)
    
    $apiUrl = "$KeyfactorHost/KeyfactorAPI/Certificates/$CertificateId/Renew"
    
    $payload = @{
        CertificateId = $CertificateId
        UseExistingCSR = $false
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl `
            -Method POST `
            -Credential $credential `
            -Body $payload `
            -ContentType "application/json"
        
        Write-Log "Certificate $CertificateId renewed successfully"
        return $response
    } catch {
        Write-Log "Failed to renew certificate $CertificateId : $_" -Level "ERROR"
        return $null
    }
}

# Deploy certificate to stores
function Invoke-CertificateDeployment {
    param(
        [string]$CertificateId,
        [array]$Stores
    )
    
    $apiUrl = "$KeyfactorHost/KeyfactorAPI/Certificates/$CertificateId/Deploy"
    
    foreach ($store in $Stores) {
        $payload = @{
            CertificateId = $CertificateId
            StoreId = $store.Id
            Alias = $store.Alias
        } | ConvertTo-Json
        
        try {
            $null = Invoke-RestMethod -Uri $apiUrl `
                -Method POST `
                -Credential $credential `
                -Body $payload `
                -ContentType "application/json"
            
            Write-Log "Certificate deployed to store: $($store.Name)"
        } catch {
            Write-Log "Failed to deploy to store $($store.Name): $_" -Level "ERROR"
        }
    }
}

# Get certificate stores
function Get-CertificateStores {
    param([string]$CertificateId)
    
    $apiUrl = "$KeyfactorHost/KeyfactorAPI/Certificates/$CertificateId/Locations"
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl `
            -Method GET `
            -Credential $credential `
            -ContentType "application/json"
        
        return $response
    } catch {
        Write-Log "Failed to get certificate stores: $_" -Level "ERROR"
        return @()
    }
}

# Main logic
Write-Log "Starting certificate renewal process"
Write-Log "Threshold: $ThresholdDays days"

if ($DryRun) {
    Write-Log "Running in DRY RUN mode" -Level "WARN"
}

# Get expiring certificates
$certificates = Get-ExpiringCertificates -Days $ThresholdDays
Write-Log "Found $($certificates.Count) expiring certificates"

$renewed = 0
$failed = 0

foreach ($cert in $certificates) {
    $certId = $cert.Id
    $subject = $cert.IssuedDN
    $expiry = $cert.NotAfter
    
    Write-Log "Processing: $subject (Expires: $expiry)"
    
    if (-not $DryRun) {
        # Renew certificate
        $renewResult = Invoke-CertificateRenewal -CertificateId $certId
        
        if ($renewResult) {
            $renewed++
            
            # Get stores where certificate is deployed
            $stores = Get-CertificateStores -CertificateId $certId
            
            if ($stores.Count -gt 0) {
                Write-Log "Deploying to $($stores.Count) stores"
                Invoke-CertificateDeployment -CertificateId $certId -Stores $stores
            }
        } else {
            $failed++
        }
        
        # Rate limiting
        Start-Sleep -Seconds 2
    } else {
        Write-Log "Would renew: $subject" -Level "INFO"
    }
}

# Summary
Write-Log "=" * 60
Write-Log "Renewal Summary:"
Write-Log "  Certificates found: $($certificates.Count)"
Write-Log "  Successfully renewed: $renewed"
Write-Log "  Failed: $failed"
Write-Log "=" * 60

exit 0

