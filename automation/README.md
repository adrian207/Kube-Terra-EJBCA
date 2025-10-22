# Keyfactor Automation Scripts
## Production-Ready Scripts for Certificate Lifecycle Management

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## 📁 Directory Structure

```
automation/
├── webhooks/          # Webhook receivers for Keyfactor events
├── renewal/           # Certificate renewal automation
├── service-reload/    # Service reload scripts after certificate updates
├── deployment/        # Certificate deployment pipelines
├── itsm/             # ServiceNow integration
├── monitoring/        # Certificate expiry monitoring
├── backup/           # Database backup scripts
├── reporting/        # Certificate inventory reports
└── README.md         # This file
```

---

## 🚀 Quick Start

### Prerequisites

**Python Scripts**:
```bash
pip install requests flask pandas openpyxl
```

**PowerShell Scripts**:
```powershell
# Windows only
Install-Module ImportExcel -Scope CurrentUser
```

**Go Scripts**:
```bash
# Requires Go 1.16+
go version
```

### Environment Variables

Create a `.env` file or set system environment variables:

```bash
# Keyfactor API
export KEYFACTOR_HOST="https://keyfactor.contoso.com"
export KEYFACTOR_USERNAME="api-user"
export KEYFACTOR_PASSWORD="SecurePassword123!"
export KEYFACTOR_DOMAIN="CONTOSO"

# Webhooks
export WEBHOOK_SECRET="your-webhook-secret"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# ServiceNow
export SERVICENOW_INSTANCE="yourinstance.service-now.com"
export SERVICENOW_USER="webhook-user"
export SERVICENOW_PASSWORD="password"

# Monitoring
export ALERT_WEBHOOK_URL="https://alertmanager.contoso.com/api/v1/alerts"
export WARNING_DAYS="30"
export CRITICAL_DAYS="7"
export CHECK_INTERVAL="60"

# Azure Backup (optional)
export AZURE_STORAGE_ACCOUNT="stkeyfactorbackup"
export AZURE_STORAGE_KEY="storage-key"

# Database
export SQL_SERVER="sql-server.contoso.com"
```

---

## 📋 Script Index

### 1. Webhooks (`webhooks/`)

Receive and process Keyfactor webhook events.

| Script | Language | Description |
|--------|----------|-------------|
| `webhook-receiver.py` | Python | Flask-based webhook receiver with HMAC validation |
| `webhook-receiver.go` | Go | High-performance webhook receiver |
| `azure-function-webhook.ps1` | PowerShell | Azure Function webhook handler |

**Quick Start**:
```bash
# Python
cd webhooks
python webhook-receiver.py

# Go
cd webhooks
go build -o webhook-receiver webhook-receiver.go
./webhook-receiver

# PowerShell (Azure Functions)
# Deploy via Azure CLI or Portal
```

**Use Cases**:
- Certificate issued/renewed notifications
- Slack/Teams alerts
- Trigger CI/CD pipelines
- ServiceNow incident creation

---

### 2. Renewal (`renewal/`)

Automated certificate renewal and deployment.

| Script | Language | Description |
|--------|----------|-------------|
| `auto-renew.py` | Python | Automatic renewal with deployment |
| `auto-renew.ps1` | PowerShell | Windows-based renewal automation |
| `auto-renew.go` | Go | High-performance renewal service |
| `renew-with-approval.ps1` | PowerShell | Renewal with email approval workflow |

**Quick Start**:
```bash
# Python
python renewal/auto-renew.py --threshold 30 --dry-run

# PowerShell
.\renewal\auto-renew.ps1 -ThresholdDays 30 -DryRun

# Go
cd renewal
go build -o auto-renew auto-renew.go
./auto-renew -threshold 30 -dry-run
```

**Options**:
- `-threshold` / `-ThresholdDays`: Days until expiry (default: 30)
- `-dry-run` / `-DryRun`: Test mode without actual renewal
- `--help` / `-?`: Show help

---

### 3. Service Reload (`service-reload/`)

Reload services after certificate updates.

| Script | Language | Platform | Description |
|--------|----------|----------|-------------|
| `reload-iis.ps1` | PowerShell | Windows | IIS SSL binding updates |
| `reload-nginx.sh` | Bash | Linux | NGINX certificate reload |

**Quick Start**:
```powershell
# IIS (Windows)
.\service-reload\reload-iis.ps1 `
    -CertificatePath "C:\Certs\server.pfx" `
    -Password "password" `
    -WebsiteName "Default Web Site"
```

```bash
# NGINX (Linux)
./service-reload/reload-nginx.sh \
    /etc/nginx/ssl/server.crt \
    /etc/nginx/ssl/server.key
