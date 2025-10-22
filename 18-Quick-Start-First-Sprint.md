# Quick Start Guide - First Sprint (2 Weeks)
## Get Started with Keyfactor Implementation

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Purpose

This guide will help you complete your first 2-week implementation sprint and demonstrate end-to-end automated certificate lifecycle management with Keyfactor.

**Sprint Goal**: Prove zero-touch certificate issuance and renewal for one workload type.

---

## Sprint Outcomes

By end of Sprint 1, you will have:

✅ **Keyfactor Command operational** with certificate discovery running  
✅ **One enrollment rail working** end-to-end (Kubernetes OR Windows OR ACME)  
✅ **Automated renewal demonstrated** with webhook-driven deployment  
✅ **Certificate inventory** for pilot scope (10-50 certificates discovered and tagged)  
✅ **Policy catalog v1.0** published with 3-5 templates  
✅ **Dashboard** showing KPIs for pilot workloads  

**Demo-ready**: Issue cert via self-service → auto-renew at configured window → service reloads without manual intervention.

---

## Prerequisites

### Required Before Starting

- [ ] Keyfactor licenses procured (SaaS tenant activated OR self-hosted license keys)
- [ ] Network access configured:
  - [ ] Orchestrators can reach Keyfactor Command (HTTPS port 443)
  - [ ] Keyfactor can reach CA (AD CS or EJBCA) for issuance
  - [ ] Webhook endpoint accessible (Azure Logic App / AWS Lambda / on-prem automation)
- [ ] Credentials ready:
  - [ ] Keyfactor admin account (Entra ID / AD)
  - [ ] CA integration account (for AD CS) or API credentials (for EJBCA)
  - [ ] Cloud provider credentials (Azure, AWS - read-only for discovery)
- [ ] Pilot workload identified (pick ONE):
  - [ ] **Option A**: 1 Kubernetes cluster (5-10 ingress certificates)
  - [ ] **Option B**: 1 Windows server group (5-10 IIS servers)
  - [ ] **Option C**: 1 set of web apps (5-10 Apache/Nginx servers)

### Team Required

- **Keyfactor Administrator** (1 person, 80% time)
- **Platform Engineer** (1 person, 40% time - for K8s/cloud/infra)
- **Automation Engineer** (1 person, 40% time - for webhooks/scripts)
- **Security Reviewer** (1 person, 10% time - for policy approval)

---

## Week 1: Setup and Discovery

### Day 1: Deploy Keyfactor Command

**If SaaS**:

1. **Activate tenant**:
   ```
   Navigate to: https://portal.keyfactor.com
   Sign in with provided activation email
   Complete org setup wizard
   ```

2. **Configure SSO** (Entra ID recommended):
   ```
   Settings → Authentication → SAML 2.0
   - IdP Entity ID: https://sts.windows.net/<tenant-id>/
   - SSO URL: https://login.microsoftonline.com/<tenant-id>/saml2
   - Certificate: Download from Entra ID
   - Attribute Mapping:
     - Email: http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress
     - Groups: http://schemas.microsoft.com/ws/2008/06/identity/claims/groups
   ```

3. **Create initial admins**:
   ```
   Users → Add User
   - Assign role: "Keyfactor Administrator"
   - Add to group: "PKI-Admins"
   ```

**If Self-Hosted**:

1. **Deploy 3-node cluster** (if HA required) or single server (for pilot):
   - **OS**: Windows Server 2019+ or Linux (containerized)
   - **Requirements**: 8 vCPU, 16 GB RAM, 100 GB disk per node
   - **Database**: SQL Server 2019+ (Always-On for HA) or PostgreSQL 12+

2. **Install Keyfactor Command**:
   ```powershell
   # Run on each node
   .\KeyfactorCommandInstaller.exe /install /config C:\temp\kf-config.json
   
   # kf-config.json:
   {
     "DatabaseConnection": "Server=sql-kf.contoso.com;Database=Keyfactor;Integrated Security=True",
     "WebAppURL": "https://keyfactor.contoso.com",
     "ServiceAccount": "CONTOSO\\svc-keyfactor",
     "AdminUser": "admin@contoso.com"
   }
   ```

3. **Configure load balancer** (if HA):
   - Health check: `GET /health` (should return 200 OK)
   - Session affinity: Not required (stateless)

