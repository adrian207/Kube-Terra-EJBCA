<#
.SYNOPSIS
    Certificate Expiry Monitor
.DESCRIPTION
    Monitors certificate expiry across all stores and sends alerts.
#>

param(
    [int]$WarningDays = 30,
    [int]$CriticalDays = 7,
    [int]$CheckIntervalMinutes = 60
)

# Configuration
$KeyfactorHost = $env:KEYFACTOR_HOST
$KeyfactorUsername = $env:KEYFACTOR_USERNAME
$KeyfactorPassword = $env:KEYFACTOR_PASSWORD | ConvertTo-SecureString -AsPlainText -Force
$KeyfactorDomain = $env:KEYFACTOR_DOMAIN

$AlertWebhookUrl = $env:ALERT_WEBHOOK_URL

$LogFile = "C:\Logs\keyfactor-monitor-$(Get-Date -Format 'yyyyMMdd').log"

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

function Get-AllCertificates {
    $apiUrl = "$KeyfactorHost/KeyfactorAPI/Certificates"
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl `
            -Method GET `
            -Credential $credential `
            -ContentType "application/json"
        
        return $response
    }
    catch {
        Write-Log "Failed to get certificates: $_" -Level "ERROR"
        return @()
    }
}

function Test-CertificateExpiry {
    param($Certificate)
    
    $expiry = [datetime]$Certificate.NotAfter
    $now = Get-Date
    $daysUntilExpiry = ($expiry - $now).Days
    
    $subject = $Certificate.IssuedDN
    
    if ($daysUntilExpiry -lt 0) {
        Write-Log "🔴 EXPIRED: $subject (Expired $(-$daysUntilExpiry) days ago)" -Level "ERROR"
        return @{ Status = "EXPIRED"; Days = $daysUntilExpiry }
    }
    elseif ($daysUntilExpiry -le $CriticalDays) {
        Write-Log "🔴 CRITICAL: $subject (Expires in $daysUntilExpiry days)" -Level "ERROR"
        return @{ Status = "CRITICAL"; Days = $daysUntilExpiry }
    }
    elseif ($daysUntilExpiry -le $WarningDays) {
        Write-Log "🟡 WARNING: $subject (Expires in $daysUntilExpiry days)" -Level "WARN"
        return @{ Status = "WARNING"; Days = $daysUntilExpiry }
    }
    
    return @{ Status = "OK"; Days = $daysUntilExpiry }
}

function Send-Alert {
    param(
        $Certificate,
        [string]$Severity,
        [int]$DaysUntilExpiry
    )
    
    if (-not $AlertWebhookUrl) {
        return
    }
    
    $payload = @{
        severity = $Severity
        subject = $Certificate.IssuedDN
        thumbprint = $Certificate.Thumbprint
        daysUntilExpiry = $DaysUntilExpiry
        expiryDate = $Certificate.NotAfter
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri $AlertWebhookUrl `
            -Method POST `
            -Body $payload `
            -ContentType "application/json" `
            -TimeoutSec 10
    }
    catch {
        Write-Log "Failed to send alert: $_" -Level "ERROR"
    }
}

# Main monitoring loop
Write-Log "Starting Certificate Expiry Monitor"
Write-Log "Warning threshold: $WarningDays days"
Write-Log "Critical threshold: $CriticalDays days"
Write-Log "Check interval: $CheckIntervalMinutes minutes"

while ($true) {
    Write-Log "Starting certificate expiry check..."
    
    $certificates = Get-AllCertificates
    Write-Log "Retrieved $($certificates.Count) certificates"
    
    if ($certificates.Count -eq 0) {
        Write-Log "No certificates retrieved, sleeping..." -Level "WARN"
        Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
        continue
    }
    
    # Counters
    $counters = @{
        EXPIRED = 0
        CRITICAL = 0
        WARNING = 0
        OK = 0
    }
    
    # Check certificates
    foreach ($cert in $certificates) {
        $result = Test-CertificateExpiry -Certificate $cert
        $counters[$result.Status]++
        
        # Send alert for expired, critical, or warning
        if ($result.Status -in @('EXPIRED', 'CRITICAL', 'WARNING')) {
            Send-Alert -Certificate $cert -Severity $result.Status -DaysUntilExpiry $result.Days
        }
    }
    
    # Summary
    Write-Log ("=" * 60)
    Write-Log "Expiry Check Summary:"
    Write-Log "  Total: $($certificates.Count)"
    Write-Log "  OK: $($counters.OK)"
    Write-Log "  Warning: $($counters.WARNING)"
    Write-Log "  Critical: $($counters.CRITICAL)"
    Write-Log "  Expired: $($counters.EXPIRED)"
    Write-Log ("=" * 60)
    
    # Sleep until next check
    Write-Log "Sleeping for $CheckIntervalMinutes minutes..."
    Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
}

