<#
.SYNOPSIS
    Certificate renewal with approval workflow
.DESCRIPTION
    Identifies expiring certificates, requests approval via email/Teams, and renews upon approval.
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

$ApprovalEmail = "pki-approvers@contoso.com"
$SMTPServer = "smtp.contoso.com"
$FromEmail = "keyfactor-automation@contoso.com"

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
        'pq.queryString' = "NotAfter<=$expiryDate AND Metadata.requiresApproval=true"
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

# Request approval via email
function Request-RenewalApproval {
    param($Certificate)
    
    $subject = $Certificate.IssuedDN
    $expiry = $Certificate.NotAfter
    $certId = $Certificate.Id
    
    # Generate approval token
    $approvalToken = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$certId|$(Get-Date -Format 'yyyyMMddHHmmss')"))
    
    # Create approval URLs
    $approveUrl = "https://keyfactor-automation.contoso.com/api/approve?token=$approvalToken"
    $rejectUrl = "https://keyfactor-automation.contoso.com/api/reject?token=$approvalToken"
    
    $emailBody = @"
<html>
<body>
    <h2>Certificate Renewal Approval Required</h2>
    <table border="1" cellpadding="5">
        <tr><th>Subject</th><td>$subject</td></tr>
        <tr><th>Expiry Date</th><td>$expiry</td></tr>
        <tr><th>Certificate ID</th><td>$certId</td></tr>
    </table>
    <p>
        <a href="$approveUrl" style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none;">Approve Renewal</a>
        <a href="$rejectUrl" style="background-color: #f44336; color: white; padding: 10px 20px; text-decoration: none;">Reject</a>
    </p>
    <p><em>This is an automated message from Keyfactor Certificate Management.</em></p>
</body>
</html>
"@
    
    try {
        Send-MailMessage -SmtpServer $SMTPServer `
            -From $FromEmail `
            -To $ApprovalEmail `
            -Subject "Certificate Renewal Approval: $subject" `
            -Body $emailBody `
            -BodyAsHtml `
            -Priority High
        
        Write-Log "Approval request sent for certificate $certId"
        return $approvalToken
    } catch {
        Write-Log "Failed to send approval email: $_" -Level "ERROR"
        return $null
    }
}

# Check approval status
function Get-ApprovalStatus {
    param([string]$ApprovalToken)
    
    # Check approval database/file
    $approvalFile = "C:\ProgramData\Keyfactor\Approvals\$ApprovalToken.json"
    
    if (Test-Path $approvalFile) {
        $approval = Get-Content $approvalFile | ConvertFrom-Json
        return $approval.Status
    }
    
    return "Pending"
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

# Main logic
Write-Log "Starting certificate renewal with approval workflow"
Write-Log "Threshold: $ThresholdDays days"

if ($DryRun) {
    Write-Log "Running in DRY RUN mode" -Level "WARN"
}

# Get expiring certificates
$certificates = Get-ExpiringCertificates -Days $ThresholdDays
Write-Log "Found $($certificates.Count) certificates requiring approval"

$renewalRequests = @()

foreach ($cert in $certificates) {
    $certId = $cert.Id
    $subject = $cert.IssuedDN
    
    Write-Log "Processing: $subject (ID: $certId)"
    
    # Check if approval already exists
    $existingApproval = Get-ChildItem "C:\ProgramData\Keyfactor\Approvals" -Filter "*$certId*" -ErrorAction SilentlyContinue
    
    if ($existingApproval) {
        $status = Get-ApprovalStatus -ApprovalToken $existingApproval.BaseName
        
        if ($status -eq "Approved") {
            Write-Log "Approval found. Renewing certificate..." -Level "INFO"
            
            if (-not $DryRun) {
                $renewed = Invoke-CertificateRenewal -CertificateId $certId
                if ($renewed) {
                    # Delete approval file after successful renewal
                    Remove-Item $existingApproval.FullName
                }
            }
        } elseif ($status -eq "Rejected") {
            Write-Log "Renewal rejected for certificate $certId" -Level "WARN"
        } else {
            Write-Log "Approval pending for certificate $certId"
        }
    } else {
        # Request new approval
        Write-Log "Requesting approval for certificate $certId"
        
        if (-not $DryRun) {
            $token = Request-RenewalApproval -Certificate $cert
            if ($token) {
                $renewalRequests += @{
                    CertificateId = $certId
                    Subject = $subject
                    Token = $token
                }
            }
        }
    }
}

# Summary
Write-Log "=" * 60
Write-Log "Renewal Summary:"
Write-Log "  Certificates processed: $($certificates.Count)"
Write-Log "  Approval requests sent: $($renewalRequests.Count)"
Write-Log "=" * 60