**Expected Time**: 2-4 hours

---

### Day 2: Integrate Certificate Authority

**Option A: Integrate Existing AD CS**

1. **Install Keyfactor CA Gateway** on AD CS server:
   ```powershell
   # On AD CS server
   .\KeyfactorCAGatewayInstaller.exe /install
   
   # Configuration:
   - Keyfactor URL: https://keyfactor.contoso.com
   - API Key: <generated from Keyfactor>
   - CA Name: <your AD CS name>
   ```

2. **Test issuance**:
   ```powershell
   # In Keyfactor portal
   Certificate Authorities → Add CA → Select "Microsoft CA"
   - Hostname: adcs.contoso.com
   - CA Name: Contoso-Issuing-CA
   - Test Connection → should succeed
   
   # Test CSR submission
   Certificates → Enroll → Manual CSR
   - Paste test CSR
   - Select CA: Contoso-Issuing-CA
   - Issue → certificate returned ✓
   ```

**Option B: Deploy New EJBCA** (if greenfield):

[Inference]: EJBCA setup is complex; for first sprint, recommend using existing AD CS if available. EJBCA can be added in later phase.

If proceeding with EJBCA:

1. Deploy EJBCA (see vendor documentation)
2. Integrate HSM (Azure Managed HSM recommended)
3. Configure in Keyfactor:
   ```
   Certificate Authorities → Add CA → EJBCA
   - REST API URL: https://ejbca.contoso.com/ejbca/ejbca-rest-api
   - Client Certificate: <mTLS cert for auth>
   - Certificate Profile: TLS-Server-Internal
   - End Entity Profile: Default
   ```

**Expected Time**: 2-4 hours

---

### Day 3: Deploy Orchestrators and Run Discovery

**Deploy Orchestrator to Pilot Network Zone**:

1. **Download orchestrator** from Keyfactor portal:
   ```
   Orchestrators → Add Orchestrator → Download Agent
   ```

2. **Install** on jump box or management server in pilot zone:
   
   **Windows**:
   ```powershell
   .\KeyfactorOrchestrator.msi /install /config orchestrator-config.json
   
   # orchestrator-config.json:
   {
     "KeyfactorURL": "https://keyfactor.contoso.com",
     "APIKey": "<generated from Keyfactor>",
     "OrchestratorName": "orch-pilot-01",
     "Capabilities": ["Discovery", "Enrollment", "Management"]
   }
   ```
   
   **Linux**:
   ```bash
   docker run -d --name keyfactor-orchestrator \
     -e KEYFACTOR_URL=https://keyfactor.contoso.com \
     -e API_KEY=<your_api_key> \
     -e ORCHESTRATOR_NAME=orch-pilot-01 \
     keyfactor/orchestrator:latest
   ```

3. **Verify orchestrator online**:
   ```
   Keyfactor Portal → Orchestrators → should show "orch-pilot-01" with status "Online"
   ```

**Configure Discovery Job**:

**For Kubernetes**:
```yaml
# In Keyfactor portal:
Discovery → Add Job → Kubernetes
- Orchestrator: orch-pilot-01
- K8s API Endpoint: https://k8s-api.contoso.com:6443
- Authentication: ServiceAccount token
  - Token: <from kubectl create sa keyfactor-discovery>
- Namespaces: production,staging (or * for all)
- Secret Types: kubernetes.io/tls
- Schedule: Daily at 2 AM
```

**For Windows/IIS**:
```yaml
Discovery → Add Job → Windows Certificate Stores
- Orchestrator: orch-pilot-01
- Targets: List of server FQDNs or OU=Servers,DC=contoso,DC=com
- Certificate Stores: ["LocalMachine\My", "LocalMachine\WebHosting"]
- Authentication: Windows (orchestrator service account needs admin rights)
- Schedule: Daily at 2 AM
```

**For Cloud (Azure)**:
```yaml
Discovery → Add Job → Azure Key Vault
- Orchestrator: orch-pilot-01
- Subscription ID: <your sub ID>
- Authentication: Managed Identity or Service Principal
- Resource Groups: rg-prod, rg-dev (or * for all)
- Key Vaults: * (discover all)
- Schedule: Daily at 2 AM
```

