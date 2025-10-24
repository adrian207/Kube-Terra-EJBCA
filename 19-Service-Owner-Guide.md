# Service Owner Guide
## Certificate Management for Application Teams

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 23, 2025  
**Status**: Complete

---

## Overview

This guide provides application teams and service owners with everything needed to request, manage, and troubleshoot certificates in the Keyfactor PKI environment. Whether you're deploying web applications, microservices, or infrastructure components, this guide covers all certificate scenarios.

**Who This Guide Is For**:
- Application developers and architects
- DevOps engineers and platform teams
- Service owners and technical leads
- Infrastructure engineers
- Security-conscious developers

---

## Quick Start

### 🚀 **Get a Certificate in 2 Minutes**

**For Kubernetes Applications**:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: production
spec:
  secretName: my-app-tls-secret
  issuerRef:
    name: keyfactor-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
  - my-app.contoso.com
  - api.my-app.contoso.com
```

**For Windows Applications**:
```powershell
# Request certificate via PowerShell
$certRequest = @{
    CommonName = "my-app.contoso.com"
    Template = "TLS-Server-Internal"
    SubjectAlternativeNames = @("api.my-app.contoso.com")
}
Invoke-RestMethod -Uri "https://keyfactor.contoso.com/api/certificates" -Method POST -Body ($certRequest | ConvertTo-Json)
```

**For Linux Applications**:
```bash
# Request certificate via ACME
certbot certonly --webroot -w /var/www/html -d my-app.contoso.com --server https://acme.contoso.com
```

---

## Certificate Types and Templates

### Available Certificate Templates

| Template | Purpose | Validity | Key Size | SAN Support |
|----------|---------|----------|----------|-------------|
| **TLS-Server-Internal** | Internal web services | 2 years | RSA 2048+ / ECDSA P-256 | ✅ |
| **TLS-Server-External** | Public-facing services | 1 year | RSA 2048+ / ECDSA P-256 | ✅ |
| **TLS-Client-Auth** | Client authentication | 2 years | RSA 2048+ / ECDSA P-256 | ✅ |
| **Code-Signing** | Application signing | 3 years | RSA 4096 | ❌ |
| **Email-SMIME** | Email encryption | 2 years | RSA 2048+ | ✅ |
| **Device-Certificate** | IoT/network devices | 5 years | RSA 2048+ | ✅ |

### Template Selection Guide

**Choose TLS-Server-Internal when**:
- Service runs on internal network only
- No external internet access required
- Development, staging, or internal production services

**Choose TLS-Server-External when**:
- Service accessible from internet
- Public-facing APIs or web applications
- Services requiring public trust

**Choose TLS-Client-Auth when**:
- Application needs to authenticate to other services
- API-to-API communication
- Service mesh authentication

---

## Enrollment Methods

### 1. Kubernetes (cert-manager) - **Recommended for K8s**

**Prerequisites**:
- cert-manager installed in cluster
- Keyfactor ClusterIssuer configured
- Proper RBAC permissions

**Certificate Request**:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: web-app-tls
  namespace: production
spec:
  secretName: web-app-tls-secret
  issuerRef:
    name: keyfactor-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
  - web-app.contoso.com
  - api.web-app.contoso.com
  - admin.web-app.contoso.com
  duration: 8760h  # 1 year
  renewBefore: 720h  # Renew 30 days before expiry
```

**Deployment Integration**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  template:
    spec:
      containers:
      - name: web-app
        image: my-app:latest
        ports:
        - containerPort: 443
        volumeMounts:
        - name: tls-secret
          mountPath: /etc/ssl/certs
          readOnly: true
      volumes:
      - name: tls-secret
        secret:
          secretName: web-app-tls-secret
```

### 2. ACME Protocol - **Recommended for Linux**

**Prerequisites**:
- Domain ownership verification
- ACME client installed (certbot, acme.sh, win-acme)
- Web server access for HTTP-01 challenge

**Certificate Request**:
```bash
# Using certbot
certbot certonly --webroot \
  -w /var/www/html \
  -d my-app.contoso.com \
  -d api.my-app.contoso.com \
  --server https://acme.contoso.com \
  --email admin@contoso.com \
  --agree-tos \
  --non-interactive

