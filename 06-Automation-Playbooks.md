# Keyfactor Automation Playbooks
## Ready-to-Use Scripts for Certificate Lifecycle Automation

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

> **📁 ALL SCRIPTS EXTRACTED TO INDIVIDUAL FILES**  
> 
> This document provides comprehensive documentation for certificate lifecycle automation.  
> **All scripts have been extracted to standalone files for immediate deployment.**  
> 
> **📂 Location**: `automation/` directory  
> **📖 Quick Start**: See [automation/README.md](./automation/README.md)
> 
> **Available Scripts**:
> - **Webhooks**: Python, Go, PowerShell (3 scripts)
> - **Renewal**: Python, PowerShell, Go (4 scripts)
> - **Service Reload**: PowerShell, Bash (2 scripts)
> - **Deployment**: Azure DevOps YAML (1 pipeline)
> - **ITSM**: Python, PowerShell (2 scripts)
> - **Monitoring**: Go, Python, PowerShell (3 scripts)
> - **Backup**: PowerShell (1 script)
> - **Reporting**: Python, PowerShell, Go (3 scripts)
> 
> **Total**: 19 production-ready scripts across 8 categories

---

## Document Purpose

This document serves as the **comprehensive reference guide** for certificate lifecycle automation. Each section provides:

- **Architecture and design patterns** for automation workflows
- **Implementation guidance** with code examples
- **Multi-language support** (Python, PowerShell, Go, Bash)
- **Configuration best practices**
- **Security considerations**
- **Troubleshooting guides**

**For immediate deployment**, all scripts are available as standalone files in the `automation/` directory. See [automation/README.md](./automation/README.md) for quick start instructions.

---

## Table of Contents