4. **Run discovery manually** (first time):
   ```
   Discovery → Select job → Run Now
   Wait 5-15 minutes depending on scope
   ```

5. **Review results**:
   ```
   Certificates → Inventory
   - Should see discovered certificates
   - Status: "Unmanaged" (not yet issued by Keyfactor)
   ```

**Expected Time**: 3-5 hours

---

### Day 4: Tag Certificate Ownership

**Goal**: Map every discovered certificate to an owner/team for accountability.

**Important**: You do NOT need an enterprise CMDB for this. See [ASSET-INVENTORY-INTEGRATION-GUIDE.md](./ASSET-INVENTORY-INTEGRATION-GUIDE.md) for 5 options from simple (CSV) to enterprise (ServiceNow).

1. **Export certificate inventory**:
   ```
   Certificates → Inventory → Export to CSV
   ```

2. **Match to Asset Inventory**:

**Option A: Simple CSV** (recommended for first sprint):
   ```python
   # Create simple asset inventory
   import pandas as pd
   import requests
   
   certs = pd.read_csv('cert-inventory.csv')
   
   # Create asset inventory from known servers (50 provided in asset-inventory-template.csv)
   assets = pd.read_csv('asset-inventory-template.csv')
   
   for index, cert in certs.iterrows():
       # Extract server from SAN or CN
       server = cert['Subject'].split('CN=')[1].split(',')[0]
       
       # Look up in asset inventory
       owner_row = assets[assets['hostname'] == server]
       if not owner_row.empty:
           owner = owner_row.iloc[0]['owner_email']
           team = owner_row.iloc[0]['owner_team']
           
           # Update cert metadata in Keyfactor via API
           requests.put(
               f'https://keyfactor.contoso.com/api/v1/certificates/{cert["ID"]}/metadata',
               headers={'Authorization': f'Bearer {api_key}'},
               json={'owner': owner, 'team': team, 'environment': owner_row.iloc[0]['environment']}
           )
   ```

**Option B: Enterprise CMDB** (if ServiceNow/BMC exists):
   ```python
   # Query ServiceNow CMDB
   import requests
   
   SNOW_URL = 'https://contoso.service-now.com/api/now/table/cmdb_ci_server'
   
   for index, cert in certs.iterrows():
       server = cert['Subject'].split('CN=')[1].split(',')[0]
       
       # Query CMDB
       response = requests.get(
           SNOW_URL,
           params={'sysparm_query': f'name={server}'},
           auth=('keyfactor-api', '<password>')
       )
       
       if response.json()['result']:
           ci = response.json()['result'][0]
           # Update Keyfactor with CMDB data
           # ...
   ```

3. **Manual tagging** (for unmapped certs):
   ```
   For each unowned cert:
   - Identify by DNS name or IP
   - Contact server/app teams to claim ownership
   - Update metadata:
     Certificates → Select cert → Metadata → Add:
       - owner: john.doe@contoso.com
       - team: web-apps
       - environment: production
       - costcenter: 12345
   ```

4. **Ownership report**:
   ```sql
   -- Run query in Keyfactor (or export and analyze)
   SELECT 
     COUNT(*) as total_certs,
     SUM(CASE WHEN metadata LIKE '%owner%' THEN 1 ELSE 0 END) as owned_certs,
     (SUM(CASE WHEN metadata LIKE '%owner%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) as percent_owned
   FROM certificates
   WHERE status = 'Active'
   
   -- Target: ≥90% owned by end of Week 1
   ```

**Expected Time**: 4-6 hours (depends on CMDB quality)

---

### Day 5: Define Policy Catalog v1.0

**Create 3-5 certificate templates** for pilot scope.

**Example: TLS-Server-Internal**

1. **In Keyfactor Portal**:
   ```
   Templates → Add Template
   - Name: TLS-Server-Internal
   - Description: Internal TLS certificates for web/API servers
   - CA: Contoso-Issuing-CA (AD CS) or EJBCA-Issuing-CA
   ```

2. **Technical Policy**:
   ```yaml
   Key Algorithm: RSA or ECDSA
   Key Size (RSA): 3072 minimum
   Key Curve (ECDSA): P-256 or P-384
   Lifetime: 730 days
   Extended Key Usage: serverAuth
   SAN Required: Yes
   Subject Format: CN={primary_san}, O=Contoso Inc, C=US
   ```