```

---

### 4. Deployment (`deployment/`)

CI/CD pipelines for certificate deployment.

| Script | Type | Platform | Description |
|--------|------|----------|-------------|
| `azure-pipelines-cert-deploy.yml` | YAML | Azure DevOps | Multi-stage deployment pipeline |

**Quick Start**:
```bash
# Import to Azure DevOps
az pipelines create \
    --name "Certificate Deployment" \
    --yml-path deployment/azure-pipelines-cert-deploy.yml
```

**Features**:
- Webhook-triggered deployment
- Multi-environment support (dev/staging/prod)
- Azure Key Vault integration
- App Service SSL binding
- Automated verification

---

### 5. ITSM Integration (`itsm/`)

ServiceNow integration for certificate events.

| Script | Language | Description |
|--------|----------|-------------|
| `servicenow-integration.py` | Python | Create incidents and change requests |
| `servicenow-integration.ps1` | PowerShell | Windows-based ServiceNow integration |

**Quick Start**:
```bash
# Python - Create incident
python itsm/servicenow-integration.py --action incident \
    --subject "CN=webapp.contoso.com" \
    --days-until-expiry 5

# PowerShell
.\itsm\servicenow-integration.ps1 -Action incident `
    -CertificateData @{
        subject="CN=webapp.contoso.com"
        daysUntilExpiry=5
        thumbprint="ABCD1234..."
    }
```

**Actions**:
- `incident`: Create incident for expiring certificate
- `change`: Create change request for renewal
- `cmdb-update`: Update CMDB with certificate info

---

### 6. Monitoring (`monitoring/`)

Certificate expiry monitoring and alerting.

| Script | Language | Description |
|--------|----------|-------------|
| `monitor-expiry.go` | Go | High-performance concurrent monitoring |
| `monitor-expiry.py` | Python | Python-based monitoring service |
| `monitor-expiry.ps1` | PowerShell | Windows monitoring service |

**Quick Start**:
```bash
# Go (recommended for production)
cd monitoring
go build -o monitor-expiry monitor-expiry.go
./monitor-expiry

# Python
python monitoring/monitor-expiry.py

# PowerShell
.\monitoring\monitor-expiry.ps1 -WarningDays 30 -CriticalDays 7
```

**Features**:
- Continuous monitoring loop
- Configurable thresholds
- Webhook alerts
- Concurrent certificate checking
- Summary statistics

**Deploy as Service** (Linux):
```bash
# Create systemd service
sudo cat > /etc/systemd/system/keyfactor-monitor.service <<EOF
[Unit]
Description=Keyfactor Certificate Expiry Monitor
After=network.target

[Service]
Type=simple
User=keyfactor
EnvironmentFile=/etc/keyfactor/monitor.env
ExecStart=/usr/local/bin/monitor-expiry
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable keyfactor-monitor
sudo systemctl start keyfactor-monitor
```

---

### 7. Backup (`backup/`)

Automated Keyfactor database backup.

| Script | Language | Platform | Description |
|--------|----------|----------|-------------|
| `backup-keyfactor-db.ps1` | PowerShell | Windows | SQL Server backup with Azure upload |

**Quick Start**:
```powershell
.\backup\backup-keyfactor-db.ps1 -RetentionDays 30
```

**Features**:
- SQL Server database backup
- Compression and checksum verification
- Retention policy management
- Optional Azure Blob Storage upload
- Automated scheduling via Task Scheduler

**Schedule Daily Backup**:
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\backup-keyfactor-db.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

Register-ScheduledTask -TaskName "Keyfactor DB Backup" `
    -Action $action `
    -Trigger $trigger `
    -User "NT AUTHORITY\SYSTEM"
```

---

### 8. Reporting (`reporting/`)

Certificate inventory and compliance reports.

| Script | Language | Output Format | Description |
|--------|----------|---------------|-------------|
| `generate-inventory-report.py` | Python | Excel (XLSX) | Comprehensive inventory with charts |
| `generate-inventory-report.ps1` | PowerShell | Excel/CSV | Windows-based reporting |
| `generate-inventory-report.go` | Go | CSV | High-performance reporting |

**Quick Start**:
```bash
# Python
python reporting/generate-inventory-report.py

# PowerShell
.\reporting\generate-inventory-report.ps1 -OutputPath "C:\Reports"

# Go
cd reporting
go build -o generate-report generate-inventory-report.go
./generate-report -output /var/reports/keyfactor
```

**Report Contents**:
- **Summary**: Certificate counts by status
- **All Certificates**: Complete inventory
- **Expiring Soon**: Certificates expiring within 30 days
- **By Issuer**: Certificates grouped by issuing CA

