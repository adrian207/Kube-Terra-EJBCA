# Keyfactor Implementation Runbooks
## Phase-by-Phase Procedures with Validation & Rollback

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Document Purpose

This document provides detailed, step-by-step implementation procedures for deploying Keyfactor Certificate Lifecycle Management across 5 phases. Each phase includes:

- **Prerequisites** - What must be in place before starting
- **Step-by-Step Procedures** - Detailed instructions with commands
- **Validation Criteria** - How to verify success at each step
- **Rollback Procedures** - How to safely revert changes if needed
- **Time Estimates** - Expected duration for each task
- **Sign-Off Checklist** - Formal approval before proceeding

---

## Table of Contents

1. [Phase 1: Foundation & Planning (Weeks 1-5)](#phase-1-foundation--planning-weeks-1-5)
2. [Phase 2: CA & HSM Foundation (Weeks 6-9)](#phase-2-ca--hsm-foundation-weeks-6-9)
3. [Phase 3: Enrollment Rails & Self-Service (Weeks 10-12)](#phase-3-enrollment-rails--self-service-weeks-10-12)
4. [Phase 4: Orchestration & Zero-Touch Operations (Weeks 13-16)](#phase-4-orchestration--zero-touch-operations-weeks-13-16)
5. [Phase 5: Optimization & Scaling (Weeks 17-20)](#phase-5-optimization--scaling-weeks-17-20)

---

## Phase 1: Foundation & Planning (Weeks 1-5)

**Objective**: Establish infrastructure, install Keyfactor Command, and configure basic settings.

**Duration**: 5 weeks  
**Team**: Infrastructure team, PKI architects, security team

---

### Week 1-2: Infrastructure Preparation

#### Task 1.1: Provision Infrastructure

**Prerequisites**:
- Azure subscription or on-premises infrastructure approved
- Network security groups/firewall rules documented
- DNS namespace reserved (e.g., `keyfactor.contoso.com`)

**Procedure**:

```bash
# Step 1: Create Resource Group (Azure)
az group create \
  --name rg-keyfactor-prod \
  --location eastus \
  --tags environment=production purpose=pki

# Step 2: Create Virtual Network
az network vnet create \
  --resource-group rg-keyfactor-prod \
  --name vnet-keyfactor \
  --address-prefix 10.10.0.0/16 \
  --subnet-name subnet-keyfactor-command \
  --subnet-prefix 10.10.1.0/24

# Step 3: Create Network Security Group
az network nsg create \
  --resource-group rg-keyfactor-prod \
  --name nsg-keyfactor-command

# Allow HTTPS
az network nsg rule create \
  --resource-group rg-keyfactor-prod \
  --nsg-name nsg-keyfactor-command \
  --name AllowHTTPS \
  --priority 100 \
  --source-address-prefixes 10.0.0.0/8 \
  --destination-port-ranges 443 \
  --protocol Tcp \
  --access Allow

# Step 4: Create SQL Server (for Keyfactor database)
az sql server create \
  --name sqlserver-keyfactor-prod \
  --resource-group rg-keyfactor-prod \
  --location eastus \
  --admin-user keyfactoradmin \
  --admin-password 'ComplexPassword123!'

# Step 5: Create SQL Database
az sql db create \
  --resource-group rg-keyfactor-prod \
  --server sqlserver-keyfactor-prod \
  --name keyfactor \
  --service-objective S3 \
  --max-size 250GB

# Step 6: Create VMs for Keyfactor Command (2x for HA)
az vm create \
  --resource-group rg-keyfactor-prod \
  --name vm-keyfactor-01 \
  --image Win2022Datacenter \
  --size Standard_D4s_v3 \
  --vnet-name vnet-keyfactor \
  --subnet subnet-keyfactor-command \
  --nsg nsg-keyfactor-command \
  --admin-username keyfactoradmin \
  --admin-password 'ComplexPassword123!' \
  --data-disk-sizes-gb 128

az vm create \
  --resource-group rg-keyfactor-prod \
  --name vm-keyfactor-02 \
  --image Win2022Datacenter \
  --size Standard_D4s_v3 \
  --vnet-name vnet-keyfactor \
  --subnet subnet-keyfactor-command \
  --nsg nsg-keyfactor-command \
  --admin-username keyfactoradmin \
  --admin-password 'ComplexPassword123!' \
  --data-disk-sizes-gb 128
```

**Validation**:
```bash
# Verify resource group
az group show --name rg-keyfactor-prod

# Verify VMs are running
az vm list --resource-group rg-keyfactor-prod --output table

# Verify SQL Server
az sql server show --name sqlserver-keyfactor-prod --resource-group rg-keyfactor-prod

# Test connectivity
Test-NetConnection -ComputerName vm-keyfactor-01.contoso.com -Port 443
Test-NetConnection -ComputerName sqlserver-keyfactor-prod.database.windows.net -Port 1433
```

**Rollback**:
```bash
# Delete entire resource group (CAUTION!)
az group delete --name rg-keyfactor-prod --yes --no-wait
```

**Time Estimate**: 4 hours  
**Status**: [ ] Complete

---

#### Task 1.2: Install Windows Prerequisites

**Prerequisites**:
- VMs provisioned and accessible via RDP
- Domain joined (if using AD authentication)
- Windows Updates applied

**Procedure**:

```powershell
# Connect to each Keyfactor Command VM via RDP

# Step 1: Install IIS with required features
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-Asp-Net45
Install-WindowsFeature -Name Web-Windows-Auth
Install-WindowsFeature -Name Web-Client-Auth

# Step 2: Install .NET Framework 4.8
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2088631" `
  -OutFile "C:\Temp\ndp48-x86-x64-allos-enu.exe"

Start-Process -FilePath "C:\Temp\ndp48-x86-x64-allos-enu.exe" `
  -ArgumentList "/q", "/norestart" -Wait

# Step 3: Install .NET Core 6.0 Hosting Bundle
Invoke-WebRequest -Uri "https://download.visualstudio.microsoft.com/download/pr/0cb3c095-c4f4-4d55-929b-3b4888a7b5f1/4156664d6bfcb46b63916a8cd43f8305/dotnet-hosting-6.0.16-win.exe" `
  -OutFile "C:\Temp\dotnet-hosting-6.0.16-win.exe"

Start-Process -FilePath "C:\Temp\dotnet-hosting-6.0.16-win.exe" `
  -ArgumentList "/install", "/quiet", "/norestart" -Wait

# Step 4: Install SQL Server Management Studio (SSMS) - optional but recommended
Invoke-WebRequest -Uri "https://aka.ms/ssmsfullsetup" `
  -OutFile "C:\Temp\SSMS-Setup.exe"

Start-Process -FilePath "C:\Temp\SSMS-Setup.exe" `
  -ArgumentList "/install", "/quiet", "/norestart" -Wait

# Step 5: Configure Windows Firewall
New-NetFirewallRule -DisplayName "Keyfactor HTTPS" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Keyfactor HTTP" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow

# Step 6: Configure TLS/SSL settings
# Disable TLS 1.0 and 1.1, enable TLS 1.2 and 1.3
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Name "Enabled" -Value 1 -PropertyType DWORD -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -Name "DisabledByDefault" -Value 0 -PropertyType DWORD -Force

# Restart to apply changes
Restart-Computer -Force
```

**Validation**:
```powershell
# Verify IIS is installed
Get-WindowsFeature -Name Web-Server

# Verify .NET versions
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where { $_.PSChildName -Match '^(?!S)\p{L}'} | Select PSChildName, version

# Verify .NET Core
dotnet --list-runtimes

# Check firewall rules
Get-NetFirewallRule -DisplayName "Keyfactor*"

# Test TLS configuration
Invoke-WebRequest -Uri "https://www.howsmyssl.com/a/check" | Select-Object -ExpandProperty Content | ConvertFrom-Json | Select-Object tls_version
```

**Rollback**:
```powershell
# Uninstall IIS
Uninstall-WindowsFeature -Name Web-Server -Remove

# Remove firewall rules
Remove-NetFirewallRule -DisplayName "Keyfactor*"
```

**Time Estimate**: 2 hours (per server)  
**Status**: [ ] vm-keyfactor-01 Complete  [ ] vm-keyfactor-02 Complete

---

### Week 3-4: Keyfactor Command Installation

#### Task 1.3: Install Keyfactor Command

**Prerequisites**:
- Windows prerequisites installed
- SQL Server database created and accessible
- Keyfactor installation files downloaded from portal
- License file obtained from Keyfactor

**Procedure**:

```powershell
# Step 1: Download Keyfactor Command installer
# (Assume downloaded to C:\Temp\KeyfactorCommand-10.5.0.msi)

# Step 2: Prepare SQL database
# Connect to SQL Server
$sqlServer = "sqlserver-keyfactor-prod.database.windows.net"
$database = "keyfactor"
$username = "keyfactoradmin"
$password = "ComplexPassword123!"

# Create SQL login for Keyfactor service account
sqlcmd -S $sqlServer -U $username -P $password -Q @"
CREATE LOGIN [CONTOSO\svc-keyfactor] FROM WINDOWS;
USE [keyfactor];
CREATE USER [CONTOSO\svc-keyfactor] FOR LOGIN [CONTOSO\svc-keyfactor];
ALTER ROLE db_owner ADD MEMBER [CONTOSO\svc-keyfactor];
"@

# Step 3: Install Keyfactor Command (Primary Node)
Start-Process msiexec.exe -ArgumentList @(
    "/i", "C:\Temp\KeyfactorCommand-10.5.0.msi",
    "/qn",  # Quiet mode
    "/L*V", "C:\Temp\KeyfactorInstall.log",  # Verbose logging
    "DBSERVER=$sqlServer",
    "DBNAME=$database",
    "DBUSER=keyfactoradmin",
    "DBPASSWORD=$password",
    "WEBSITENAME=Keyfactor",
    "WEBSITEPORT=443",
    "SERVICEACCOUNT=CONTOSO\svc-keyfactor",
    "SERVICEPASSWORD=ServiceAccountPassword123!"
) -Wait -NoNewWindow

# Step 4: Copy license file
Copy-Item "C:\Temp\keyfactor.lic" -Destination "C:\Program Files\Keyfactor\Keyfactor Command\license.lic"

# Step 5: Configure IIS bindings
Import-Module WebAdministration

# Create HTTPS binding with self-signed cert (temporary)
$cert = New-SelfSignedCertificate -DnsName "keyfactor.contoso.com" -CertStoreLocation Cert:\LocalMachine\My

New-WebBinding -Name "Keyfactor" -Protocol https -Port 443
$binding = Get-WebBinding -Name "Keyfactor" -Protocol https
$binding.AddSslCertificate($cert.Thumbprint, "My")

# Step 6: Start Keyfactor services
Start-Service -Name "Keyfactor*"

# Step 7: Verify installation
Start-Sleep -Seconds 30
Invoke-WebRequest -Uri "https://localhost/Keyfactor" -UseBasicParsing
```

**Validation**:
```powershell
# Check services are running
Get-Service -Name "Keyfactor*"

# Verify IIS application pool
Get-IISAppPool -Name "Keyfactor"

# Check database connectivity
sqlcmd -S $sqlServer -U $username -P $password -Q "SELECT @@VERSION"

# Access web interface
Start-Process "https://keyfactor.contoso.com/Keyfactor"

# Expected: Login page appears

# Verify logs for errors
Get-Content "C:\Program Files\Keyfactor\Keyfactor Command\logs\keyfactor.log" -Tail 50
```

**Rollback**:
```powershell
# Stop services
Stop-Service -Name "Keyfactor*"

# Uninstall Keyfactor
Start-Process msiexec.exe -ArgumentList "/x", "C:\Temp\KeyfactorCommand-10.5.0.msi", "/qn" -Wait

# Drop database (CAUTION!)
sqlcmd -S $sqlServer -U $username -P $password -Q "DROP DATABASE keyfactor"
```

**Time Estimate**: 3 hours (primary node), 2 hours (secondary node)  
**Status**: [ ] vm-keyfactor-01 Complete  [ ] vm-keyfactor-02 Complete

---

#### Task 1.4: Initial Configuration

**Prerequisites**:
- Keyfactor Command installed and accessible
- Admin account created during installation

**Procedure**:

```powershell
# Step 1: Login to Keyfactor Command
# Navigate to https://keyfactor.contoso.com/Keyfactor
# Login with initial admin credentials

# Step 2: Configure SMTP for notifications (via UI)
# Settings → System Settings → Email
# - SMTP Server: smtp.contoso.com
# - Port: 587
# - From Address: keyfactor@contoso.com
# - Authentication: Yes
# - Test email configuration

# Step 3: Configure Active Directory authentication (via UI)
# Settings → Security → Authentication
# - Enable Windows Authentication
# - Configure AD domain: CONTOSO
# - Test AD connectivity

# Step 4: Create initial security roles (via UI)
# Settings → Security → Roles → Add Role
# Role: Certificate Administrator
# Permissions:
#   - Certificate Management: Full Control
#   - Template Management: Full Control
#   - Store Management: Full Control

# Role: Certificate Requester
# Permissions:
#   - Certificate Enrollment: Allow
#   - Certificate View: Allow

# Step 5: Add security principals to roles
# Settings → Security → Role Membership
# Add AD groups:
#   - PKI-Administrators → Certificate Administrator
#   - PKI-Users → Certificate Requester

# Step 6: Configure API access
# Settings → API Settings
# - Enable REST API: Yes
# - API URL: https://keyfactor.contoso.com/KeyfactorAPI
# - OAuth: Enable (optional)

# Step 7: Configure audit logging
# Settings → Audit → Audit Log Settings
# - Enable audit logging: Yes
# - Retention: 365 days
# - Log all certificate operations

# Via PowerShell (alternative):
$apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$cred = Get-Credential  # Admin credentials

# Enable API
Invoke-RestMethod -Uri "$apiUrl/SystemSettings" `
  -Method PUT `
  -Credential $cred `
  -Body (@{
      apiEnabled = $true
      oauthEnabled = $true
  } | ConvertTo-Json) `
  -ContentType "application/json"
```

**Validation**:
```powershell
# Test SMTP
# Send test email from Settings → Email

# Test AD authentication
# Logout and login with AD credentials

# Test API access
$token = "Bearer YOUR_TOKEN"
Invoke-RestMethod -Uri "$apiUrl/Certificates" `
  -Headers @{Authorization=$token} `
  -Method GET

# Verify roles
Invoke-RestMethod -Uri "$apiUrl/Security/Roles" `
  -Credential $cred `
  -Method GET

# Check audit logs
# Navigate to Reports → Audit Logs
# Verify recent actions are logged
```

**Rollback**:
- N/A (configuration changes, not destructive)
- Can revert individual settings via UI

**Time Estimate**: 4 hours  
**Status**: [ ] Complete

---

### Week 5: Documentation & Sign-Off

#### Task 1.5: Create Runbooks and Documentation

**Prerequisites**:
- Keyfactor Command installed and configured
- All phase 1 tasks completed

**Procedure**:

1. **Document as-built configuration**
   - Infrastructure diagram
   - Network topology
   - Service account details
   - Firewall rules
   - Database connection strings

2. **Create operator runbooks**
   - Start/stop procedures
   - Backup/restore procedures
   - Troubleshooting guide
   - Emergency contacts

3. **Conduct knowledge transfer**
   - Operations team training
   - Admin UI walkthrough
   - API demonstration
   - Q&A session

4. **Phase 1 Sign-Off**

**Phase 1 Completion Checklist**:

```
□ Infrastructure provisioned (VMs, networking, storage)
□ SQL Server database created and configured
□ Keyfactor Command installed on primary node
□ Keyfactor Command installed on secondary node (if HA)
□ HTTPS bindings configured with certificates
□ SMTP configured and tested
□ Active Directory authentication configured
□ Security roles and permissions defined
□ API access enabled and tested
□ Audit logging configured
□ Documentation completed
□ Operations team trained
□ Backup procedures documented and tested
□ Disaster recovery plan documented

Sign-Off:
- Project Manager: _________________ Date: _______
- Technical Lead: __________________ Date: _______
- Security Lead: ___________________ Date: _______
- Operations Lead: _________________ Date: _______
```

**Time Estimate**: 1 week  
**Status**: [ ] Complete

---

## Phase 2: CA & HSM Foundation (Weeks 6-9)

**Objective**: Integrate Certificate Authorities, configure HSM, establish trust chains.

**Duration**: 4 weeks  
**Team**: PKI architects, security team, CA administrators

---

### Week 6: CA Integration Planning

#### Task 2.1: Assess Existing CA Infrastructure

**Prerequisites**:
- Access to existing AD CS or EJBCA environment
- CA hierarchy documented
- Current certificate templates inventoried

**Procedure**:

```powershell
# Step 1: Inventory existing AD CS infrastructure
# On AD CS server:
certutil -CAInfo

# List certificate templates
certutil -CATemplates

# Export current templates
Get-CATemplate | Export-Csv -Path "C:\Temp\ca-templates.csv" -NoTypeInformation

# Step 2: Analyze current usage
# Generate report of certificates issued in last 12 months
certutil -view -restrict "Certificate Expiration Date>=01/01/2024" -out "RequesterName,CommonName,NotAfter" > C:\Temp\cert-report.txt

# Step 3: Document CA hierarchy
certutil -CAInfo chain

# Step 4: Identify certificates for migration
# Create inventory of certificates to be managed by Keyfactor
# Priority: Public-facing TLS certificates, expiring soon

# Step 5: Create migration plan
# Document:
# - Which CAs will be integrated first
# - Which templates will be migrated
# - Certificate renewal strategy
# - Timeline and dependencies
```

**Validation**:
- CA inventory document created
- Template list exported
- Certificate inventory completed
- Migration plan approved by stakeholders

**Time Estimate**: 1 week  
**Status**: [ ] Complete

---

### Week 7-8: CA Gateway Installation

#### Task 2.2: Install Microsoft AD CS Gateway

**Prerequisites**:
- AD CS infrastructure accessible
- Gateway server or VM provisioned
- Keyfactor Command operational

**Procedure**:

```powershell
# Step 1: Download AD CS Gateway from Keyfactor portal
# (Assume downloaded to C:\Temp\ADCS-Gateway-3.0.msi)

# Step 2: Install gateway on dedicated server or Keyfactor Command server
Start-Process msiexec.exe -ArgumentList @(
    "/i", "C:\Temp\ADCS-Gateway-3.0.msi",
    "/qn",
    "/L*V", "C:\Temp\ADCSGatewayInstall.log",
    "COMMANDSERVER=keyfactor.contoso.com",
    "SERVICEACCOUNT=CONTOSO\svc-keyfactor",
    "SERVICEPASSWORD=ServiceAccountPassword123!"
) -Wait -NoNewWindow

# Step 3: Configure gateway in Keyfactor Command
# Navigate to Settings → Certificate Authorities → Add CA
# CA Type: Microsoft CA via Gateway
# Gateway Server: gateway.contoso.com
# CA Name: Contoso-IssuingCA-01

# Via API:
$apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$cred = Get-Credential

$caConfig = @{
    Name = "Contoso-IssuingCA-01"
    Type = "MicrosoftADCS"
    Gateway = "gateway.contoso.com"
    Hostname = "ca-server.contoso.com"
    LogicalName = "Contoso-IssuingCA-01"
    Properties = @{
        TemplatePermissions = "Allow"
        AutoPublish = $true
    }
}

Invoke-RestMethod -Uri "$apiUrl/CertificateAuthorities" `
  -Method POST `
  -Credential $cred `
  -Body ($caConfig | ConvertTo-Json) `
  -ContentType "application/json"

# Step 4: Test CA connectivity
# In Keyfactor UI: Certificate Authorities → Test Connection
# Expected: Success

# Step 5: Sync certificate templates
# Certificate Authorities → Contoso-IssuingCA-01 → Sync Templates
```

**Validation**:
```powershell
# Verify gateway service is running
Get-Service -Name "KeyfactorADCSGateway"

# Test CA connection
Invoke-RestMethod -Uri "$apiUrl/CertificateAuthorities/Contoso-IssuingCA-01/status" `
  -Credential $cred `
  -Method GET

# Verify templates synced
Invoke-RestMethod -Uri "$apiUrl/CertificateAuthorities/Contoso-IssuingCA-01/templates" `
  -Credential $cred `
  -Method GET

# Enroll test certificate
# Navigate to Certificates → Enroll → Select template → Submit
# Verify certificate is issued
```

**Rollback**:
```powershell
# Delete CA from Keyfactor
Invoke-RestMethod -Uri "$apiUrl/CertificateAuthorities/Contoso-IssuingCA-01" `
  -Credential $cred `
  -Method DELETE

# Uninstall gateway
Start-Process msiexec.exe -ArgumentList "/x", "C:\Temp\ADCS-Gateway-3.0.msi", "/qn" -Wait
```

**Time Estimate**: 1 day (per CA)  
**Status**: [ ] Complete

---

#### Task 2.3: (Optional) Deploy EJBCA as Issuing CA

**Prerequisites**:
- Decision to use EJBCA instead of or in addition to AD CS
- Linux/container infrastructure available
- HSM configured (if using HSM)

**Procedure**:

See [KEYFACTOR-INTEGRATIONS-GUIDE.md](#1-ejbca-community-edition) for detailed installation.

```bash
# Quick deployment via Docker Compose
git clone https://github.com/Keyfactor/ejbca-ce.git
cd ejbca-ce/docker

# Configure environment
cp .env.example .env
nano .env
# Set:
# DATABASE_HOST=ejbca-db.contoso.com
# DATABASE_NAME=ejbca
# DATABASE_USER=ejbca
# DATABASE_PASSWORD=SecurePassword123!
# TLS_HOSTNAME=ejbca.contoso.com

# Deploy
docker-compose up -d

# Wait for startup
docker-compose logs -f ejbca

# Configure superadmin certificate
docker exec ejbca-ca /opt/primekey/bin/ejbca.sh ra addendentity \
  --username superadmin \
  --dn "CN=SuperAdmin,O=Contoso,C=US" \
  --type 1 \
  --token P12 \
  --password admin123

# Download superadmin P12
docker cp ejbca-ca:/opt/primekey/superadmin.p12 ./superadmin.p12
```

**Validation**:
```bash
# Access EJBCA admin console
https://ejbca.contoso.com/ejbca/adminweb

# Verify CA is active
curl -k --cert superadmin.p12:admin123 \
  https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1/ca/ManagementCA/status

# Test certificate enrollment
curl -k --cert superadmin.p12:admin123 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"certificate_request":"<BASE64_CSR>"}' \
  https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1/certificate/enroll/pkcs10
```

**Time Estimate**: 2 days  
**Status**: [ ] Complete

---

### Week 9: HSM Integration

#### Task 2.4: Configure Azure Managed HSM

**Prerequisites**:
- Azure subscription with HSM quota approved
- Permissions to create Managed HSM
- Key Vault premium tier available

**Procedure**:

```bash
# Step 1: Create Managed HSM
az keyvault create \
  --name kv-keyfactor-hsm-prod \
  --resource-group rg-keyfactor-prod \
  --location eastus \
  --sku premium

# Step 2: Enable HSM-backed keys
az keyvault key create \
  --vault-name kv-keyfactor-hsm-prod \
  --name ca-signing-key \
  --kty RSA-HSM \
  --size 4096 \
  --ops sign verify \
  --protection hsm

# Step 3: Grant Keyfactor service account access
az keyvault set-policy \
  --name kv-keyfactor-hsm-prod \
  --object-id <KEYFACTOR_MANAGED_IDENTITY_OBJECT_ID> \
  --key-permissions get list sign verify

# Step 4: Configure EJBCA to use Azure HSM
# In EJBCA:
# Crypto Tokens → Create New
# Type: Azure Key Vault
# Vault URL: https://kv-keyfactor-hsm-prod.vault.azure.net
# Authentication: Managed Identity
# Key Alias: ca-signing-key

# Step 5: Create CA with HSM-backed key
# Certificate Authorities → Create CA
# Name: Contoso-IssuingCA-HSM
# Crypto Token: Azure Key Vault
# Key: ca-signing-key
# Subject DN: CN=Contoso Issuing CA,O=Contoso,C=US
# Validity: 10 years
```

**Validation**:
```bash
# Verify HSM key exists
az keyvault key show \
  --vault-name kv-keyfactor-hsm-prod \
  --name ca-signing-key

# Test key signing operation
az keyvault key sign \
  --vault-name kv-keyfactor-hsm-prod \
  --name ca-signing-key \
  --algorithm RS256 \
  --value "SGVsbG8gV29ybGQ="

# Verify CA is using HSM
# In EJBCA: Certificate Authorities → Contoso-IssuingCA-HSM
# Crypto Token should show "Azure Key Vault"

# Issue test certificate
# Verify certificate chain includes HSM-backed CA
```

**Rollback**:
```bash
# Delete CA (CAUTION!)
# In EJBCA: Certificate Authorities → Delete

# Delete HSM key
az keyvault key delete \
  --vault-name kv-keyfactor-hsm-prod \
  --name ca-signing-key
```

**Time Estimate**: 1 week  
**Status**: [ ] Complete

---

### Phase 2 Completion Checklist

```
□ CA infrastructure assessed and documented
□ Migration plan created and approved
□ AD CS Gateway installed (if using AD CS)
□ CA integrated with Keyfactor Command
□ Certificate templates synchronized
□ Test certificate issued successfully
□ EJBCA deployed (if applicable)
□ HSM configured and tested
□ CA hierarchy established
□ Root and intermediate certificates distributed
□ CRL/OCSP endpoints configured
□ Trust chains validated
□ Backup procedures for CA keys documented
□ Disaster recovery plan for CA updated

Sign-Off:
- PKI Architect: ___________________ Date: _______
- Security Lead: ___________________ Date: _______
- CA Administrator: ________________ Date: _______
```

---

## Phase 3: Enrollment Rails & Self-Service (Weeks 10-12)

**Objective**: Enable certificate enrollment via multiple protocols (ACME, EST, SCEP, cert-manager).

**Duration**: 3 weeks  
**Team**: DevOps engineers, platform team, PKI operators

---

### Week 10: ACME Server Configuration

#### Task 3.1: Enable ACME Protocol

**Prerequisites**:
- Keyfactor Command 10.x+ installed
- ACME directory URL defined
- Certificate templates configured for ACME

**Procedure**:

```powershell
# Step 1: Enable ACME in Keyfactor Command
# Navigate to Settings → Enrollment → ACME
# - Enable ACME: Yes
# - Directory URL: https://keyfactor.contoso.com/acme/directory
# - Challenge Types: HTTP-01, DNS-01
# - Certificate Validity: 90 days
# - Auto-Renewal: 30 days before expiry

# Step 2: Configure DNS for validation
# Create DNS records:
# _acme-challenge.contoso.com TXT (for DNS-01)

# Step 3: Configure ACME profile
# Enrollment → ACME Profiles → Add Profile
# Name: Web Server ACME
# Template: WebServerTemplate
# Challenge: DNS-01
# Allowed Domains: *.contoso.com, *.internal.contoso.com

# Via API:
$apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$cred = Get-Credential

$acmeProfile = @{
    Name = "WebServerACME"
    Template = "WebServerTemplate"
    ChallengeType = "DNS-01"
    AllowedDomains = @("*.contoso.com", "*.internal.contoso.com")
    Validity = 90
    AutoRenew = $true
}

Invoke-RestMethod -Uri "$apiUrl/ACME/Profiles" `
  -Method POST `
  -Credential $cred `
  -Body ($acmeProfile | ConvertTo-Json) `
  -ContentType "application/json"
```

**Validation**:
```bash
# Test ACME directory
curl https://keyfactor.contoso.com/acme/directory

# Expected output:
# {
#   "newNonce": "https://keyfactor.contoso.com/acme/new-nonce",
#   "newAccount": "https://keyfactor.contoso.com/acme/new-account",
#   "newOrder": "https://keyfactor.contoso.com/acme/new-order",
#   ...
# }

# Test with certbot
certbot certonly \
  --server https://keyfactor.contoso.com/acme/directory \
  --manual \
  --preferred-challenges dns \
  --domain test.contoso.com

# Verify certificate issued
openssl x509 -in /etc/letsencrypt/live/test.contoso.com/cert.pem -noout -text
```

**Rollback**:
```powershell
# Disable ACME
# Settings → Enrollment → ACME → Disable

# Delete ACME profile
Invoke-RestMethod -Uri "$apiUrl/ACME/Profiles/WebServerACME" `
  -Method DELETE `
  -Credential $cred
```

**Time Estimate**: 2 days  
**Status**: [ ] Complete

---

#### Task 3.2: Configure cert-manager for Kubernetes

**Prerequisites**:
- Kubernetes cluster(s) accessible
- cert-manager installed (v1.8+)
- Keyfactor Command issuer deployed

**Procedure**:

See [KEYFACTOR-INTEGRATIONS-GUIDE.md](#4-command-cert-manager-issuer) for detailed installation.

```bash
# Step 1: Install cert-manager (if not already installed)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Step 2: Install Keyfactor Command issuer
git clone https://github.com/Keyfactor/command-cert-manager-issuer.git
cd command-cert-manager-issuer

helm install command-issuer ./charts/command-issuer \
  --namespace command-issuer-system \
  --create-namespace

# Step 3: Create secret with Keyfactor credentials
kubectl create secret generic command-secret \
  --namespace default \
  --from-literal=hostname='https://keyfactor.contoso.com' \
  --from-literal=username='k8s-issuer-api' \
  --from-literal=password='SecurePassword123!'

# Step 4: Configure issuer
cat <<EOF | kubectl apply -f -
apiVersion: command-issuer.keyfactor.com/v1alpha1
kind: CommandIssuer
metadata:
  name: command-issuer-prod
  namespace: default
spec:
  commandSecretName: command-secret
  certificateTemplate: "KubernetesServerAuth"
  certificateAuthority: "Contoso-IssuingCA-01"
  metadata:
    - key: "kubernetes-cluster"
      value: "prod-cluster-01"
EOF

# Step 5: Issue test certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-k8s-cert
  namespace: default
spec:
  secretName: test-k8s-secret
  issuerRef:
    name: command-issuer-prod
    kind: CommandIssuer
    group: command-issuer.keyfactor.com
  commonName: test-app.contoso.com
  dnsNames:
    - test-app.contoso.com
  duration: 2160h  # 90 days
  renewBefore: 720h  # 30 days
EOF
```

**Validation**:
```bash
# Check issuer status
kubectl get commandissuer command-issuer-prod -o yaml

# Check certificate status
kubectl get certificate test-k8s-cert
# Expected: READY=True

# Verify secret created
kubectl get secret test-k8s-secret -o yaml

# Check certificate details
kubectl get secret test-k8s-secret -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

**Rollback**:
```bash
# Delete certificate
kubectl delete certificate test-k8s-cert

# Delete issuer
kubectl delete commandissuer command-issuer-prod

# Uninstall issuer
helm uninstall command-issuer -n command-issuer-system
```

**Time Estimate**: 1 day (per cluster)  
**Status**: [ ] Complete

---

### Week 11-12: Additional Enrollment Methods

#### Task 3.3: Configure EST (Enrollment over Secure Transport)

**Prerequisites**:
- Keyfactor Command supports EST (10.x+)
- Certificate template configured for EST
- Network devices support EST protocol

**Procedure**:

```powershell
# Step 1: Enable EST in Keyfactor Command
# Settings → Enrollment → EST
# - Enable EST: Yes
# - EST URL: https://keyfactor.contoso.com/.well-known/est
# - Authentication: Client Certificate + HTTP Basic
# - Certificate Validity: 365 days

# Step 2: Create EST profile
# Enrollment → EST Profiles → Add Profile
# Name: Network Device EST
# Template: NetworkDeviceTemplate
# Authentication: Mutual TLS
# Allowed Devices: Based on client certificate CN

# Step 3: Test with OpenSSL
# Generate CSR
openssl req -new -newkey rsa:2048 -nodes \
  -keyout device.key \
  -out device.csr \
  -subj "/CN=router01.contoso.com/O=Contoso/C=US"

# Enroll via EST
curl -X POST \
  --cacert ca-cert.pem \
  --cert client-cert.pem \
  --key client-key.pem \
  -H "Content-Type: application/pkcs10" \
  -H "Content-Transfer-Encoding: base64" \
  --data-binary @device.csr.b64 \
  https://keyfactor.contoso.com/.well-known/est/simpleenroll \
  -o device-cert.p7

# Convert PKCS#7 to PEM
openssl pkcs7 -in device-cert.p7 -print_certs -out device-cert.pem
```

**Validation**:
```bash
# Verify EST endpoint
curl https://keyfactor.contoso.com/.well-known/est/cacerts

# Verify certificate enrolled
openssl x509 -in device-cert.pem -noout -text

# Test on actual network device (Cisco example)
# crypto pki trustpoint KeyfactorEST
#   enrollment url https://keyfactor.contoso.com/.well-known/est
#   enrollment retry count 3
#   enrollment mode ra
# crypto pki authenticate KeyfactorEST
# crypto pki enroll KeyfactorEST
```

**Time Estimate**: 2 days  
**Status**: [ ] Complete

---

#### Task 3.4: Configure SCEP (for Legacy Devices)

**Prerequisites**:
- SCEP server component available (NDES or third-party)
- Certificate template configured for SCEP
- Challenge password mechanism defined

**Procedure**:

```powershell
# If using Microsoft NDES:
# Step 1: Install NDES role
Install-WindowsFeature -Name ADCS-Device-Enrollment -IncludeManagementTools

# Step 2: Configure NDES
# Server Manager → AD CS → Configure → Device Enrollment Service
# Service account: CONTOSO\svc-ndes
# CA: Contoso-IssuingCA-01
# Certificate template: IPSECIntermediateOffline

# Step 3: Integrate NDES with Keyfactor
# Keyfactor → Settings → Enrollment → SCEP
# NDES Server: ndes.contoso.com
# Challenge Password: Rotate weekly via script

# Step 4: Test SCEP enrollment
$scepUrl = "https://ndes.contoso.com/certsrv/mscep/mscep.dll"

# Generate challenge password (from Keyfactor or NDES)
$challenge = "CHALLENGE_PASSWORD_12345"

# Enroll certificate (example with iOS profile)
# Create iOS profile with SCEP payload:
# URL: $scepUrl
# Challenge: $challenge
# Subject: CN=$DEVICENAME
# Key Size: 2048
```

**Validation**:
```powershell
# Test SCEP endpoint
Invoke-WebRequest -Uri "$scepUrl?operation=GetCACaps"

# Expected: POSTPKIOperation, Renewal, SHA-256, ...

# Verify NDES is issuing certificates
Get-EventLog -LogName Application -Source Microsoft-Windows-NetworkDeviceEnrollmentService -Newest 20

# Test with device enrollment
# iOS: Settings → General → Profile → Install
# Expected: Certificate appears in Certificates list
```

**Time Estimate**: 2 days  
**Status**: [ ] Complete

---

### Phase 3 Completion Checklist

```
□ ACME server enabled and tested
□ ACME profiles configured for web servers
□ cert-manager issuer deployed to Kubernetes clusters
□ Test certificates issued via cert-manager
□ EST endpoint configured and tested
□ EST enrollment tested with network device
□ SCEP/NDES integrated (if applicable)
□ SCEP tested with mobile devices
□ Self-service enrollment portal configured
□ End-user documentation created
□ Training provided to DevOps teams
□ Enrollment metrics dashboard created

Sign-Off:
- DevOps Lead: ____________________ Date: _______
- Platform Engineer: _______________ Date: _______
- PKI Operator: ____________________ Date: _______
```

---

## Phase 4: Orchestration & Zero-Touch Operations (Weeks 13-16)

**Objective**: Deploy orchestrators, configure certificate stores, enable automated renewal.

**Duration**: 4 weeks  
**Team**: Operations team, orchestrator administrators, platform engineers

---

### Week 13: Universal Orchestrator Deployment

#### Task 4.1: Install Universal Orchestrator

**Prerequisites**:
- Orchestrator server(s) provisioned
- Keyfactor Command operational
- PAM provider configured (optional but recommended)

**Procedure**:

```powershell
# Step 1: Download Universal Orchestrator installer
# (Assume downloaded from Keyfactor portal)

# Step 2: Install orchestrator
Start-Process msiexec.exe -ArgumentList @(
    "/i", "C:\Temp\KeyfactorUniversalOrchestrator-10.5.0.msi",
    "/qn",
    "/L*V", "C:\Temp\OrchestratorInstall.log",
    "COMMANDSERVER=keyfactor.contoso.com",
    "SERVICEACCOUNT=CONTOSO\svc-orchestrator",
    "SERVICEPASSWORD=OrchestratorPassword123!"
) -Wait -NoNewWindow

# Step 3: Register orchestrator with Keyfactor Command
# Navigate to Settings → Orchestrators → Add Orchestrator
# Name: Orchestrator-01
# Hostname: orchestrator-01.contoso.com
# Status: Active

# Or via API:
$apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$cred = Get-Credential

$orchestrator = @{
    AgentName = "Orchestrator-01"
    HostName = "orchestrator-01.contoso.com"
    Status = "Active"
    Capabilities = @("IIS", "AzureKeyVault", "F5")
}

Invoke-RestMethod -Uri "$apiUrl/Agents" `
  -Method POST `
  -Credential $cred `
  -Body ($orchestrator | ConvertTo-Json) `
  -ContentType "application/json"

# Step 4: Install orchestrator extensions
# Copy extension DLLs to C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\

# Azure Key Vault extension
Copy-Item "C:\Temp\AzureKeyVault\*" `
  -Destination "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\AzureKeyVault" `
  -Recurse

# IIS extension
Copy-Item "C:\Temp\IIS\*" `
  -Destination "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\IIS" `
  -Recurse

# Step 5: Restart orchestrator service
Restart-Service "KeyfactorOrchestrator"

# Step 6: Verify orchestrator is online
Start-Sleep -Seconds 30
```

**Validation**:
```powershell
# Check orchestrator service
Get-Service "KeyfactorOrchestrator"

# Verify registration in Keyfactor
Invoke-RestMethod -Uri "$apiUrl/Agents/Orchestrator-01" `
  -Credential $cred `
  -Method GET

# Expected: Status = "Active", LastSeen = recent timestamp

# Check orchestrator logs
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\orchestrator.log" -Tail 50

# Verify extensions loaded
Get-ChildItem "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions"
```

**Rollback**:
```powershell
# Unregister from Keyfactor
Invoke-RestMethod -Uri "$apiUrl/Agents/Orchestrator-01" `
  -Credential $cred `
  -Method DELETE

# Uninstall orchestrator
Start-Process msiexec.exe -ArgumentList "/x", "C:\Temp\KeyfactorUniversalOrchestrator-10.5.0.msi", "/qn" -Wait
```

**Time Estimate**: 2 hours (per orchestrator)  
**Status**: [ ] Complete

---

### Week 14-15: Certificate Store Configuration

#### Task 4.2: Configure IIS Certificate Stores

**Prerequisites**:
- Universal Orchestrator installed with IIS extension
- IIS servers identified and accessible via WinRM
- Service account with admin rights on target servers

**Procedure**:

```powershell
# Step 1: Enable WinRM on target IIS servers
# (Run on each IIS server)
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Service\Auth\Windows -Value $true

# Step 2: Configure store type in Keyfactor Command
# Settings → Certificate Locations → Store Types → Add
# Name: IIS Binding
# Short Name: IISB
# Supports: Management Add, Discovery, Inventory

# Step 3: Add certificate store for each IIS server
# Navigate to Certificate Locations → Certificate Stores → Add
# Or via API:

$servers = @("webapp01", "webapp02", "api01")

foreach ($server in $servers) {
    $store = @{
        StoreType = "IISB"
        ClientMachine = "$server.contoso.com"
        StorePath = "Default Web Site"
        AgentId = "Orchestrator-01"
        Properties = @{
            SiteName = "Default Web Site"
            Port = "443"
            IPAddress = "*"
            HostName = "$server.contoso.com"
            SniFlag = "1"
        }
        Credentials = @{
            UsePAM = $true
            PAMProvider = "CyberArk"
            SecretPath = "Keyfactor-Orchestrator/$server-creds"
        }
        InventorySchedule = "0 2 * * *"  # Daily at 2 AM
    }

    Invoke-RestMethod -Uri "$apiUrl/CertificateStores" `
      -Method POST `
      -Credential $cred `
      -Body ($store | ConvertTo-Json -Depth 10) `
      -ContentType "application/json"
}

# Step 4: Test inventory
# Certificate Stores → Select store → Actions → Inventory Now
```

**Validation**:
```powershell
# Verify stores created
Invoke-RestMethod -Uri "$apiUrl/CertificateStores?storeType=IISB" `
  -Credential $cred `
  -Method GET

# Test WinRM connectivity from orchestrator
Test-WSMan -ComputerName webapp01.contoso.com

# Run inventory job
# Dashboard → Orchestrator Jobs → Filter by Store Type: IISB
# Expected: Status = Success

# Verify certificates discovered
# Certificates → Filter by Location: webapp01.contoso.com
# Expected: IIS certificates listed
```

**Rollback**:
```powershell
# Delete stores
foreach ($server in $servers) {
    $storeId = (Invoke-RestMethod -Uri "$apiUrl/CertificateStores?clientMachine=$server.contoso.com" -Credential $cred).Id
    Invoke-RestMethod -Uri "$apiUrl/CertificateStores/$storeId" `
      -Method DELETE `
      -Credential $cred
}
```

**Time Estimate**: 1 hour (per server type), 3 days total  
**Status**: [ ] Complete

---

#### Task 4.3: Configure Azure Key Vault Stores

**Prerequisites**:
- Azure Key Vaults created
- Service Principal with Key Vault access
- Universal Orchestrator with Azure Key Vault extension

**Procedure**:

See [KEYFACTOR-INTEGRATIONS-GUIDE.md](#5-azure-key-vault-orchestrator) for detailed configuration.

```bash
# Step 1: Create Service Principal for orchestrator
az ad sp create-for-rbac --name "Keyfactor-Orchestrator-SP" \
  --role "Key Vault Certificates Officer"

# Output: appId, password, tenant

# Step 2: Grant Key Vault permissions
az keyvault set-policy \
  --name mykeyvault-prod \
  --spn <appId> \
  --certificate-permissions get list import delete

# Step 3: Configure store in Keyfactor Command
# Certificate Stores → Add
# Type: Azure Key Vault
# Client Machine: mykeyvault-prod
# Store Path: mykeyvault-prod
# Properties:
#   AzureCloud: AzureCloud
#   VaultName: mykeyvault-prod
#   SubscriptionId: <subscription-id>
#   TenantId: <tenant-id>
#   ApplicationId: <appId>
#   ClientSecret: <password>
# Agent: Orchestrator-01

# Via PowerShell:
$akvStore = @{
    StoreType = "AKV"
    ClientMachine = "mykeyvault-prod"
    StorePath = "mykeyvault-prod"
    AgentId = "Orchestrator-01"
    Properties = @{
        AzureCloud = "AzureCloud"
        VaultName = "mykeyvault-prod"
        SubscriptionId = "<subscription-id>"
        TenantId = "<tenant-id>"
        ApplicationId = "<appId>"
        ClientSecret = "<password>"
    }
    InventorySchedule = "0 */6 * * *"  # Every 6 hours
}

Invoke-RestMethod -Uri "$apiUrl/CertificateStores" `
  -Method POST `
  -Credential $cred `
  -Body ($akvStore | ConvertTo-Json -Depth 10) `
  -ContentType "application/json"

# Step 4: Test inventory
```

**Validation**:
```bash
# Verify Service Principal access
az keyvault certificate list --vault-name mykeyvault-prod --spn <appId>

# Test inventory in Keyfactor
# Certificate Stores → mykeyvault-prod → Inventory Now
# Expected: Certificates from Key Vault listed

# Verify orchestrator job
# Dashboard → Orchestrator Jobs → Filter by mykeyvault-prod
# Expected: Status = Success
```

**Time Estimate**: 1 hour (per Key Vault)  
**Status**: [ ] Complete

---

### Week 16: Automated Renewal Configuration

#### Task 4.4: Enable Auto-Renewal Workflows

**Prerequisites**:
- Certificate stores configured
- Renewal policies defined
- Notification templates configured

**Procedure**:

```powershell
# Step 1: Configure renewal settings
# Settings → Certificate Management → Renewal Settings
# - Default Renewal Period: 30 days before expiry
# - Auto-Renew Enabled: Yes
# - Notify on Renewal: Yes
# - Retry Failed Renewals: 3 times

# Step 2: Create renewal workflow
# Workflows → Add Workflow
# Trigger: Certificate Expiry (30 days before)
# Conditions: Metadata.automated = true
# Actions:
#   1. Renew Certificate
#   2. Deploy to All Stores
#   3. Send Notification

# Via API:
$workflow = @{
    Name = "Auto-Renewal-Workflow"
    Trigger = @{
        Type = "CertificateExpiry"
        DaysBefore = 30
    }
    Conditions = @(
        @{
            Field = "Metadata.automated"
            Operator = "equals"
            Value = "true"
        }
    )
    Actions = @(
        @{
            Type = "RenewCertificate"
            Parameters = @{
                UseExistingKey = $false
                RenewWithSameTemplate = $true
            }
        },
        @{
            Type = "DeployToStores"
            Parameters = @{
                DeployToAll = $true
                RemoveOldCertificate = $true
            }
        },
        @{
            Type = "SendNotification"
            Parameters = @{
                Template = "CertificateRenewed"
                Recipients = "pki-team@contoso.com"
            }
        }
    )
}

Invoke-RestMethod -Uri "$apiUrl/Workflows" `
  -Method POST `
  -Credential $cred `
  -Body ($workflow | ConvertTo-Json -Depth 10) `
  -ContentType "application/json"

# Step 3: Tag certificates for auto-renewal
# Certificates → Select certificates → Bulk Actions → Update Metadata
# Set: automated = true

# Step 4: Test workflow
# Certificates → Select test certificate
# Set expiry to 29 days from now (for testing)
# Wait for workflow to trigger (check every 15 minutes)
```

**Validation**:
```powershell
# Verify workflow created
Invoke-RestMethod -Uri "$apiUrl/Workflows" -Credential $cred

# Check workflow execution history
Invoke-RestMethod -Uri "$apiUrl/Workflows/Auto-Renewal-Workflow/executions" -Credential $cred

# Monitor renewal jobs
# Dashboard → Certificate Operations → Renewals
# Expected: Renewals happening automatically

# Verify notifications sent
# Check email: pki-team@contoso.com
# Expected: "Certificate Renewed" notification

# Check orchestrator deployed renewed cert
# Certificate Stores → View certificate locations
# Expected: New certificate deployed to all stores
```

**Rollback**:
```powershell
# Disable workflow
Invoke-RestMethod -Uri "$apiUrl/Workflows/Auto-Renewal-Workflow/disable" `
  -Method POST `
  -Credential $cred

# Remove automated tag from certificates
# Certificates → Bulk Actions → Update Metadata
# Remove: automated tag
```

**Time Estimate**: 2 days  
**Status**: [ ] Complete

---

### Phase 4 Completion Checklist

```
□ Universal Orchestrators deployed (minimum 2 for HA)
□ Orchestrator extensions installed
□ PAM provider configured (HashiCorp Vault or CyberArk)
□ IIS certificate stores configured
□ Azure Key Vault stores configured
□ F5/load balancer stores configured (if applicable)
□ Certificate inventory completed for all stores
□ Auto-renewal workflows configured
□ Test renewal executed successfully
□ Notification templates configured
□ Certificate deployment tested
□ Service restart hooks configured
□ Monitoring dashboard for orchestrator jobs
□ Escalation procedures documented

Sign-Off:
- Operations Lead: _________________ Date: _______
- Orchestrator Admin: ______________ Date: _______
- Platform Engineer: _______________ Date: _______
```

---

## Phase 5: Optimization & Scaling (Weeks 17-20)

**Objective**: Optimize performance, implement monitoring, scale to production load.

**Duration**: 4 weeks  
**Team**: Operations, monitoring team, performance engineers

---

### Week 17-18: Monitoring & Observability

#### Task 5.1: Configure Monitoring Dashboard

**Prerequisites**:
- Monitoring platform available (Azure Monitor, Datadog, Grafana, etc.)
- Keyfactor API access for metrics
- Log aggregation configured

**Procedure**:

```powershell
# Step 1: Enable Prometheus metrics (if using Prometheus/Grafana)
# Configure Keyfactor to expose metrics endpoint
# Settings → Monitoring → Prometheus
# Enable: Yes
# Endpoint: https://keyfactor.contoso.com/metrics

# Step 2: Configure Azure Monitor (if using Azure)
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group rg-keyfactor-prod \
  --workspace-name la-keyfactor-prod \
  --location eastus

# Install Azure Monitor agent on Keyfactor servers
# VM → Extensions → Add → Azure Monitor Agent

# Configure data collection
az monitor data-collection-rule create \
  --resource-group rg-keyfactor-prod \
  --name dcr-keyfactor-logs \
  --location eastus \
  --rule-file keyfactor-dcr.json

# Step 3: Create dashboard
# Azure Monitor → Dashboards → New Dashboard
# Add tiles:
# - Certificate Expiry (next 30 days)
# - Enrollment Rate
# - Renewal Success Rate
# - Orchestrator Job Status
# - API Response Time

# Or via ARM template:
az deployment group create \
  --resource-group rg-keyfactor-prod \
  --template-file keyfactor-dashboard.json

# Step 4: Configure alerts
# Azure Monitor → Alerts → New Alert Rule

# Alert 1: Certificate Expiry
# Condition: Count of certificates expiring in 7 days > 10
# Action: Email pki-team@contoso.com

# Alert 2: Orchestrator Job Failure
# Condition: Failed orchestrator jobs > 5% in 1 hour
# Action: Create incident in ServiceNow

# Alert 3: API High Latency
# Condition: API P95 latency > 2 seconds
# Action: Page on-call engineer

# Via PowerShell:
$alertRules = @(
    @{
        Name = "CertificateExpirySoon"
        Query = "SELECT COUNT(*) FROM Certificates WHERE NotAfter <= DATEADD(day, 7, GETDATE())"
        Threshold = 10
        ActionGroup = "pki-team-email"
    },
    @{
        Name = "OrchestratorJobFailure"
        Query = "SELECT (COUNT(CASE WHEN Status='Failed' THEN 1 END) * 100.0 / COUNT(*)) as FailureRate FROM OrchestratorJobs WHERE StartTime >= DATEADD(hour, -1, GETDATE())"
        Threshold = 5
        ActionGroup = "servicenow-incident"
    }
)

foreach ($rule in $alertRules) {
    # Create alert via Azure Monitor API or CLI
}
```

**Validation**:
```powershell
# Verify metrics endpoint
Invoke-WebRequest -Uri "https://keyfactor.contoso.com/metrics"

# Check Log Analytics data ingestion
az monitor log-analytics query \
  --workspace la-keyfactor-prod \
  --analytics-query "KeyfactorLogs | take 10"

# View dashboard
# Navigate to Azure Portal → Dashboards → Keyfactor Dashboard

# Test alerts
# Trigger alert condition (e.g., manually fail an orchestrator job)
# Verify alert fires and notification sent
```

**Time Estimate**: 1 week  
**Status**: [ ] Complete

---

### Week 19: Performance Optimization

#### Task 5.2: Database Performance Tuning

**Prerequisites**:
- Access to SQL Server database
- Baseline performance metrics collected
- Database backup taken

**Procedure**:

```sql
-- Step 1: Analyze current performance
-- Connect to SQL Server
USE keyfactor;

-- Check table sizes
SELECT 
    t.name AS TableName,
    p.rows AS RowCounts,
    (SUM(a.total_pages) * 8) / 1024 AS TotalSpaceMB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
GROUP BY t.name, p.rows
ORDER BY TotalSpaceMB DESC;

-- Step 2: Add missing indexes
-- Analyze execution plans and add recommended indexes

-- Index for certificate searches by thumbprint
CREATE NONCLUSTERED INDEX IX_Certificates_Thumbprint
ON Certificates(Thumbprint)
INCLUDE (SerialNumber, NotAfter, Subject);

-- Index for expiry queries
CREATE NONCLUSTERED INDEX IX_Certificates_NotAfter
ON Certificates(NotAfter)
WHERE NotAfter >= GETDATE();

-- Index for orchestrator jobs
CREATE NONCLUSTERED INDEX IX_OrchestratorJobs_Status_StartTime
ON OrchestratorJobs(Status, StartTime DESC);

-- Step 3: Update statistics
UPDATE STATISTICS Certificates WITH FULLSCAN;
UPDATE STATISTICS CertificateStores WITH FULLSCAN;
UPDATE STATISTICS OrchestratorJobs WITH FULLSCAN;

-- Step 4: Configure maintenance plans
-- Create job for index maintenance (rebuild/reorganize)
-- Schedule: Weekly, off-hours

-- Step 5: Optimize SQL Server settings
-- Increase max server memory (leave 4GB for OS)
EXEC sp_configure 'max server memory (MB)', 12288;  -- 12 GB
RECONFIGURE;

-- Enable query store for monitoring
ALTER DATABASE keyfactor SET QUERY_STORE = ON;
ALTER DATABASE keyfactor SET QUERY_STORE (OPERATION_MODE = READ_WRITE);

-- Step 6: Implement archival strategy
-- Archive old certificates to separate table
CREATE TABLE CertificatesArchive (
    -- Same schema as Certificates table
    -- ...
);

-- Move certificates older than 2 years
INSERT INTO CertificatesArchive
SELECT * FROM Certificates
WHERE NotAfter < DATEADD(year, -2, GETDATE());

DELETE FROM Certificates
WHERE NotAfter < DATEADD(year, -2, GETDATE());
```

**Validation**:
```sql
-- Check index usage
SELECT 
    OBJECT_NAME(ixs.object_id) AS TableName,
    ix.name AS IndexName,
    ixs.user_seeks + ixs.user_scans + ixs.user_lookups AS TotalReads,
    ixs.user_updates AS TotalWrites
FROM sys.dm_db_index_usage_stats ixs
INNER JOIN sys.indexes ix ON ixs.object_id = ix.object_id AND ixs.index_id = ix.index_id
WHERE ixs.database_id = DB_ID('keyfactor')
ORDER BY TotalReads DESC;

-- Measure query performance
-- Run sample queries and compare execution time
SET STATISTICS TIME ON;
SELECT * FROM Certificates WHERE NotAfter <= DATEADD(day, 30, GETDATE());
SET STATISTICS TIME OFF;

-- Check wait statistics
SELECT TOP 10
    wait_type,
    wait_time_ms / 1000.0 AS wait_time_sec,
    waiting_tasks_count
FROM sys.dm_os_wait_stats
ORDER BY wait_time_ms DESC;
```

**Time Estimate**: 2 days  
**Status**: [ ] Complete

---

#### Task 5.3: Application Performance Optimization

**Prerequisites**:
- Performance baseline established
- Load testing tools configured
- Monitoring in place

**Procedure**:

```powershell
# Step 1: Configure application pool settings
# On Keyfactor Command servers
Import-Module WebAdministration

# Increase worker processes for multi-core systems
Set-ItemProperty "IIS:\AppPools\Keyfactor" -Name processModel.maxProcesses -Value 4

# Increase queue length
Set-ItemProperty "IIS:\AppPools\Keyfactor" -Name queueLength -Value 2000

# Configure recycling
Set-ItemProperty "IIS:\AppPools\Keyfactor" -Name recycling.periodicRestart.time -Value "00:00:00"
Set-ItemProperty "IIS:\AppPools\Keyfactor" -Name recycling.periodicRestart.memory -Value 2097152  # 2 GB

# Step 2: Configure connection pooling
# Edit web.config
$webConfig = "C:\inetpub\wwwroot\Keyfactor\web.config"
# Update connection string:
# Add: Min Pool Size=10;Max Pool Size=100;

# Step 3: Enable output caching for static content
# web.config
<system.webServer>
  <caching>
    <profiles>
      <add extension=".js" policy="CacheUntilChange" kernelCachePolicy="CacheUntilChange" duration="30.00:00:00" />
      <add extension=".css" policy="CacheUntilChange" kernelCachePolicy="CacheUntilChange" duration="30.00:00:00" />
    </profiles>
  </caching>
</system.webServer>

# Step 4: Configure API rate limiting
# To prevent abuse and ensure fair usage
# Settings → API Settings → Rate Limiting
# - Requests per minute: 300
# - Burst: 500
# - Per IP: Enabled

# Step 5: Load test
# Using Apache Bench
ab -n 1000 -c 10 https://keyfactor.contoso.com/KeyfactorAPI/Certificates

# Or using k6
k6 run --vus 50 --duration 5m keyfactor-load-test.js

# Step 6: Analyze results and tune
# Monitor CPU, memory, response times
# Adjust worker processes, connection pool based on results
```

**Validation**:
```powershell
# Check application pool settings
Get-ItemProperty "IIS:\AppPools\Keyfactor" | Select-Object processModel, recycling, queueLength

# Monitor performance counters
Get-Counter '\Process(w3wp)\% Processor Time'
Get-Counter '\Process(w3wp)\Working Set'

# Check API response times
Measure-Command { Invoke-RestMethod -Uri "$apiUrl/Certificates?take=100" -Credential $cred }

# Expected: < 500ms for p95

# Verify rate limiting
# Make rapid API calls
for ($i=0; $i -lt 400; $i++) {
    Invoke-RestMethod -Uri "$apiUrl/Certificates" -Credential $cred
}
# Expected: 429 Too Many Requests after limit exceeded
```

**Time Estimate**: 2 days  
**Status**: [ ] Complete

---

### Week 20: Production Readiness & Scaling

#### Task 5.4: Disaster Recovery Testing

**Prerequisites**:
- Backup procedures documented
- DR environment provisioned
- Runbooks created

**Procedure**:

```powershell
# Step 1: Backup Keyfactor database
# Create full backup
sqlcmd -S sqlserver-keyfactor-prod.database.windows.net -U keyfactoradmin -P password -Q @"
BACKUP DATABASE keyfactor
TO DISK = '/var/backups/keyfactor_full.bak'
WITH COMPRESSION, CHECKSUM;
"@

# Or via Azure
az sql db export \
  --resource-group rg-keyfactor-prod \
  --server sqlserver-keyfactor-prod \
  --name keyfactor \
  --admin-user keyfactoradmin \
  --admin-password password \
  --storage-key-type StorageAccessKey \
  --storage-key <storage-key> \
  --storage-uri https://stkeyfactorbackup.blob.core.windows.net/backups/keyfactor.bacpac

# Step 2: Backup configuration files
$backupPath = "\\backup-server\keyfactor\$(Get-Date -Format yyyyMMdd)"
New-Item -Path $backupPath -ItemType Directory -Force

# Backup Keyfactor config
Copy-Item "C:\Program Files\Keyfactor\Keyfactor Command\web.config" -Destination $backupPath
Copy-Item "C:\Program Files\Keyfactor\Keyfactor Command\appsettings.json" -Destination $backupPath

# Backup IIS config
webcmd export /c /p "$backupPath\IIS-config.xml"

# Step 3: Test restore to DR environment
# Provision DR infrastructure (DR resource group)
# Restore database
az sql db import \
  --resource-group rg-keyfactor-dr \
  --server sqlserver-keyfactor-dr \
  --name keyfactor \
  --admin-user keyfactoradmin \
  --admin-password password \
  --storage-key-type StorageAccessKey \
  --storage-key <storage-key> \
  --storage-uri https://stkeyfactorbackup.blob.core.windows.net/backups/keyfactor.bacpac

# Install Keyfactor on DR servers
# Restore configuration files
# Update connection strings to point to DR database

# Step 4: Validate DR environment
# Test login to DR Keyfactor instance
# Verify certificates visible
# Test certificate enrollment
# Test orchestrator connectivity

# Step 5: Calculate RTO/RPO
# RTO (Recovery Time Objective): Time to restore service
# RPO (Recovery Point Objective): Maximum data loss

# Document:
# - Time to provision infrastructure: X hours
# - Time to restore database: Y minutes
# - Time to restore application: Z minutes
# Total RTO: X+Y+Z

# Step 6: Failover testing
# Schedule maintenance window
# Perform controlled failover to DR
# Verify all services operational
# Failback to production
```

**Validation**:
```powershell
# Verify backup exists and is valid
Test-Path "\\backup-server\keyfactor\$(Get-Date -Format yyyyMMdd)\*"

# Test database restore
sqlcmd -S sqlserver-keyfactor-dr.database.windows.net -U keyfactoradmin -P password -Q "SELECT COUNT(*) FROM Certificates"

# Verify DR instance functional
Invoke-WebRequest -Uri "https://keyfactor-dr.contoso.com/Keyfactor"

# Test certificate operations in DR
# Enroll test certificate
# Verify stored in DR database

# Document RTO/RPO achieved
# RTO: < 4 hours
# RPO: < 15 minutes (transaction log backup frequency)
```

**Time Estimate**: 3 days  
**Status**: [ ] Complete

---

### Phase 5 Completion Checklist

```
□ Monitoring dashboard deployed
□ Alerts configured and tested
□ Log aggregation functional
□ Database performance optimized
□ Indexes created and statistics updated
□ Application performance tuned
□ Load testing completed
□ Capacity planning documented
□ Backup procedures automated
□ Disaster recovery tested
□ RTO/RPO objectives met
□ Runbooks updated
□ Knowledge transfer completed
□ Production readiness review passed

Sign-Off:
- Operations Lead: _________________ Date: _______
- Performance Engineer: ____________ Date: _______
- SRE Lead: ________________________ Date: _______
- CISO: ____________________________ Date: _______
```

---

## Appendix A: Rollback Decision Tree

```
Issue Detected During Phase
│
├─ Critical (System Down, Data Loss)
│   └─> IMMEDIATE ROLLBACK
│       1. Stop all services
│       2. Restore from last known good backup
│       3. Notify stakeholders
│       4. Root cause analysis
│
├─ High (Major Functionality Broken)
│   └─> CONDITIONAL ROLLBACK
│       1. Assess impact and scope
│       2. Attempt quick fix (< 2 hours)
│       3. If not resolved → Rollback
│       4. Schedule retry
│
├─ Medium (Minor Issues, Workarounds Available)
│   └─> FIX FORWARD
│       1. Document workaround
│       2. Schedule fix in next sprint
│       3. Monitor closely
│
└─ Low (Cosmetic, Non-Blocking)
    └─> DEFER
        1. Log issue
        2. Add to backlog
        3. Continue implementation
```

---

## Appendix B: Common Issues & Resolutions

### Issue: Keyfactor Service Won't Start

**Symptoms**: Service fails to start, Event Log shows database connection error

**Resolution**:
```powershell
# Check database connectivity
sqlcmd -S sqlserver-keyfactor-prod.database.windows.net -U keyfactoradmin -P password -Q "SELECT @@VERSION"

# Check connection string in web.config
Get-Content "C:\Program Files\Keyfactor\Keyfactor Command\web.config" | Select-String "connectionString"

# Verify service account permissions
# SQL Server → Security → Logins → CONTOSO\svc-keyfactor
# Database → keyfactor → Users → Verify db_owner role

# Restart service
Restart-Service "Keyfactor*"
```

---

### Issue: Orchestrator Jobs Failing

**Symptoms**: Jobs show "Failed" status in dashboard

**Resolution**:
```powershell
# Check orchestrator logs
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\orchestrator.log" -Tail 100

# Common causes:
# 1. Credentials expired/invalid
#    → Update in certificate store configuration
#
# 2. Target server unreachable
#    → Test-NetConnection -ComputerName target-server -Port 443
#
# 3. Extension missing/failed to load
#    → Verify extension DLLs in extensions folder
#    → Check extension-specific log files

# Retry failed job
# Dashboard → Orchestrator Jobs → Select job → Retry
```

---

### Issue: Certificate Enrollment Fails

**Symptoms**: Enrollment request returns error, certificate not issued

**Resolution**:
```powershell
# Check CA connectivity
Invoke-RestMethod -Uri "$apiUrl/CertificateAuthorities/Contoso-IssuingCA-01/status" -Credential $cred

# Verify template permissions
# AD CS: Certificate Templates console → Template → Security
# Ensure requesting user/group has "Enroll" permission

# Check enrollment logs
# Keyfactor → Reports → Audit Logs → Filter: Enrollment

# Test enrollment via API
$enrollRequest = @{
    Template = "WebServerTemplate"
    Subject = "CN=test.contoso.com"
    SANs = @("DNS:test.contoso.com")
}

Invoke-RestMethod -Uri "$apiUrl/Enrollment/CSR" `
  -Method POST `
  -Credential $cred `
  -Body ($enrollRequest | ConvertTo-Json) `
  -ContentType "application/json"
```

---

## Appendix C: Contact Information

| Role | Name | Email | Phone | Escalation Path |
|------|------|-------|-------|-----------------|
| Project Manager | [Name] | pm@contoso.com | x1234 | VP Engineering |
| Technical Lead | [Name] | techlead@contoso.com | x1235 | Director IT |
| PKI Architect | [Name] | pki-arch@contoso.com | x1236 | CISO |
| Operations Lead | [Name] | ops-lead@contoso.com | x1237 | Director Operations |
| Security Lead | [Name] | sec-lead@contoso.com | x1238 | CISO |
| Keyfactor Support | Keyfactor | support@keyfactor.com | +1-216-785-2990 | Account Manager |

---

## Appendix D: Tools & Resources

### Required Software

| Tool | Version | Purpose | Download Link |
|------|---------|---------|---------------|
| SQL Server Management Studio | 19.x | Database administration | https://aka.ms/ssmsfullsetup |
| Azure CLI | 2.50+ | Azure resource management | https://aka.ms/installazurecliwindows |
| PowerShell | 7.3+ | Automation scripts | https://aka.ms/powershell |
| OpenSSL | 3.x | Certificate testing | https://slproweb.com/products/Win32OpenSSL.html |
| Postman | Latest | API testing | https://www.postman.com/downloads/ |
| Visual Studio Code | Latest | Script editing | https://code.visualstudio.com/ |

---

**Document Version**: 1.0  
**Last Updated**: October 22, 2025  
**Author**: Adrian Johnson <adrian207@gmail.com>

**End of Implementation Runbooks**