3. **Authorization** (RBAC):
   ```yaml
   Allowed Groups:
     - INFRA-ServerAdmins:
         auto_approve: true
         san_patterns: ["*.contoso.com", "*.internal.contoso.com"]
         max_sans: 10
     - APP-WebDevs:
         auto_approve: true
         san_patterns: ["*.dev.contoso.com", "*.test.contoso.com"]
         max_sans: 5
   
   SAN Validation:
     - DNS must resolve: Yes
     - DNS zone must be: contoso.com, internal.contoso.com
     - Wildcard allowed: Yes (for admins), No (for devs)
   ```

4. **Renewal**:
   ```yaml
   Auto-renew: Yes
   Renewal window: 30 days before expiry
   Notify owner: Yes (email at T-30d, T-7d, T-1d)
   ```

**Repeat for other templates**:
- TLS-Client-mTLS (if service-to-service auth in pilot)
- K8s-Ingress-TLS (if Kubernetes pilot)
- Windows-Domain-Computer (if Windows pilot)

**Document templates** in `03-Policy-Catalog.md` or internal wiki.

**Expected Time**: 2-3 hours

---

## Week 2: Enrollment and Automation

### Day 6-8: Deploy One Enrollment Rail

**Choose ONE based on your pilot workload**:

---

#### **Option A: Kubernetes + cert-manager**

**Install cert-manager**:
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=120s
```

**Install Keyfactor Issuer Plugin**:
```bash
# Install Keyfactor CA Issuer (external issuer for cert-manager)
kubectl apply -f https://github.com/Keyfactor/cert-manager-issuer/releases/latest/download/keyfactor-issuer.yaml

# Or use generic external issuer with Keyfactor webhook
```

**Create Keyfactor API Credentials**:
```bash
# In Keyfactor portal: Generate API key for ServiceAccount "cert-manager"
API_KEY="<your_api_key>"

# Create secret in K8s
kubectl create secret generic keyfactor-api-token \
  --from-literal=token=$API_KEY \
  -n cert-manager
```

**Configure ClusterIssuer**:
```yaml
# keyfactor-cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: keyfactor-issuer
spec:
  keyfactor:
    server: https://keyfactor.contoso.com
    caName: Contoso-Issuing-CA
    template: K8s-Ingress-TLS
    secretRef:
      name: keyfactor-api-token
      key: token
```

```bash
kubectl apply -f keyfactor-cluster-issuer.yaml

# Verify issuer is ready
kubectl get clusterissuer keyfactor-issuer -o yaml
# Status should show: Ready: True
```

**Test with Sample Application**:
```yaml
# test-app-certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-app-tls
  namespace: default
spec:
  secretName: test-app-tls-secret
  issuerRef:
    name: keyfactor-issuer
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
    - test-app.dev.contoso.com
  duration: 2160h  # 90 days
  renewBefore: 720h  # Renew 30 days before expiry
```

```bash
kubectl apply -f test-app-certificate.yaml

# Watch certificate issuance
kubectl get certificate test-app-tls -w
# Should transition: Pending → Issued

# Verify secret created
kubectl get secret test-app-tls-secret -o yaml
# Should contain tls.crt and tls.key
```

**Deploy Test Ingress**:
```yaml
# test-app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-app-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: keyfactor-issuer
spec:
  tls:
  - hosts:
    - test-app.dev.contoso.com
    secretName: test-app-tls-secret
  rules:
  - host: test-app.dev.contoso.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-app
            port:
              number: 80
```

```bash
kubectl apply -f test-app-ingress.yaml