**Schedule Monthly Reports**:
```bash
# Linux cron
0 9 1 * * /usr/local/bin/generate-report -output /var/reports/keyfactor
```

```powershell
# Windows Task Scheduler
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\generate-inventory-report.ps1"

$trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At 9:00AM

Register-ScheduledTask -TaskName "Keyfactor Monthly Report" `
    -Action $action -Trigger $trigger
```

---

## 🔧 Common Use Cases

### Use Case 1: Automated Renewal Pipeline

```bash
# 1. Monitor expiry daily
./monitoring/monitor-expiry.go

# 2. Auto-renew certificates expiring within 30 days
./renewal/auto-renew.go -threshold 30

# 3. Deploy via Azure Pipeline (triggered by webhook)
# See deployment/azure-pipelines-cert-deploy.yml
```

### Use Case 2: Alert-Driven Workflow

```bash
# 1. Webhook receives CertificateExpiring event
./webhooks/webhook-receiver.py

# 2. Send Slack notification

# 3. Create ServiceNow incident
python itsm/servicenow-integration.py --action incident
```

### Use Case 3: Monthly Reporting

```bash
# Generate comprehensive report on 1st of month
python reporting/generate-inventory-report.py

# Email report to stakeholders (add to cron)
```

---

## 🛡️ Security Considerations

### Credentials Management

**❌ DO NOT**:
- Hard-code credentials in scripts
- Commit credentials to version control
- Use plain-text passwords

**✅ DO**:
- Use environment variables
- Use Azure Key Vault / HashiCorp Vault
- Use Managed Identity (Azure)
- Rotate credentials regularly

### HMAC Signature Verification

All webhook receivers verify HMAC signatures:

```python
# Python example
signature = request.headers.get('X-Keyfactor-Signature')
if not verify_hmac(payload, signature, WEBHOOK_SECRET):
    abort(401)
```

### Least Privilege

- Use service accounts with minimal permissions
- Restrict API user to read/renew only
- Audit service account activity

---

## 📊 Performance Benchmarks

| Script | Language | Certificates | Processing Time | Memory |
|--------|----------|--------------|-----------------|--------|
| `monitor-expiry.go` | Go | 10,000 | ~8 seconds | ~50 MB |
| `monitor-expiry.py` | Python | 10,000 | ~25 seconds | ~120 MB |
| `monitor-expiry.ps1` | PowerShell | 10,000 | ~45 seconds | ~200 MB |
| `auto-renew.go` | Go | 1,000 | ~15 seconds | ~40 MB |
| `generate-report.go` | Go | 50,000 | ~30 seconds | ~80 MB |

**Recommendation**: Use Go scripts for production environments with large certificate volumes (>5,000 certificates).

---

## 🐛 Troubleshooting

### Authentication Failures

```
Error: 401 Unauthorized
```

**Solution**:
```bash
# Verify credentials
curl -u "$KEYFACTOR_DOMAIN\\$KEYFACTOR_USERNAME:$KEYFACTOR_PASSWORD" \
    "$KEYFACTOR_HOST/KeyfactorAPI/Certificates" | jq .
```

### Webhook Signature Verification Failed

```
Error: Invalid HMAC signature
```

**Solution**:
- Verify `WEBHOOK_SECRET` matches Keyfactor configuration
- Check signature header name: `X-Keyfactor-Signature`
- Ensure payload is hashed before verification

### Module Not Found (Python)

```
ModuleNotFoundError: No module named 'requests'
```

**Solution**:
```bash
pip install -r requirements.txt
```

### Script Not Executable (Linux)

```
Permission denied: ./script.sh
```

**Solution**:
```bash
chmod +x script.sh
```

---

## 📚 Additional Resources

- [Keyfactor API Documentation](https://keyfactor.github.io/keyfactor-api-docs/)
- [Main Implementation Guide](../01-Executive-Design-Document.md)
- [RBAC Framework](../02-RBAC-Authorization-Framework.md)
- [Enrollment Rails Guide](../07-Enrollment-Rails-Guide.md)
- [Keyfactor Integrations Guide](../KEYFACTOR-INTEGRATIONS-GUIDE.md)

---

## 📞 Support

**Internal Support**:
- Email: adrian207@gmail.com
- Slack: #pki-automation

**Vendor Support**:
- Keyfactor Support Portal: https://support.keyfactor.com

---

**Document Version**: 1.0  
**Last Updated**: October 22, 2025  
**Author**: Adrian Johnson <adrian207@gmail.com>

**End of Automation Scripts README**
