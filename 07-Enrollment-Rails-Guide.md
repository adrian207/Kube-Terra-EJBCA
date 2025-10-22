# Certificate Enrollment Rails Guide
## ACME, EST, SCEP, Auto-Enrollment & cert-manager Configurations

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Document Purpose

This guide provides comprehensive configuration and implementation details for all certificate enrollment methods supported by Keyfactor. Each enrollment "rail" is documented with:

- **Protocol overview** and use cases
- **Complete configuration examples**
- **Client setup** for various platforms
- **Security considerations**
- **Troubleshooting** common issues
- **Performance tuning** recommendations

---

## Table of Contents

1. [ACME (Automated Certificate Management Environment)](#1-acme-automated-certificate-management-environment)
2. [EST (Enrollment over Secure Transport)](#2-est-enrollment-over-secure-transport)
3. [SCEP (Simple Certificate Enrollment Protocol)](#3-scep-simple-certificate-enrollment-protocol)
4. [GPO Auto-Enrollment (Windows)](#4-gpo-auto-enrollment-windows)
5. [Kubernetes cert-manager](#5-kubernetes-cert-manager)
6. [API-Based Enrollment](#6-api-based-enrollment)
7. [Manual Enrollment Portal](#7-manual-enrollment-portal)

---

## 1. ACME (Automated Certificate Management Environment)

### Overview

ACME is the protocol used by Let's Encrypt and other automated certificate authorities. It provides:
- Fully automated certificate issuance
- Domain validation via HTTP-01 or DNS-01 challenges
- Automatic renewal
- No manual CSR generation required

**Best For**: Public-facing web servers, cloud-native applications, containerized workloads

---

### 1.1: Configure ACME Server in Keyfactor

#### Enable ACME Protocol

```powershell
# Via Keyfactor UI:
# Settings → Enrollment → ACME

# Or via API:
$apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$cred = Get-Credential

$acmeConfig = @{
    Enabled = $true
    DirectoryUrl = "https://keyfactor.contoso.com/acme/directory"
    ChallengeTypes = @("HTTP-01", "DNS-01")
    DefaultValidity = 90  # days
    AutoRenewalThreshold = 30  # days before expiry
    RateLimitPerAccount = 50  # requests per hour
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/Enrollment/ACME/Config" `
    -Method PUT `
    -Credential $cred `
    -Body $acmeConfig `
    -ContentType "application/json"
```

#### Create ACME Profile

```powershell
# Define ACME profile for web servers
$acmeProfile = @{
    Name = "Public Web Server ACME"
    Template = "WebServerTemplate"
    ChallengeType = "HTTP-01"
    AllowedDomains = @("*.contoso.com", "*.app.contoso.com")
    BlockedDomains = @("localhost", "*.local")
    RequireEAB = $false  # External Account Binding
    MaxCertificatesPerAccount = 100
    Metadata = @{
        Environment = "production"
        AutoRenew = "true"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/Enrollment/ACME/Profiles" `
    -Method POST `
    -Credential $cred `
    -Body $acmeProfile `
    -ContentType "application/json"
```

---

### 1.2: ACME Client Configuration

#### Using Certbot (Linux/Python)

```bash
# Install certbot
sudo apt-get update
sudo apt-get install certbot

# Configure certbot for Keyfactor ACME
cat > /etc/letsencrypt/cli.ini <<EOF
# Keyfactor ACME server
server = https://keyfactor.contoso.com/acme/directory

# Email for notifications
email = certificates@contoso.com

# Agree to ToS
agree-tos = true

# Use standalone authenticator
authenticator = standalone
EOF

# Request certificate (HTTP-01 challenge)
sudo certbot certonly \
  --config /etc/letsencrypt/cli.ini \
  --standalone \
  --preferred-challenges http \
  --domain webapp01.contoso.com \
  --domain www.webapp01.contoso.com

# Certificate stored in:
# /etc/letsencrypt/live/webapp01.contoso.com/fullchain.pem
# /etc/letsencrypt/live/webapp01.contoso.com/privkey.pem

# Test automatic renewal
sudo certbot renew --dry-run

# Enable automatic renewal (cron)
sudo crontab -e
# Add: 0 0,12 * * * certbot renew --quiet
```

#### Using acme.sh (Lightweight Shell Script)

```bash
# Install acme.sh
curl https://get.acme.sh | sh

# Set Keyfactor ACME server
export ACME_DIRECTORY="https://keyfactor.contoso.com/acme/directory"

# Issue certificate with HTTP validation
~/.acme.sh/acme.sh --issue \
  --server "$ACME_DIRECTORY" \
  --domain webapp01.contoso.com \
  --webroot /var/www/html

# Issue certificate with DNS validation (Cloudflare example)
export CF_Token="your-cloudflare-api-token"
~/.acme.sh/acme.sh --issue \
  --server "$ACME_DIRECTORY" \
  --domain webapp01.contoso.com \
  --dns dns_cf

# Install certificate to NGINX
~/.acme.sh/acme.sh --install-cert \
  --domain webapp01.contoso.com \
  --key-file /etc/nginx/ssl/webapp01.key \
  --fullchain-file /etc/nginx/ssl/webapp01.crt \
  --reloadcmd "systemctl reload nginx"

# Enable automatic renewal
~/.acme.sh/acme.sh --cron
```

#### Using win-acme (Windows/IIS)

```powershell
# Download win-acme
Invoke-WebRequest -Uri "https://github.com/win-acme/win-acme/releases/latest/download/win-acme.zip" `
  -OutFile "C:\Temp\win-acme.zip"

Expand-Archive -Path "C:\Temp\win-acme.zip" -DestinationPath "C:\Tools\win-acme"

# Run win-acme
cd "C:\Tools\win-acme"

# Interactive setup
.\wacs.exe

# Or automated setup
.\wacs.exe `
  --source iis `
  --siteid 1 `
  --acme-server "https://keyfactor.contoso.com/acme/directory" `
  --emailaddress certificates@contoso.com `
  --accepttos

# Configure automatic renewal (Task Scheduler)
# Task is automatically created by win-acme
Get-ScheduledTask -TaskName "win-acme renew*"
```

---

### 1.3: DNS-01 Challenge Configuration

DNS-01 challenge is required for wildcard certificates.

#### Configure DNS Provider Integration

```yaml
# For cert-manager (Kubernetes)
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
stringData:
  api-token: your-cloudflare-api-token
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: keyfactor-acme-dns
spec:
  acme:
    server: https://keyfactor.contoso.com/acme/directory
    email: certificates@contoso.com
    privateKeySecretRef:
      name: keyfactor-acme-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
        selector:
          dnsZones:
            - contoso.com
```

#### Manual DNS-01 Challenge

```bash
# Start certificate request
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --server https://keyfactor.contoso.com/acme/directory \
  --domain "*.contoso.com" \
  --email certificates@contoso.com

# Certbot will prompt:
# Please deploy a DNS TXT record under the name:
# _acme-challenge.contoso.com
# with the following value:
# abc123...xyz789

# Create DNS TXT record
# Name: _acme-challenge
# Type: TXT
# Value: abc123...xyz789
# TTL: 300

# Verify DNS propagation
dig _acme-challenge.contoso.com TXT +short

# Press Enter in certbot to continue
```

---

### 1.4: ACME External Account Binding (EAB)

For enterprise environments requiring pre-authorization.

#### Generate EAB Credentials

```powershell
# In Keyfactor UI:
# Enrollment → ACME → Accounts → Generate EAB

# Or via API:
$eab = Invoke-RestMethod -Uri "$apiUrl/Enrollment/ACME/EAB" `
    -Method POST `
    -Credential $cred `
    -Body (@{
        Email = "webapp-team@contoso.com"
        ValidFor = 30  # days
    } | ConvertTo-Json) `
    -ContentType "application/json"

Write-Host "Key ID: $($eab.KeyId)"
Write-Host "HMAC Key: $($eab.HmacKey)"
```

#### Use EAB with Certbot

```bash
# Request certificate with EAB
certbot register \
  --server https://keyfactor.contoso.com/acme/directory \
  --email webapp-team@contoso.com \
  --eab-kid "your-key-id" \
  --eab-hmac-key "your-hmac-key"

# Now issue certificates normally
certbot certonly --standalone -d webapp01.contoso.com
```

---

### 1.5: ACME Troubleshooting

#### Common Issues

**Issue**: `Unable to connect to ACME server`

```bash
# Test ACME directory
curl https://keyfactor.contoso.com/acme/directory

# Expected output:
# {
#   "newNonce": "https://keyfactor.contoso.com/acme/new-nonce",
#   "newAccount": "https://keyfactor.contoso.com/acme/new-account",
#   ...
# }

# Check DNS resolution
nslookup keyfactor.contoso.com

# Test HTTPS connectivity
openssl s_client -connect keyfactor.contoso.com:443
```

**Issue**: `HTTP-01 challenge failed`

```bash
# Verify port 80 is open
nc -zv your-server.com 80

# Test HTTP challenge endpoint
curl http://your-server.com/.well-known/acme-challenge/test

# Check web server logs
tail -f /var/log/nginx/access.log
```

**Issue**: `DNS-01 challenge failed`

```bash
# Verify DNS TXT record
dig _acme-challenge.contoso.com TXT +short

# Check DNS propagation globally
https://www.whatsmydns.net/#TXT/_acme-challenge.contoso.com

# Test with multiple DNS servers
dig @8.8.8.8 _acme-challenge.contoso.com TXT
dig @1.1.1.1 _acme-challenge.contoso.com TXT
```

---

## 2. EST (Enrollment over Secure Transport)

### Overview

EST (RFC 7030) is designed for secure certificate enrollment for devices and IoT endpoints. It provides:
- Mutual TLS authentication
- Simple HTTP-based protocol
- Certificate renewal
- CA certificate distribution

**Best For**: Network devices (routers, switches, firewalls), IoT devices, embedded systems

---

### 2.1: Configure EST Server

#### Enable EST in Keyfactor

```powershell
# Enable EST enrollment
$estConfig = @{
    Enabled = $true
    BaseUrl = "https://keyfactor.contoso.com/.well-known/est"
    AuthMethod = "ClientCertificate"  # or "HTTPBasic"
    RequireMutualTLS = $true
    AllowReenrollment = $true
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/Enrollment/EST/Config" `
    -Method PUT `
    -Credential $cred `
    -Body $estConfig `
    -ContentType "application/json"
```

#### Create EST Profile

```powershell
$estProfile = @{
    Name = "Network Device EST"
    Template = "NetworkDeviceTemplate"
    RequireClientCertificate = $true
    AllowedSubjectPatterns = @("*.network.contoso.com", "router-*", "switch-*")
    ValidityDays = 365
    KeyUsage = @("DigitalSignature", "KeyEncipherment")
    ExtendedKeyUsage = @("ServerAuthentication", "ClientAuthentication")
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/Enrollment/EST/Profiles" `
    -Method POST `
    -Credential $cred `
    -Body $estProfile `
    -ContentType "application/json"
```

---

### 2.2: EST Client Configuration

#### Using OpenSSL (Linux)

```bash
# Download CA certificates
curl --cacert root-ca.pem \
  https://keyfactor.contoso.com/.well-known/est/cacerts \
  -o ca-certs.p7

# Convert PKCS#7 to PEM
openssl pkcs7 -print_certs -in ca-certs.p7 -out ca-bundle.pem

# Generate key pair
openssl genrsa -out device.key 2048

# Create CSR
openssl req -new -key device.key -out device.csr \
  -subj "/CN=router01.network.contoso.com/O=Contoso/C=US"

# Convert CSR to base64
base64 device.csr > device.csr.b64

# Enroll via EST (with client certificate)
curl -X POST \
  --cacert ca-bundle.pem \
  --cert client-cert.pem \
  --key client-key.pem \
  -H "Content-Type: application/pkcs10" \
  -H "Content-Transfer-Encoding: base64" \
  --data-binary @device.csr.b64 \
  https://keyfactor.contoso.com/.well-known/est/simpleenroll \
  -o device-cert.p7

# Convert response to PEM
openssl pkcs7 -print_certs -in device-cert.p7 -out device-cert.pem

echo "Certificate enrolled successfully"
```

#### Using estclient (Cisco-style EST Client)

```bash
# Install estclient
git clone https://github.com/cisco/libest.git
cd libest
./configure --with-ssl-dir=/usr
make
sudo make install

# Enroll certificate
estclient -e \
  -s keyfactor.contoso.com \
  -p 443 \
  -u /.well-known/est \
  -c ca-bundle.pem \
  --common-name router01.network.contoso.com \
  --out device-cert.pem \
  --out-key device-key.pem

# Re-enroll (renew)
estclient -r \
  -s keyfactor.contoso.com \
  -p 443 \
  -u /.well-known/est \
  -c ca-bundle.pem \
  --cert device-cert.pem \
  --key device-key.pem \
  --out device-cert-renewed.pem
```

---

### 2.3: EST on Network Devices

#### Cisco IOS Configuration

```cisco
! Configure EST trustpoint
crypto pki trustpoint KeyfactorEST
 enrollment url https://keyfactor.contoso.com/.well-known/est
 enrollment mode ra
 enrollment retry count 3
 enrollment retry period 1
 fqdn router01.network.contoso.com
 subject-name CN=router01.network.contoso.com,O=Contoso,C=US
 revocation-check none
 rsakeypair KeyfactorKey 2048
!
! Authenticate CA
crypto pki authenticate KeyfactorEST

! Enroll certificate
crypto pki enroll KeyfactorEST

! Verify certificate
show crypto pki certificates KeyfactorEST

! Enable HTTPS with EST certificate
ip http secure-server
ip http secure-trustpoint KeyfactorEST
```

#### Palo Alto Firewall Configuration

```xml
<!-- Via XML API or CLI -->
<config>
  <shared>
    <certificate>
      <entry name="est-device-cert">
        <algorithm>
          <RSA>
            <rsa-nbits>2048</rsa-nbits>
          </RSA>
        </algorithm>
        <common-name>paloalto-fw01.network.contoso.com</common-name>
        <signed-by>EST-CA</signed-by>
      </entry>
    </certificate>
    <scep-profile>
      <entry name="KeyfactorEST">
        <ca-identity>EST-CA</ca-identity>
        <scep-url>https://keyfactor.contoso.com/.well-known/est</scep-url>
        <scep-challenge>
          <dynamic>
            <username>est-user</username>
            <password>est-password</password>
          </dynamic>
        </scep-challenge>
      </entry>
    </scep-profile>
  </shared>
</config>
```

---

## 3. SCEP (Simple Certificate Enrollment Protocol)

### Overview

SCEP is widely used for automated certificate enrollment, especially for mobile devices and legacy systems.

**Best For**: Mobile devices (iOS, Android), legacy systems, mass device enrollment

---

### 3.1: Configure NDES (Microsoft SCEP Server)

#### Install NDES Role

```powershell
# On Windows Server (must be domain-joined)

# Install NDES
Install-WindowsFeature -Name ADCS-Device-Enrollment -IncludeManagementTools

# Configure NDES
# Server Manager → AD CS → Configure Device Enrollment Service

# Or via PowerShell:
Install-AdcsNetworkDeviceEnrollmentService `
    -ServiceAccountName "CONTOSO\svc-ndes" `
    -ServiceAccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force) `
    -CAConfig "ca-server.contoso.com\Contoso-IssuingCA-01" `
    -RAName "NDES-RA" `
    -RAEmail "ndes@contoso.com" `
    -SigningProviderName "Microsoft Strong Cryptographic Provider" `
    -SigningKeyLength 2048 `
    -EncryptionProviderName "Microsoft Strong Cryptographic Provider" `
    -EncryptionKeyLength 2048
```

#### Integrate NDES with Keyfactor

```powershell
# Configure NDES to use Keyfactor templates
# Modify registry on NDES server

$registryPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\MSCEP"

# Set certificate template
Set-ItemProperty -Path $registryPath -Name "EncryptionTemplate" -Value "NDESEncryption"
Set-ItemProperty -Path $registryPath -Name "SignatureTemplate" -Value "NDESSignature"
Set-ItemProperty -Path $registryPath -Name "GeneralPurposeTemplate" -Value "NDESGeneral"

# Restart IIS
iisreset

# Test SCEP endpoint
Invoke-WebRequest -Uri "http://ndes.contoso.com/certsrv/mscep/mscep.dll?operation=GetCACaps"
```

---

### 3.2: SCEP Client Configuration

#### iOS Configuration Profile

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <!-- SCEP Payload -->
        <dict>
            <key>PayloadType</key>
            <string>com.apple.security.scep</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.contoso.scep.device</string>
            <key>PayloadUUID</key>
            <string>12345678-1234-1234-1234-123456789012</string>
            <key>PayloadDisplayName</key>
            <string>Contoso Device Certificate</string>
            
            <!-- SCEP Configuration -->
            <key>PayloadContent</key>
            <dict>
                <key>URL</key>
                <string>https://ndes.contoso.com/certsrv/mscep/mscep.dll</string>
                <key>Name</key>
                <string>Contoso-IssuingCA-01</string>
                <key>Subject</key>
                <array>
                    <array>
                        <array>
                            <string>CN</string>
                            <string>%HardwareUUID%</string>
                        </array>
                    </array>
                </array>
                <key>Challenge</key>
                <string>CHALLENGE_PASSWORD</string>
                <key>Keysize</key>
                <integer>2048</integer>
                <key>Key Type</key>
                <string>RSA</string>
                <key>Key Usage</key>
                <integer>5</integer> <!-- Digital Signature + Key Encipherment -->
            </dict>
        </dict>
    </array>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadIdentifier</key>
    <string>com.contoso.device-cert-profile</string>
    <key>PayloadUUID</key>
    <string>87654321-4321-4321-4321-210987654321</string>
    <key>PayloadDisplayName</key>
    <string>Device Certificate Profile</string>
    <key>PayloadDescription</key>
    <string>Installs device certificate via SCEP</string>
</dict>
</plist>
```

#### Android (via MDM)

```json
{
  "kind": "android#managedConfiguration",
  "productId": "com.contoso.mdm",
  "managedProperty": [
    {
      "key": "scep_config",
      "valueBundleArray": [
        {
          "managedProperty": [
            {
              "key": "scep_url",
              "valueString": "https://ndes.contoso.com/certsrv/mscep/mscep.dll"
            },
            {
              "key": "scep_challenge",
              "valueString": "CHALLENGE_PASSWORD"
            },
            {
              "key": "subject",
              "valueString": "CN=${DEVICE_ID},O=Contoso,C=US"
            },
            {
              "key": "key_size",
              "valueInteger": 2048
            }
          ]
        }
      ]
    }
  ]
}
```

---

### 3.3: SCEP Challenge Password Management

#### Dynamic Challenge Password Generation

```powershell
# Generate one-time challenge passwords for SCEP

function New-SCEPChallenge {
    param(
        [string]$DeviceId,
        [int]$ValidForHours = 24
    )
    
    # Generate random challenge
    $challenge = [Convert]::ToBase64String([System.Guid]::NewGuid().ToByteArray())
    
    # Store in database with expiry
    $expiry = (Get-Date).AddHours($ValidForHours)
    
    $challengeData = @{
        Challenge = $challenge
        DeviceId = $DeviceId
        Expiry = $expiry.ToString("o")
        Used = $false
    } | ConvertTo-Json
    
    # Store in database or Redis
    Invoke-RestMethod -Uri "https://api.contoso.com/scep/challenges" `
        -Method POST `
        -Body $challengeData `
        -ContentType "application/json"
    
    return $challenge
}

# Generate challenge for device enrollment
$deviceId = "iPhone-12345"
$challenge = New-SCEPChallenge -DeviceId $deviceId -ValidForHours 1

Write-Host "Challenge for $deviceId : $challenge"
Write-Host "Valid for 1 hour"
```

#### Challenge Validation Webhook

```python
# NDES webhook to validate SCEP challenges
from flask import Flask, request, jsonify
import redis
import json
from datetime import datetime

app = Flask(__name__)
redis_client = redis.Redis(host='localhost', port=6379, db=0)

@app.route('/scep/validate', methods=['POST'])
def validate_challenge():
    data = request.json
    challenge = data.get('challenge')
    device_id = data.get('deviceId')
    
    # Retrieve challenge from Redis
    challenge_key = f"scep:challenge:{challenge}"
    challenge_data = redis_client.get(challenge_key)
    
    if not challenge_data:
        return jsonify({'valid': False, 'reason': 'Challenge not found'}), 404
    
    challenge_info = json.loads(challenge_data)
    
    # Check expiry
    expiry = datetime.fromisoformat(challenge_info['expiry'])
    if datetime.utcnow() > expiry:
        redis_client.delete(challenge_key)
        return jsonify({'valid': False, 'reason': 'Challenge expired'}), 403
    
    # Check if already used
    if challenge_info.get('used'):
        return jsonify({'valid': False, 'reason': 'Challenge already used'}), 403
    
    # Mark as used
    challenge_info['used'] = True
    redis_client.set(challenge_key, json.dumps(challenge_info), ex=86400)  # Keep for 24h
    
    return jsonify({'valid': True, 'deviceId': challenge_info['deviceId']}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
```

---

## 4. GPO Auto-Enrollment (Windows)

### Overview

Windows Group Policy auto-enrollment automatically requests and installs certificates on domain-joined computers and users.

**Best For**: Windows domain environments, user certificates, computer certificates

---

### 4.1: Configure Certificate Templates

#### Computer Certificate Template

```powershell
# On AD CS server or workstation with RSAT

# Duplicate "Computer" template
$templateName = "AutoEnroll-Computer"

# Configure template permissions via certutil
certutil -dstemplate $templateName > $null

# Set permissions (PowerShell - requires AD module)
Import-Module ActiveDirectory

$templateDN = "CN=$templateName,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,DC=contoso,DC=com"

# Grant Authenticated Users read and enroll
$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-11")  # Authenticated Users
$identity = $sid.Translate([System.Security.Principal.NTAccount])

# Add ACE for auto-enrollment
dsacls $templateDN /G "$($identity.Value):GR;Enroll"
dsacls $templateDN /G "$($identity.Value):GR;AutoEnroll"

# Publish template to CA
certutil -SetCATemplates +$templateName
```

#### User Certificate Template

```powershell
$templateName = "AutoEnroll-User"

# Configure for user certificates
# Properties:
# - Subject: Supplied in request (or auto-generated from AD)
# - Key Usage: Digital Signature, Key Encipherment
# - Extended Key Usage: Client Authentication, Secure Email
# - Validity: 1 year
# - Renewal: 6 months

# Publish to CA
certutil -SetCATemplates +$templateName
```

---

### 4.2: Configure Group Policy

#### Create GPO for Computer Auto-Enrollment

```powershell
# Create new GPO
New-GPO -Name "Certificate Auto-Enrollment - Computers" -Domain contoso.com

# Configure certificate auto-enrollment
$gpoName = "Certificate Auto-Enrollment - Computers"

# Set registry values via GPO
# Computer Configuration → Policies → Windows Settings → Security Settings → Public Key Policies
# → Certificate Services Client - Auto-Enrollment

# Via PowerShell (using Group Policy module):
Set-GPRegistryValue -Name $gpoName `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" `
    -ValueName "AEPolicy" `
    -Type DWord `
    -Value 7

# Value meanings:
# 0 = Disabled
# 1 = Enroll certificates
# 3 = Enroll and renew
# 7 = Enroll, renew, and remove expired certificates

# Link GPO to OU
New-GPLink -Name $gpoName -Target "OU=Computers,DC=contoso,DC=com"

# Force GPO update
Invoke-GPUpdate -Computer "all" -Force
```

#### Create GPO for User Auto-Enrollment

```powershell
New-GPO -Name "Certificate Auto-Enrollment - Users" -Domain contoso.com

$gpoName = "Certificate Auto-Enrollment - Users"

# User Configuration → Policies → Windows Settings → Security Settings → Public Key Policies
Set-GPRegistryValue -Name $gpoName `
    -Key "HKCU\SOFTWARE\Policies\Microsoft\Cryptography\AutoEnrollment" `
    -ValueName "AEPolicy" `
    -Type DWord `
    -Value 7

New-GPLink -Name $gpoName -Target "OU=Users,DC=contoso,DC=com"
```

---

### 4.3: Verify Auto-Enrollment

#### On Client Computer

```powershell
# Force GPO update
gpupdate /force

# Trigger certificate auto-enrollment manually
certutil -pulse

# View auto-enrollment results
Get-ChildItem Cert:\LocalMachine\My

# Check event log
Get-WinEvent -LogName "Microsoft-Windows-CertificateServicesClient-LifeCycle-System/Operational" -MaxEvents 50 |
    Where-Object { $_.Message -like "*AutoEnroll*" }

# Verify certificate properties
Get-ChildItem Cert:\LocalMachine\My |
    Where-Object { $_.Subject -like "*$env:COMPUTERNAME*" } |
    Format-List Subject, Issuer, NotAfter, HasPrivateKey
```

---

## 5. Kubernetes cert-manager

### Overview

cert-manager automates certificate management in Kubernetes clusters using CRDs (Custom Resource Definitions).

**Best For**: Kubernetes workloads, microservices, ingress controllers

---

### 5.1: Install cert-manager

```bash
# Install cert-manager via Helm
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.0 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager

# Verify installation
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

---

### 5.2: Configure Keyfactor Command Issuer

**Installation**: See [KEYFACTOR-INTEGRATIONS-GUIDE.md - Command cert-manager Issuer](#4-command-cert-manager-issuer)

```bash
# Install Command issuer
helm install command-issuer \
  oci://ghcr.io/keyfactor/command-cert-manager-issuer/charts/command-issuer \
  --namespace command-issuer-system \
  --create-namespace

# Create Keyfactor credentials secret
kubectl create secret generic keyfactor-credentials \
  --namespace default \
  --from-literal=hostname='https://keyfactor.contoso.com' \
  --from-literal=username='k8s-issuer' \
  --from-literal=password='SecurePassword123!' \
  --from-literal=domain='CONTOSO'

# Create CommandIssuer
cat <<EOF | kubectl apply -f -
apiVersion: command-issuer.keyfactor.com/v1alpha1
kind: CommandIssuer
metadata:
  name: keyfactor-prod
  namespace: default
spec:
  commandSecretName: keyfactor-credentials
  certificateTemplate: "KubernetesServerAuth"
  certificateAuthority: "Contoso-IssuingCA-01"
  metadata:
    - key: "cluster"
      value: "prod-k8s-01"
    - key: "environment"
      value: "production"
EOF

# Verify issuer
kubectl get commandissuer keyfactor-prod -o yaml
```

---

### 5.3: Issue Certificates with cert-manager

#### Single Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webapp-tls
  namespace: default
spec:
  secretName: webapp-tls-secret
  issuerRef:
    name: keyfactor-prod
    kind: CommandIssuer
    group: command-issuer.keyfactor.com
  commonName: webapp.contoso.com
  dnsNames:
    - webapp.contoso.com
    - www.webapp.contoso.com
  duration: 2160h  # 90 days
  renewBefore: 720h  # 30 days
  privateKey:
    algorithm: RSA
    size: 2048
```

#### Wildcard Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-contoso
  namespace: default
spec:
  secretName: wildcard-contoso-tls
  issuerRef:
    name: keyfactor-prod
    kind: CommandIssuer
  commonName: "*.contoso.com"
  dnsNames:
    - "*.contoso.com"
    - contoso.com
  duration: 2160h
  renewBefore: 720h
```

#### Certificate for Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: default
  annotations:
    cert-manager.io/issuer: "keyfactor-prod"
    cert-manager.io/issuer-kind: "CommandIssuer"
    cert-manager.io/issuer-group: "command-issuer.keyfactor.com"
spec:
  tls:
    - hosts:
        - webapp.contoso.com
      secretName: webapp-tls-secret  # cert-manager will create this
  rules:
    - host: webapp.contoso.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: webapp
                port:
                  number: 80
```

---

### 5.4: Automatic Certificate Renewal

cert-manager automatically renews certificates based on `renewBefore`.

```bash
# Monitor certificate status
kubectl get certificate -A

# View certificate details
kubectl describe certificate webapp-tls

# Check renewal events
kubectl get events --field-selector involvedObject.name=webapp-tls

# Force renewal
cmctl renew webapp-tls --namespace default

# View certificate in secret
kubectl get secret webapp-tls-secret -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

---

## 6. API-Based Enrollment

### Overview

Direct API enrollment for custom integrations and automation.

---

### 6.1: Enroll via Keyfactor REST API

```python
#!/usr/bin/env python3
"""
Keyfactor API Certificate Enrollment Example
"""

import requests
import json
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

# Configuration
KEYFACTOR_HOST = "https://keyfactor.contoso.com"
KEYFACTOR_USERNAME = "api-user"
KEYFACTOR_PASSWORD = "SecurePassword123!"
KEYFACTOR_DOMAIN = "CONTOSO"

# Generate key pair
private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
    backend=default_backend()
)

# Create CSR
csr = x509.CertificateSigningRequestBuilder().subject_name(x509.Name([
    x509.NameAttribute(NameOID.COMMON_NAME, "api-test.contoso.com"),
    x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Contoso Ltd"),
    x509.NameAttribute(NameOID.COUNTRY_NAME, "US"),
])).add_extension(
    x509.SubjectAlternativeName([
        x509.DNSName("api-test.contoso.com"),
        x509.DNSName("www.api-test.contoso.com"),
    ]),
    critical=False,
).sign(private_key, hashes.SHA256(), backend=default_backend())

# Convert CSR to PEM
csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode()

# Enroll certificate via API
api_url = f"{KEYFACTOR_HOST}/KeyfactorAPI/Enrollment/CSR"

payload = {
    "CSR": csr_pem,
    "CertificateAuthority": "Contoso-IssuingCA-01",
    "Template": "WebServerTemplate",
    "Subject": "CN=api-test.contoso.com,O=Contoso Ltd,C=US",
    "SANs": {
        "DNS": ["api-test.contoso.com", "www.api-test.contoso.com"]
    },
    "Metadata": {
        "owner": "api-team@contoso.com",
        "environment": "production",
        "automated": "true"
    }
}

response = requests.post(
    api_url,
    auth=(f"{KEYFACTOR_DOMAIN}\\{KEYFACTOR_USERNAME}", KEYFACTOR_PASSWORD),
    headers={'Content-Type': 'application/json'},
    json=payload,
    timeout=60
)

response.raise_for_status()

result = response.json()
certificate_id = result['CertificateId']
certificate_pem = result['CertificateInformation']['SerializedCertificate']

print(f"Certificate enrolled successfully!")
print(f"Certificate ID: {certificate_id}")

# Save certificate and private key
with open("api-test.crt", "w") as f:
    f.write(certificate_pem)

with open("api-test.key", "w") as f:
    f.write(private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption()
    ).decode())

print("Certificate and key saved to api-test.crt and api-test.key")
```

---

## 7. Manual Enrollment Portal

### Overview

Web-based self-service portal for manual certificate requests.

---

### 7.1: Configure Self-Service Portal

```powershell
# Enable self-service portal in Keyfactor
$portalConfig = @{
    Enabled = $true
    Url = "https://keyfactor.contoso.com/portal"
    AllowedTemplates = @("WebServerTemplate", "CodeSigningTemplate")
    RequireApproval = $true
    ApprovalGroup = "PKI-Approvers@contoso.com"
    MaxRequestsPerUser = 10
    EmailNotifications = $true
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/Portal/Config" `
    -Method PUT `
    -Credential $cred `
    -Body $portalConfig `
    -ContentType "application/json"
```

---

## Appendix: Comparison Matrix

| Method | Automation | Complexity | Best For | Renewal |
|--------|------------|------------|----------|---------|
| **ACME** | ✅ High | Low | Web servers, cloud | Automatic |
| **EST** | ✅ High | Medium | Network devices, IoT | Automatic |
| **SCEP** | ✅ High | Medium | Mobile devices | Automatic |
| **GPO Auto-Enrollment** | ✅ High | Low | Windows domain | Automatic |
| **cert-manager** | ✅ High | Medium | Kubernetes | Automatic |
| **API** | ⚙️ Medium | High | Custom integrations | Manual/Automated |
| **Portal** | ❌ Manual | Low | One-off requests | Manual |

---

**Document Version**: 1.0  
**Last Updated**: October 22, 2025  
**Author**: Adrian Johnson <adrian207@gmail.com>

**End of Enrollment Rails Guide**