# Test HTTPS
curl https://test-app.dev.contoso.com
# Should return 200 OK with valid TLS cert
```

---

#### **Option B: Windows Auto-Enrollment**

**Configure GPO**:

1. **Create GPO**: "Certificate Auto-Enrollment - Pilot Servers"
   ```
   Group Policy Management Console:
   - Right-click OU containing pilot servers → Create a GPO
   - Name: "Certificate Auto-Enrollment - Pilot Servers"
   ```

2. **Configure Auto-Enrollment**:
   ```
   Edit GPO:
   Computer Configuration → Policies → Windows Settings 
     → Security Settings → Public Key Policies 
     → Certificate Services Client - Auto-Enrollment
   
   - Configuration Model: Enabled
   - Renew expired certificates, update pending certificates, remove revoked certificates: ✓
   - Update certificates that use certificate templates: ✓
   ```

3. **Publish Certificate Template** (in AD CS):
   ```powershell
   # On AD CS server
   # Ensure template "Windows-Domain-Computer" exists and is published
   certutil -CATemplates
   # Should list: "Windows-Domain-Computer"
   
   # If not, publish:
   # Open Certification Authority MMC → Certificate Templates → right-click → New → Certificate Template to Issue
   # Select "Computer" template (or custom "Windows-Domain-Computer")
   ```

4. **Apply GPO to pilot servers**:
   ```
   Link GPO to OU: OU=PilotServers,OU=Servers,DC=contoso,DC=com
   ```

5. **Force GPO update on pilot server**:
   ```powershell
   # RDP to pilot server
   gpupdate /force
   
   # Trigger certificate enrollment
   certutil -pulse
   
   # Verify certificate issued
   Get-ChildItem Cert:\LocalMachine\My
   # Should show new cert with CN=<server-fqdn>
   ```

**Configure Keyfactor Orchestrator for IIS Auto-Binding**:

1. **Install Keyfactor IIS Store Type** (orchestrator plugin)
2. **Configure IIS Certificate Store**:
   ```yaml
   Certificate Stores → Add Store → IIS
   - Store Type: IIS
   - Server: iis-pilot-01.contoso.com
   - Orchestrator: orch-pilot-01
   - Authentication: Windows (orchestrator service account)
   - Auto-bind: Yes (update IIS bindings on renewal)
   - Sites: Default Web Site, MyApp
   ```

3. **Test renewal**:
   ```powershell
   # Temporarily shorten cert lifetime for testing
   # In AD CS template: set validity to 7 days
   # OR manually expire cert in Keyfactor
   
   # Trigger renewal
   # Keyfactor should: renew → install to cert store → update IIS binding → iisreset
   
   # Verify IIS using new cert
   Get-WebBinding -Name "Default Web Site" -Protocol https
   # Check certificate thumbprint matches renewed cert
   ```

---

#### **Option C: ACME for Web Servers**

**Configure Keyfactor ACME Directory**:

1. **In Keyfactor Portal**:
   ```
   ACME → Add Directory
   - Name: internal-dev
   - URL: https://keyfactor.contoso.com/acme/internal-dev
   - Template: TLS-Server-Internal
   - Authentication: API Key
   - Allowed Users: APP-WebDevs, INFRA-ServerAdmins
   - Allowed Domains: *.dev.contoso.com, *.test.contoso.com
   - Challenge Types: HTTP-01, DNS-01
   ```

2. **Configure DNS Integration** (for DNS-01):
   ```
   ACME → DNS Providers → Add
   - Provider: Azure DNS
   - Authentication: Managed Identity or Service Principal
   - Zones: dev.contoso.com, test.contoso.com
   ```

**Install ACME Client on Pilot Server**:

**Linux (certbot)**:
```bash
# Install certbot
sudo apt-get install certbot  # Debian/Ubuntu
# OR
sudo yum install certbot  # RHEL/CentOS

# Request certificate
sudo certbot certonly \
  --server https://keyfactor.contoso.com/acme/internal-dev \
  --email admin@contoso.com \
  --agree-tos \
  --manual --preferred-challenges http \
  --domain webapp01.dev.contoso.com

# Follow prompts to place validation file
# Certificate saved to: /etc/letsencrypt/live/webapp01.dev.contoso.com/

# Configure Apache/Nginx to use cert
sudo vim /etc/apache2/sites-available/webapp01.conf
# SSLCertificateFile /etc/letsencrypt/live/webapp01.dev.contoso.com/fullchain.pem
# SSLCertificateKeyFile /etc/letsencrypt/live/webapp01.dev.contoso.com/privkey.pem

sudo systemctl reload apache2
```

**Windows (win-acme)**:
```powershell
# Download win-acme
Invoke-WebRequest -Uri "https://github.com/win-acme/win-acme/releases/latest/download/win-acme.v2.2.6.1521.x64.pluggable.zip" -OutFile "win-acme.zip"
Expand-Archive -Path win-acme.zip -DestinationPath C:\win-acme