# Using acme.sh
acme.sh --issue -d my-app.contoso.com -d api.my-app.contoso.com \
  --webroot /var/www/html \
  --server https://acme.contoso.com
```

**Auto-Renewal Setup**:
```bash
# Add to crontab for automatic renewal
0 2 * * * /usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
```

### 3. Windows GPO Auto-Enrollment - **Recommended for Windows**

**Prerequisites**:
- Domain-joined Windows server
- GPO configured for auto-enrollment
- Proper group membership

**Certificate Request** (Automatic):
```powershell
# Certificates are automatically enrolled via GPO
# Check certificate store
Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object {$_.Subject -like "*my-app*"}

# Export certificate for application use
$cert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object {$_.Subject -eq "CN=my-app.contoso.com"}
$cert | Export-Certificate -FilePath "C:\certs\my-app.cer" -Type CERT
```

### 4. REST API - **For Custom Integrations**

**Prerequisites**:
- API credentials (client certificate or token)
- Network access to Keyfactor API
- Understanding of certificate templates

**Certificate Request**:
```python
import requests
import json

# API configuration
api_url = "https://keyfactor.contoso.com/api/certificates"
headers = {
    "Authorization": "Bearer YOUR_API_TOKEN",
    "Content-Type": "application/json"
}

# Certificate request
cert_request = {
    "CommonName": "my-app.contoso.com",
    "Template": "TLS-Server-Internal",
    "SubjectAlternativeNames": [
        "api.my-app.contoso.com",
        "admin.my-app.contoso.com"
    ],
    "KeyAlgorithm": "RSA",
    "KeySize": 2048,
    "ValidityPeriod": 730  # days
}

# Submit request
response = requests.post(api_url, headers=headers, json=cert_request)
if response.status_code == 201:
    cert_id = response.json()["Id"]
    print(f"Certificate request submitted: {cert_id}")
else:
    print(f"Request failed: {response.text}")
```

---

## Authorization and Access Control

### Multi-Layer Authorization Model

The PKI platform uses a 4-layer authorization model. **ALL layers must pass** for certificate issuance:

#### Layer 1: Identity RBAC
**Question**: "WHO can request certificates?"

**Your Role Requirements**:
- Member of authorized AD group (e.g., `APP-WebDevelopers`, `INFRA-ServerAdmins`)
- Valid authentication (MFA required)
- Active account status

**Check Your Access**:
```powershell
# Check your group membership
Get-ADUser -Identity $env:USERNAME -Properties MemberOf | Select-Object -ExpandProperty MemberOf

# Verify PKI access
Invoke-RestMethod -Uri "https://keyfactor.contoso.com/api/access/check" -Headers @{Authorization="Bearer $token"}
```

#### Layer 2: SAN Validation
**Question**: "WHAT domains can you request?"

**Domain Patterns**:
- `*.contoso.com` - All subdomains
- `*.dev.contoso.com` - Development subdomains only
- `*.prod.contoso.com` - Production subdomains only
- `api.contoso.com` - Specific domain

**Check Domain Authorization**:
```bash
# Check if domain is authorized for your role
curl -H "Authorization: Bearer $token" \
  "https://keyfactor.contoso.com/api/domains/validate?domain=my-app.contoso.com"
```

#### Layer 3: Resource Binding
**Question**: "WHERE can the certificate be deployed?"

**Asset Ownership Verification**:
- Certificate requester must own the target server/application
- Asset inventory integration (CMDB, Azure, AWS)
- Resource tagging and metadata validation

**Verify Asset Ownership**:
```python
# Check asset ownership
import requests

def check_asset_ownership(server_name, requester):
    response = requests.get(f"https://cmdb.contoso.com/api/assets/{server_name}")
    asset = response.json()
    
    if requester in asset["owners"]:
        return True
    return False

# Example usage
if check_asset_ownership("web-app-01", "john.doe@contoso.com"):
    print("Asset ownership verified")
