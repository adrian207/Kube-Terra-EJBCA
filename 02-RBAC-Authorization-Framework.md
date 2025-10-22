# RBAC and Authorization Framework
## Certificate Issuance Access Control

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Executive Summary

This document defines the multi-layer authorization framework for certificate issuance. Every certificate request is evaluated against four independent control layers:

1. **Identity-Based RBAC** (WHO) - User/service principal authentication and role membership
2. **SAN Validation** (WHAT) - Domain/resource authorization
3. **Resource Binding** (WHERE) - Target infrastructure authorization
4. **Template Policy** (HOW) - Technical and business rules

**Defense-in-depth approach**: All layers must pass for issuance to succeed.

---

## Table of Contents

1. [Authorization Layers](#1-authorization-layers)
2. [Identity-Based RBAC](#2-identity-based-rbac)
3. [SAN Validation Rules](#3-san-validation-rules)
4. [Resource Binding](#4-resource-binding)
5. [Template-Level Policies](#5-template-level-policies)
6. [Authorization Flow Examples](#6-authorization-flow-examples)
7. [Role Definitions](#7-role-definitions)
8. [Exception Handling](#8-exception-handling)
9. [Audit and Compliance](#9-audit-and-compliance)

---

## 1. Authorization Layers

### 1.1 Layer Architecture

```
Certificate Request (CSR + metadata)
  │
  ├─ Layer 1: Identity RBAC ───────────────────────┐
  │  └─ WHO: Is requester authenticated?            │
  │     Is requester authorized for this template? │
  │                                                 │
  ├─ Layer 2: SAN Validation ──────────────────────┤
  │  └─ WHAT: Are requested SANs in allowed scope? │
  │     Does requester control these domains?      │
  │                                                 │
  ├─ Layer 3: Resource Binding ────────────────────┤
  │  └─ WHERE: Is target resource valid?           │
  │     Does requester own/operate target?         │
  │                                                 │
  └─ Layer 4: Template Policy ─────────────────────┘
     └─ HOW: Does request meet technical policy?
        Is approval required?

  Result: APPROVED → Issue Certificate
          DENIED → Log reason, notify requester
```

### 1.2 Fail-Closed Design

- **Default deny**: No access unless explicitly granted
- **Deny trumps allow**: Single layer denial blocks issuance
- **Audit all denials**: Every denied request logged with reason and requester
- **Exception process**: High-approval-threshold override for legitimate edge cases

---

## 2. Identity-Based RBAC

### 2.1 Authentication Methods

| Method | Use Case | Authentication Provider |
|--------|----------|------------------------|
| **Entra ID (Azure AD)** | Human users, service principals | OAuth2/OIDC, MFA required for admins |
| **Active Directory** | On-prem users, Windows auto-enrollment | Kerberos/NTLM |
| **Kubernetes ServiceAccount** | Pods, cert-manager | K8s API bearer token |
| **API Key** | CI/CD pipelines, automation | Keyfactor-issued API key with HMAC |
| **Mutual TLS** | Service-to-service | Existing certificate (for renewal) |
| **SCEP Challenge** | Devices (Intune, Cisco ISE) | One-time password or device attestation |

### 2.2 Standard Roles

#### Role: Web-App-Developer

**Purpose**: Developers building internal web applications

**Permissions**:
- ✅ Request certificates from templates:
  - TLS-Server-Internal (dev/test SANs only)
  - TLS-Client-mTLS (dev/test)
- ✅ Renew owned certificates
- ✅ View certificates owned by their team
- ❌ Cannot request production certificates
- ❌ Cannot revoke certificates
- ❌ Cannot modify templates

**Membership**:
- **AD Group**: `APP-WebDevs`
- **Entra Group**: `SG-ApplicationDevelopers`
- **Vault Role**: `web-app-issuer`

**SAN Restrictions**:
- Allowed: `*.dev.contoso.com`, `*.test.contoso.com`, `*.staging.contoso.com`
- Denied: `*.prod.contoso.com`, `*.contoso.com` (wildcard), public domains

**Rate Limits**:
- 20 certificate requests per day per user
- 5 requests per unique SAN per week

---

#### Role: Infrastructure-Admin

**Purpose**: Server and infrastructure administrators

**Permissions**:
- ✅ Request certificates from templates:
  - TLS-Server-Internal (all environments)
  - TLS-Server-Public (non-wildcard)
  - Device-Auth-EST
  - Windows-Domain-Computer
- ✅ Renew any certificate
- ✅ View all certificates
- ✅ Revoke certificates for owned resources
- ❌ Cannot request wildcard certificates (requires approval)
- ❌ Cannot modify CA configuration

**Membership**:
- **AD Group**: `INFRA-ServerAdmins`
- **Entra Group**: `SG-InfrastructureAdmins`

**SAN Restrictions**:
- Allowed: `*.contoso.com`, `*.internal.contoso.com`, public domains (with DNS validation)
- Denied: External/partner domains
- Wildcard: Requires manager approval

**Rate Limits**:
- 100 certificate requests per day

---

#### Role: K8s-Platform-Operator

**Purpose**: Kubernetes cert-manager and service mesh

**Permissions**:
- ✅ Request certificates from templates:
  - K8s-Ingress-TLS
  - K8s-ServiceMesh-mTLS
- ✅ Automatic renewal
- ✅ View certificates in managed namespaces
- ❌ Cannot request certificates for external domains

**Membership**:
- **Kubernetes ServiceAccount**: `cert-manager` in `cert-manager` namespace
- **ServiceAccount Label**: `cert-issuer-role: k8s-platform`

**SAN Restrictions**:
- Allowed: `*.svc.cluster.local`, `*.{cluster-name}.contoso.com`, `*.{environment}.contoso.com`
- Denied: Production public domains (unless specific ingress)
- Namespace binding: Can only create secrets in authorized namespaces

**Rate Limits**:
- 1000 requests per day per cluster (high volume for service mesh)

---

#### Role: Security-PKI-Admin

**Purpose**: PKI administrators and security team

**Permissions**:
- ✅ Request certificates from ALL templates
- ✅ Revoke ANY certificate (with audit trail)
- ✅ Modify certificate templates
- ✅ Configure RBAC policies
- ✅ Access audit logs
- ✅ Emergency certificate issuance (break-glass)
- ❌ Cannot modify immutable audit logs

**Membership**:
- **AD Group**: `SEC-PKI-Admins`
- **Entra Group**: `SG-PKIAdministrators`
- **Required**: MFA + YubiKey/FIDO2

**SAN Restrictions**:
- None (full access)

**Additional Controls**:
- Dual approval for:
  - Root CA key access
  - Wildcard certificate issuance for production
  - Mass revocation (>10 certs)
- All actions logged to SIEM with immediate alert

---

#### Role: Device-Provisioner

**Purpose**: Automated device enrollment (IoT, VPN, network equipment)

**Permissions**:
- ✅ Request certificates from templates:
  - Device-Auth-EST
  - Device-Auth-SCEP
- ✅ Automatic renewal
- ❌ Cannot request TLS server certificates

**Membership**:
- **Service Principal**: `SP-DeviceProvisioner`
- **Vault AppRole**: `device-provisioner`

**SAN Restrictions**:
- CN: Device serial number or MAC address
- SAN: Device identifier (e.g., `device-{serial}.devices.contoso.com`)
- Denied: User-facing domains

**Additional Validation**:
- Device must exist in CMDB
- Device status: active, not decommissioned
- Device owner: validated team

---

#### Role: Code-Signing-Developer

**Purpose**: Developers authorized to sign code

**Permissions**:
- ✅ Request certificates from templates:
  - Code-Signing-Standard
- ✅ Sign code via API (private key never leaves HSM)
- ❌ Cannot export private key
- ❌ Cannot request TLS certificates

**Membership**:
- **AD Group**: `DEV-CodeSigners`
- **Approval Required**: Manager + Security review
- **Background Check**: Must be current within 12 months

**Technical Constraints**:
- Private key: Generated in Azure Key Vault HSM (Premium tier)
- Signing: API call to Key Vault (cryptographic operation "sign")
- Audit: Every signing operation logged with binary hash

**Lifecycle**:
- Request → Manager approval → Security review → Background check → Issuance
- Renewal: Automatic if background check current
- Revocation: Immediate on employment termination or security incident

---

### 2.3 Group-to-Template Mapping

| AD/Entra Group | Authorized Templates | Auto-Approve | Approval Required |
|----------------|---------------------|--------------|-------------------|
| **APP-WebDevs** | TLS-Server-Internal (dev/test only), TLS-Client-mTLS | Yes | No |
| **INFRA-ServerAdmins** | TLS-Server-Internal, TLS-Server-Public, Device-Auth-EST, Windows-Domain-Computer | Yes | Wildcard certs |
| **SEC-PKI-Admins** | ALL | Yes | Root CA access, mass actions |
| **K8s-Platform** (ServiceAccount) | K8s-Ingress-TLS, K8s-ServiceMesh-mTLS | Yes | No |
| **DEV-CodeSigners** | Code-Signing-Standard | No | Always (manager + security) |
| **CONTRACTORS** | None | No | Must use approval workflow |

---

## 3. SAN Validation Rules

### 3.1 Purpose

Prevent domain hijacking and unauthorized certificate issuance for domains not owned/controlled by requester.

### 3.2 SAN Validation per Role

#### Web-App-Developer

```yaml
allowed_san_patterns:
  - "*.dev.contoso.com"
  - "*.test.contoso.com"
  - "*.staging.contoso.com"
  - "app-*.dev.contoso.com"
  
denied_san_patterns:
  - "*.prod.contoso.com"
  - "*.contoso.com"  # Wildcard too broad
  - "*"  # Bare wildcard
  - "*.microsoft.com"  # External domain
  - "*.partnercorp.com"  # Partner domain
  
validation_rules:
  - dns_must_resolve: true  # SAN must resolve in corporate DNS
  - dns_record_must_be_in_zones: ["dev.contoso.com", "test.contoso.com"]
  - max_sans_per_cert: 5
  - wildcard_allowed: false
```

**Denial Examples**:
- ❌ Request for `webapp.prod.contoso.com` → Denied (prod not in allowed patterns)
- ❌ Request for `*.dev.contoso.com` → Denied (wildcard not allowed for this role)
- ❌ Request for `malicious.microsoft.com` → Denied (external domain)
- ❌ Request for `nonexistent.dev.contoso.com` → Denied (DNS doesn't resolve)

---

#### Infrastructure-Admin

```yaml
allowed_san_patterns:
  - "*.contoso.com"
  - "*.internal.contoso.com"
  - "*.cloud.contoso.com"
  - "public-api.contoso.com"  # Specific public domains
  
denied_san_patterns:
  - "*.microsoft.com"  # External domains
  - "*"  # Bare wildcard
  
validation_rules:
  - dns_must_resolve: true
  - dns_validation_for_public: true  # Public domains require DNS-01 challenge or CAA record check
  - max_sans_per_cert: 10
  - wildcard_allowed: true
  - wildcard_requires_approval: true  # *.contoso.com requires CISO approval
```

**Approval Workflow for Wildcard**:
1. User requests `*.prod.contoso.com`
2. Keyfactor creates approval request in ServiceNow
3. Manager approves (business justification)
4. CISO or delegate approves (security review)
5. Certificate issued

---

#### K8s-Platform-Operator

```yaml
allowed_san_patterns:
  - "*.svc.cluster.local"
  - "*.prod-cluster-01.svc.cluster.local"
  - "*.prod.contoso.com"  # For ingress
  - "*.api.contoso.com"  # For APIs
  
denied_san_patterns:
  - "*.contoso.com"  # Too broad
  
validation_rules:
  - cluster_name_in_san: true  # SAN must include cluster identifier
  - namespace_ownership: true  # ServiceAccount must own target namespace
  - max_sans_per_cert: 3
  - wildcard_allowed: true  # For ingress wildcard
```

**Namespace Binding Example**:
```
ServiceAccount: cert-manager in namespace prod-app-01
Requests cert for: myapp.prod.contoso.com
Target secret: myapp-tls in namespace prod-app-01

Keyfactor validates:
  ✓ ServiceAccount has role "k8s-platform"
  ✓ SAN matches allowed pattern "*.prod.contoso.com"
  ✓ Target namespace "prod-app-01" has ownership label: "team=app-team-01"
  ✓ ServiceAccount allowed to create secrets in namespaces with label "team=app-team-01"
  
Result: APPROVED
```

---

### 3.3 DNS Validation

**Internal Domains** (*.contoso.com, *.internal.contoso.com):
- DNS must resolve in corporate DNS (authoritative check)
- A/AAAA record or CNAME must exist
- [Inference]: Prevents typosquatting and accidental issuance

**Public Domains**:
- **ACME DNS-01 Challenge**: Requester must prove control by creating TXT record
  - `_acme-challenge.myapp.contoso.com TXT "validation-token"`
- **CAA Record Check**: Domain must allow issuance from our CA
  - `contoso.com CAA 0 issue "ejbca.contoso.com"`
- **Ownership Verification**: Domain must be in approved public domain list (maintained by security team)

---

### 3.4 SAN Pattern Matching

**Syntax**:
- `*.example.com`: Matches any single-level subdomain (myapp.example.com, api.example.com)
- `*.*.example.com`: Matches two-level subdomains (not typically allowed)
- `app-*.example.com`: Matches prefix pattern (app-web.example.com, app-api.example.com)

**Matching Algorithm**:
```python
def san_matches_pattern(san: str, pattern: str) -> bool:
    # Convert pattern to regex
    regex_pattern = pattern.replace(".", "\\.").replace("*", "[a-z0-9-]+")
    regex_pattern = f"^{regex_pattern}$"
    
    # Match
    return re.match(regex_pattern, san, re.IGNORECASE) is not None

# Examples:
san_matches_pattern("myapp.dev.contoso.com", "*.dev.contoso.com")  # True
san_matches_pattern("api.myapp.dev.contoso.com", "*.dev.contoso.com")  # False (two levels)
san_matches_pattern("myapp.prod.contoso.com", "*.dev.contoso.com")  # False (different zone)
```

---

## 4. Resource Binding

### 4.1 Purpose

Ensure certificates are only deployed to authorized infrastructure owned/operated by the requester.

### 4.2 Binding Types

#### Server/VM Binding

**Validation**:
- Target server must exist in CMDB
- Server must have owner metadata
- Requester must be:
  - Server owner, OR
  - Member of server's owning team, OR
  - Member of INFRA-ServerAdmins

**Example**:
```yaml
Certificate Request:
  requester: jane.doe@contoso.com
  template: TLS-Server-Internal
  san: webapp01.internal.contoso.com
  target_server: vm-webapp-01
  
Keyfactor validation:
  - Query CMDB: vm-webapp-01
    - Owner: team-web-apps
    - Environment: production
    - Status: active
  - Check: Is jane.doe member of team-web-apps?
    - Active Directory: jane.doe ∈ AD group "TEAM-WebApps" ✓
  - Result: APPROVED
```

**Denial Scenario**:
```yaml
Certificate Request:
  requester: bob.smith@contoso.com (member of team-platform)
  target_server: vm-webapp-01 (owned by team-web-apps)
  
Keyfactor validation:
  - Check: Is bob.smith member of team-web-apps? ✗
  - Check: Is bob.smith member of INFRA-ServerAdmins? ✗
  - Result: DENIED (requester does not own target server)
```

---

#### Azure Key Vault Binding

**Validation**:
- Target Key Vault must exist
- Requester must have Key Vault permissions:
  - `Microsoft.KeyVault/vaults/secrets/write` (for cert delivery)
  - Verified via Azure RBAC check (Keyfactor uses managed identity to query)

**Example**:
```yaml
Certificate Request:
  requester: service-principal-app-01
  template: TLS-Client-mTLS
  delivery_target: keyvault:kv-prod-app-01/secrets/myapp-tls
  
Keyfactor validation:
  - Azure API: Check if SP has write permission on kv-prod-app-01
    - Role Assignment: service-principal-app-01 has role "Key Vault Secrets Officer" on kv-prod-app-01 ✓
  - Result: APPROVED, cert delivered to Key Vault
```

---

#### Kubernetes Namespace Binding

**Validation**:
- Target namespace must exist
- ServiceAccount must be allowed to create/update secrets in that namespace
- Namespace ownership label must match ServiceAccount's authorized teams

**Example**:
```yaml
Certificate Request:
  requester: ServiceAccount cert-manager (namespace: cert-manager)
  template: K8s-Ingress-TLS
  san: myapp.prod.contoso.com
  target_secret: myapp-tls (namespace: prod-app-team-01)
  
Keyfactor validation:
  - K8s API: Get namespace prod-app-team-01
    - Labels: team=app-team-01, environment=production
  - K8s API: Check if ServiceAccount cert-manager has RoleBinding in prod-app-team-01
    - RoleBinding exists: cert-manager can create secrets ✓
  - Check policy: Is ServiceAccount authorized for team=app-team-01?
    - ClusterRole keyfactor-issuer has annotation: allowed-teams=app-team-01,platform-team ✓
  - Result: APPROVED
```

---

#### Load Balancer / CDN Binding

**Validation**:
- Target load balancer must exist (Azure App Gateway, F5, Cloudflare)
- Requester must have operator permissions on that resource
- Certificate SAN must match load balancer backend pool or frontend domain

**Example (Azure Application Gateway)**:
```yaml
Certificate Request:
  requester: svc-automation@contoso.com
  template: TLS-Server-Public
  san: www.contoso.com
  target: appgateway:ag-prod-public/httpListener-www
  
Keyfactor validation:
  - Azure API: Get Application Gateway ag-prod-public
    - Frontend IP: 203.0.113.10
    - DNS: www.contoso.com → 203.0.113.10 ✓
  - Azure API: Check if svc-automation@contoso.com has write permission
    - Role: "Network Contributor" on resource group ✓
  - Result: APPROVED
```

---

## 5. Template-Level Policies

### 5.1 Template Structure

Each template defines:
- **Technical policy**: Key type, size, EKU, lifetime, SAN format
- **Authorization policy**: Allowed roles, SAN patterns, resource binding
- **Approval workflow**: Auto-approve vs manual approval
- **Delivery policy**: Where cert is deployed (endpoint, Key Vault, Vault)

### 5.2 Example Template: TLS-Server-Internal

```yaml
template:
  name: TLS-Server-Internal
  description: Internal TLS server certificates for web/API servers
  ca: EJBCA-Issuing-CA
  
authorization:
  allowed_roles:
    - role: INFRA-ServerAdmins
      auto_approve: true
      san_patterns: ["*.contoso.com", "*.internal.contoso.com"]
      max_sans: 10
      
    - role: APP-WebDevs
      auto_approve: true
      san_patterns: ["*.dev.contoso.com", "*.test.contoso.com"]
      max_sans: 5
      restrictions:
        - environment_must_be: ["dev", "test", "staging"]
        - cannot_deploy_to: production_servers
  
  denied_roles:
    - CONTRACTORS  # Must use approval workflow
  
  require_mfa: false  # For standard issuance
  
san_validation:
  allowed_patterns:
    - "*.contoso.com"
    - "*.internal.contoso.com"
  denied_patterns:
    - "*.microsoft.com"
    - "*"  # No bare wildcards
  dns_validation_required: true
  max_sans_per_cert: 10
  
resource_binding:
  require_cmdb_asset: true
  require_asset_owner: true
  require_requester_authorization: true  # Requester must own or operate asset
  
technical_policy:
  key_algorithm: ["RSA", "ECDSA"]
  key_size_min_rsa: 3072
  key_curve_ecdsa: ["P-256", "P-384"]
  lifetime_days: 730
  extended_key_usage: ["serverAuth"]
  subject_format: "CN={primary_san}"
  san_required: true
  
renewal:
  auto_renew: true
  renewal_window_days: 30  # Renew at T-30d
  renewal_window_percent: 30  # Or 30% of lifetime, whichever comes first
  notify_owner: true
  notify_methods: ["email", "slack"]
  
approval_workflow:
  auto_approve: true
  approval_required_if:
    - condition: "wildcard_san == true"
      approvers: ["manager", "security_team"]
    - condition: "lifetime_days > 730"
      approvers: ["security_team", "ciso"]
  max_auto_approve_per_day: 20  # Rate limit per user
  
delivery:
  methods: ["endpoint", "keyvault", "vault"]
  endpoint_types: ["windows_cert_store", "linux_pem", "load_balancer"]
  keyvault_backup: true  # Always backup to Key Vault
  
audit:
  log_all_requests: true
  log_denials_to_siem: true
  alert_on_denial: true
  alert_on_policy_violation: true
```

---

## 6. Authorization Flow Examples

### 6.1 Success Case: Developer Requests Dev Cert

```
Step 1: Authentication
  User: jane.doe@contoso.com
  Method: Entra ID (OAuth2)
  MFA: Not required (standard template)
  Result: ✓ Authenticated

Step 2: Layer 1 - Identity RBAC
  User groups: APP-WebDevs, AllEmployees
  Requested template: TLS-Server-Internal
  Role check: APP-WebDevs authorized for TLS-Server-Internal ✓
  Result: ✓ AUTHORIZED

Step 3: Layer 2 - SAN Validation
  Requested SAN: myapp.dev.contoso.com
  Role SAN patterns: ["*.dev.contoso.com", "*.test.contoso.com"]
  Pattern match: ✓ matches "*.dev.contoso.com"
  DNS validation: myapp.dev.contoso.com → 10.1.5.23 ✓
  DNS zone: dev.contoso.com (authorized) ✓
  Result: ✓ SAN VALID

Step 4: Layer 3 - Resource Binding
  Target server: vm-myapp-dev-01
  CMDB lookup:
    - Server: vm-myapp-dev-01
    - Owner: team-web-apps
    - Environment: dev
  User membership: jane.doe ∈ TEAM-WebApps ✓
  Environment check: dev (allowed for APP-WebDevs) ✓
  Result: ✓ RESOURCE AUTHORIZED

Step 5: Layer 4 - Template Policy
  Key type: ECDSA P-256 ✓ (meets policy)
  Lifetime: 730 days ✓
  EKU: serverAuth ✓
  Approval: auto_approve for APP-WebDevs in dev environment ✓
  Rate limit: 3 certs today (under limit of 20) ✓
  Result: ✓ POLICY COMPLIANT

Final Result: ✓✓✓✓ APPROVED
  → Certificate issued
  → Delivered to vm-myapp-dev-01 + Key Vault backup
  → Ownership metadata tagged
  → Audit log entry created
  → User notified via email
```

---

### 6.2 Denial Case: Developer Tries to Request Prod Cert

```
Step 1: Authentication
  User: jane.doe@contoso.com
  Method: Entra ID
  Result: ✓ Authenticated

Step 2: Layer 1 - Identity RBAC
  User groups: APP-WebDevs
  Requested template: TLS-Server-Internal
  Role check: APP-WebDevs authorized for TLS-Server-Internal ✓
  Result: ✓ AUTHORIZED (so far)

Step 3: Layer 2 - SAN Validation
  Requested SAN: myapp.prod.contoso.com
  Role SAN patterns: ["*.dev.contoso.com", "*.test.contoso.com"]
  Pattern match: ✗ does NOT match any allowed pattern
  Result: ✗ SAN DENIED

Final Result: ✗ DENIED
  Reason: "SAN 'myapp.prod.contoso.com' not in allowed patterns for role 'APP-WebDevs'"
  Action:
    - Request denied, no certificate issued
    - Audit log entry: denial with reason
    - Alert to security team (INFO level)
    - Email to user:
      "Your request for myapp.prod.contoso.com was denied. Reason: Production 
       domains require Infrastructure-Admin role. Please contact your manager 
       if you need production access."
```

---

### 6.3 Approval Case: Admin Requests Wildcard Cert

```
Step 1-4: (All pass)
  User: admin.bob@contoso.com
  Role: INFRA-ServerAdmins
  SAN: *.prod.contoso.com
  Resource: load-balancer-prod
  All layers authorize request ✓

Step 5: Layer 4 - Template Policy (Approval Required)
  Wildcard detected: *.prod.contoso.com
  Policy: wildcard_requires_approval = true
  Approval workflow triggered:
    - Create ServiceNow ticket
    - Required approvers:
      1. Manager of requestor
      2. Security team (CISO or delegate)
  
  Timeline:
    T+10 min: Manager approves (ticket updated)
    T+45 min: Security team approves (ticket updated)
    T+46 min: Keyfactor polls ServiceNow, sees all approvals
  
Final Result: ✓ APPROVED (after manual approval)
  → Certificate issued
  → Delivered to load-balancer-prod
  → Audit log: includes approval chain with timestamps
  → Notification sent to requester, approvers, and security team
```

---

## 7. Role Definitions

### 7.1 Role Matrix

| Role | Templates | Environments | SAN Scope | Approval | Revoke |
|------|-----------|--------------|-----------|----------|--------|
| **Web-App-Developer** | TLS-Server-Internal, TLS-Client-mTLS | Dev, Test, Staging | *.dev/test.contoso.com | Auto | Own team only |
| **Infrastructure-Admin** | All TLS templates, Device-Auth | All | *.contoso.com (wildcard needs approval) | Auto (non-wildcard) | All managed resources |
| **K8s-Platform-Operator** | K8s-Ingress-TLS, K8s-ServiceMesh-mTLS | All | *.svc.cluster.local, cluster domains | Auto | Namespace-scoped |
| **Security-PKI-Admin** | ALL | ALL | ALL | Auto (most), approval for root CA access | ALL (with audit) |
| **Device-Provisioner** | Device-Auth-EST, Device-Auth-SCEP | N/A | Device identifiers only | Auto (if device in CMDB) | Devices only |
| **Code-Signing-Developer** | Code-Signing-Standard | N/A | N/A (code signing) | Always requires approval | No (revocation by security only) |

### 7.2 Privilege Escalation Paths

**How to get Infrastructure-Admin**:
1. Submit access request in ServiceNow
2. Manager approval
3. Security team review (background check if external hire)
4. AD group membership granted
5. Training required (PKI 101 course)

**How to get Security-PKI-Admin**:
1. Must be security team member (organizational requirement)
2. CISO approval required
3. Background check (enhanced)
4. YubiKey issued (FIDO2 token)
5. MFA enforced
6. Training: Advanced PKI course + incident response

---

## 8. Exception Handling

### 8.1 Exception Request Process

**When needed**:
- Request denied by policy but legitimate business need exists
- Example: Issue cert for partner domain, long lifetime for embedded device

**Process**:
1. User submits exception request (ServiceNow form)
   - Business justification
   - Risk assessment
   - Compensating controls
2. Manager approval
3. Security team review
4. CISO approval (if high risk)
5. Exception granted with:
   - Time limit (e.g., 90 days)
   - Specific request only (not blanket approval)
   - Audit trail

**Example Exception**:
```
Request: Issue certificate for partnercorp.com (external domain)
Requester: Integration team
Justification: Partnership integration requires mutual TLS; partner cannot issue cert from our CA
Risk: Partner controls domain, could issue malicious cert
Compensating Controls:
  - Certificate pinning in our app (only accept specific cert thumbprint)
  - 90-day lifetime (shorter than standard)
  - Manual renewal with re-approval
Approval: Manager → Security → CISO
Result: APPROVED with conditions (90-day validity, manual renewal)
```

### 8.2 Break-Glass Procedures

**Scenario**: Emergency certificate issuance bypassing normal controls

**Authorized Users**: Security-PKI-Admin role only

**Process**:
1. PKI Admin uses "Emergency Issuance" template
2. Requires second admin to approve (dual control)
3. All fields logged (who, what, why, when)
4. SIEM alert generated immediately
5. Post-incident review within 24 hours
6. Incident report filed

**Use Cases**:
- Certificate expired, production outage in progress
- Automation failure, manual intervention needed
- CA offline, need to issue from backup CA

---

## 9. Audit and Compliance

### 9.1 Logged Events

**All requests (approved or denied)**:
```json
{
  "event": "certificate_request",
  "timestamp": "2025-10-22T14:23:11.123Z",
  "requester": {
    "user": "jane.doe@contoso.com",
    "groups": ["APP-WebDevs", "AllEmployees"],
    "authentication_method": "EntraID-OAuth2",
    "source_ip": "10.1.2.34",
    "user_agent": "Keyfactor-SDK/1.2.3"
  },
  "request": {
    "template": "TLS-Server-Internal",
    "subject": "CN=myapp.dev.contoso.com",
    "sans": ["myapp.dev.contoso.com", "myapp-api.dev.contoso.com"],
    "key_algorithm": "ECDSA",
    "key_size": "P-256",
    "lifetime_days": 730,
    "target_resource": "vm-myapp-dev-01",
    "delivery_target": "keyvault:kv-dev/secrets/myapp-tls"
  },
  "authorization": {
    "layer1_identity_rbac": {
      "result": "approved",
      "role": "APP-WebDevs",
      "authorized_for_template": true
    },
    "layer2_san_validation": {
      "result": "approved",
      "sans_validated": ["myapp.dev.contoso.com", "myapp-api.dev.contoso.com"],
      "matched_patterns": ["*.dev.contoso.com"],
      "dns_validated": true
    },
    "layer3_resource_binding": {
      "result": "approved",
      "resource": "vm-myapp-dev-01",
      "resource_owner": "team-web-apps",
      "requester_authorized": true
    },
    "layer4_template_policy": {
      "result": "approved",
      "policy_compliant": true,
      "approval_required": false
    }
  },
  "result": "approved",
  "certificate_id": "12345",
  "issued_at": "2025-10-22T14:23:15.456Z",
  "expires_at": "2027-10-22T14:23:15.456Z"
}
```

**Denied request example**:
```json
{
  "event": "certificate_request_denied",
  "timestamp": "2025-10-22T15:30:00.000Z",
  "requester": {
    "user": "jane.doe@contoso.com",
    "groups": ["APP-WebDevs"]
  },
  "request": {
    "template": "TLS-Server-Internal",
    "sans": ["myapp.prod.contoso.com"]
  },
  "authorization": {
    "layer2_san_validation": {
      "result": "denied",
      "reason": "SAN 'myapp.prod.contoso.com' does not match allowed patterns ['*.dev.contoso.com', '*.test.contoso.com']"
    }
  },
  "result": "denied",
  "denial_reason": "SAN validation failed",
  "notification_sent_to": "jane.doe@contoso.com",
  "severity": "INFO"
}
```

### 9.2 SIEM Integration

**Events forwarded to SIEM** (Azure Sentinel / Splunk):
- All denied requests (INFO level)
- High-privilege actions (Security-PKI-Admin role) (WARNING level)
- Break-glass procedures used (CRITICAL level)
- Mass revocation (CRITICAL level)
- Policy modifications (WARNING level)

**SIEM Alerts**:
- Multiple denied requests from same user (>5 in 1 hour) → Potential attack
- Certificate request for external domain → Review for compromise
- Break-glass used → Immediate security team notification

### 9.3 Compliance Reporting

**SOC 2 Type II**:
- Quarterly access review: Export all users with PKI roles, verify still employed
- Policy review: Document any policy changes with approvals
- Audit log integrity: Demonstrate logs are immutable

**PCI-DSS**:
- Certificate inventory: All certificates for cardholder data environment
- Key management: Demonstrate HSM protection for CA keys
- Revocation procedures: Test revocation → CRL/OCSP updated

---

## Appendices

### A. Quick Reference: Role Permissions

| Action | Web-Dev | Infra-Admin | K8s-Platform | PKI-Admin |
|--------|---------|-------------|--------------|-----------|
| Request dev/test cert | ✅ | ✅ | ✅ | ✅ |
| Request prod cert | ❌ | ✅ | ✅ | ✅ |
| Request wildcard cert | ❌ | ⚠️ (approval) | ⚠️ (ingress only) | ✅ |
| Revoke own cert | ✅ | ✅ | ✅ | ✅ |
| Revoke others' cert | ❌ | ⚠️ (owned resources) | ❌ | ✅ |
| Modify template | ❌ | ❌ | ❌ | ✅ |
| View audit logs | ❌ | ⚠️ (own requests) | ❌ | ✅ |
| Break-glass issuance | ❌ | ❌ | ❌ | ✅ (dual control) |

### B. Contact Information

**Questions or Access Requests**:
- Email: pki-team@contoso.com
- Slack: #pki-support
- ServiceNow: [Create request → Security → PKI Access]

**Document Owner**: Adrian Johnson <adrian207@gmail.com>

---

**Version**: 1.0  
**Last Updated**: October 22, 2025  
**Next Review**: January 22, 2026