# Run win-acme
cd C:\win-acme
.\wacs.exe

# Interactive prompts:
# N: Create new certificate
# 2: Manual input
# Host: webapp01.dev.contoso.com
# ACME server: https://keyfactor.contoso.com/acme/internal-dev
# Email: admin@contoso.com

# Win-acme will:
# - Place validation file in IIS
# - Request cert from Keyfactor
# - Install to Windows cert store
# - Update IIS binding
# - Create scheduled task for renewal
```

**Test Renewal**:
```bash
# Linux
sudo certbot renew --dry-run --server https://keyfactor.contoso.com/acme/internal-dev

# Windows
C:\win-acme\wacs.exe --renew
```

---

### Day 9: Implement Webhook Automation

**Goal**: Automate certificate deployment on renewal.

**Choose platform**: Azure Logic App (recommended for Azure-heavy shops) OR AWS Lambda OR on-prem Python/PowerShell script.

---

**Azure Logic App Example**:

1. **Create Logic App**:
   ```
   Azure Portal → Logic Apps → Create
   - Name: keyfactor-renewal-automation
   - Region: <your region>
   - Plan: Consumption (pay-per-use)
   ```

2. **Design workflow**:
   ```
   Trigger: HTTP Request (Keyfactor webhook)
   └─ Parse JSON (webhook payload)
      └─ Condition: event == "certificate_renewed"
         ├─ True:
         │  ├─ HTTP GET: Fetch certificate from Keyfactor API
         │  │   URL: https://keyfactor.contoso.com/api/v1/certificates/{certificateId}/download
         │  │   Headers: Authorization: Bearer <API_KEY>
         │  │
         │  ├─ Azure Key Vault: Set Secret
         │  │   Vault: kv-prod
         │  │   Secret Name: {metadata.server}-tls
         │  │   Value: {pfx_base64}
         │  │
         │  ├─ Run PowerShell Script (Hybrid Worker or Azure Automation)
         │  │   Script: Update-IISBinding.ps1
         │  │   Parameters: -Server {metadata.server} -Thumbprint {thumbprint}
         │  │
         │  ├─ HTTP GET: Verify deployment
         │  │   URL: https://{metadata.server}
         │  │   Expected: Status 200, Cert thumbprint matches
         │  │
         │  └─ ServiceNow: Create Change Record
         │      Body: "Renewed cert for {server}, new expiry {expiryDate}"
         │
         └─ False: (ignore other events)
   ```

3. **Deploy Update-IISBinding.ps1** (on Hybrid Worker or as Azure Automation Runbook):
   ```powershell
   param(
       [string]$Server,
       [string]$Thumbprint
   )
   
   # Fetch PFX from Key Vault
   $secret = Get-AzKeyVaultSecret -VaultName "kv-prod" -Name "$Server-tls"
   $pfxBytes = [Convert]::FromBase64String($secret.SecretValue)
   $pfxPath = "C:\temp\$Server-$Thumbprint.pfx"
   [System.IO.File]::WriteAllBytes($pfxPath, $pfxBytes)
   
   # Import to server cert store
   Invoke-Command -ComputerName $Server -ScriptBlock {
       param($pfxPath, $Thumbprint)
       
       Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\My -Exportable:$false
       
       # Update IIS binding
       Import-Module WebAdministration
       $binding = Get-WebBinding -Name "Default Web Site" -Protocol https
       $binding.AddSslCertificate($Thumbprint, "My")
       
       # Graceful recycle
       iisreset /noforce
       
   } -ArgumentList $pfxPath, $Thumbprint
   
   Write-Output "Certificate deployed successfully to $Server"
   ```

4. **Configure Keyfactor webhook**:
   ```
   Keyfactor Portal → Webhooks → Add
   - Name: renewal-automation
   - Events: certificate_renewed
   - URL: <Logic App HTTP trigger URL>
   - Authentication: HMAC signature (shared secret)
   ```

5. **Test end-to-end**:
   ```
   # Manually trigger renewal in Keyfactor
   Certificates → Select pilot cert → Actions → Renew Now
   
   # Watch Logic App run history
   Azure Portal → Logic App → Run History → Latest run
   - Should show: Success, all steps completed
   
   # Verify:
   - Key Vault has new secret version
   - IIS server has new cert bound
   - ServiceNow change record created
   ```

---

### Day 10: Measure and Demo

**Configure Dashboard**:

**In Keyfactor Portal** (or PowerBI / Grafana):

1. **Certificate Expiration Timeline**:
   ```
   Widget: Bar Chart
   - X-axis: Time buckets (30d, 60d, 90d, 180d, 365d)
   - Y-axis: Certificate count
   - Filter: Status = Active, Environment = Pilot
   ```

2. **Renewal Success Rate**:
   ```
   Widget: Gauge
   - Metric: (Successful renewals / Total renewal attempts) × 100
   - Target: ≥95%
   - Period: Last 7 days
   ```

3. **Unmanaged Certificates**:
   ```
   Widget: Number
   - Metric: COUNT(*) WHERE isManaged = false
   - Target: 0 (for pilot scope)
   ```

4. **Auto-Renewal Coverage**:
   ```
   Widget: Pie Chart
   - Slices:
     - Auto-renewed: certificates with auto_renew = true
     - Manual: certificates with auto_renew = false
   - Target: ≥80% auto-renewed
   ```

**Prepare Demo**:

**Demo Script**:

1. **Show inventory**:
   ```
   "We've discovered 47 certificates in our pilot scope across 12 servers.
    All are tagged with ownership metadata (owner, team, environment)."
   
   [Navigate to: Certificates → Inventory → Filter: Environment = pilot]
   ```

2. **Request new certificate** (self-service):
   ```
   "A developer can request a cert via Kubernetes manifest:"
   
   [Show Certificate YAML manifest]
   [kubectl apply -f test-app-cert.yaml]
   [Watch: kubectl get certificate test-app-tls -w]
   [Show: Certificate issued in <30 seconds]
   ```

3. **Show authorization enforcement**:
   ```
   "If I try to request a cert for a domain I'm not authorized for..."
   
   [Attempt to issue cert for *.prod.contoso.com as APP-WebDevs user]
   [Show: Request denied with reason "SAN not in allowed patterns"]
   [Show: Audit log entry with denial reason]
   ```

4. **Demonstrate renewal**:
   ```
   "For this test cert, I've set a short lifetime (1 day). Let's watch renewal."
   
   [Show: Certificate expiring in 6 hours]
   [cert-manager triggers renewal automatically]
   [New certificate issued, secret updated]
   [Ingress controller reloads (no downtime)]
   [Show: HTTPS endpoint now serving new cert]
   [Show: ServiceNow change record created automatically]
   ```

5. **Show KPIs**:
   ```
   "In our pilot, we've achieved:
    - 100% certificate visibility (47/47 discovered)
    - 95% auto-renewal rate (1 cert required manual approval)
    - <2 minute time-to-issue
    - Zero manual intervention for renewals"
   
   [Show dashboard]
   ```

**Expected Time**: 4 hours (prep + demo)

---

## Success Criteria Checklist

### Technical

- [ ] Keyfactor Command operational and accessible
- [ ] CA integrated and issuing certificates
- [ ] Orchestrator deployed and discovering certificates
- [ ] ≥90% of pilot certificates have ownership metadata
- [ ] 3-5 certificate templates defined and tested
- [ ] One enrollment rail working end-to-end (K8s OR Windows OR ACME)
- [ ] Webhook automation deployed and tested
- [ ] Certificate renewal demonstrated with zero downtime
- [ ] Dashboard showing KPIs for pilot scope

### Process

- [ ] Certificate policy catalog v1.0 published
- [ ] RBAC groups configured (pilot: ≥2 groups)
- [ ] Runbook documented for common operations
- [ ] Support channel established (#pki-support)

### Demonstration

- [ ] Demo successfully delivered to stakeholders
- [ ] End-to-end automation proven (issue → renew → deploy)
- [ ] Authorization controls demonstrated (deny + allow scenarios)
- [ ] KPIs presented showing success metrics

---

## Common Issues and Troubleshooting

### Issue: Orchestrator shows "Offline"

**Cause**: Network connectivity or authentication failure

**Troubleshooting**:
```bash
# Check orchestrator logs
# Windows: C:\Program Files\Keyfactor\Orchestrator\logs\orchestrator.log
# Linux: docker logs keyfactor-orchestrator