else:
    print("Asset ownership verification failed")
```

#### Layer 4: Template Policy
**Question**: "HOW should the certificate be issued?"

**Policy Enforcement**:
- Technical constraints (key size, algorithm, validity)
- Approval workflows for sensitive templates
- Compliance requirements

### Common Authorization Scenarios

**Scenario 1: Web Developer Requesting Internal Certificate**
```
✅ Layer 1: Member of APP-WebDevelopers group
✅ Layer 2: Requesting *.dev.contoso.com (authorized pattern)
✅ Layer 3: Owns development server web-dev-01
✅ Layer 4: TLS-Server-Internal template (auto-approved)
Result: Certificate issued automatically
```

**Scenario 2: Developer Requesting Production Certificate**
```
✅ Layer 1: Member of APP-WebDevelopers group
✅ Layer 2: Requesting *.prod.contoso.com (authorized pattern)
❌ Layer 3: Does not own production server web-prod-01
Result: Request denied - "You do not have ownership of web-prod-01"
```

**Scenario 3: Infrastructure Team Requesting Code Signing**
```
✅ Layer 1: Member of INFRA-ServerAdmins group
✅ Layer 2: Requesting code-signing.contoso.com (authorized)
✅ Layer 3: Owns build server build-01
⚠️ Layer 4: Code-Signing template requires manual approval
Result: Request submitted for approval
```

---

## Certificate Lifecycle Management

### Automatic Renewal Process

**How It Works**:
1. **T-30 days**: Keyfactor detects certificate expiring in 30 days
2. **Auto-renewal**: Certificate automatically renewed
3. **Webhook notification**: Automation pipeline triggered
4. **Deployment**: New certificate deployed to application
5. **Verification**: Certificate deployment verified
6. **Notification**: Success/failure notification sent

**What You Need to Do**:
- **Nothing!** Automatic renewal handles everything
- Monitor notifications for any issues
- Ensure webhook endpoints are accessible

### Manual Renewal (If Needed)

**When Manual Renewal Is Required**:
- Automatic renewal failed
- Certificate template changed
- Domain changes required
- Emergency renewal needed

**Manual Renewal Process**:
```bash
# For ACME certificates
certbot renew --force-renewal -d my-app.contoso.com

# For Kubernetes certificates
kubectl delete certificate my-app-tls -n production
# Recreate the Certificate resource (cert-manager will request new cert)

# For Windows certificates
# Delete old certificate from store, GPO will auto-enroll new one
```

### Certificate Revocation

**When to Revoke Certificates**:
- Private key compromised
- Certificate no longer needed
- Domain ownership lost
- Application decommissioned

**Revocation Process**:
```python
import requests

def revoke_certificate(cert_id, reason="unspecified"):
    api_url = f"https://keyfactor.contoso.com/api/certificates/{cert_id}/revoke"
    headers = {"Authorization": "Bearer YOUR_TOKEN"}
    
    payload = {
        "Reason": reason,
        "RevocationDate": "2025-10-23T10:00:00Z"
    }
    
    response = requests.post(api_url, headers=headers, json=payload)
    return response.status_code == 200

# Example usage
revoke_certificate("cert-12345", "keyCompromise")
```

---

## Integration with Secrets Management

### Azure Key Vault Integration

**For Azure-Native Applications**:
```python
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

# Initialize Key Vault client
credential = DefaultAzureCredential()
client = SecretClient(vault_url="https://my-vault.vault.azure.net/", credential=credential)

# Store certificate
certificate_pem = """-----BEGIN CERTIFICATE-----
MIIFXjCCA0agAwIBAgIJAK...
-----END CERTIFICATE-----"""

client.set_secret("my-app-cert", certificate_pem)

# Retrieve certificate
secret = client.get_secret("my-app-cert")
certificate = secret.value
```

**Automatic Key Vault Updates**:
- Webhook automation updates Key Vault when certificates renew
- Applications automatically get new certificates
- No manual intervention required

### HashiCorp Vault Integration

**For Multi-Cloud Applications**:
```python
import hvac

