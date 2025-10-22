# Architecture Diagrams
## Visual System Architecture and Flows

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Purpose

This document provides visual representations of the Keyfactor certificate lifecycle management system architecture, enrollment flows, and integration patterns.

---

## Table of Contents

1. [High-Level System Architecture](#1-high-level-system-architecture)
2. [Component Architecture](#2-component-architecture)
3. [Authorization Flow](#3-authorization-flow)
4. [Enrollment Flows](#4-enrollment-flows)
5. [Renewal Automation Flow](#5-renewal-automation-flow)
6. [Network Architecture](#6-network-architecture)
7. [Integration Architecture](#7-integration-architecture)

---

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  ENROLLMENT LAYER                                │
│                                                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │   ACME   │  │   EST    │  │   SCEP   │  │   GPO    │  │   API    │         │
│  │  (HTTP)  │  │ (HTTPS)  │  │ (HTTP)   │  │ AutoEnroll│ │(REST/SDK)│         │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘         │
│       │             │             │             │             │                 │
└───────┼─────────────┼─────────────┼─────────────┼─────────────┼─────────────────┘
        │             │             │             │             │
        ▼             ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          KEYFACTOR COMMAND (Control Plane)                       │
│                                                                                   │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │                       POLICY ENGINE (RBAC + SAN)                          │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │  │
│  │  │  Identity    │  │     SAN      │  │   Resource   │  │   Template   │ │  │
│  │  │    RBAC      │  │  Validation  │  │   Binding    │  │    Policy    │ │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                   │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                   │
│  │   Discovery    │  │   Workflow     │  │   Webhook      │                   │
│  │   & Inventory  │  │   Engine       │  │   Publisher    │                   │
│  └────────────────┘  └────────────────┘  └────────────────┘                   │
│                                                                                   │
│  ┌──────────────────────────────────────────────────────────────────────────┐  │
│  │             ORCHESTRATORS (Agents in each network zone)                   │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
└────────┬──────────────────────┬──────────────────────┬──────────────────────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────────────┐
│       CA         │  │  Secrets Stores   │  │       Target Endpoints           │
│    LAYER         │  │                   │  │                                  │
│                  │  │  ┌─────────────┐  │  │  ┌─────────────┐               │
│  ┌───────────┐   │  │  │   Azure     │  │  │  │   Windows   │               │
│  │  AD CS    │   │  │  │ Key Vault   │  │  │  │   IIS/Svrs  │               │
│  └───────────┘   │  │  └─────────────┘  │  │  └─────────────┘               │
│                  │  │                   │  │                                  │
│  ┌───────────┐   │  │  ┌─────────────┐  │  │  ┌─────────────┐               │
│  │  EJBCA    │   │  │  │ HashiCorp   │  │  │  │ Kubernetes  │               │
│  │  (HSM)    │   │  │  │   Vault     │  │  │  │  Clusters   │               │
│  └───────────┘   │  │  └─────────────┘  │  │  └─────────────┘               │
│                  │  │                   │  │                                  │
│  ┌───────────┐   │  │                   │  │  ┌─────────────┐               │
│  │ Public CA │   │  │                   │  │  │     Load    │               │
│  │(Let's Enc)│   │  │                   │  │  │   Balancers │               │
│  └───────────┘   │  │                   │  │  └─────────────┘               │
└──────────────────┘  └──────────────────┘  └──────────────────────────────────┘
         │                      │                      │
         └──────────────────────┴──────────────────────┘
                                │
                                ▼
                ┌───────────────────────────────┐
                │   Observability & Audit       │
                │  ┌─────────────────────────┐  │
                │  │  Azure Monitor/Grafana  │  │
                │  │  (Dashboards & Alerts)  │  │
                │  └─────────────────────────┘  │
                │  ┌─────────────────────────┐  │
                │  │  Azure Sentinel/SIEM    │  │
                │  │  (Security Events)      │  │
                │  └─────────────────────────┘  │
                │  ┌─────────────────────────┐  │
                │  │  ServiceNow (ITSM)      │  │
                │  │  (Change/Incidents)     │  │
                │  └─────────────────────────┘  │
                └───────────────────────────────┘
```

---

## 2. Component Architecture

### 2.1 Keyfactor Command Internal Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        KEYFACTOR COMMAND                                │
│                                                                          │
│  ┌───────────────────────────────────────────────────────────────┐     │
│  │                     API Gateway (REST/GraphQL)                  │     │
│  │  - Authentication (OAuth2, API Keys)                            │     │
│  │  - Rate Limiting                                                │     │
│  │  - Request Validation                                           │     │
│  └───────────────┬────────────────────────────┬───────────────────┘     │
│                  │                            │                         │
│  ┌───────────────▼────────┐    ┌──────────────▼─────────────┐          │
│  │   Policy Engine         │    │   Workflow Engine          │          │
│  │                         │    │                            │          │
│  │  - RBAC Evaluation      │    │  - Approval Routing        │          │
│  │  - SAN Validation       │    │  - ServiceNow Integration  │          │
│  │  - Resource Binding     │    │  - Notification            │          │
│  │  - Template Enforcement │    │                            │          │
│  └───────────────┬─────────┘    └────────────┬───────────────┘          │
│                  │                           │                          │
│                  └──────────┬────────────────┘                          │
│                             │                                           │
│             ┌───────────────▼────────────────┐                          │
│             │   Certificate Manager           │                          │
│             │                                 │                          │
│             │  - Issuance Coordination        │                          │
│             │  - Renewal Scheduling           │                          │
│             │  - Revocation Processing        │                          │
│             │  - Inventory Management         │                          │
│             └────────┬────────────────────────┘                          │
│                      │                                                   │
│        ┌─────────────┼─────────────┐                                    │
│        │             │             │                                    │
│  ┌─────▼──────┐ ┌────▼────┐ ┌─────▼──────┐                             │
│  │   CA       │ │ Webhook │ │ Discovery  │                             │
│  │ Connector  │ │Publisher│ │  Engine    │                             │
│  └─────┬──────┘ └────┬────┘ └─────┬──────┘                             │
│        │             │            │                                     │
└────────┼─────────────┼────────────┼─────────────────────────────────────┘
         │             │            │
         ▼             ▼            ▼
    ┌────────┐   ┌─────────┐  ┌──────────────┐
    │   CA   │   │Automation│  │Orchestrators │
    │(AD CS/ │   │ Pipeline │  │(per zone)    │
    │ EJBCA) │   │(Webhooks)│  │              │
    └────────┘   └─────────┘  └──────────────┘
```

### 2.2 Orchestrator Architecture

```
Network Zone (e.g., On-Prem Datacenter, Azure VNet, AWS VPC)
│
├─ Keyfactor Orchestrator (Agent)
│  │
│  ├─ Discovery Module
│  │  ├─ Port Scanner (443, 8443, 3389)
│  │  ├─ File System Scanner (/etc/ssl, C:\ProgramData\Certs)
│  │  ├─ Cloud API Scanner (Azure Resource Graph, AWS API)
│  │  └─ Kubernetes API Scanner (secrets with type: kubernetes.io/tls)
│  │
│  ├─ Enrollment Module
│  │  ├─ CSR Generation (if central key gen)
│  │  ├─ Certificate Retrieval
│  │  └─ Delivery to Target
│  │
│  ├─ Renewal Module
│  │  ├─ Expiration Monitor
│  │  ├─ Auto-Renewal Trigger
│  │  └─ Certificate Replacement
│  │
│  └─ Management Module
│     ├─ Revocation Check
│     ├─ Inventory Sync
│     └─ Health Reporting
│
└─ Target Assets
   ├─ IIS Servers
   ├─ Apache/Nginx
   ├─ F5 Load Balancers
   ├─ Azure Key Vault
   └─ File Systems
```

---

## 3. Authorization Flow

### 3.1 Multi-Layer Authorization Diagram

```
Certificate Request
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│         LAYER 1: Identity-Based RBAC                      │
│                                                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  1. Authenticate User/Service                      │  │
│  │     - Entra ID OAuth2 / AD Kerberos / API Key     │  │
│  │                                                     │  │
│  │  2. Retrieve Groups/Roles                          │  │
│  │     - AD Groups: APP-WebDevs, INFRA-ServerAdmins  │  │
│  │                                                     │  │
│  │  3. Check Template Authorization                   │  │
│  │     - Is role authorized for requested template?  │  │
│  └────────────────────────────────────────────────────┘  │
│                                                            │
│         ✓ PASS → Layer 2   |   ✗ DENY → Reject           │
└──────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│         LAYER 2: SAN Validation                           │
│                                                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  1. Extract Requested SANs                         │  │
│  │     - CN: myapp.dev.contoso.com                    │  │
│  │     - SAN: myapp.dev.contoso.com, api.dev...      │  │
│  │                                                     │  │
│  │  2. Pattern Matching                               │  │
│  │     - Role allowed patterns: *.dev.contoso.com    │  │
│  │     - Match? YES ✓                                 │  │
│  │                                                     │  │
│  │  3. DNS Validation                                 │  │
│  │     - DNS lookup: myapp.dev.contoso.com → 10.1.5.23│  │
│  │     - Zone check: dev.contoso.com (authorized)    │  │
│  └────────────────────────────────────────────────────┘  │
│                                                            │
│         ✓ PASS → Layer 3   |   ✗ DENY → Reject           │
└──────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│         LAYER 3: Resource Binding                         │
│                                                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  1. Identify Target Resource                       │  │
│  │     - Server: vm-myapp-dev-01                      │  │
│  │     - Key Vault: kv-dev-myapp                      │  │
│  │                                                     │  │
│  │  2. Query CMDB/Cloud API                           │  │
│  │     - Server owner: team-web-apps                  │  │
│  │     - Environment: dev                              │  │
│  │                                                     │  │
│  │  3. Authorization Check                            │  │
│  │     - Is requester member of team-web-apps? YES ✓  │  │
│  │     - Does requester have write access to KV? YES ✓│  │
│  └────────────────────────────────────────────────────┘  │
│                                                            │
│         ✓ PASS → Layer 4   |   ✗ DENY → Reject           │
└──────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│         LAYER 4: Template Policy                          │
│                                                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │  1. Technical Validation                           │  │
│  │     - Key: ECDSA P-256 ✓ (meets min requirements) │  │
│  │     - Lifetime: 730 days ✓ (within limit)         │  │
│  │     - EKU: serverAuth ✓ (allowed)                  │  │
│  │                                                     │  │
│  │  2. Approval Requirement Check                     │  │
│  │     - Wildcard? NO                                 │  │
│  │     - Lifetime > policy? NO                        │  │
│  │     - Result: Auto-approve ✓                       │  │
│  │                                                     │  │
│  │  3. Rate Limit Check                               │  │
│  │     - Requests today: 3 / 20 limit ✓              │  │
│  └────────────────────────────────────────────────────┘  │
│                                                            │
│         ✓ PASS → APPROVED   |   ✗ DENY → Reject          │
└──────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────┐
│           RESULT: APPROVED                                │
│                                                            │
│  → Forward to CA for issuance                             │
│  → Tag with ownership metadata                            │
│  → Schedule renewal                                       │
│  → Create audit log entry                                 │
│  → Notify requester                                       │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Enrollment Flows

### 4.1 Windows Auto-Enrollment (GPO)

```
┌─────────────────┐
│ Windows Server  │
│ (Domain Member) │
└────────┬────────┘
         │
         │ 1. GPUpdate (automatic or manual)
         │    Group Policy: "Certificate Auto-Enrollment"
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Local Certificate Services Client                       │
│  - Check for new templates                               │
│  - Check for renewals needed                             │
│  - Generate keypair (non-exportable)                     │
│  - Create CSR with computer FQDN as SAN                  │
└────────┬────────────────────────────────────────────────┘
         │
         │ 2. Submit CSR to CA
         │    (via RPC to AD CS or HTTPS to EJBCA via Keyfactor)
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  AD CS or EJBCA (via Keyfactor)                          │
│  - Validate computer is in correct OU                    │
│  - Check template permissions                            │
│  - Issue certificate                                     │
└────────┬────────────────────────────────────────────────┘
         │
         │ 3. Certificate Issued
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Keyfactor Orchestrator                                  │
│  - Discovers new certificate                             │
│  - Adds to inventory with metadata                       │
│  - Triggers webhook: "certificate_issued"                │
└────────┬────────────────────────────────────────────────┘
         │
         │ 4. Certificate Installed
         │
         ▼
┌─────────────────┐
│ Windows Server  │
│ Cert Store:     │
│ LocalMachine\My │
│                 │
│ IIS auto-binds  │
│ (if configured) │
└─────────────────┘
```

### 4.2 Kubernetes cert-manager Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Developer or GitOps Pipeline                                │
│  Applies Certificate resource:                               │
│                                                               │
│  apiVersion: cert-manager.io/v1                              │
│  kind: Certificate                                           │
│  metadata:                                                   │
│    name: myapp-tls                                           │
│  spec:                                                       │
│    secretName: myapp-tls-secret                              │
│    issuerRef:                                                │
│      name: keyfactor-issuer                                  │
│      kind: ClusterIssuer                                     │
│    dnsNames: [myapp.prod.contoso.com]                        │
└────────────┬────────────────────────────────────────────────┘
             │
             │ 1. kubectl apply
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  cert-manager Controller (in K8s cluster)                    │
│  - Watches Certificate resources                             │
│  - Detects new Certificate: myapp-tls                        │
│  - Generates private key (ECDSA P-256)                       │
│  - Creates CSR                                               │
└────────────┬────────────────────────────────────────────────┘
             │
             │ 2. Submit CSR to ClusterIssuer
             │    (calls Keyfactor API with ServiceAccount token)
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Keyfactor Command                                           │
│  - Authenticates ServiceAccount "cert-manager"               │
│  - Authorization Checks:                                     │
│    ✓ Layer 1: ServiceAccount has role "k8s-platform"        │
│    ✓ Layer 2: SAN "myapp.prod.contoso.com" matches pattern  │
│    ✓ Layer 3: Namespace "production" owned by authorized team│
│    ✓ Layer 4: Template policy compliant                     │
│  - Forward to CA                                             │
└────────────┬────────────────────────────────────────────────┘
             │
             │ 3. CA Issues Certificate
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  cert-manager Controller                                     │
│  - Receives signed certificate                               │
│  - Creates/Updates Secret:                                   │
│    apiVersion: v1                                            │
│    kind: Secret                                              │
│    type: kubernetes.io/tls                                   │
│    data:                                                     │
│      tls.crt: <base64 cert>                                  │
│      tls.key: <base64 key>                                   │
└────────────┬────────────────────────────────────────────────┘
             │
             │ 4. Secret Updated (atomic replace)
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│  Ingress Controller (nginx/traefik/istio)                    │
│  - Watches Secret: myapp-tls-secret                          │
│  - Detects change                                            │
│  - Reloads TLS configuration (zero downtime)                 │
│  - Now serving HTTPS with new certificate                    │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 ACME Enrollment Flow

```
┌─────────────────┐
│  ACME Client    │
│ (certbot/win-   │
│  acme/acme.sh)  │
└────────┬────────┘
         │
         │ 1. Request certificate for myapp.contoso.com
         │    certbot certonly --server https://keyfactor.contoso.com/acme/internal \
         │      --domain myapp.contoso.com
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Keyfactor ACME Directory                                │
│  - Authenticate client (API key or OAuth2)               │
│  - Create order for myapp.contoso.com                    │
│  - Return challenge:                                     │
│    - HTTP-01: http://myapp.contoso.com/.well-known/     │
│               acme-challenge/<token>                     │
│    OR                                                    │
│    - DNS-01: _acme-challenge.myapp.contoso.com TXT      │
└────────┬────────────────────────────────────────────────┘
         │
         │ 2. Challenge details returned
         │
         ▼
┌─────────────────┐
│  ACME Client    │
│ - Places token  │
│   (HTTP file or │
│    DNS TXT)     │
│ - Notifies ready│
└────────┬────────┘
         │
         │ 3. Challenge ready notification
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Keyfactor ACME Directory                                │
│  - Validates challenge:                                  │
│    - HTTP-01: Fetches http://myapp.contoso.com/.well... │
│    - DNS-01: Queries _acme-challenge.myapp.contoso.com  │
│  - Challenge valid? YES ✓                                │
│  - Run authorization checks (RBAC + SAN + resource)      │
│  - Forward CSR to CA                                     │
└────────┬────────────────────────────────────────────────┘
         │
         │ 4. CA Issues Certificate
         │
         ▼
┌─────────────────┐
│  ACME Client    │
│ - Download cert │
│ - Install to:   │
│   IIS binding   │
│   Apache conf   │
│   Nginx conf    │
│ - Reload service│
└─────────────────┘
```

---

## 5. Renewal Automation Flow

```
T-30 days before certificate expiration
       │
       ▼
┌───────────────────────────────────────────────────────────┐
│  Keyfactor Renewal Scheduler                               │
│  - Daily scan: certificates expiring in 30 days            │
│  - Identifies: cert ID 12345 for "webapp.contoso.com"      │
│  - Auto-renewal eligible? YES (policy: auto_renew=true)    │
│  - Trigger renewal job                                     │
└───────────┬───────────────────────────────────────────────┘
            │
            │ 1. Renewal triggered
            │
            ▼
┌───────────────────────────────────────────────────────────┐
│  Keyfactor Certificate Manager                             │
│  - Retrieve existing cert metadata                         │
│  - Policy check: any changes? NO                           │
│  - Generate new keypair (or reuse if rekey=false)          │
│  - Create CSR (same SAN, same parameters)                  │
│  - Submit to CA                                            │
└───────────┬───────────────────────────────────────────────┘
            │
            │ 2. New certificate issued
            │
            ▼
┌───────────────────────────────────────────────────────────┐
│  Keyfactor Webhook Publisher                               │
│  - Event: "certificate_renewed"                            │
│  - Payload:                                                │
│    {                                                       │
│      "certificate_id": 12345,                              │
│      "subject": "CN=webapp.contoso.com",                   │
│      "thumbprint": "NEW_THUMBPRINT_ABC123",                │
│      "old_thumbprint": "OLD_THUMBPRINT_DEF456",            │
│      "expires_at": "2027-10-22T...",                       │
│      "metadata": {                                         │
│        "server": "iis-web-01",                             │
│        "environment": "production"                         │
│      }                                                     │
│    }                                                       │
│  - POST to: https://automation.contoso.com/webhook         │
└───────────┬───────────────────────────────────────────────┘
            │
            │ 3. Webhook delivered
            │
            ▼
┌───────────────────────────────────────────────────────────┐
│  Automation Pipeline (Azure Logic App / AWS Lambda)        │
│                                                             │
│  Step 1: Fetch new certificate from Keyfactor API          │
│          GET /api/v1/certificates/12345/download            │
│                                                             │
│  Step 2: Write to Azure Key Vault                          │
│          az keyvault secret set --vault-name kv-prod       │
│            --name webapp-tls --value <PFX_base64>          │
│          (creates new secret version)                      │
│                                                             │
│  Step 3: Deploy to IIS server                              │
│          Invoke-Command -ComputerName iis-web-01 {         │
│            Import-PfxCertificate ...                       │
│            Set-WebBinding -CertificateHash <new_thumbprint>│
│            iisreset /noforce                               │
│          }                                                 │
│                                                             │
│  Step 4: Verify deployment                                 │
│          $response = Invoke-WebRequest https://webapp...   │
│          if ($response.Certificate.Thumbprint -eq          │
│              $newThumbprint) { SUCCESS } else { ROLLBACK } │
│                                                             │
│  Step 5: Log to ServiceNow                                 │
│          POST /api/now/table/change_request                │
│          {                                                 │
│            "short_description": "Auto-renewed cert...",    │
│            "state": "Closed",                              │
│            "close_notes": "Success: new thumbprint ABC123" │
│          }                                                 │
└───────────┬───────────────────────────────────────────────┘
            │
            │ 4. Success
            │
            ▼
┌───────────────────────────────────────────────────────────┐
│  IIS Server                                                │
│  - Now serving HTTPS with new certificate                  │
│  - No downtime (graceful recycle)                          │
│  - Old cert archived                                       │
└────────────────────────────────────────────────────────────┘
```

**Failure Handling**:

```
If Step 3 (Deploy to IIS) fails:
       │
       ▼
┌───────────────────────────────────────────────────────────┐
│  Automation Pipeline - Error Handler                       │
│                                                             │
│  1. Rollback: Restore old certificate binding              │
│     Set-WebBinding -CertificateHash <old_thumbprint>       │
│                                                             │
│  2. Alert: Create ServiceNow incident                      │
│     Priority: P2 (service not impacted, but renewal failed)│
│     Assigned to: IIS team + on-call engineer               │
│                                                             │
│  3. Retry: Schedule retry in 1 hour (exponential backoff)  │
│                                                             │
│  4. Escalation: If failed 3x, page on-call                 │
└────────────────────────────────────────────────────────────┘
```

---

## 6. Network Architecture

### 6.1 Network Zones and Orchestrator Placement

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        KEYFACTOR COMMAND (SaaS or DMZ)                   │
│                           https://keyfactor.contoso.com                  │
└────────────┬────────────────────────────────────────────────────────────┘
             │
             │ HTTPS (outbound from each zone)
             │
   ┌─────────┼─────────┬─────────────┬─────────────┬─────────────┐
   │         │         │             │             │             │
   ▼         ▼         ▼             ▼             ▼             ▼
┌────────┐┌────────┐┌────────────┐┌────────────┐┌────────┐ ┌────────┐
│ On-Prem││ Azure  ││    AWS     ││ Kubernetes ││  DMZ   │ │  OT/   │
│DataCtr ││  VNet  ││    VPC     ││  Clusters  ││ Network│ │  IoT   │
│        ││        ││            ││            ││        │ │Network │
│ ┌────┐ ││ ┌────┐ ││  ┌────┐   ││  ┌────┐    ││ ┌────┐ │ │ ┌────┐ │
│ │Orch│ ││ │Orch│ ││  │Orch│   ││  │cert│    ││ │Orch│ │ │ │Orch│ │
│ │ 1  │ ││ │ 3  │ ││  │ 5  │   ││  │-mgr│    ││ │ 7  │ │ │ │ 8  │ │
│ │HA  │ ││ │HA  │ ││  │HA  │   ││  │(API)   ││ │HA  │ │ │ │    │ │
│ │    │ ││ │    │ ││  │    │   ││  │        ││ │    │ │ │ │    │ │
│ └─┬──┘ ││ └─┬──┘ ││  └─┬──┘   ││  └─┬──┘    ││ └─┬──┘ │ │ └─┬──┘ │
│   │    ││   │    ││    │      ││    │       ││   │    │ │   │    │
│ ┌─▼──┐ ││ ┌─▼──┐ ││  ┌─▼──┐   ││  ┌─▼──┐    ││ ┌─▼──┐ │ │ ┌─▼──┐ │
│ │IIS │ ││ │VMs │ ││  │EC2 │   ││  │Pods│    ││ │F5  │ │ │ │VPN │ │
│ │Svrs│ ││ │AppGW│││  │ALB │   ││  │Ingr│    ││ │LB  │ │ │ │Gw  │ │
│ └────┘ ││ └────┘ ││  └────┘   ││  └────┘    ││ └────┘ │ │ └────┘ │
└────────┘└────────┘└────────────┘└────────────┘└────────┘ └────────┘
```

**Firewall Rules**:

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| Orchestrators (all zones) | Keyfactor Command | 443 | HTTPS | API calls, cert retrieval |
| Keyfactor Command | CA (AD CS/EJBCA) | 443 | HTTPS | Certificate issuance |
| Keyfactor Command | Azure Key Vault | 443 | HTTPS | Cert delivery |
| Keyfactor Command | HashiCorp Vault | 8200 | HTTPS | Cert delivery |
| Orchestrators | Target endpoints | 443, 5986 | HTTPS, WinRM | Cert deployment |
| Keyfactor Command | Webhook endpoints | 443 | HTTPS | Event notification |

---

## 7. Integration Architecture

### 7.1 Secrets Management Integration

```
                    ┌──────────────────────┐
                    │ Keyfactor Command     │
                    │ (Certificate Manager) │
                    └──────────┬───────────┘
                               │
                               │ Certificate Issued/Renewed
                               │
            ┌──────────────────┴──────────────────┐
            │                                     │
            ▼                                     ▼
┌─────────────────────────┐         ┌─────────────────────────┐
│   Azure Key Vault        │         │   HashiCorp Vault       │
│                          │         │                         │
│  POST /secrets/webapp-tls│         │  POST /v1/kv/data/      │
│  {                       │         │       webapp/tls        │
│    "value": "<PFX_b64>", │         │  {                      │
│    "contentType":        │         │    "data": {            │
│      "application/       │         │      "certificate":     │
│       x-pkcs12"          │         │        "<PEM>",         │
│  }                       │         │      "private_key":     │
│                          │         │        "<PEM>"          │
│  Result: New version     │         │    }                    │
│    created (v5)          │         │  }                      │
│                          │         │                         │
│  Event Grid publishes:   │         │  Result: Version 6      │
│  SecretNewVersionCreated │         │                         │
└──────────┬───────────────┘         └──────────┬──────────────┘
           │                                    │
           │ Event notification                 │ Vault watches
           │                                    │ for new version
           ▼                                    ▼
┌─────────────────────────┐         ┌─────────────────────────┐
│   Application (Azure)    │         │   Application (K8s)     │
│                          │         │                         │
│  - Subscribe to Event    │         │  - Vault Agent          │
│    Grid topic            │         │    sidecar              │
│  - Receive event         │         │  - Polls for new ver    │
│  - Fetch new secret      │         │  - Fetches secret       │
│  - Reload config         │         │  - Writes to tmpfs      │
│  - Graceful restart      │         │  - App reads from file  │
│                          │         │  - App hot-reloads      │
└──────────────────────────┘         └─────────────────────────┘
```

### 7.2 ITSM Integration (ServiceNow)

```
┌──────────────────────┐
│ Keyfactor Webhook    │
│ "certificate_renewed"│
└──────────┬───────────┘
           │
           │ POST webhook
           │
           ▼
┌─────────────────────────────────────────────────────────┐
│ Automation Pipeline (Azure Logic App)                    │
│                                                           │
│  1. Parse webhook payload                                │
│  2. Deploy certificate (see Renewal Flow)                │
│  3. On SUCCESS:                                          │
│     ┌─────────────────────────────────────────────┐     │
│     │ POST /api/now/table/change_request          │     │
│     │ {                                           │     │
│     │   "type": "Standard",                       │     │
│     │   "category": "Certificate Renewal",        │     │
│     │   "short_description": "Auto-renewed TLS    │     │
│     │     cert for webapp.contoso.com",           │     │
│     │   "description": "Certificate ID: 12345\n   │     │
│     │     Old Expiry: 2025-10-23\n                │     │
│     │     New Expiry: 2027-10-23\n                │     │
│     │     Server: iis-web-01\n                    │     │
│     │     Deployment: Success",                   │     │
│     │   "state": "Closed",                        │     │
│     │   "close_code": "Successful",               │     │
│     │   "close_notes": "Automated renewal and     │     │
│     │     deployment completed successfully"      │     │
│     │ }                                           │     │
│     └─────────────────────────────────────────────┘     │
│                                                           │
│  4. On FAILURE:                                          │
│     ┌─────────────────────────────────────────────┐     │
│     │ POST /api/now/table/incident                │     │
│     │ {                                           │     │
│     │   "priority": "2 - High",                   │     │
│     │   "category": "Certificate",                │     │
│     │   "short_description": "Certificate renewal │     │
│     │     deployment failed: webapp.contoso.com", │     │
│     │   "description": "Error: <error_message>\n  │     │
│     │     Rollback: Successful\n                  │     │
│     │     Action Required: Manual investigation", │     │
│     │   "assignment_group": "IIS-Team",           │     │
│     │   "assigned_to": "on-call-engineer"         │     │
│     │ }                                           │     │
│     └─────────────────────────────────────────────┘     │
└───────────────────────────────────────────────────────────┘
```

---

## Legend

**Symbols**:
- `│`, `─`, `┌`, `└`, `┐`, `┘`: Box drawing (components, boundaries)
- `▼`, `▲`, `►`, `◄`: Flow direction
- `✓`: Validation passed
- `✗`: Validation failed / denied
- `⚠️`: Warning / requires approval

**Network**:
- Solid lines: HTTPS/TLS connections
- Dashed lines: Event/webhook delivery

---

## Document Owner

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Last Updated**: October 22, 2025

For editable diagram sources (Visio, Draw.io), contact PKI team.

