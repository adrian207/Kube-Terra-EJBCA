# Azure Function to handle Keyfactor webhooks
# Trigger: HTTP POST to /api/webhook

using namespace System.Net

param($Request, $TriggerMetadata)

# Configuration
$WebhookSecret = $env:WEBHOOK_SECRET

function Test-WebhookSignature {
    param(
        [string]$Payload,
        [string]$Signature
    )
    
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($WebhookSecret)
    $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Payload))
    $expectedSignature = [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    
    return $Signature -eq $expectedSignature
}

function Send-ToLogicApp {
    param($EventData)
    
    $logicAppUrl = $env:LOGIC_APP_URL
    if (-not $logicAppUrl) {
        Write-Warning "Logic App URL not configured"
        return
    }
    
    try {
        Invoke-RestMethod -Uri $logicAppUrl `
            -Method POST `
            -Body ($EventData | ConvertTo-Json -Depth 10) `
            -ContentType "application/json" `
            -ErrorAction Stop
        
        Write-Host "Event sent to Logic App"
    } catch {
        Write-Error "Failed to send to Logic App: $_"
    }
}

function Invoke-CertificateExpiringHandler {
    param($EventData)
    
    $cert = $EventData.certificate
    $daysUntilExpiry = $EventData.daysUntilExpiry
    
    Write-Host "Certificate expiring in $daysUntilExpiry days: $($cert.subject)"
    
    # Send to Logic App for further processing
    Send-ToLogicApp -EventData $EventData
}

function Invoke-CertificateRenewedHandler {
    param($EventData)
    
    $cert = $EventData.certificate
    
    Write-Host "Certificate renewed: $($cert.subject)"
    
    # Trigger deployment pipeline
    $devOpsUrl = $env:AZURE_DEVOPS_WEBHOOK_URL
    if ($devOpsUrl) {
        Invoke-RestMethod -Uri $devOpsUrl `
            -Method POST `
            -Body (@{
                certificateId = $cert.id
                subject = $cert.subject
                action = "deploy"
            } | ConvertTo-Json) `
            -ContentType "application/json"
    }
}

# Main handler
try {
    # Get signature from header
    $signature = $Request.Headers.'X-Keyfactor-Signature'
    if (-not $signature) {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Unauthorized
            Body = "Missing signature"
        })
        return
    }
    
    # Get payload
    $payload = $Request.Body | ConvertTo-Json -Depth 10
    
    # Verify signature
    if (-not (Test-WebhookSignature -Payload $payload -Signature $signature)) {
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::Unauthorized
            Body = "Invalid signature"
        })
        return
    }
    
    # Parse event
    $eventData = $Request.Body
    $eventType = $eventData.eventType
    
    Write-Host "Received webhook: $eventType"
    
    # Route to handler
    switch ($eventType) {
        "CertificateExpiring" { Invoke-CertificateExpiringHandler -EventData $eventData }
        "CertificateRenewed" { Invoke-CertificateRenewedHandler -EventData $eventData }
        default { Write-Warning "No handler for event type: $eventType" }
    }
    
    # Return success
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = "Webhook processed"
    })
    
} catch {
    Write-Error "Webhook processing error: $_"
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        Body = "Internal server error"
    })
}