# Initialize Vault client
client = hvac.Client(url='https://vault.contoso.com')
client.token = 'YOUR_VAULT_TOKEN'

# Store certificate
cert_data = {
    "certificate": certificate_pem,
    "private_key": private_key_pem,
    "issuing_ca": ca_cert_pem
}

client.secrets.kv.v2.create_or_update_secret(
    path='my-app/certificate',
    secret=cert_data
)

# Retrieve certificate
secret = client.secrets.kv.v2.read_secret_version(path='my-app/certificate')
certificate = secret['data']['data']['certificate']
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Certificate Request Denied

**Symptoms**:
- Request returns "Access Denied" or "Authorization Failed"
- Certificate not issued after request

**Diagnosis Steps**:
1. **Check Identity RBAC**:
   ```powershell
   # Verify group membership
   Get-ADUser -Identity $env:USERNAME -Properties MemberOf
   ```

2. **Check Domain Authorization**:
   ```bash
   # Test domain validation
   curl -H "Authorization: Bearer $token" \
     "https://keyfactor.contoso.com/api/domains/validate?domain=my-app.contoso.com"
   ```

3. **Check Asset Ownership**:
   ```python
   # Verify server ownership
   check_asset_ownership("my-server", "your-email@contoso.com")
   ```

**Solutions**:
- Request access to appropriate AD group
- Use authorized domain patterns
- Verify asset ownership in CMDB
- Contact PKI team for assistance

#### Issue 2: Automatic Renewal Failed

**Symptoms**:
- Certificate expired
- Renewal notifications show failure
- Application showing certificate errors

**Diagnosis Steps**:
1. **Check Certificate Status**:
   ```bash
   # Check certificate expiry
   openssl x509 -in my-app.crt -text -noout | grep "Not After"
   ```

2. **Check Webhook Logs**:
   ```bash
   # Check automation logs
   kubectl logs -n automation webhook-handler
   ```

3. **Verify Network Connectivity**:
   ```bash
   # Test webhook endpoint
   curl -X POST https://webhook.contoso.com/certificate-renewed \
     -H "Content-Type: application/json" \
     -d '{"test": "connectivity"}'
   ```

**Solutions**:
- Fix webhook endpoint connectivity
- Update automation scripts
- Manually renew certificate
- Contact PKI team for assistance

#### Issue 3: Certificate Not Deployed

**Symptoms**:
- Certificate issued but not available to application
- Application still using old certificate
- Secret not updated in Kubernetes/Azure Key Vault

**Diagnosis Steps**:
1. **Check Certificate Status**:
   ```bash
   # Verify certificate was issued
   curl -H "Authorization: Bearer $token" \
     "https://keyfactor.contoso.com/api/certificates/my-cert-id"
   ```

2. **Check Secret Store**:
   ```bash
   # Check Kubernetes secret
   kubectl get secret my-app-tls -n production -o yaml
   
   # Check Azure Key Vault
   az keyvault secret show --vault-name my-vault --name my-app-cert
   ```

3. **Check Automation Logs**:
   ```bash
   # Check deployment automation
   kubectl logs -n automation cert-deployer
   ```

**Solutions**:
- Restart application to pick up new certificate
- Manually update secret store
- Check automation script configuration
- Contact PKI team for assistance

### Emergency Procedures

#### Emergency Certificate Renewal

**When**: Certificate expired and automatic renewal failed

**Process**:
1. **Immediate Action**:
   ```bash
   # Force certificate renewal
   certbot renew --force-renewal -d my-app.contoso.com
   ```