# Common errors:
# - "401 Unauthorized" → API key invalid or expired
# - "Connection timeout" → Firewall blocking port 443
# - "Certificate validation failed" → Trust chain issue

# Fix:
# - Regenerate API key in Keyfactor Portal
# - Verify firewall rules: orchestrator → keyfactor.contoso.com:443
# - Import Keyfactor TLS cert to orchestrator trust store
```

---

### Issue: Certificate request denied "SAN validation failed"

**Cause**: Requested SAN not in allowed patterns for requester's role

**Troubleshooting**:
```
# Check requester's groups
Keyfactor Portal → Users → <user> → Groups

# Check template SAN patterns
Templates → <template> → Authorization → SAN Patterns

# Example fix:
# If user in "APP-WebDevs" requesting "myapp.prod.contoso.com"
# But "APP-WebDevs" only allowed ["*.dev.contoso.com", "*.test.contoso.com"]
# → Either use dev/test domain OR request INFRA-ServerAdmins group membership
```

---

### Issue: cert-manager Certificate stuck in "Pending"

**Cause**: CSR submission to Keyfactor failed or challenge validation failed

**Troubleshooting**:
```bash
# Check Certificate events
kubectl describe certificate <name>
# Look for:
# - "Failed to request certificate: 401 Unauthorized" → API key invalid
# - "Failed to validate order: DNS validation failed" → DNS record not created

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager -f

