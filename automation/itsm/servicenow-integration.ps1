<#
.SYNOPSIS
    ServiceNow Integration for Certificate Management
.DESCRIPTION
    Creates incidents and change requests based on certificate events.
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("incident", "change", "cmdb-update")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$CertificateData
)

# Configuration
$ServiceNowInstance = $env:SERVICENOW_INSTANCE
$ServiceNowUser = $env:SERVICENOW_USER
$ServiceNowPassword = $env:SERVICENOW_PASSWORD

$LogFile = "C:\Logs\servicenow-integration-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Level - $Message" | Tee-Object -FilePath $LogFile -Append
}

function New-ServiceNowIncident {
    param(
        [string]$ShortDescription,
        [string]$Description,
        [string]$Urgency = "3",
        [string]$Impact = "3"
    )
    
    $url = "https://$ServiceNowInstance/api/now/table/incident"
    
    $body = @{
        short_description = $ShortDescription
        description = $Description
        urgency = $Urgency
        impact = $Impact
        category = "Security"
        subcategory = "Certificate Management"
        assignment_group = "PKI Team"
    } | ConvertTo-Json
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential(
            $ServiceNowUser,
            (ConvertTo-SecureString $ServiceNowPassword -AsPlainText -Force)
        )
        
        $response = Invoke-RestMethod -Uri $url `
            -Method POST `
            -Credential $credential `
            -Body $body `
            -ContentType "application/json"
        
        $incidentNumber = $response.result.number
        Write-Log "Incident created: $incidentNumber"
        return $response.result
    }
    catch {
        Write-Log "Failed to create incident: $_" -Level "ERROR"
        return $null
    }
}

function New-ServiceNowChangeRequest {
    param(
        [string]$ShortDescription,
        [string]$Description,
        [string]$Risk = "moderate",
        [string]$Priority = "3"
    )
    
    $url = "https://$ServiceNowInstance/api/now/table/change_request"
    
    $body = @{
        short_description = $ShortDescription
        description = $Description
        risk = $Risk
        priority = $Priority
        category = "Security"
        type = "Standard"
        assignment_group = "PKI Team"
    } | ConvertTo-Json
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential(
            $ServiceNowUser,
            (ConvertTo-SecureString $ServiceNowPassword -AsPlainText -Force)
        )
        
        $response = Invoke-RestMethod -Uri $url `
            -Method POST `
            -Credential $credential `
            -Body $body `
            -ContentType "application/json"
        
        $changeNumber = $response.result.number
        Write-Log "Change request created: $changeNumber"
        return $response.result
    }
    catch {
        Write-Log "Failed to create change request: $_" -Level "ERROR"
        return $null
    }
}

function Update-ServiceNowCMDB {
    param(
        [string]$CIName,
        [hashtable]$CertificateData
    )
    
    $searchUrl = "https://$ServiceNowInstance/api/now/table/cmdb_ci_server"
    $query = "name=$CIName"
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential(
            $ServiceNowUser,
            (ConvertTo-SecureString $ServiceNowPassword -AsPlainText -Force)
        )
        
        # Search for CI
        $searchResponse = Invoke-RestMethod -Uri "$searchUrl`?sysparm_query=$query" `
            -Method GET `
            -Credential $credential `
            -ContentType "application/json"
        
        if ($searchResponse.result.Count -eq 0) {
            Write-Log "CI not found: $CIName" -Level "WARN"
            return $null
        }
        
        $ciSysId = $searchResponse.result[0].sys_id
        
        # Update CI
        $updateUrl = "$searchUrl/$ciSysId"
        $updateBody = @{
            u_certificate_thumbprint = $CertificateData.thumbprint
            u_certificate_expiry = $CertificateData.expiry
            u_certificate_issuer = $CertificateData.issuer
        } | ConvertTo-Json
        
        $updateResponse = Invoke-RestMethod -Uri $updateUrl `
            -Method PATCH `
            -Credential $credential `
            -Body $updateBody `
            -ContentType "application/json"
        
        Write-Log "CMDB CI updated: $CIName"
        return $updateResponse.result
    }
    catch {
        Write-Log "Failed to update CMDB: $_" -Level "ERROR"
        return $null
    }
}

# Main logic
if (-not $ServiceNowInstance -or -not $ServiceNowUser -or -not $ServiceNowPassword) {
    Write-Log "ServiceNow credentials not configured" -Level "ERROR"
    exit 1
}

Write-Log "Starting ServiceNow integration - Action: $Action"

switch ($Action) {
    "incident" {
        $subject = $CertificateData.subject
        $daysUntilExpiry = $CertificateData.daysUntilExpiry
        
        $shortDesc = "Certificate Expiring Soon: $subject"
        $description = @"
Certificate Details:
- Subject: $subject
- Days Until Expiry: $daysUntilExpiry
- Thumbprint: $($CertificateData.thumbprint)
- Issuer: $($CertificateData.issuer)

Action Required:
Please review and renew this certificate before expiry.
"@
        
        $urgency = if ($daysUntilExpiry -lt 7) { "2" } else { "3" }
        $impact = if ($daysUntilExpiry -lt 7) { "2" } else { "3" }
        
        New-ServiceNowIncident -ShortDescription $shortDesc -Description $description `
            -Urgency $urgency -Impact $impact
    }
    
    "change" {
        $subject = $CertificateData.subject
        
        $shortDesc = "Certificate Renewal Change Request: $subject"
        $description = @"
Certificate Renewal Details:
- Subject: $subject
- Old Thumbprint: $($CertificateData.oldThumbprint)
- New Thumbprint: $($CertificateData.newThumbprint)
- New Expiry: $($CertificateData.newExpiry)

Deployment Plan:
1. Update certificate in all stores
2. Reload services
3. Verify HTTPS endpoints
4. Update CMDB
"@
        
        New-ServiceNowChangeRequest -ShortDescription $shortDesc -Description $description `
            -Risk "low" -Priority "3"
    }
    
    "cmdb-update" {
        $hostname = $CertificateData.hostname
        
        Update-ServiceNowCMDB -CIName $hostname -CertificateData $CertificateData
    }
}

Write-Log "ServiceNow integration completed"
exit 0