2. **Deploy Certificate**:
   ```bash
   # Update Kubernetes secret
   kubectl create secret tls my-app-tls \
     --cert=my-app.crt --key=my-app.key \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

3. **Restart Application**:
   ```bash
   # Restart to pick up new certificate
   kubectl rollout restart deployment my-app -n production
   ```

#### Break-Glass Certificate Issuance

**When**: Emergency access needed for critical systems

**Process**:
1. **Contact PKI Team**: Call PKI emergency line
2. **Provide Justification**: Explain emergency situation
3. **Dual Approval**: Two PKI administrators approve
4. **Manual Issuance**: Certificate issued manually
5. **Post-Incident Review**: Document and review process

---

## Best Practices

### Certificate Request Best Practices

1. **Use Descriptive Names**:
   ```yaml
   # Good
   metadata:
     name: web-app-prod-tls
   
   # Bad
   metadata:
     name: cert1
   ```

2. **Include All Required SANs**:
   ```yaml
   dnsNames:
   - web-app.contoso.com
   - api.web-app.contoso.com
   - admin.web-app.contoso.com
   - monitoring.web-app.contoso.com
   ```

3. **Set Appropriate Validity Period**:
   ```yaml
   duration: 8760h  # 1 year for external
   duration: 17520h # 2 years for internal
   ```

4. **Configure Early Renewal**:
   ```yaml
   renewBefore: 720h  # Renew 30 days before expiry
   ```

### Security Best Practices

1. **Never Share Private Keys**:
   - Private keys should never be shared between applications
   - Use separate certificates for different environments
   - Store private keys securely (HSM, Key Vault, Vault)

2. **Use Strong Key Sizes**:
   - RSA: Minimum 2048 bits, prefer 3072+ bits
   - ECDSA: P-256 or P-384 curves
   - Avoid weak algorithms (MD5, SHA-1)

3. **Implement Certificate Pinning**:
   ```python
   import ssl
   import requests
   
   # Certificate pinning for API calls
   def create_pinned_session(cert_pem):
       session = requests.Session()
       session.verify = cert_pem
       return session
   ```

4. **Monitor Certificate Health**:
   ```python
   # Monitor certificate expiry
   import ssl
   import socket
   from datetime import datetime
   
   def check_cert_expiry(hostname, port=443):
       context = ssl.create_default_context()
       with socket.create_connection((hostname, port)) as sock:
           with context.wrap_socket(sock, server_hostname=hostname) as ssock:
               cert = ssock.getpeercert()
               expiry = datetime.strptime(cert['notAfter'], '%b %d %H:%M:%S %Y %Z')
               days_until_expiry = (expiry - datetime.now()).days
               return days_until_expiry
   ```

### Operational Best Practices

1. **Automate Everything**:
   - Use Infrastructure as Code (IaC) for certificate requests
   - Automate certificate deployment
   - Implement health checks for certificate status

2. **Document Certificate Usage**:
   - Document which applications use which certificates
   - Maintain certificate inventory
   - Track certificate dependencies

3. **Test Certificate Changes**:
   - Test certificate renewal in non-production first
   - Implement canary deployments for certificate updates
   - Have rollback procedures ready

4. **Monitor Certificate Metrics**:
   - Track certificate expiry dates
   - Monitor renewal success rates
   - Alert on certificate-related issues

---

## Support and Resources

### Getting Help

**Self-Service Resources**:
- **Documentation**: This guide and related PKI documentation
- **Knowledge Base**: Internal wiki with common scenarios
- **Scripts**: Pre-built automation scripts in `/automation` directory

**Contact Information**:
- **PKI Team**: pki-team@contoso.com
- **Slack Channel**: #pki-support
- **ServiceNow**: Create request → Security → PKI Support
- **Emergency**: Call PKI emergency line (24/7)

### Training and Certification

**Available Training**:
- **PKI Fundamentals**: 2-hour online course
- **Keyfactor Platform**: 4-hour hands-on workshop
- **Certificate Automation**: 2-hour automation workshop
- **Security Best Practices**: 1-hour security briefing

**Certification Path**:
- **PKI User**: Basic certificate management
- **PKI Operator**: Advanced certificate operations
- **PKI Administrator**: Full PKI administration

### Useful Commands and Scripts

**Certificate Validation Script**:
```bash
#!/bin/bash
# validate-certificate.sh
# Validates certificate configuration and connectivity

DOMAIN=$1
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

echo "Validating certificate for $DOMAIN..."