# Check Keyfactor audit log
# Portal → Audit → filter by requester = cert-manager
# Look for denied requests with reason

# Common fixes:
# - Regenerate API key secret
# - Check DNS integration (for DNS-01 challenge)
# - Verify ClusterIssuer configuration
```

---

### Issue: Webhook not triggering automation

**Cause**: Webhook endpoint unreachable or authentication failed

**Troubleshooting**:
```bash
# Check Keyfactor webhook logs
# Portal → Webhooks → <webhook> → Delivery History
# Look for:
# - "Delivery failed: 500 Server Error" → Automation endpoint issue
# - "Delivery failed: Timeout" → Endpoint unreachable or slow

# Test webhook manually
curl -X POST <webhook_url> \
  -H "Content-Type: application/json" \
  -d '{"event":"certificate_renewed","certificateId":"12345",...}'

# Check automation logs
# Logic App: Azure Portal → Logic App → Run History
# Lambda: AWS CloudWatch Logs

# Common fixes:
# - Check firewall: Keyfactor → webhook endpoint
# - Verify webhook authentication (HMAC signature)
# - Increase timeout (for slow endpoints)
```

---

## Next Steps After Sprint 1

**Immediate** (Week 3):
- Expand pilot scope (add 10-20 more certificates)
- Deploy second enrollment rail (if did K8s, now add Windows)
- Implement monitoring alerts (cert expiring <7 days)

**Short-term** (Month 2):
- Phase 2: CA and HSM (if not done) - see [05-Implementation-Runbooks.md](./05-Implementation-Runbooks.md)
- Phase 3: Add remaining enrollment rails
- Enable policy enforcement (deny unmanaged certs in CI/CD)

**Medium-term** (Month 3-6):
- Scale to all environments (dev → test → staging → prod)
- Mandatory management (block unmanaged certs)
- Advanced automation (drift detection, compliance reporting)

---

## Resources

**Documentation**:
- [01 - Executive Design Document](./01-Executive-Design-Document.md)
- [02 - RBAC Authorization Framework](./02-RBAC-Authorization-Framework.md)
- [03 - Policy Catalog](./03-Policy-Catalog.md)
- [07 - Enrollment Rails Guide](./07-Enrollment-Rails-Guide.md)
- [10 - Incident Response Procedures](./10-Incident-Response-Procedures.md)

**Vendor Docs**:
- Keyfactor Command: https://software.keyfactor.com/Guides/Keyfactor_Platform/
- cert-manager: https://cert-manager.io/docs/
- ACME Protocol: https://datatracker.ietf.org/doc/html/rfc8555

**Support**:
- Slack: #pki-support
- Email: pki-team@contoso.com
- On-call: [PagerDuty/ServiceNow]

---

## Feedback

**Document Owner**: Adrian Johnson <adrian207@gmail.com>

**Found issues with this guide?** Submit feedback to #pki-support or create a ticket.

**Version**: 1.0  
**Last Updated**: October 22, 2025