1. [Webhook Handlers](#1-webhook-handlers)
2. [Certificate Renewal Automation](#2-certificate-renewal-automation)
3. [Service Reload Automation](#3-service-reload-automation)
4. [Certificate Deployment Pipelines](#4-certificate-deployment-pipelines)
5. [ITSM Integration](#5-itsm-integration)
6. [Monitoring & Alerting](#6-monitoring--alerting)
7. [Backup & Recovery](#7-backup--recovery)
8. [Reporting & Analytics](#8-reporting--analytics)

---

## 1. Webhook Handlers

### Overview

Webhook handlers receive events from Keyfactor Command when certificate operations occur (enrollment, renewal, revocation, expiry warnings).

---

### 1.1: Generic Webhook Receiver (Python/Flask)

**Purpose**: Receive and process Keyfactor webhooks, route to appropriate handlers.

**File**: `webhook-receiver.py`

```python
#!/usr/bin/env python3
"""
Keyfactor Webhook Receiver
Receives webhook events from Keyfactor Command and routes to appropriate handlers.
"""

from flask import Flask, request, jsonify
import hmac
import hashlib
import json
import logging
from datetime import datetime
import os
import requests

app = Flask(__name__)

# Configuration
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'your-secret-key')
LOG_FILE = '/var/log/keyfactor-webhooks.log'

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def verify_signature(payload, signature):
    """Verify webhook signature to ensure authenticity."""
    expected_signature = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected_signature)

def send_to_servicenow(event_data):
    """Create incident in ServiceNow for certificate events."""
    snow_url = os.environ.get('SERVICENOW_URL')
    snow_user = os.environ.get('SERVICENOW_USER')
    snow_password = os.environ.get('SERVICENOW_PASSWORD')
    
    if not all([snow_url, snow_user, snow_password]):
        logger.warning("ServiceNow credentials not configured")
        return
    
    incident_data = {
        'short_description': f"Certificate Event: {event_data['eventType']}",
        'description': json.dumps(event_data, indent=2),
        'category': 'Security',
        'subcategory': 'Certificate Management',
        'urgency': '3',
        'impact': '3'
    }
    
    try:
        response = requests.post(
            f"{snow_url}/api/now/table/incident",
            auth=(snow_user, snow_password),
            headers={'Content-Type': 'application/json'},
            json=incident_data,
            timeout=10
        )
        response.raise_for_status()
        logger.info(f"ServiceNow incident created: {response.json()['result']['number']}")
    except Exception as e:
        logger.error(f"Failed to create ServiceNow incident: {e}")

def send_to_slack(event_data):
    """Send notification to Slack."""
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    
    if not slack_webhook_url:
        logger.warning("Slack webhook URL not configured")
        return
    
    event_type = event_data.get('eventType', 'Unknown')
    cert_subject = event_data.get('certificate', {}).get('subject', 'Unknown')
    
    # Color coding based on event type
    color_map = {
        'CertificateExpiring': 'warning',
        'CertificateExpired': 'danger',
        'CertificateRenewed': 'good',
        'CertificateRevoked': 'danger',
        'CertificateIssued': 'good'
    }
    
    slack_message = {
        'attachments': [{
            'color': color_map.get(event_type, 'good'),
            'title': f"Certificate Event: {event_type}",
            'fields': [
                {'title': 'Subject', 'value': cert_subject, 'short': True},
                {'title': 'Event', 'value': event_type, 'short': True},
                {'title': 'Time', 'value': datetime.utcnow().isoformat(), 'short': True}
            ],
            'footer': 'Keyfactor Certificate Management'
        }]
    }
    
    try:
        response = requests.post(
            slack_webhook_url,
            json=slack_message,
            timeout=10
        )
        response.raise_for_status()
        logger.info("Slack notification sent")
    except Exception as e:
        logger.error(f"Failed to send Slack notification: {e}")

def handle_certificate_expiring(event_data):
    """Handle certificate expiring event."""
    cert = event_data.get('certificate', {})
    days_until_expiry = event_data.get('daysUntilExpiry', 0)
    
    logger.info(f"Certificate expiring in {days_until_expiry} days: {cert.get('subject')}")
    
    # Send notifications
    send_to_slack(event_data)
    
    # If < 7 days, create incident
    if days_until_expiry < 7:
        send_to_servicenow(event_data)

def handle_certificate_expired(event_data):
    """Handle certificate expired event."""
    cert = event_data.get('certificate', {})
    
    logger.error(f"Certificate EXPIRED: {cert.get('subject')}")
    
    # Critical notification
    send_to_slack(event_data)
    send_to_servicenow(event_data)

def handle_certificate_renewed(event_data):
    """Handle certificate renewed event."""
    cert = event_data.get('certificate', {})
    
    logger.info(f"Certificate renewed: {cert.get('subject')}")
    send_to_slack(event_data)

def handle_certificate_revoked(event_data):
    """Handle certificate revoked event."""
    cert = event_data.get('certificate', {})
    reason = event_data.get('revocationReason', 'Unknown')
    
    logger.warning(f"Certificate revoked: {cert.get('subject')} - Reason: {reason}")
    
    send_to_slack(event_data)
    send_to_servicenow(event_data)

def handle_certificate_issued(event_data):
    """Handle certificate issued event."""
    cert = event_data.get('certificate', {})
    
    logger.info(f"Certificate issued: {cert.get('subject')}")

# Event handler mapping
EVENT_HANDLERS = {
    'CertificateExpiring': handle_certificate_expiring,
    'CertificateExpired': handle_certificate_expired,
    'CertificateRenewed': handle_certificate_renewed,
    'CertificateRevoked': handle_certificate_revoked,
    'CertificateIssued': handle_certificate_issued
}

@app.route('/webhook', methods=['POST'])
def webhook():
    """Main webhook endpoint."""
    try:
        # Get signature from header
        signature = request.headers.get('X-Keyfactor-Signature')
        if not signature:
            logger.warning("Missing signature header")
            return jsonify({'error': 'Missing signature'}), 401
        
        # Get payload
        payload = request.get_data(as_text=True)
        
        # Verify signature
        if not verify_signature(payload, signature):
            logger.warning("Invalid signature")
            return jsonify({'error': 'Invalid signature'}), 401
        
        # Parse event data
        event_data = json.loads(payload)
        event_type = event_data.get('eventType')
        
        logger.info(f"Received webhook: {event_type}")
        
        # Route to appropriate handler
        handler = EVENT_HANDLERS.get(event_type)
        if handler:
            handler(event_data)
        else:
            logger.warning(f"No handler for event type: {event_type}")
        
        return jsonify({'status': 'success'}), 200
    
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON: {e}")
        return jsonify({'error': 'Invalid JSON'}), 400
    
    except Exception as e:
        logger.error(f"Webhook processing error: {e}", exc_info=True)
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}), 200

if __name__ == '__main__':
    # Run on port 5000, bind to all interfaces
    app.run(host='0.0.0.0', port=5000, debug=False)
```

**Deployment**:

```bash
# 1. Install dependencies
pip install flask requests

# 2. Create systemd service
cat > /etc/systemd/system/keyfactor-webhook.service <<EOF
[Unit]
Description=Keyfactor Webhook Receiver
After=network.target

[Service]
Type=simple
User=keyfactor
WorkingDirectory=/opt/keyfactor-webhooks
Environment="WEBHOOK_SECRET=your-secret-key"
Environment="SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
Environment="SERVICENOW_URL=https://your-instance.service-now.com"
Environment="SERVICENOW_USER=webhook-user"
Environment="SERVICENOW_PASSWORD=password"
ExecStart=/usr/bin/python3 /opt/keyfactor-webhooks/webhook-receiver.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 3. Start service
systemctl daemon-reload
systemctl enable keyfactor-webhook
systemctl start keyfactor-webhook

# 4. Configure Keyfactor Command webhook
# In Keyfactor UI:
# Settings → Webhooks → Add Webhook
# URL: http://webhook-server.contoso.com:5000/webhook
# Events: CertificateExpiring, CertificateExpired, CertificateRenewed, etc.
# Secret: your-secret-key

# 5. Test webhook
curl -X POST http://localhost:5000/webhook \
  -H "Content-Type: application/json" \
  -H "X-Keyfactor-Signature: $(echo -n '{"eventType":"CertificateIssued"}' | openssl dgst -sha256 -hmac 'your-secret-key' -hex | cut -d' ' -f2)" \
  -d '{"eventType":"CertificateIssued","certificate":{"subject":"CN=test.contoso.com"}}'
```

---

### 1.2: Webhook Handler (PowerShell/Azure Functions)

**Purpose**: Azure Function to handle Keyfactor webhooks in Azure environment.

**File**: `run.ps1`

```powershell
# Azure Function to handle Keyfactor webhooks
# Trigger: HTTP POST to /api/webhook

using namespace System.Net

param($Request, $TriggerMetadata)

# Configuration
$WebhookSecret = $env:WEBHOOK_SECRET

function Verify-Signature {
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

function Handle-CertificateExpiring {
    param($EventData)
    
    $cert = $EventData.certificate
    $daysUntilExpiry = $EventData.daysUntilExpiry
    
    Write-Host "Certificate expiring in $daysUntilExpiry days: $($cert.subject)"
    
    # Send to Logic App for further processing
    Send-ToLogicApp -EventData $EventData
}

function Handle-CertificateRenewed {
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
    if (-not (Verify-Signature -Payload $payload -Signature $signature)) {
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
        "CertificateExpiring" { Handle-CertificateExpiring -EventData $eventData }
        "CertificateRenewed" { Handle-CertificateRenewed -EventData $eventData }
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
```

**Deployment**:

```powershell
# 1. Create Azure Function App
az functionapp create `
  --resource-group rg-keyfactor-prod `
  --consumption-plan-location eastus `
  --runtime powershell `
  --runtime-version 7.2 `
  --functions-version 4 `
  --name func-keyfactor-webhooks `
  --storage-account stkeyfactorfunc

# 2. Set environment variables
az functionapp config appsettings set `
  --name func-keyfactor-webhooks `
  --resource-group rg-keyfactor-prod `
  --settings `
    WEBHOOK_SECRET="your-secret-key" `
    LOGIC_APP_URL="https://logic-app-url" `
    AZURE_DEVOPS_WEBHOOK_URL="https://dev.azure.com/..."

# 3. Deploy function
func azure functionapp publish func-keyfactor-webhooks

# 4. Get function URL
az functionapp function show `
  --name func-keyfactor-webhooks `
  --resource-group rg-keyfactor-prod `
  --function-name webhook `
  --query invokeUrlTemplate

# 5. Configure in Keyfactor
# URL: https://func-keyfactor-webhooks.azurewebsites.net/api/webhook
```

---

## 2. Certificate Renewal Automation

### 2.1: Automated Renewal Script (Python)

**Purpose**: Automatically renew certificates nearing expiry.

**File**: `auto-renew.py`

```python
#!/usr/bin/env python3
"""
Certificate Auto-Renewal Script
Queries Keyfactor for expiring certificates and automatically renews them.
"""

import requests
import logging
from datetime import datetime, timedelta
import os
import sys
import time
import json

# Configuration
KEYFACTOR_HOST = os.environ.get('KEYFACTOR_HOST', 'https://keyfactor.contoso.com')
KEYFACTOR_USERNAME = os.environ.get('KEYFACTOR_USERNAME')
KEYFACTOR_PASSWORD = os.environ.get('KEYFACTOR_PASSWORD')
KEYFACTOR_DOMAIN = os.environ.get('KEYFACTOR_DOMAIN', 'CONTOSO')

RENEWAL_THRESHOLD_DAYS = int(os.environ.get('RENEWAL_THRESHOLD_DAYS', '30'))
DRY_RUN = os.environ.get('DRY_RUN', 'false').lower() == 'true'

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/keyfactor-renewal.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class KeyfactorClient:
    def __init__(self, hostname, username, password, domain):
        self.hostname = hostname
        self.base_url = f"{hostname}/KeyfactorAPI"
        self.session = requests.Session()
        self.session.auth = (f"{domain}\\{username}", password)
        self.session.headers.update({
            'Content-Type': 'application/json',
            'X-Keyfactor-Requested-With': 'APIClient'
        })
    
    def get_expiring_certificates(self, days):
        """Get certificates expiring within specified days."""
        expiry_date = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
        
        params = {
            'pq.queryString': f'NotAfter<={expiry_date} AND Metadata.automated=true',
            'pq.pageReturned': 1,
            'pq.returnLimit': 1000
        }
        
        try:
            response = self.session.get(
                f"{self.base_url}/Certificates",
                params=params,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get expiring certificates: {e}")
            return []
    
    def renew_certificate(self, cert_id):
        """Renew a certificate."""
        payload = {
            'CertificateId': cert_id,
            'UseExistingCSR': False
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/Certificates/{cert_id}/Renew",
                json=payload,
                timeout=60
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to renew certificate {cert_id}: {e}")
            return None
    
    def get_certificate_locations(self, cert_id):
        """Get all locations where certificate is deployed."""
        try:
            response = self.session.get(
                f"{self.base_url}/Certificates/{cert_id}/Locations",
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get certificate locations: {e}")
            return []
    
    def deploy_certificate(self, cert_id, store_id, alias):
        """Deploy certificate to a store."""
        payload = {
            'CertificateId': cert_id,
            'StoreId': store_id,
            'Alias': alias,
            'Overwrite': True
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/Certificates/{cert_id}/Deploy",
                json=payload,
                timeout=60
            )
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to deploy certificate to store {store_id}: {e}")
            return False

def renew_and_deploy(client, cert):
    """Renew certificate and deploy to all existing locations."""
    cert_id = cert['Id']
    subject = cert['IssuedDN']
    expiry = cert['NotAfter']
    
    logger.info(f"Processing certificate: {subject} (Expires: {expiry})")
    
    if DRY_RUN:
        logger.info(f"[DRY RUN] Would renew certificate {cert_id}")
        return True
    
    # Get existing locations before renewal
    locations = client.get_certificate_locations(cert_id)
    logger.info(f"Certificate deployed to {len(locations)} locations")
    
    # Renew certificate
    logger.info(f"Renewing certificate {cert_id}...")
    renewed_cert = client.renew_certificate(cert_id)
    
    if not renewed_cert:
        logger.error(f"Failed to renew certificate {cert_id}")
        return False
    
    new_cert_id = renewed_cert.get('CertificateId')
    logger.info(f"Certificate renewed successfully. New ID: {new_cert_id}")
    
    # Deploy to all previous locations
    success_count = 0
    for location in locations:
        store_id = location['StoreId']
        alias = location['Alias']
        
        logger.info(f"Deploying to store {store_id} with alias {alias}...")
        if client.deploy_certificate(new_cert_id, store_id, alias):
            success_count += 1
            logger.info(f"Successfully deployed to store {store_id}")
        else:
            logger.error(f"Failed to deploy to store {store_id}")
        
        # Rate limiting
        time.sleep(1)
    
    logger.info(f"Deployment complete: {success_count}/{len(locations)} successful")
    return success_count == len(locations)

def main():
    """Main renewal logic."""
    if not all([KEYFACTOR_USERNAME, KEYFACTOR_PASSWORD]):
        logger.error("Missing Keyfactor credentials")
        sys.exit(1)
    
    logger.info(f"Starting certificate renewal process (Threshold: {RENEWAL_THRESHOLD_DAYS} days)")
    if DRY_RUN:
        logger.info("Running in DRY RUN mode - no changes will be made")
    
    # Initialize client
    client = KeyfactorClient(
        hostname=KEYFACTOR_HOST,
        username=KEYFACTOR_USERNAME,
        password=KEYFACTOR_PASSWORD,
        domain=KEYFACTOR_DOMAIN
    )
    
    # Get expiring certificates
    certificates = client.get_expiring_certificates(RENEWAL_THRESHOLD_DAYS)
    logger.info(f"Found {len(certificates)} certificates expiring in {RENEWAL_THRESHOLD_DAYS} days")
    
    if not certificates:
        logger.info("No certificates require renewal")
        return 0
    
    # Renew each certificate
    success_count = 0
    failed_count = 0
    
    for cert in certificates:
        try:
            if renew_and_deploy(client, cert):
                success_count += 1
            else:
                failed_count += 1
        except Exception as e:
            logger.error(f"Unexpected error processing certificate: {e}", exc_info=True)
            failed_count += 1
        
        # Rate limiting between certificates
        time.sleep(2)
    
    # Summary
    logger.info("=" * 60)
    logger.info(f"Renewal Summary:")
    logger.info(f"  Total certificates: {len(certificates)}")
    logger.info(f"  Successful: {success_count}")
    logger.info(f"  Failed: {failed_count}")
    logger.info("=" * 60)
    
    return 0 if failed_count == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
```

**Deployment**:

```bash
# 1. Install dependencies
pip install requests

# 2. Create cron job for daily execution
crontab -e

# Add line (runs daily at 2 AM):
0 2 * * * /usr/bin/python3 /opt/keyfactor-scripts/auto-renew.py

# 3. Set environment variables
cat > /etc/default/keyfactor-renewal <<EOF
KEYFACTOR_HOST=https://keyfactor.contoso.com
KEYFACTOR_USERNAME=renewal-automation
KEYFACTOR_PASSWORD=SecurePassword123!
KEYFACTOR_DOMAIN=CONTOSO
RENEWAL_THRESHOLD_DAYS=30
DRY_RUN=false
EOF

# 4. Test in dry-run mode
DRY_RUN=true python3 /opt/keyfactor-scripts/auto-renew.py

# 5. Run actual renewal
python3 /opt/keyfactor-scripts/auto-renew.py
```

---

### 2.2: Renewal with Approval Workflow (PowerShell)

**Purpose**: Request approval before renewing critical certificates.

**File**: `renew-with-approval.ps1`

```powershell
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
function Renew-Certificate {
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
                $renewed = Renew-Certificate -CertificateId $certId
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
```

---

## 3. Service Reload Automation

### 3.1: IIS Service Reload (PowerShell)

**Purpose**: Automatically reload IIS bindings after certificate deployment.

**File**: `reload-iis.ps1`

```powershell
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
    $updatedBinding = Get-WebBinding -Name $SiteName -Protocol https
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
```

**Usage**:

```powershell
# Call from Keyfactor orchestrator post-deployment script
.\reload-iis.ps1 -ServerName "webapp01" -SiteName "Default Web Site" -CertificateThumbprint "ABCD1234..."

# Or configure as scheduled task triggered by Keyfactor webhook
```

---

### 3.2: NGINX Service Reload (Bash)

**Purpose**: Reload NGINX configuration after certificate deployment.

**File**: `reload-nginx.sh`

```bash
#!/bin/bash
#
# Reload NGINX after certificate deployment
# Usage: reload-nginx.sh <cert-path> <key-path> <nginx-config>
#

set -e

# Configuration
CERT_PATH="$1"
KEY_PATH="$2"
NGINX_CONFIG="${3:-/etc/nginx/nginx.conf}"
LOG_FILE="/var/log/keyfactor-nginx-reload.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Validate inputs
if [ -z "$CERT_PATH" ] || [ -z "$KEY_PATH" ]; then
    log "ERROR: Certificate path and key path are required"
    echo "Usage: $0 <cert-path> <key-path> [nginx-config]"
    exit 1
fi

log "Starting NGINX certificate update"
log "Certificate: $CERT_PATH"
log "Key: $KEY_PATH"
log "Config: $NGINX_CONFIG"

# Verify certificate and key exist
if [ ! -f "$CERT_PATH" ]; then
    log "ERROR: Certificate file not found: $CERT_PATH"
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    log "ERROR: Key file not found: $KEY_PATH"
    exit 1
fi

# Verify certificate and key match
log "Verifying certificate and key match..."
CERT_MODULUS=$(openssl x509 -noout -modulus -in "$CERT_PATH" | openssl md5)
KEY_MODULUS=$(openssl rsa -noout -modulus -in "$KEY_PATH" | openssl md5)

if [ "$CERT_MODULUS" != "$KEY_MODULUS" ]; then
    log "ERROR: Certificate and key do not match"
    log "  Certificate modulus: $CERT_MODULUS"
    log "  Key modulus: $KEY_MODULUS"
    exit 1
fi

log "Certificate and key match successfully"

# Backup existing configuration
BACKUP_DIR="/etc/nginx/backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/nginx-$(date +%Y%m%d-%H%M%S).tar.gz"

log "Creating backup: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C /etc/nginx .

# Test NGINX configuration
log "Testing NGINX configuration..."
nginx -t -c "$NGINX_CONFIG"

if [ $? -ne 0 ]; then
    log "ERROR: NGINX configuration test failed"
    exit 1
fi

log "NGINX configuration test passed"

# Reload NGINX
log "Reloading NGINX..."
systemctl reload nginx

if [ $? -ne 0 ]; then
    log "ERROR: NGINX reload failed"
    log "Attempting to restore from backup..."
    
    # Restore backup
    tar -xzf "$BACKUP_FILE" -C /etc/nginx
    systemctl reload nginx
    
    log "Configuration restored from backup"
    exit 1
fi

log "NGINX reloaded successfully"

# Verify NGINX is running
sleep 2
if systemctl is-active --quiet nginx; then
    log "NGINX is running"
else
    log "ERROR: NGINX is not running after reload"
    exit 1
fi

# Test HTTPS endpoint
log "Testing HTTPS endpoint..."
HTTPS_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost)

if [ "$HTTPS_TEST" == "200" ] || [ "$HTTPS_TEST" == "301" ] || [ "$HTTPS_TEST" == "302" ]; then
    log "HTTPS endpoint test successful (Status: $HTTPS_TEST)"
else
    log "WARNING: HTTPS endpoint test returned status: $HTTPS_TEST"
fi

# Verify certificate expiry
CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
log "New certificate expires: $CERT_EXPIRY"

log "NGINX certificate update completed successfully"
exit 0
```

**Deployment**:

```bash
# 1. Make executable
chmod +x /opt/keyfactor-scripts/reload-nginx.sh

# 2. Configure in Keyfactor orchestrator
# Remote File Orchestrator → Post-Deployment Script
# /opt/keyfactor-scripts/reload-nginx.sh \
#   /etc/nginx/ssl/server.crt \
#   /etc/nginx/ssl/server.key \
#   /etc/nginx/nginx.conf

# 3. Test manually
/opt/keyfactor-scripts/reload-nginx.sh \
  /tmp/test-cert.pem \
  /tmp/test-key.pem

# 4. View logs
tail -f /var/log/keyfactor-nginx-reload.log
```

---

## 4. Certificate Deployment Pipelines

### 4.1: Azure DevOps Pipeline (YAML)

**Purpose**: CI/CD pipeline to deploy certificates across environments.

**File**: `azure-pipelines-cert-deploy.yml`

```yaml
# Azure DevOps Pipeline for Certificate Deployment
# Triggered by Keyfactor webhook when certificate is renewed

trigger: none  # Manual or webhook-triggered only

pr: none

parameters:
  - name: certificateId
    displayName: 'Certificate ID'
    type: string
  - name: environment
    displayName: 'Target Environment'
    type: string
    default: 'development'
    values:
      - development
      - staging
      - production
  - name: approvalRequired
    displayName: 'Require Approval'
    type: boolean
    default: true

variables:
  - group: keyfactor-credentials-${{ parameters.environment }}
  - name: certificateId
    value: ${{ parameters.certificateId }}

stages:
  - stage: FetchCertificate
    displayName: 'Fetch Certificate from Keyfactor'
    jobs:
      - job: Fetch
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: PowerShell@2
            displayName: 'Download Certificate'
            inputs:
              targetType: 'inline'
              script: |
                $keyfactorHost = "$(KeyfactorHost)"
                $apiUrl = "$keyfactorHost/KeyfactorAPI/Certificates/$(certificateId)/Download"
                
                $credential = New-Object System.Management.Automation.PSCredential(
                    "$(KeyfactorUsername)",
                    (ConvertTo-SecureString "$(KeyfactorPassword)" -AsPlainText -Force)
                )
                
                # Download certificate in PFX format
                $response = Invoke-RestMethod -Uri $apiUrl `
                    -Method POST `
                    -Credential $credential `
                    -Body '{"IncludeChain":true,"Password":"$(CertPassword)"}' `
                    -ContentType "application/json"
                
                # Save to file
                [System.IO.File]::WriteAllBytes(
                    "$(Build.ArtifactStagingDirectory)/certificate.pfx",
                    [System.Convert]::FromBase64String($response.CertificateData)
                )
                
                Write-Host "Certificate downloaded successfully"
          
          - task: PublishPipelineArtifact@1
            displayName: 'Publish Certificate Artifact'
            inputs:
              targetPath: '$(Build.ArtifactStagingDirectory)'
              artifactName: 'certificate'

  - stage: DeployToAzure
    displayName: 'Deploy to Azure Resources'
    dependsOn: FetchCertificate
    condition: succeeded()
    jobs:
      - deployment: DeployKeyVault
        displayName: 'Deploy to Azure Key Vault'
        pool:
          vmImage: 'ubuntu-latest'
        environment: ${{ parameters.environment }}
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: certificate
                
                - task: AzureCLI@2
                  displayName: 'Import to Key Vault'
                  inputs:
                    azureSubscription: 'Azure-${{ parameters.environment }}'
                    scriptType: 'bash'
                    scriptLocation: 'inlineScript'
                    inlineScript: |
                      # Import certificate to Key Vault
                      az keyvault certificate import \
                        --vault-name $(KeyVaultName) \
                        --name $(CertificateName) \
                        --file $(Pipeline.Workspace)/certificate/certificate.pfx \
                        --password $(CertPassword)
                      
                      echo "Certificate imported to Key Vault successfully"
      
      - deployment: DeployAppService
        displayName: 'Deploy to App Service'
        dependsOn: DeployKeyVault
        pool:
          vmImage: 'ubuntu-latest'
        environment: ${{ parameters.environment }}
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  displayName: 'Bind Certificate to App Service'
                  inputs:
                    azureSubscription: 'Azure-${{ parameters.environment }}'
                    scriptType: 'bash'
                    scriptLocation: 'inlineScript'
                    inlineScript: |
                      # Get certificate thumbprint from Key Vault
                      THUMBPRINT=$(az keyvault certificate show \
                        --vault-name $(KeyVaultName) \
                        --name $(CertificateName) \
                        --query 'x509ThumbprintHex' \
                        --output tsv)
                      
                      # Bind to App Service
                      az webapp config ssl bind \
                        --resource-group $(ResourceGroup) \
                        --name $(AppServiceName) \
                        --certificate-thumbprint $THUMBPRINT \
                        --ssl-type SNI
                      
                      echo "Certificate bound to App Service successfully"

  - stage: Verification
    displayName: 'Verify Deployment'
    dependsOn: DeployToAzure
    condition: succeeded()
    jobs:
      - job: Verify
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: PowerShell@2
            displayName: 'Verify HTTPS Endpoint'
            inputs:
              targetType: 'inline'
              script: |
                $appUrl = "https://$(AppServiceName).azurewebsites.net"
                
                Write-Host "Testing $appUrl..."
                
                try {
                    $response = Invoke-WebRequest -Uri $appUrl -UseBasicParsing -TimeoutSec 30
                    Write-Host "✓ HTTPS endpoint accessible (Status: $($response.StatusCode))"
                    
                    # Verify certificate
                    $request = [System.Net.HttpWebRequest]::Create($appUrl)
                    $request.GetResponse() | Out-Null
                    $cert = $request.ServicePoint.Certificate
                    
                    Write-Host "✓ Certificate Subject: $($cert.Subject)"
                    Write-Host "✓ Certificate Expiry: $($cert.GetExpirationDateString())"
                    
                } catch {
                    Write-Error "HTTPS endpoint test failed: $_"
                    exit 1
                }
          
          - task: PowerShell@2
            displayName: 'Send Notification'
            inputs:
              targetType: 'inline'
              script: |
                # Send Teams notification
                $teamsWebhook = "$(TeamsWebhookUrl)"
                
                $message = @{
                    "@type" = "MessageCard"
                    "@context" = "https://schema.org/extensions"
                    "summary" = "Certificate Deployed"
                    "themeColor" = "0078D7"
                    "title" = "Certificate Deployment Successful"
                    "sections" = @(
                        @{
                            "facts" = @(
                                @{ "name" = "Environment"; "value" = "${{ parameters.environment }}" },
                                @{ "name" = "Certificate ID"; "value" = "$(certificateId)" },
                                @{ "name" = "App Service"; "value" = "$(AppServiceName)" },
                                @{ "name" = "Pipeline"; "value" = "$(Build.DefinitionName)" }
                            )
                        }
                    )
                } | ConvertTo-Json -Depth 10
                
                Invoke-RestMethod -Uri $teamsWebhook `
                    -Method POST `
                    -Body $message `
                    -ContentType "application/json"
```

**Setup**:

```bash
# 1. Create variable groups in Azure DevOps
# keyfactor-credentials-development:
#   KeyfactorHost: https://keyfactor-dev.contoso.com
#   KeyfactorUsername: pipeline-dev
#   KeyfactorPassword: ***SECRET***
#   CertPassword: ***SECRET***
#   KeyVaultName: kv-app-dev
#   CertificateName: webapp-cert
#   AppServiceName: webapp-dev
#   ResourceGroup: rg-webapp-dev
#   TeamsWebhookUrl: https://outlook.office.com/webhook/...

# 2. Create service connections
# Azure-development: Azure subscription for dev
# Azure-staging: Azure subscription for staging
# Azure-production: Azure subscription for production

# 3. Trigger via webhook
# In Keyfactor: Webhooks → Add Webhook
# URL: https://dev.azure.com/{org}/{project}/_apis/pipelines/{pipelineId}/runs?api-version=6.0
# Method: POST
# Body:
# {
#   "resources": {
#     "repositories": {
#       "self": {
#         "refName": "refs/heads/main"
#       }
#     }
#   },
#   "templateParameters": {
#     "certificateId": "{{certificate.id}}",
#     "environment": "{{certificate.metadata.environment}}"
#   }
# }
```

---

## 5. ITSM Integration

### 5.1: ServiceNow Incident Creation (Python)

**Purpose**: Automatically create ServiceNow incidents for certificate events.

**File**: `servicenow-integration.py`

```python
#!/usr/bin/env python3
"""
ServiceNow Integration for Certificate Management
Creates incidents and change requests based on certificate events.
"""

import requests
import logging
import os
import json
from datetime import datetime

# Configuration
SERVICENOW_INSTANCE = os.environ.get('SERVICENOW_INSTANCE')  # e.g., 'yourinstance.service-now.com'
SERVICENOW_USER = os.environ.get('SERVICENOW_USER')
SERVICENOW_PASSWORD = os.environ.get('SERVICENOW_PASSWORD')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ServiceNowClient:
    def __init__(self, instance, username, password):
        self.instance = instance
        self.base_url = f"https://{instance}/api/now"
        self.auth = (username, password)
        self.headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def create_incident(self, short_description, description, urgency='3', impact='3', category='Security'):
        """Create an incident in ServiceNow."""
        url = f"{self.base_url}/table/incident"
        
        payload = {
            'short_description': short_description,
            'description': description,
            'urgency': urgency,
            'impact': impact,
            'category': category,
            'subcategory': 'Certificate Management',
            'assignment_group': 'PKI Team',
            'caller_id': SERVICENOW_USER
        }
        
        try:
            response = requests.post(
                url,
                auth=self.auth,
                headers=self.headers,
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            
            incident = response.json()['result']
            logger.info(f"Incident created: {incident['number']}")
            return incident
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to create incident: {e}")
            return None
    
    def create_change_request(self, short_description, description, risk='moderate', priority='3'):
        """Create a change request in ServiceNow."""
        url = f"{self.base_url}/table/change_request"
        
        payload = {
            'short_description': short_description,
            'description': description,
            'risk': risk,
            'priority': priority,
            'category': 'Security',
            'type': 'Standard',
            'assignment_group': 'PKI Team',
            'requested_by': SERVICENOW_USER
        }
        
        try:
            response = requests.post(
                url,
                auth=self.auth,
                headers=self.headers,
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            
            change = response.json()['result']
            logger.info(f"Change request created: {change['number']}")
            return change
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to create change request: {e}")
            return None
    
    def update_cmdb(self, ci_name, certificate_data):
        """Update CMDB CI with certificate information."""
        url = f"{self.base_url}/table/cmdb_ci_server"
        
        # Search for CI
        params = {'sysparm_query': f'name={ci_name}'}
        
        try:
            response = requests.get(
                url,
                auth=self.auth,
                headers=self.headers,
                params=params,
                timeout=30
            )
            response.raise_for_status()
            
            cis = response.json()['result']
            
            if not cis:
                logger.warning(f"CI not found: {ci_name}")
                return None
            
            ci_sys_id = cis[0]['sys_id']
            
            # Update CI with certificate info
            update_url = f"{url}/{ci_sys_id}"
            update_payload = {
                'u_certificate_thumbprint': certificate_data.get('thumbprint'),
                'u_certificate_expiry': certificate_data.get('expiry'),
                'u_certificate_issuer': certificate_data.get('issuer')
            }
            
            response = requests.patch(
                update_url,
                auth=self.auth,
                headers=self.headers,
                json=update_payload,
                timeout=30
            )
            response.raise_for_status()
            
            logger.info(f"CMDB CI updated: {ci_name}")
            return response.json()['result']
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to update CMDB: {e}")
            return None

def handle_certificate_expiring(cert_data, client):
    """Handle certificate expiring event."""
    subject = cert_data.get('subject')
    days_until_expiry = cert_data.get('daysUntilExpiry')
    
    short_desc = f"Certificate Expiring Soon: {subject}"
    description = f"""
Certificate Details:
- Subject: {subject}
- Days Until Expiry: {days_until_expiry}
- Thumbprint: {cert_data.get('thumbprint')}
- Issuer: {cert_data.get('issuer')}

Action Required:
Please review and renew this certificate before expiry.
    """
    
    # Create incident with high urgency if < 7 days
    urgency = '2' if days_until_expiry < 7 else '3'
    impact = '2' if days_until_expiry < 7 else '3'
    
    client.create_incident(short_desc, description, urgency=urgency, impact=impact)

def handle_certificate_renewal(cert_data, client):
    """Handle certificate renewal event."""
    subject = cert_data.get('subject')
    
    short_desc = f"Certificate Renewal Change Request: {subject}"
    description = f"""
Certificate Renewal Details:
- Subject: {subject}
- Old Thumbprint: {cert_data.get('oldThumbprint')}
- New Thumbprint: {cert_data.get('newThumbprint')}
- New Expiry: {cert_data.get('newExpiry')}

Deployment Plan:
1. Update certificate in all stores
2. Reload services
3. Verify HTTPS endpoints
4. Update CMDB
    """
    
    client.create_change_request(short_desc, description, risk='low', priority='3')
    
    # Update CMDB
    hostname = cert_data.get('hostname')
    if hostname:
        client.update_cmdb(hostname, {
            'thumbprint': cert_data.get('newThumbprint'),
            'expiry': cert_data.get('newExpiry'),
            'issuer': cert_data.get('issuer')
        })

def main():
    """Main function."""
    if not all([SERVICENOW_INSTANCE, SERVICENOW_USER, SERVICENOW_PASSWORD]):
        logger.error("ServiceNow credentials not configured")
        return 1
    
    client = ServiceNowClient(SERVICENOW_INSTANCE, SERVICENOW_USER, SERVICENOW_PASSWORD)
    
    # Example usage
    cert_data = {
        'subject': 'CN=webapp01.contoso.com',
        'thumbprint': 'ABCD1234...',
        'issuer': 'CN=Contoso CA',
        'daysUntilExpiry': 5
    }
    
    handle_certificate_expiring(cert_data, client)
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
```

---

## 6. Monitoring & Alerting

### 6.1: Certificate Expiry Monitor (Go)

**Purpose**: High-performance monitoring for certificate expiry across all stores.

**File**: `monitor-expiry.go`

```go
package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"sync"
	"time"
)

// Configuration
type Config struct {
	KeyfactorHost     string
	KeyfactorUsername string
	KeyfactorPassword string
	KeyfactorDomain   string
	WarningDays       int
	CriticalDays      int
	CheckInterval     int // minutes
}

// Certificate represents a certificate from Keyfactor
type Certificate struct {
	ID          string    `json:"Id"`
	Subject     string    `json:"IssuedDN"`
	Thumbprint  string    `json:"Thumbprint"`
	NotAfter    time.Time `json:"NotAfter"`
	Locations   []string  `json:"Locations"`
}

// Monitor handles certificate monitoring
type Monitor struct {
	config Config
	client *http.Client
}

// NewMonitor creates a new certificate monitor
func NewMonitor(config Config) *Monitor {
	return &Monitor{
		config: config,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// GetCertificates retrieves all certificates from Keyfactor
func (m *Monitor) GetCertificates() ([]Certificate, error) {
	url := fmt.Sprintf("%s/KeyfactorAPI/Certificates", m.config.KeyfactorHost)
	
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	
	// Set authentication
	req.SetBasicAuth(
		fmt.Sprintf("%s\\%s", m.config.KeyfactorDomain, m.config.KeyfactorUsername),
		m.config.KeyfactorPassword,
	)
	req.Header.Set("Content-Type", "application/json")
	
	resp, err := m.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		body, _ := ioutil.ReadAll(resp.Body)
		return nil, fmt.Errorf("API request failed: %s - %s", resp.Status, string(body))
	}
	
	var certificates []Certificate
	if err := json.NewDecoder(resp.Body).Decode(&certificates); err != nil {
		return nil, err
	}
	
	return certificates, nil
}

// CheckExpiry checks certificate expiry and sends alerts
func (m *Monitor) CheckExpiry(cert Certificate) string {
	now := time.Now()
	daysUntilExpiry := int(cert.NotAfter.Sub(now).Hours() / 24)
	
	if daysUntilExpiry < 0 {
		log.Printf("🔴 EXPIRED: %s (Expired %d days ago)", cert.Subject, -daysUntilExpiry)
		return "EXPIRED"
	} else if daysUntilExpiry <= m.config.CriticalDays {
		log.Printf("🔴 CRITICAL: %s (Expires in %d days)", cert.Subject, daysUntilExpiry)
		return "CRITICAL"
	} else if daysUntilExpiry <= m.config.WarningDays {
		log.Printf("🟡 WARNING: %s (Expires in %d days)", cert.Subject, daysUntilExpiry)
		return "WARNING"
	}
	
	return "OK"
}

// SendAlert sends alert to monitoring system
func (m *Monitor) SendAlert(cert Certificate, severity string) error {
	alertURL := os.Getenv("ALERT_WEBHOOK_URL")
	if alertURL == "" {
		return nil // No alert configured
	}
	
	now := time.Now()
	daysUntilExpiry := int(cert.NotAfter.Sub(now).Hours() / 24)
	
	payload := map[string]interface{}{
		"severity":        severity,
		"subject":         cert.Subject,
		"thumbprint":      cert.Thumbprint,
		"daysUntilExpiry": daysUntilExpiry,
		"expiryDate":      cert.NotAfter.Format(time.RFC3339),
		"timestamp":       now.Format(time.RFC3339),
	}
	
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	
	resp, err := http.Post(alertURL, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		return fmt.Errorf("alert webhook returned status %d", resp.StatusCode)
	}
	
	return nil
}

// MonitorLoop runs continuous monitoring
func (m *Monitor) MonitorLoop() {
	ticker := time.NewTicker(time.Duration(m.config.CheckInterval) * time.Minute)
	defer ticker.Stop()
	
	for {
		log.Println("Starting certificate expiry check...")
		
		certificates, err := m.GetCertificates()
		if err != nil {
			log.Printf("Error retrieving certificates: %v", err)
			<-ticker.C
			continue
		}
		
		log.Printf("Retrieved %d certificates", len(certificates))
		
		// Counters
		expired := 0
		critical := 0
		warning := 0
		ok := 0
		
		// Check certificates concurrently
		var wg sync.WaitGroup
		semaphore := make(chan struct{}, 10) // Limit concurrency
		
		for _, cert := range certificates {
			wg.Add(1)
			go func(c Certificate) {
				defer wg.Done()
				semaphore <- struct{}{}        // Acquire
				defer func() { <-semaphore }() // Release
				
				status := m.CheckExpiry(c)
				
				switch status {
				case "EXPIRED":
					expired++
					m.SendAlert(c, "CRITICAL")
				case "CRITICAL":
					critical++
					m.SendAlert(c, "CRITICAL")
				case "WARNING":
					warning++
					m.SendAlert(c, "WARNING")
				default:
					ok++
				}
			}(cert)
		}
		
		wg.Wait()
		
		// Summary
		log.Println("======================================")
		log.Printf("Expiry Check Summary:")
		log.Printf("  Total: %d", len(certificates))
		log.Printf("  OK: %d", ok)
		log.Printf("  Warning: %d", warning)
		log.Printf("  Critical: %d", critical)
		log.Printf("  Expired: %d", expired)
		log.Println("======================================")
		
		<-ticker.C
	}
}

func main() {
	config := Config{
		KeyfactorHost:     os.Getenv("KEYFACTOR_HOST"),
		KeyfactorUsername: os.Getenv("KEYFACTOR_USERNAME"),
		KeyfactorPassword: os.Getenv("KEYFACTOR_PASSWORD"),
		KeyfactorDomain:   os.Getenv("KEYFACTOR_DOMAIN"),
		WarningDays:       30,
		CriticalDays:      7,
		CheckInterval:     60, // 1 hour
	}
	
	if config.KeyfactorHost == "" || config.KeyfactorUsername == "" || config.KeyfactorPassword == "" {
		log.Fatal("Missing Keyfactor credentials")
	}
	
	log.Println("Starting Certificate Expiry Monitor...")
	log.Printf("Warning threshold: %d days", config.WarningDays)
	log.Printf("Critical threshold: %d days", config.CriticalDays)
	log.Printf("Check interval: %d minutes", config.CheckInterval)
	
	monitor := NewMonitor(config)
	monitor.MonitorLoop()
}
```

**Build and Deploy**:

```bash
# Build
go build -o monitor-expiry monitor-expiry.go

# Create systemd service
sudo cat > /etc/systemd/system/keyfactor-monitor.service <<EOF
[Unit]
Description=Keyfactor Certificate Expiry Monitor
After=network.target

[Service]
Type=simple
User=keyfactor
Environment="KEYFACTOR_HOST=https://keyfactor.contoso.com"
Environment="KEYFACTOR_USERNAME=monitor-user"
Environment="KEYFACTOR_PASSWORD=password"
Environment="KEYFACTOR_DOMAIN=CONTOSO"
Environment="ALERT_WEBHOOK_URL=https://alertmanager.contoso.com/api/v1/alerts"
ExecStart=/usr/local/bin/monitor-expiry
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start service
sudo systemctl daemon-reload
sudo systemctl enable keyfactor-monitor
sudo systemctl start keyfactor-monitor

# View logs
sudo journalctl -u keyfactor-monitor -f
```

---

## 7. Backup & Recovery

### 7.1: Database Backup Script (PowerShell)

**Purpose**: Automated backup of Keyfactor database with retention policy.

**File**: `backup-keyfactor-db.ps1`

```powershell
<#
.SYNOPSIS
    Backup Keyfactor database with retention management
#>

param(
    [int]$RetentionDays = 30
)

# Configuration
$SqlServer = $env:SQL_SERVER
$Database = "keyfactor"
$BackupPath = "C:\Backups\Keyfactor"
$LogFile = "C:\Logs\keyfactor-backup-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

Write-Log "Starting Keyfactor database backup"

# Create backup directory if not exists
if (-not (Test-Path $BackupPath)) {
    New-Item -Path $BackupPath -ItemType Directory -Force
    Write-Log "Created backup directory: $BackupPath"
}

# Generate backup filename
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "$BackupPath\keyfactor-$timestamp.bak"

Write-Log "Backup file: $backupFile"

# Perform backup
try {
    $query = @"
BACKUP DATABASE [$Database]
TO DISK = '$backupFile'
WITH COMPRESSION, CHECKSUM, STATS = 10;
"@
    
    Invoke-Sqlcmd -ServerInstance $SqlServer -Query $query -QueryTimeout 0
    
    Write-Log "Database backup completed successfully"
    
    # Verify backup
    $verifyQuery = "RESTORE VERIFYONLY FROM DISK = '$backupFile'"
    Invoke-Sqlcmd -ServerInstance $SqlServer -Query $verifyQuery
    
    Write-Log "Backup verification successful"
    
    # Get backup size
    $size = (Get-Item $backupFile).Length / 1MB
    Write-Log "Backup size: $([math]::Round($size, 2)) MB"
    
} catch {
    Write-Log "ERROR: Backup failed - $_"
    exit 1
}

# Cleanup old backups
Write-Log "Cleaning up backups older than $RetentionDays days"

$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
$oldBackups = Get-ChildItem $BackupPath -Filter "keyfactor-*.bak" |
    Where-Object { $_.CreationTime -lt $cutoffDate }

foreach ($backup in $oldBackups) {
    Write-Log "Deleting old backup: $($backup.Name)"
    Remove-Item $backup.FullName -Force
}

Write-Log "Backup cleanup completed"

# Upload to Azure Blob Storage (optional)
$storageAccount = $env:AZURE_STORAGE_ACCOUNT
$storageKey = $env:AZURE_STORAGE_KEY
$container = "keyfactor-backups"

if ($storageAccount -and $storageKey) {
    Write-Log "Uploading backup to Azure Storage..."
    
    try {
        $ctx = New-AzStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageKey
        
        Set-AzStorageBlobContent -File $backupFile `
            -Container $container `
            -Blob "keyfactor-$timestamp.bak" `
            -Context $ctx `
            -Force
        
        Write-Log "Backup uploaded to Azure Storage successfully"
    } catch {
        Write-Log "WARNING: Failed to upload to Azure Storage - $_"
    }
}

Write-Log "Backup process completed"
```

---

## 8. Reporting & Analytics

### 8.1: Certificate Inventory Report (Python)

**Purpose**: Generate comprehensive certificate inventory reports.

**File**: `generate-inventory-report.py`

```python
#!/usr/bin/env python3
"""
Certificate Inventory Report Generator
Generates detailed reports of all certificates managed by Keyfactor.
"""

import requests
import pandas as pd
from datetime import datetime, timedelta
import os
import sys
import logging

# Configuration
KEYFACTOR_HOST = os.environ.get('KEYFACTOR_HOST')
KEYFACTOR_USERNAME = os.environ.get('KEYFACTOR_USERNAME')
KEYFACTOR_PASSWORD = os.environ.get('KEYFACTOR_PASSWORD')
KEYFACTOR_DOMAIN = os.environ.get('KEYFACTOR_DOMAIN', 'CONTOSO')

REPORT_OUTPUT_DIR = '/var/reports/keyfactor'

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class KeyfactorReporter:
    def __init__(self, hostname, username, password, domain):
        self.base_url = f"{hostname}/KeyfactorAPI"
        self.session = requests.Session()
        self.session.auth = (f"{domain}\\{username}", password)
        self.session.headers.update({'Content-Type': 'application/json'})
    
    def get_all_certificates(self):
        """Retrieve all certificates."""
        certs = []
        page = 1
        page_size = 1000
        
        while True:
            params = {
                'pq.pageReturned': page,
                'pq.returnLimit': page_size
            }
            
            response = self.session.get(f"{self.base_url}/Certificates", params=params)
            response.raise_for_status()
            
            batch = response.json()
            if not batch:
                break
            
            certs.extend(batch)
            page += 1
            
            logger.info(f"Retrieved {len(certs)} certificates...")
        
        return certs
    
    def generate_inventory_report(self):
        """Generate inventory report."""
        logger.info("Generating inventory report...")
        
        certificates = self.get_all_certificates()
        logger.info(f"Total certificates: {len(certificates)}")
        
        # Convert to DataFrame
        df = pd.DataFrame(certificates)
        
        # Extract key fields
        df['Subject'] = df['IssuedDN']
        df['Expiry'] = pd.to_datetime(df['NotAfter'])
        df['DaysUntilExpiry'] = (df['Expiry'] - datetime.now()).dt.days
        
        # Categorize by expiry
        df['Status'] = pd.cut(
            df['DaysUntilExpiry'],
            bins=[-float('inf'), 0, 7, 30, 90, float('inf')],
            labels=['Expired', 'Critical (< 7 days)', 'Warning (< 30 days)', 'Attention (< 90 days)', 'OK']
        )
        
        # Generate summary
        summary = df['Status'].value_counts().to_dict()
        
        # Save detailed report
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        output_file = f"{REPORT_OUTPUT_DIR}/inventory-{timestamp}.xlsx"
        
        with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
            # Summary sheet
            summary_df = pd.DataFrame.from_dict(summary, orient='index', columns=['Count'])
            summary_df.to_excel(writer, sheet_name='Summary')
            
            # All certificates
            df[['Subject', 'Thumbprint', 'Expiry', 'DaysUntilExpiry', 'Status']].to_excel(
                writer, sheet_name='All Certificates', index=False
            )
            
            # Expiring soon
            expiring = df[df['DaysUntilExpiry'] <= 30].sort_values('DaysUntilExpiry')
            expiring[['Subject', 'Expiry', 'DaysUntilExpiry']].to_excel(
                writer, sheet_name='Expiring Soon', index=False
            )
            
            # By issuer
            issuer_summary = df.groupby('IssuerDN').size().reset_index(name='Count')
            issuer_summary.to_excel(writer, sheet_name='By Issuer', index=False)
        
        logger.info(f"Report saved: {output_file}")
        logger.info(f"Summary: {summary}")
        
        return output_file

def main():
    if not all([KEYFACTOR_HOST, KEYFACTOR_USERNAME, KEYFACTOR_PASSWORD]):
        logger.error("Missing Keyfactor credentials")
        return 1
    
    # Create output directory
    os.makedirs(REPORT_OUTPUT_DIR, exist_ok=True)
    
    reporter = KeyfactorReporter(
        hostname=KEYFACTOR_HOST,
        username=KEYFACTOR_USERNAME,
        password=KEYFACTOR_PASSWORD,
        domain=KEYFACTOR_DOMAIN
    )
    
    report_file = reporter.generate_inventory_report()
    print(f"Report generated: {report_file}")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
```

---

## Appendix: Quick Reference

### Webhook Event Types

| Event Type | Description | Recommended Action |
|------------|-------------|-------------------|
| `CertificateIssued` | New certificate issued | Log event, update CMDB |
| `CertificateRenewed` | Certificate renewed | Deploy to stores, reload services |
| `CertificateExpiring` | Certificate nearing expiry | Send notification, request renewal |
| `CertificateExpired` | Certificate has expired | Create incident, escalate |
| `CertificateRevoked` | Certificate revoked | Remove from stores, update CRL |
| `StoreInventoryComplete` | Store inventory finished | Update asset database |
| `DeploymentComplete` | Certificate deployment finished | Reload service, verify endpoint |

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/KeyfactorAPI/Certificates` | GET | List certificates |
| `/KeyfactorAPI/Certificates/{id}` | GET | Get certificate details |
| `/KeyfactorAPI/Certificates/{id}/Renew` | POST | Renew certificate |
| `/KeyfactorAPI/Certificates/{id}/Download` | POST | Download certificate |
| `/KeyfactorAPI/Certificates/{id}/Revoke` | POST | Revoke certificate |
| `/KeyfactorAPI/CertificateStores` | GET | List certificate stores |
| `/KeyfactorAPI/Agents` | GET | List orchestrators |

### Environment Variables

```bash
# Keyfactor
KEYFACTOR_HOST=https://keyfactor.contoso.com
KEYFACTOR_USERNAME=api-user
KEYFACTOR_PASSWORD=SecurePassword123!
KEYFACTOR_DOMAIN=CONTOSO

# Webhooks
WEBHOOK_SECRET=your-webhook-secret

# ServiceNow
SERVICENOW_INSTANCE=yourinstance.service-now.com
SERVICENOW_USER=webhook-user
SERVICENOW_PASSWORD=password

# Slack
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Azure
AZURE_STORAGE_ACCOUNT=stkeyfactorbackup
AZURE_STORAGE_KEY=storage-key

# Monitoring
ALERT_WEBHOOK_URL=https://alertmanager.contoso.com/api/v1/alerts
```

---

**Document Version**: 1.0  
**Last Updated**: October 22, 2025  
**Author**: Adrian Johnson <adrian207@gmail.com>

**End of Automation Playbooks**