# Check certificate expiry
echo "Certificate expiry:"
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates

# Check certificate chain
echo "Certificate chain:"
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -issuer -subject

# Check SANs
echo "Subject Alternative Names:"
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -text | grep -A 1 "Subject Alternative Name"
```

**Certificate Renewal Check**:
```python
#!/usr/bin/env python3
# check-cert-renewal.py
# Check if certificates need renewal

import ssl
import socket
from datetime import datetime, timedelta
import json

def check_cert_expiry(hostname, port=443):
    try:
        context = ssl.create_default_context()
        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()
                expiry = datetime.strptime(cert['notAfter'], '%b %d %H:%M:%S %Y %Z')
                days_until_expiry = (expiry - datetime.now()).days
                return {
                    'hostname': hostname,
                    'expiry_date': expiry.isoformat(),
                    'days_until_expiry': days_until_expiry,
                    'needs_renewal': days_until_expiry < 30,
                    'status': 'OK' if days_until_expiry > 30 else 'WARNING' if days_until_expiry > 0 else 'CRITICAL'
                }
    except Exception as e:
        return {
            'hostname': hostname,
            'error': str(e),
            'status': 'ERROR'
        }

# Check multiple domains
domains = [
    'web-app.contoso.com',
    'api.contoso.com',
    'admin.contoso.com'
]

results = []
for domain in domains:
    result = check_cert_expiry(domain)
    results.append(result)
    print(f"{domain}: {result['status']} ({result.get('days_until_expiry', 'N/A')} days)")

# Output JSON for monitoring systems
print(json.dumps(results, indent=2))
```

---

## Appendix

### Certificate Template Details

**TLS-Server-Internal**:
- **Purpose**: Internal web services and APIs
- **Validity**: 2 years
- **Key Size**: RSA 2048+ or ECDSA P-256
- **SAN Support**: Yes
- **Approval**: Automatic
- **Use Cases**: Internal APIs, microservices, development environments

**TLS-Server-External**:
- **Purpose**: Public-facing web services
- **Validity**: 1 year
- **Key Size**: RSA 2048+ or ECDSA P-256
- **SAN Support**: Yes
- **Approval**: Automatic
- **Use Cases**: Public websites, external APIs, customer-facing services

**Code-Signing**:
- **Purpose**: Application and code signing
- **Validity**: 3 years
- **Key Size**: RSA 4096
- **SAN Support**: No
- **Approval**: Manual (requires PKI admin approval)
- **Use Cases**: Application signing, driver signing, firmware signing

### Domain Pattern Examples

**Authorized Patterns**:
- `*.contoso.com` - All subdomains
- `*.dev.contoso.com` - Development subdomains
- `*.staging.contoso.com` - Staging subdomains
- `*.prod.contoso.com` - Production subdomains
- `api.contoso.com` - Specific API domain
- `admin.contoso.com` - Specific admin domain

**Unauthorized Patterns**:
- `*.external.com` - External domains not authorized
- `*.competitor.com` - Competitor domains
- `root.contoso.com` - Root domain (use specific subdomain)

### Error Codes and Messages

| Error Code | Message | Solution |
|------------|---------|----------|
| **AUTH-001** | "User not authorized for certificate template" | Request access to appropriate AD group |
| **AUTH-002** | "Domain not authorized for user role" | Use authorized domain pattern |
| **AUTH-003** | "Asset ownership verification failed" | Verify server ownership in CMDB |
| **AUTH-004** | "Certificate template requires manual approval" | Wait for PKI admin approval |
| **RENEW-001** | "Automatic renewal failed" | Check webhook connectivity and logs |
| **RENEW-002** | "Certificate deployment failed" | Check application configuration |
| **RENEW-003** | "Service reload failed" | Check service configuration and permissions |

---

**Last Updated**: October 23, 2025  
**Version**: 1.0  
**Status**: ✅ Complete - Ready for Service Owner Use

---

*This guide provides everything service owners need to successfully manage certificates in the Keyfactor PKI environment. For additional support, contact the PKI team at pki-team@contoso.com.*