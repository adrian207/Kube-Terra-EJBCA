# Service Owner Guide
## Certificate Lifecycle Management for Developers and Service Owners

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 23, 2025  
**Classification**: Internal Use  
**Target Audience**: Developers, service owners, application teams

---

## Document Purpose

This guide provides application developers and service owners with everything they need to know about requesting, managing, and troubleshooting certificates for their services. It covers self-service options, best practices, and common scenarios.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Understanding Certificate Templates](#2-understanding-certificate-templates)
3. [Requesting Certificates](#3-requesting-certificates)
4. [Certificate Lifecycle](#4-certificate-lifecycle)
5. [Integration Patterns](#5-integration-patterns)
6. [Troubleshooting](#6-troubleshooting)
7. [Best Practices](#7-best-practices)
8. [FAQ](#8-faq)

---

## 1. Quick Start

### 1.1 I Just Need a Certificate - What Do I Do?

**Choose your platform**:

| Platform | Method | Time to Certificate | Documentation Link |
|----------|--------|-------------------|-------------------|
| **Kubernetes** | Apply `Certificate` CRD | < 5 minutes | [§ 3.4](#34-kubernetes-cert-manager) |
| **Azure App Service** | Azure Key Vault integration | < 10 minutes | [§ 3.5](#35-azure-app-service) |
| **Windows Server** | GPO auto-enrollment | Automatic | [§ 3.6](#36-windows-servers) |
| **Linux Server** | ACME (certbot) | < 5 minutes | [§ 3.3](#33-acme-protocol-linux-containers) |
| **Network Device** | SCEP enrollment | < 15 minutes | [§ 3.7](#37-network-devices) |
| **Custom App** | Keyfactor API | < 10 minutes | [§ 3.8](#38-api-based-custom-integrations) |
| **One-off / Special** | Self-service portal | < 30 minutes | [§ 3.2](#32-self-service-web-portal) |

### 1.2 Before You Start

**You'll Need**:
1. ✅ **Hostname**: The FQDN for your service (e.g., `api.contoso.com`)
2. ✅ **Authorization**: You must own the domain/hostname (verified via asset inventory)
3. ✅ **Template**: Know which certificate template to use (see [§ 2](#2-understanding-certificate-templates))
4. ✅ **Deployment**: Where will the certificate be deployed? (Key Vault, file, container)

**Common Scenarios**:
- **Internal website**: Use `TLS-Server-Internal` template
- **Public-facing website**: Use `TLS-Server-Public` template  
- **API service**: Use `TLS-Server-Internal` template
- **Client authentication**: Use `TLS-Client-Auth` template
- **Code signing**: Use `Code-Signing` template (requires approval)

---

## 2. Understanding Certificate Templates

### 2.1 Available Templates

| Template Name | Purpose | Validity | Key Size | Approval Required |
|---------------|---------|----------|----------|-------------------|
| **TLS-Server-Internal** | Internal HTTPS services | 1 year | RSA 2048 | ❌ Auto |
| **TLS-Server-Public** | Public-facing HTTPS | 90 days | RSA 2048 | ❌ Auto |
| **TLS-Server-Extended** | Long-lived internal services | 2 years | RSA 2048 | ✅ Required |
| **TLS-Client-Auth** | Client certificate authentication | 1 year | RSA 2048 | ❌ Auto |
| **Code-Signing** | Software code signing | 3 years | RSA 4096 | ✅ Required |
| **Email-Protection** | S/MIME email encryption | 2 years | RSA 2048 | ❌ Auto |
| **Wildcard-Internal** | Wildcard certificates (*.contoso.com) | 1 year | RSA 2048 | ✅ Required |

**See**: [03-Policy-Catalog.md](./03-Policy-Catalog.md) for complete template details

### 2.2 Which Template Should I Use?

**Decision Tree**:
```
What kind of certificate do you need?
├─ HTTPS/TLS Server Certificate
│  ├─ Internal service? → TLS-Server-Internal
│  ├─ Public-facing? → TLS-Server-Public
│  └─ Need long validity (2+ years)? → TLS-Server-Extended (requires approval)
│
├─ Client Authentication
│  └─ User or device authentication → TLS-Client-Auth
│
├─ Code Signing
│  └─ Signing executables, scripts, containers → Code-Signing (requires approval)
│
├─ Email Encryption
│  └─ S/MIME email → Email-Protection
│
└─ Wildcard Certificate
   └─ Multiple subdomains (*.contoso.com) → Wildcard-Internal (requires approval)
```

### 2.3 Authorization Rules

**You can ONLY request certificates for**:
- ✅ Hostnames you own (verified via asset inventory / CMDB)
- ✅ Domains your team is authorized for
- ✅ Services you are tagged as owner of

**Common authorization errors**:
- ❌ "Access denied: You do not own this hostname"
  - **Solution**: Update asset inventory with correct owner
- ❌ "SAN validation failed: example.com not in allowed domains"
  - **Solution**: Request access to domain or use correct domain
- ❌ "Template not authorized for your role"
  - **Solution**: Request access via ServiceNow ticket

---

## 3. Requesting Certificates

### 3.1 Method Comparison

| Method | Best For | Complexity | Auto-Renewal |
|--------|----------|------------|--------------|
| **Kubernetes (cert-manager)** | Containerized apps | ⭐ Easy | ✅ Yes |
| **ACME (certbot)** | Linux servers, containers | ⭐⭐ Moderate | ✅ Yes |
| **GPO Auto-Enrollment** | Windows domain servers | ⭐ Easy (automatic) | ✅ Yes |
| **Azure Key Vault** | Azure services | ⭐ Easy | ✅ Yes (manual setup) |
| **API** | Custom integrations | ⭐⭐⭐ Complex | ✅ Yes (if you implement) |
| **Self-Service Portal** | One-off requests | ⭐ Easy | ❌ Manual renewal |

### 3.2 Self-Service Web Portal

**Use Case**: One-time certificate requests, special scenarios, manual enrollment

**Steps**:
1. **Navigate** to: https://keyfactor.contoso.com
2. **Login** with your corporate credentials
3. **Click** "Request Certificate"
4. **Select** template (e.g., "TLS-Server-Internal")
5. **Enter** details:
   ```
   Common Name (CN): api.contoso.com
   Subject Alternative Names (SANs):
     - api.contoso.com
     - api-backup.contoso.com
   
   Metadata:
     - Owner: your-email@contoso.com
     - Application: Your App Name
     - Environment: Production
   ```
6. **Submit** request
7. **Download** certificate (PEM or PFX format)

**Certificate Formats**:
- **PEM** (for Linux/NGINX/Apache):
  - `certificate.pem` - certificate
  - `private-key.pem` - private key (keep secure!)
  - `ca-chain.pem` - CA chain
- **PFX/P12** (for Windows/IIS):
  - `certificate.pfx` - certificate + private key (password-protected)

**Timeline**:
- ✅ **Auto-approved templates**: Instant (< 30 seconds)
- ⏳ **Approval-required templates**: 1-2 business days

### 3.3 ACME Protocol (Linux, Containers)

**Use Case**: Linux servers, containers, Let's Encrypt-compatible clients

**Supported Clients**:
- `certbot` (recommended for Linux)
- `acme.sh` (lightweight, shell-based)
- `win-acme` (Windows)
- `lego` (Go-based, multi-cloud)

**Example: certbot on Linux**

```bash
# Install certbot
sudo apt-get update
sudo apt-get install -y certbot

# Configure ACME server
export ACME_SERVER="https://keyfactor.contoso.com/acme"
export ACME_EMAIL="your-email@contoso.com"

# Request certificate (HTTP-01 challenge)
sudo certbot certonly \
  --standalone \
  --server $ACME_SERVER \
  --email $ACME_EMAIL \
  --agree-tos \
  --no-eff-email \
  -d api.contoso.com

# Certificate files will be in:
# /etc/letsencrypt/live/api.contoso.com/fullchain.pem
# /etc/letsencrypt/live/api.contoso.com/privkey.pem

# Setup auto-renewal (runs twice daily)
sudo certbot renew --dry-run  # Test renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

**Example: acme.sh (lightweight)**

```bash
# Install acme.sh
curl https://get.acme.sh | sh -s email=your-email@contoso.com

# Set ACME server
export ACME_SERVER="https://keyfactor.contoso.com/acme"

# Request certificate
acme.sh --issue \
  --server $ACME_SERVER \
  -d api.contoso.com \
  --standalone

# Install certificate
acme.sh --install-cert -d api.contoso.com \
  --cert-file /etc/nginx/certs/api.contoso.com.crt \
  --key-file /etc/nginx/certs/api.contoso.com.key \
  --fullchain-file /etc/nginx/certs/api.contoso.com.fullchain.crt \
  --reloadcmd "sudo systemctl reload nginx"

# Auto-renewal is automatic (daily check)
```

**Challenge Types**:
- **HTTP-01**: Webserver must be accessible on port 80 (most common)
- **DNS-01**: Add TXT record to DNS (for wildcards, private networks)
- **TLS-ALPN-01**: TLS-based challenge (port 443)

### 3.4 Kubernetes (cert-manager)

**Use Case**: Kubernetes workloads, microservices, ingress TLS

**Prerequisites**:
- cert-manager installed in your cluster
- Keyfactor `ClusterIssuer` configured by platform team

**Example: Ingress with automatic TLS**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-api-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: "keyfactor-issuer"
spec:
  tls:
  - hosts:
    - api.contoso.com
    secretName: api-tls-secret  # cert-manager will create this
  rules:
  - host: api.contoso.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

**Example: Standalone Certificate**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-certificate
  namespace: production
spec:
  secretName: my-app-tls
  duration: 2160h  # 90 days
  renewBefore: 360h  # Renew 15 days before expiry
  subject:
    organizations:
      - Contoso Inc
  commonName: app.contoso.com
  dnsNames:
    - app.contoso.com
    - app-backup.contoso.com
  issuerRef:
    name: keyfactor-issuer
    kind: ClusterIssuer
    group: keyfactor.com
```

**Using the Certificate in a Pod**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: production
spec:
  containers:
  - name: app
    image: my-app:latest
    volumeMounts:
    - name: tls-certs
      mountPath: "/etc/tls"
      readOnly: true
  volumes:
  - name: tls-certs
    secret:
      secretName: my-app-tls  # Created by cert-manager
```

**Check Certificate Status**:

```bash
# List certificates
kubectl get certificates -n production

# Check certificate details
kubectl describe certificate my-app-certificate -n production

# View certificate in secret
kubectl get secret my-app-tls -n production -o yaml
```

**Auto-Renewal**: ✅ Automatic - cert-manager renews 15 days before expiry

### 3.5 Azure App Service

**Use Case**: Azure App Service, Azure Functions with custom domains

**Option 1: Azure Key Vault Integration (Recommended)**

```bash
# 1. Request certificate and store in Azure Key Vault
#    (Keyfactor orchestrator does this automatically)

# 2. Grant App Service access to Key Vault
az webapp config ssl bind \
  --certificate-source AzureKeyVault \
  --certificate-name api-contoso-com \
  --resource-group my-rg \
  --name my-app-service \
  --ssl-type SNI

# Auto-renewal: ✅ Yes (orchestrator updates Key Vault, App Service auto-syncs)
```

**Option 2: Manual Upload**

```bash
# 1. Download certificate from Keyfactor portal (PFX format)

# 2. Upload to App Service
az webapp config ssl upload \
  --certificate-file certificate.pfx \
  --certificate-password "password" \
  --resource-group my-rg \
  --name my-app-service

# 3. Bind to custom domain
az webapp config hostname add \
  --hostname api.contoso.com \
  --resource-group my-rg \
  --webapp-name my-app-service
```

**Auto-Renewal**: 
- Option 1: ✅ Automatic
- Option 2: ❌ Manual renewal required

### 3.6 Windows Servers (Domain-Joined)

**Use Case**: Windows servers joined to Active Directory domain

**Auto-Enrollment (Recommended)**:

✅ **No action required!** Certificates are automatically enrolled via Group Policy.

**How it works**:
1. Server is domain-joined
2. GPO applies certificate policy
3. Certificate is automatically requested from AD CS
4. Certificate is automatically renewed before expiry
5. Certificate is stored in Windows Certificate Store

**Verify Auto-Enrollment**:

```powershell
# Open Certificate Manager
certlm.msc

# Check for certificate in Personal > Certificates
# Look for certificate with your server's FQDN

# Verify auto-enrollment is working
Get-ChildItem Cert:\LocalMachine\My | Where-Object {
    $_.Subject -like "*$($env:COMPUTERNAME)*"
}

# Check auto-enrollment status
gpresult /r | Select-String "Certificate"
```

**Manual Enrollment** (if auto-enrollment fails):

```powershell
# Request certificate manually
$cert = Get-Certificate -Template "TLS-Server-Internal" `
    -SubjectName "CN=$env:COMPUTERNAME.$env:USERDNSDOMAIN" `
    -DnsName "$env:COMPUTERNAME.$env:USERDNSDOMAIN" `
    -CertStoreLocation Cert:\LocalMachine\My

# Verify certificate
Get-ChildItem Cert:\LocalMachine\My\$($cert.Certificate.Thumbprint)
```

**Bind to IIS**:

```powershell
# Import WebAdministration module
Import-Module WebAdministration

# Bind certificate to IIS site
$cert = Get-ChildItem Cert:\LocalMachine\My | 
    Where-Object { $_.Subject -like "*yourserver*" } | 
    Select-Object -First 1

New-IISSiteBinding -Name "Default Web Site" `
    -BindingInformation "*:443:" `
    -Protocol https `
    -CertificateThumbprint $cert.Thumbprint `
    -CertStoreLocation "Cert:\LocalMachine\My"
```

### 3.7 Network Devices (SCEP)

**Use Case**: Cisco routers/switches, Palo Alto firewalls, F5 load balancers

**SCEP Enrollment Steps**:

1. **Get SCEP URL** from PKI team:
   ```
   https://keyfactor.contoso.com/scep/[scep-profile-id]
   ```

2. **Configure device** (example: Cisco IOS):

```cisco
crypto pki trustpoint KEYFACTOR
 enrollment url http://keyfactor.contoso.com/scep/network-devices
 subject-name CN=router01.contoso.com
 revocation-check none
 rsakeypair KEYFACTOR 2048
 
crypto pki authenticate KEYFACTOR
crypto pki enroll KEYFACTOR
```

3. **Verify enrollment**:

```cisco
show crypto pki certificates
```

**Device-Specific Guides**:
- **Cisco IOS/IOS-XE**: [Link to Cisco SCEP guide]
- **Palo Alto**: [Link to Palo Alto SCEP guide]
- **F5 BIG-IP**: [Link to F5 SCEP guide]

### 3.8 API-Based (Custom Integrations)

**Use Case**: Custom applications, CI/CD pipelines, automation scripts

**Authentication**:

```bash
# Option 1: Username/Password
curl -X POST https://keyfactor.contoso.com/KeyfactorAPI/Auth/Login \
  -H "Content-Type: application/json" \
  -d '{"username": "your-email@contoso.com", "password": "your-password"}' \
  | jq -r '.access_token' > token.txt

# Option 2: API Key (recommended)
export KEYFACTOR_API_KEY="your-api-key"
```

**Request Certificate (Python)**:

```python
import requests
import json

# Configuration
KEYFACTOR_API_URL = "https://keyfactor.contoso.com/KeyfactorAPI"
API_KEY = "your-api-key"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# Generate CSR (using cryptography library)
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

# Generate private key
private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
    backend=default_backend()
)

# Generate CSR
csr = x509.CertificateSigningRequestBuilder().subject_name(
    x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, "api.contoso.com"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Contoso Inc"),
    ])
).add_extension(
    x509.SubjectAlternativeName([
        x509.DNSName("api.contoso.com"),
        x509.DNSName("api-backup.contoso.com"),
    ]),
    critical=False,
).sign(private_key, hashes.SHA256(), default_backend())

csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode('utf-8')

# Submit certificate request
request_data = {
    "CSR": csr_pem,
    "Template": "TLS-Server-Internal",
    "CertificateAuthority": "Contoso-Enterprise-CA",
    "Metadata": {
        "Owner": "your-email@contoso.com",
        "Application": "API Service",
        "Environment": "Production"
    },
    "SANs": {
        "DNS": ["api.contoso.com", "api-backup.contoso.com"]
    }
}

response = requests.post(
    f"{KEYFACTOR_API_URL}/Certificates/Enroll",
    headers=headers,
    json=request_data
)

if response.status_code == 201:
    cert_data = response.json()
    print(f"Certificate issued! ID: {cert_data['CertificateId']}")
    
    # Save certificate
    with open("certificate.pem", "w") as f:
        f.write(cert_data['Certificates'][0])
    
    # Save private key
    with open("private-key.pem", "wb") as f:
        f.write(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ))
    
    print("Certificate saved to certificate.pem")
    print("Private key saved to private-key.pem (keep secure!)")
else:
    print(f"Error: {response.status_code} - {response.text}")
```

**Request Certificate (PowerShell)**:

```powershell
# Configuration
$KeyfactorApiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$ApiKey = "your-api-key"

$headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type" = "application/json"
}

# Generate CSR (simplified - use proper CSR generation in production)
$csr = @"
-----BEGIN CERTIFICATE REQUEST-----
[Your CSR content here]
-----END CERTIFICATE REQUEST-----
"@

# Submit certificate request
$requestBody = @{
    CSR = $csr
    Template = "TLS-Server-Internal"
    CertificateAuthority = "Contoso-Enterprise-CA"
    Metadata = @{
        Owner = "your-email@contoso.com"
        Application = "API Service"
        Environment = "Production"
    }
    SANs = @{
        DNS = @("api.contoso.com", "api-backup.contoso.com")
    }
} | ConvertTo-Json

$response = Invoke-RestMethod `
    -Uri "$KeyfactorApiUrl/Certificates/Enroll" `
    -Method Post `
    -Headers $headers `
    -Body $requestBody

Write-Host "Certificate issued! ID: $($response.CertificateId)"
$response.Certificates[0] | Out-File "certificate.pem"
```

---

## 4. Certificate Lifecycle

### 4.1 Certificate Renewal

**Automatic Renewal**:

Most certificates renew automatically 30 days before expiration:

| Method | Auto-Renewal | Your Action |
|--------|--------------|-------------|
| **Kubernetes (cert-manager)** | ✅ Automatic | None - cert-manager handles it |
| **ACME (certbot)** | ✅ Automatic | Verify certbot.timer is running |
| **Windows GPO** | ✅ Automatic | None - GPO handles it |
| **Azure Key Vault** | ✅ Automatic | Verify orchestrator is running |
| **API** | ⚠️ Your responsibility | Implement renewal logic |
| **Web Portal** | ❌ Manual | Request new cert before expiry |

**Check Certificate Expiry**:

```bash
# Check certificate expiry (Linux)
openssl x509 -in certificate.pem -noout -enddate

# Check certificate expiry (with days remaining)
openssl x509 -in certificate.pem -noout -checkend 2592000  # 30 days
# Exit code 0 = valid for 30+ days, 1 = expires within 30 days
```

```powershell
# Check certificate expiry (Windows/PowerShell)
$cert = Get-ChildItem Cert:\LocalMachine\My | 
    Where-Object { $_.Subject -like "*yourhost*" }
$daysRemaining = ($cert.NotAfter - (Get-Date)).Days
Write-Host "Certificate expires in $daysRemaining days"
```

**Manual Renewal** (if automatic renewal fails):

1. **Request new certificate** using the same method as original
2. **Deploy new certificate** to replace expiring certificate
3. **Revoke old certificate** (optional, but recommended after successful deployment)

### 4.2 Certificate Revocation

**When to Revoke**:
- ✅ Private key compromised or suspected compromise
- ✅ Service decommissioned
- ✅ Certificate no longer needed
- ✅ Incorrect information in certificate
- ❌ **Don't revoke** if just renewing (old cert expires naturally)

**How to Revoke**:

**Option 1: Self-Service Portal**
1. Navigate to https://keyfactor.contoso.com
2. Search for your certificate
3. Click "Revoke"
4. Select reason: "Cessation of Operation" (most common) or "Key Compromise" (emergency)
5. Confirm revocation

**Option 2: API**

```bash
curl -X DELETE https://keyfactor.contoso.com/KeyfactorAPI/Certificates/{cert-id}/Revoke \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "RevocationReason": 5,
    "Comment": "Service decommissioned",
    "EffectiveDate": "2025-10-23T14:30:00Z"
  }'
```

**Revocation Reasons**:
- **Code 1**: Key Compromise (emergency - immediate revocation)
- **Code 5**: Cessation of Operation (most common - service retired)
- **Code 4**: Superseded (replaced by new certificate)

**Timeline**: Revoked certificates appear in CRL within 1 hour

### 4.3 Certificate Replacement

**Scenario**: Replace certificate with new key pair (not a renewal)

**Steps**:
1. **Request new certificate** (generates new key pair)
2. **Deploy new certificate** alongside old certificate
3. **Test** with new certificate
4. **Switch traffic** to new certificate
5. **Revoke old certificate** after successful cutover

---

## 5. Integration Patterns

### 5.1 CI/CD Pipeline Integration

**Scenario**: Automatically request and deploy certificates in deployment pipeline

**Example: Azure DevOps Pipeline**

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  KEYFACTOR_API_URL: 'https://keyfactor.contoso.com/KeyfactorAPI'
  KEYFACTOR_API_KEY: $(KeyfactorApiKey)  # Stored in Azure DevOps secrets

steps:
- task: Bash@3
  displayName: 'Request Certificate from Keyfactor'
  inputs:
    targetType: 'inline'
    script: |
      # Generate CSR
      openssl req -new -newkey rsa:2048 -nodes \
        -keyout private-key.pem \
        -out certificate.csr \
        -subj "/CN=api.contoso.com/O=Contoso Inc"
      
      # Convert CSR to single line
      CSR=$(cat certificate.csr | sed ':a;N;$!ba;s/\n/\\n/g')
      
      # Request certificate via API
      curl -X POST $KEYFACTOR_API_URL/Certificates/Enroll \
        -H "Authorization: Bearer $KEYFACTOR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"CSR\": \"$CSR\", \"Template\": \"TLS-Server-Internal\", \"CertificateAuthority\": \"Contoso-Enterprise-CA\"}" \
        -o response.json
      
      # Extract certificate
      cat response.json | jq -r '.Certificates[0]' > certificate.pem

- task: AzureKeyVault@2
  displayName: 'Upload Certificate to Key Vault'
  inputs:
    azureSubscription: 'Azure Subscription'
    KeyVaultName: 'prod-keyvault'
    SecretsFilter: '*'
    RunAsPreJob: false

- task: AzureCLI@2
  displayName: 'Import Certificate'
  inputs:
    azureSubscription: 'Azure Subscription'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Combine cert and key into PFX
      openssl pkcs12 -export -out certificate.pfx \
        -inkey private-key.pem \
        -in certificate.pem \
        -password pass:temppassword
      
      # Upload to Key Vault
      az keyvault certificate import \
        --vault-name prod-keyvault \
        --name api-contoso-com \
        --file certificate.pfx \
        --password temppassword
```

### 5.2 HashiCorp Vault Integration

**Scenario**: Store Keyfactor certificates in HashiCorp Vault for consumption by applications

**Keyfactor Orchestrator** automatically syncs certificates to Vault (configured by platform team).

**Retrieve Certificate from Vault**:

```bash
# Authenticate to Vault
export VAULT_ADDR="https://vault.contoso.com:8200"
export VAULT_TOKEN="your-vault-token"

# Read certificate from Vault
vault kv get secret/certs/api-contoso-com

# Extract certificate and key
vault kv get -field=certificate secret/certs/api-contoso-com > certificate.pem
vault kv get -field=private_key secret/certs/api-contoso-com > private-key.pem
```

### 5.3 Monitoring Certificate Expiry

**Set up monitoring** to avoid surprises:

**Option 1: Keyfactor Dashboard**
- Navigate to https://keyfactor.contoso.com
- View "My Certificates"
- Filter by "Expires in < 30 days"

**Option 2: Email Alerts** (configured by platform team)
- Receive email 30, 15, and 7 days before expiry
- Automatic for all certificates you own

**Option 3: Prometheus Metrics** (for DevOps teams)

```yaml
# Prometheus exporter for certificate expiry
scrape_configs:
  - job_name: 'certificate-exporter'
    static_configs:
      - targets: ['api.contoso.com:443']
    metrics_path: /probe
    params:
      module: [https]
```

---

## 6. Troubleshooting

### 6.1 Common Issues

#### Issue: "Access Denied - You do not own this hostname"

**Cause**: You're not listed as the owner in the asset inventory

**Solution**:
1. Check asset inventory: https://cmdb.contoso.com (or CSV file)
2. If incorrect, update owner to your email/team
3. Wait 15 minutes for sync
4. Retry certificate request

**Quick Fix**: Contact #pki-support on Slack with hostname

---

#### Issue: "SAN Validation Failed - Domain not authorized"

**Cause**: The domain (e.g., `external.com`) is not in your allowed domains list

**Solution**:
1. Verify domain is correct (check for typos)
2. If domain is correct, request access:
   - Open ServiceNow ticket: Security → PKI Access Request
   - Justify business need
   - Approval from Security team required

**Workaround**: Use an authorized domain if possible (e.g., `*.contoso.com`)

---

#### Issue: "Certificate Enrollment Failed - No Response from CA"

**Cause**: CA is offline or network issue

**Solution**:
1. Check Keyfactor status page: https://status.keyfactor.contoso.com
2. Retry in 5-10 minutes
3. If persistent, contact #pki-support

---

#### Issue: "Certificate Not Renewing Automatically (ACME)"

**Cause**: Certbot renewal timer not running or challenge failing

**Solution**:

```bash
# Check certbot timer status
sudo systemctl status certbot.timer

# If not running, start it
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Test renewal manually
sudo certbot renew --dry-run

# Check logs for errors
sudo journalctl -u certbot -n 50
```

**Common ACME renewal failures**:
- **Port 80 blocked**: HTTP-01 challenge requires port 80 open
- **DNS not resolving**: Verify hostname resolves to server IP
- **Firewall blocking**: Check firewall allows inbound on port 80

---

#### Issue: "Certificate Expired - Services Down!"

**Cause**: Automatic renewal failed and wasn't caught

**EMERGENCY PROCEDURE**:
1. **Request new certificate immediately** using fastest method (API or portal)
2. **Deploy certificate** to affected service
3. **Restart service** to load new certificate
4. **Notify #pki-support** of the incident for post-mortem

**Prevention**:
- Enable monitoring alerts
- Review certificates expiring in next 30 days weekly
- Test renewal process in non-production environments

---

### 6.2 Getting Help

**Self-Service Resources**:
- **Documentation**: This guide and https://keyfactor.contoso.com/docs
- **Status Page**: https://status.keyfactor.contoso.com
- **FAQ**: [§ 8](#8-faq)

**Contact Support**:
| Channel | Response Time | Best For |
|---------|--------------|----------|
| **Slack: #pki-support** | < 2 hours (business hours) | Questions, troubleshooting |
| **Email: pki-team@contoso.com** | < 4 hours (business hours) | Non-urgent requests |
| **ServiceNow Ticket** | < 1 business day | Access requests, approvals |
| **Emergency (Prod Down)** | Call: ext. 9999 | **Production outages only** |

---

## 7. Best Practices

### 7.1 Security

✅ **DO**:
- ✅ Use automated enrollment methods (ACME, cert-manager, GPO)
- ✅ Rotate certificates regularly (even before expiry)
- ✅ Use separate certificates per service (not shared)
- ✅ Store private keys securely (Key Vault, Vault, or file with 600 permissions)
- ✅ Revoke certificates immediately if private key compromised
- ✅ Use strong key sizes (RSA 2048+ or ECC P-256+)

❌ **DON'T**:
- ❌ Share private keys between services
- ❌ Commit private keys to Git repositories
- ❌ Email private keys
- ❌ Use weak key sizes (RSA 1024 or below)
- ❌ Reuse old private keys after certificate expiry
- ❌ Disable certificate validation in applications

### 7.2 Operational

✅ **DO**:
- ✅ Tag certificates with owner and application metadata
- ✅ Document where certificates are deployed
- ✅ Test renewal process in dev/test environments
- ✅ Monitor certificate expiry (30+ days notice)
- ✅ Automate renewal and deployment where possible
- ✅ Keep asset inventory up-to-date

❌ **DON'T**:
- ❌ Request certificates "just in case" (unused certificates are security risk)
- ❌ Use overly long validity periods (> 1 year for servers)
- ❌ Ignore expiry warnings
- ❌ Skip testing after certificate replacement

### 7.3 Certificate Hygiene

**Weekly**:
- Review certificates expiring in next 30 days
- Verify automatic renewal is working

**Monthly**:
- Audit unused certificates (revoke if not needed)
- Review certificate inventory for your applications
- Update asset inventory if services changed

**Quarterly**:
- Review authorization (do you still own these hosts?)
- Rotate long-lived certificates (code signing, etc.)

---

## 8. FAQ

### General

**Q: How long does it take to get a certificate?**  
A: Auto-approved templates: instant (< 30 seconds). Approval-required: 1-2 business days.

**Q: How much does a certificate cost?**  
A: Internal certificates are free (part of platform service). External/public certificates may have costs (contact PKI team).

**Q: Can I use Let's Encrypt instead?**  
A: For internal services: No, use Keyfactor. For public-facing services: Contact PKI team for guidance.

**Q: What's the maximum certificate validity?**  
A: Public certificates: 90 days (industry standard). Internal: 1-2 years depending on template.

**Q: Can I request wildcard certificates (*.contoso.com)?**  
A: Yes, but requires approval. Submit request via ServiceNow. Justify business need.

---

### Technical

**Q: What key size should I use?**  
A: RSA 2048-bit or ECC P-256. RSA 4096 for code signing.

**Q: Which certificate format should I download?**  
A: **Linux/NGINX**: PEM. **Windows/IIS**: PFX. **Java**: JKS (convert from PFX).

**Q: Do I need to include the CA chain?**  
A: Yes, always include the full certificate chain for compatibility.

**Q: Can I generate the private key on Keyfactor?**  
A: For security, generate private keys on your own system and submit CSR. Exception: Windows GPO auto-enrollment.

**Q: How do I convert between certificate formats?**  
A: See [16-Glossary-References.md](./16-Glossary-References.md) Appendix B: Conversion Cheat Sheet

---

### Troubleshooting

**Q: My auto-renewal failed. What do I do?**  
A: Check [§ 6.1](#61-common-issues) for troubleshooting steps. Contact #pki-support if unresolved.

**Q: I accidentally deleted my private key. Can I recover it?**  
A: No. Private keys are not stored by Keyfactor. Request a new certificate.

**Q: Can I renew a certificate before it expires?**  
A: Yes. Request a new certificate anytime. Deploy the new one and revoke the old one after successful cutover.

**Q: My certificate expired and services are down. Help!**  
A: See [§ 6.1 Emergency Procedure](#61-common-issues) - "Certificate Expired - Services Down!"

---

## Appendix A: Quick Reference Commands

### Check Certificate Expiry
```bash
# Linux
openssl x509 -in certificate.pem -noout -enddate

# Check if expires in < 30 days
openssl x509 -in certificate.pem -noout -checkend 2592000
```

### Generate CSR
```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout private-key.pem \
  -out certificate.csr \
  -subj "/CN=api.contoso.com/O=Contoso Inc"
```

### Convert Certificate Formats
```bash
# PEM to PFX
openssl pkcs12 -export -out cert.pfx -inkey key.pem -in cert.pem

# PFX to PEM
openssl pkcs12 -in cert.pfx -out cert.pem -nodes
```

### View Certificate Details
```bash
openssl x509 -in certificate.pem -text -noout
```

---

## Appendix B: Contact Information

**PKI Team**:
- **Slack**: #pki-support
- **Email**: pki-team@contoso.com
- **ServiceNow**: Security → PKI Support
- **Emergency**: ext. 9999 (production outages only)

**Documentation**:
- **This Guide**: https://docs.contoso.com/pki/service-owner-guide
- **Full Documentation**: https://github.com/contoso/pki-docs
- **Keyfactor Portal**: https://keyfactor.contoso.com

---

## Document Maintenance

**Review Schedule**: Quarterly or when processes change  
**Owner**: PKI Team  
**Last Reviewed**: October 23, 2025  
**Next Review**: January 23, 2026

**Feedback**: Please submit feedback or questions to #pki-support

---

**Happy certificate management! Remember: Automate everything, monitor proactively, and don't wait until the last minute to renew. 🎉**

---

*For questions or feedback, contact: adrian207@gmail.com or #pki-support on Slack*

**End of Service Owner Guide**

