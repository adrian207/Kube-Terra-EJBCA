# Certificate Policy Catalog
## Template Definitions and Enforcement Rules

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Purpose

This document defines all certificate templates (policies) available for issuance. Each template specifies:
- **Authorization**: Who can request
- **Technical requirements**: Key type, size, EKU, lifetime
- **SAN validation**: Allowed domain patterns
- **Approval workflow**: Auto-approve vs manual
- **Delivery**: Where certificates are deployed

Templates are enforced by Keyfactor Command at issuance time. Non-compliant requests are automatically denied.

---

## Template Index

| Template Name | Use Case | Lifetime | Key Type | Approval |
|---------------|----------|----------|----------|----------|
| **[TLS-Server-Internal](#1-tls-server-internal)** | Internal web/API servers | 730d | RSA 3072 / ECDSA P-256 | Auto |
| **[TLS-Server-Public](#2-tls-server-public)** | Internet-facing servers | 398d | RSA 3072 / ECDSA P-256 | Auto (non-wildcard) |
| **[TLS-Server-Wildcard](#3-tls-server-wildcard)** | Wildcard domains | 398d | ECDSA P-256 | Requires approval |
| **[TLS-Client-mTLS](#4-tls-client-mtls)** | Service-to-service auth | 365d | RSA 3072 / ECDSA P-256 | Auto |
| **[K8s-Ingress-TLS](#5-k8s-ingress-tls)** | Kubernetes ingress | 90d | ECDSA P-256 | Auto |
| **[K8s-ServiceMesh-mTLS](#6-k8s-servicemesh-mtls)** | Service mesh (Istio/Linkerd) | 24h | ECDSA P-256 | Auto |
| **[Device-Auth-EST](#7-device-auth-est)** | Servers, IoT devices | 365d | RSA 3072 | Auto (if in CMDB) |
| **[Device-Auth-SCEP](#8-device-auth-scep)** | Intune-managed devices | 365d | RSA 2048 | Auto (if compliant) |
| **[Windows-Domain-Computer](#9-windows-domain-computer)** | Domain-joined servers | 730d | RSA 3072 | Auto (GPO) |
| **[Code-Signing-Standard](#10-code-signing-standard)** | Sign binaries/scripts | 365d | RSA 3072 (HSM) | Manager + Security |

---

## 1. TLS-Server-Internal

**Use Case**: TLS certificates for internal web servers, APIs, and application endpoints

### Authorization

**Allowed Roles**:
- **INFRA-ServerAdmins**: All internal environments
- **APP-WebDevs**: Dev, test, staging only

**SAN Restrictions**:
- **INFRA-ServerAdmins**: `*.contoso.com`, `*.internal.contoso.com`
- **APP-WebDevs**: `*.dev.contoso.com`, `*.test.contoso.com`, `*.staging.contoso.com`

**Resource Binding**:
- Target server must exist in CMDB
- Requester must be server owner or team member

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA

key_algorithm: ["RSA", "ECDSA"]
key_size_min_rsa: 3072
key_curve_ecdsa: ["P-256", "P-384"]

lifetime_days: 730
renewal_window_days: 30

subject_format: "CN={primary_san}, O=Contoso Inc, C=US"

extended_key_usage:
  - serverAuth

san_required: true
san_max_count: 10

signature_algorithm: "SHA256WithRSA" or "SHA256WithECDSA"
```

### SAN Validation

```yaml
allowed_patterns:
  - "*.contoso.com"
  - "*.internal.contoso.com"
  - "*.cloud.contoso.com"

denied_patterns:
  - "*.microsoft.com"  # External domains
  - "*"  # Bare wildcard

validation_rules:
  - dns_must_resolve: true
  - dns_zone_must_be: ["contoso.com", "internal.contoso.com"]
  - wildcard_requires_approval: false  # Wildcard allowed for internal
```

### Approval Workflow

- **Auto-approve**: Yes (for standard requests)
- **Approval required if**:
  - Lifetime > 730 days
  - SAN count > 10
  - Requester is contractor (not FTE)

### Renewal

```yaml
auto_renew: true
renewal_window:
  days_before_expiry: 30
  or_percent_lifetime: 30
notify_owner: true
notify_at: [30d, 7d, 1d]
```

### Delivery

**Methods**:
- Windows: LocalMachine\My certificate store
- Linux: `/etc/ssl/certs/` and `/etc/ssl/private/`
- Azure Key Vault: Versioned secret
- HashiCorp Vault: `pki/issue/internal-server`

**Post-Delivery Automation**:
- IIS: Update binding, graceful recycle
- Apache/Nginx: Replace cert files, reload config
- Azure App Gateway: API call to update listener
- Key Vault: Publish event to Event Grid

---

## 2. TLS-Server-Public

**Use Case**: TLS certificates for internet-facing web servers and APIs

### Authorization

**Allowed Roles**:
- **INFRA-ServerAdmins**: All public domains
- **APP-WebDevs**: Not authorized (public certs require admin role)

**SAN Restrictions**:
- Must be publicly resolvable domain
- Domain must be in approved public domain list: `contoso.com`, `api.contoso.com`, `www.contoso.com`
- Wildcard: NOT allowed (use TLS-Server-Wildcard template)

**DNS Validation**:
- **ACME DNS-01 Challenge** required for public domains
- Or: Manual DNS validation by PKI team

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA

key_algorithm: ["RSA", "ECDSA"]
key_size_min_rsa: 3072
key_curve_ecdsa: "P-256"  # P-384 optional

lifetime_days: 398  # CA/Browser Forum max for public TLS

subject_format: "CN={primary_san}, O=Contoso Inc, C=US"

extended_key_usage:
  - serverAuth

san_required: true
san_max_count: 5  # Limit for public certs

must_staple_ocsp: true  # OCSP Must-Staple for public certs
```

### SAN Validation

```yaml
allowed_patterns:
  - "contoso.com"
  - "*.{approved_subdomain}.contoso.com"  # e.g., *.api.contoso.com, *.cdn.contoso.com
  - "www.contoso.com"
  - "api.contoso.com"

denied_patterns:
  - "*.contoso.com"  # Wildcard not allowed (use separate template)
  - "*"

validation_rules:
  - dns_must_resolve_public: true
  - caa_record_check: true  # CAA record must allow our CA
  - domain_must_be_approved: true  # Must be in public domain whitelist
```

**CAA Record Check**:
```
; Example CAA record
contoso.com. CAA 0 issue "ejbca.contoso.com"
contoso.com. CAA 0 issuewild ";"  # Disallow wildcard unless explicit
```

### Approval Workflow

- **Auto-approve**: Yes (if all validation passes)
- **Approval required if**:
  - New public domain (not previously issued)
  - Lifetime > 398 days (policy violation)
  - >3 SANs (requires security review for multi-domain)

### Renewal

```yaml
auto_renew: true
renewal_window:
  days_before_expiry: 30
early_renewal_if: dns_challenge_can_complete  # Renew early if DNS API available
notify_owner: true
```

### Delivery

- Edge load balancers (CDN, Azure Front Door, Cloudflare)
- Azure Key Vault (for App Service, App Gateway)
- IIS/Apache/Nginx on DMZ servers

---

## 3. TLS-Server-Wildcard

**Use Case**: Wildcard certificates (e.g., `*.contoso.com`)

**[Inference]**: Wildcard certificates pose higher security risk (compromise of one server compromises all subdomains). Use only when necessary (e.g., CDN, multi-tenant SaaS).

### Authorization

**Allowed Roles**:
- **INFRA-ServerAdmins**: With approval
- **Security-PKI-Admin**: Without approval (for emergency)

**Approval Required**:
- Manager approval
- Security team (CISO or delegate) approval
- Business justification required

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA

key_algorithm: "ECDSA"  # ECDSA only for performance (wildcard used heavily)
key_curve_ecdsa: "P-256"

lifetime_days: 398  # Same as public

subject_format: "CN={wildcard_domain}, O=Contoso Inc, C=US"

extended_key_usage:
  - serverAuth

san_required: true
san_max_count: 3  # Limit wildcard SANs

must_staple_ocsp: true
```

### SAN Validation

```yaml
allowed_patterns:
  - "*.contoso.com"
  - "*.api.contoso.com"
  - "*.cdn.contoso.com"

denied_patterns:
  - "*"  # No bare wildcard
  - "*.*.contoso.com"  # No multi-level wildcard

validation_rules:
  - dns_zone_ownership: true  # Must prove ownership of entire zone
  - approval_required: true
```

### Approval Workflow

**Steps**:
1. Requester submits with business justification
2. Manager approves (why wildcard is needed vs individual certs)
3. Security team reviews:
   - Is wildcard necessary?
   - What is the blast radius if compromised?
   - Are compensating controls in place? (e.g., certificate pinning, short lifetime)
4. CISO or delegate approves
5. Certificate issued

**Example Justification**:
> "Wildcard cert needed for multi-tenant SaaS platform where customer subdomains are dynamically created (customer1.contoso.com, customer2.contoso.com, etc.). Individual certs not feasible due to dynamic provisioning. Compensating controls: 90-day lifetime (shorter than standard), WAF in front of all subdomains, certificate monitoring."

### Renewal

- **Auto-renew**: After initial approval, renewals auto-approved if no policy changes
- **Re-approval required if**: Lifetime increase, SAN addition

---

## 4. TLS-Client-mTLS

**Use Case**: Client certificates for mutual TLS authentication between services

### Authorization

**Allowed Roles**:
- **INFRA-ServerAdmins**: All environments
- **APP-WebDevs**: Dev, test, staging only
- **K8s-Platform**: For service mesh

**SAN Restrictions**:
- Service identifiers: `service-{name}.{environment}.contoso.com`
- Or: URI SANs for SPIFFE: `spiffe://contoso.com/ns/{namespace}/sa/{serviceaccount}`

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA

key_algorithm: ["RSA", "ECDSA"]
key_size_min_rsa: 3072
key_curve_ecdsa: "P-256"

lifetime_days: 365

subject_format: "CN={service_name}, OU={environment}, O=Contoso Inc"

extended_key_usage:
  - clientAuth
  - serverAuth  # Some services act as both client and server

san_required: true
san_types: ["DNS", "URI"]  # Support SPIFFE URIs
```

### SAN Validation

```yaml
allowed_patterns:
  dns:
    - "service-*.contoso.com"
    - "*.svc.cluster.local"
  uri:
    - "spiffe://contoso.com/ns/*/sa/*"
    - "spiffe://contoso.com/workload/*"

validation_rules:
  - dns_must_resolve_or_service_principal_exists: true
  - uri_spiffe_format_valid: true
```

### Approval Workflow

- **Auto-approve**: Yes

### Delivery

- Azure Key Vault
- HashiCorp Vault
- Kubernetes secret
- Service configuration file

---

## 5. K8s-Ingress-TLS

**Use Case**: Kubernetes ingress TLS termination

### Authorization

**Allowed Roles**:
- **K8s-Platform** (ServiceAccount `cert-manager`)

**Namespace Binding**:
- ServiceAccount can only create certs for authorized namespaces
- Verified via Kubernetes RBAC

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA

key_algorithm: "ECDSA"
key_curve_ecdsa: "P-256"

lifetime_days: 90  # Short-lived for Kubernetes

subject_format: "CN={primary_san}"

extended_key_usage:
  - serverAuth

san_required: true
san_max_count: 5
```

### SAN Validation

```yaml
allowed_patterns:
  - "*.{cluster_name}.contoso.com"
  - "*.prod.contoso.com"  # If prod cluster
  - "*.dev.contoso.com"  # If dev cluster

validation_rules:
  - dns_must_resolve: true
  - namespace_ownership: true  # SAN must be owned by requesting namespace
```

### Renewal

```yaml
auto_renew: true
renewal_window:
  days_before_expiry: 30
cert_manager_handles: true  # cert-manager automatically renews
```

### Delivery

- Kubernetes TLS secret in target namespace
- Secret type: `kubernetes.io/tls`

---

## 6. K8s-ServiceMesh-mTLS

**Use Case**: Service mesh mTLS (Istio, Linkerd, Consul Connect)

### Authorization

**Allowed Roles**:
- **K8s-Platform** (ServiceAccount for service mesh CA)

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA

key_algorithm: "ECDSA"
key_curve_ecdsa: "P-256"

lifetime_days: 1  # 24 hours (short-lived for service mesh)

subject_format: "CN={workload_identity}"

extended_key_usage:
  - clientAuth
  - serverAuth

san_required: true
san_types: ["URI"]
san_format: "spiffe://contoso.com/ns/{namespace}/sa/{serviceaccount}"
```

### SAN Validation

```yaml
allowed_patterns:
  uri:
    - "spiffe://contoso.com/ns/*/sa/*"

validation_rules:
  - spiffe_namespace_must_exist: true
  - spiffe_serviceaccount_must_exist: true
```

### Renewal

```yaml
auto_renew: true
renewal_window:
  hours_before_expiry: 6  # Renew 6 hours before expiry (for 24h cert)
service_mesh_handles: true  # Service mesh (Istio/Linkerd) auto-rotates
```

---

## 7. Device-Auth-EST

**Use Case**: Device authentication certificates via EST protocol

### Authorization

**Allowed Roles**:
- **Device-Provisioner** (service account for device enrollment automation)
- **INFRA-ServerAdmins** (manual enrollment)

**Device Validation**:
- Device must exist in CMDB
- Device status: active (not decommissioned)

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA

key_algorithm: "RSA"  # Many devices don't support ECDSA
key_size_min_rsa: 3072

lifetime_days: 365

subject_format: "CN={device_serial_or_hostname}, OU=Devices, O=Contoso Inc"

extended_key_usage:
  - clientAuth

san_required: true
san_format: "DNS={device_fqdn}, URI=device:{serial_number}"
```

### SAN Validation

```yaml
allowed_patterns:
  dns:
    - "*.devices.contoso.com"
  uri:
    - "device:*"

validation_rules:
  - device_must_exist_in_cmdb: true
  - device_must_be_active: true
```

---

## 8. Device-Auth-SCEP

**Use Case**: Device certificates via SCEP (primarily Intune-managed endpoints)

### Authorization

**Allowed Roles**:
- **Intune SCEP Service** (automated enrollment)

**Device Validation**:
- Device must be enrolled in Intune
- Device must be compliant (security policy checks passed)

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA (or NDES if AD CS)

key_algorithm: "RSA"
key_size_min_rsa: 2048  # Some mobile devices limited to 2048

lifetime_days: 365

subject_format: "CN={DeviceId}"

extended_key_usage:
  - clientAuth

san_required: true
san_format: "URI={{AADDeviceId}}"
```

---

## 9. Windows-Domain-Computer

**Use Case**: Windows domain-joined servers and workstations

### Authorization

**Allowed Roles**:
- **Domain Computers** (via GPO auto-enrollment)

**Enrollment Method**:
- GPO: Certificate Services Client - Auto-Enrollment

### Technical Policy

```yaml
certificate_authority: AD CS or EJBCA

key_algorithm: "RSA"
key_size_min_rsa: 3072

lifetime_days: 730

subject_format: "CN={ComputerName}, OU=Computers, O=Contoso Inc"

extended_key_usage:
  - clientAuth
  - serverAuth  # For servers running IIS/RDP

san_required: true
san_format: "DNS={FQDN}"
```

### Renewal

```yaml
auto_renew: true
renewal_window:
  percent_lifetime: 25  # Renew at 25% remaining (182 days for 730d cert)
windows_auto_enrollment_handles: true
```

---

## 10. Code-Signing-Standard

**Use Case**: Sign code (binaries, scripts, installers)

**[Inference]**: Code signing requires highest security due to risk of malware distribution. Private key never leaves HSM.

### Authorization

**Allowed Roles**:
- **DEV-CodeSigners** (designated developers with approval)

**Approval Required**:
- Manager approval
- Security team review
- Background check (within 12 months)

### Technical Policy

```yaml
certificate_authority: EJBCA-Issuing-CA (Code Signing subordinate)

key_algorithm: "RSA"
key_size_min_rsa: 3072

lifetime_days: 365

subject_format: "CN={Developer Name}, OU=Engineering, O=Contoso Inc"

extended_key_usage:
  - codeSigning

san_required: false

key_storage: "HSM"  # MUST be Azure Key Vault HSM or network HSM
key_exportable: false  # Private key never exported
```

### Signing Process

**NOT direct cert delivery**. Instead:
1. Certificate issued with private key in HSM
2. Developer signs via API call:
   ```powershell
   # Sign via Azure Key Vault
   Set-AuthenticodeSignature -FilePath .\MyApp.exe `
       -HashAlgorithm SHA256 `
       -TimestampServer "http://timestamp.digicert.com" `
       -Certificate (Get-AzKeyVaultCertificate -VaultName "kv-codesigning" -Name "dev-john-doe")
   ```
3. Every signing operation logged:
   - Developer identity
   - File hash (SHA256)
   - Timestamp
   - IP address

### Revocation

- **Immediate revocation on**:
  - Employee termination
  - Security incident
  - Compromised account
- **Impact**: All binaries signed with that cert become untrusted (must re-sign)

---

## Template Lifecycle

### Creating a New Template

**Process**:
1. Submit template proposal (document business need, technical requirements)
2. Security review (risk assessment)
3. PKI Architect designs template (keys, lifetime, EKU, RBAC)
4. Approval by CISO
5. Implement in Keyfactor (configuration)
6. Test with pilot group
7. Document in this catalog
8. Publish to service owners

### Modifying an Existing Template

**Process**:
1. Submit change request (ServiceNow)
2. Impact analysis (how many certs affected?)
3. Security review (does change increase risk?)
4. Approval by PKI Architect + Security
5. Implement in test environment
6. Validate with affected service owners
7. Deploy to production
8. Update documentation

### Retiring a Template

**Process**:
1. Identify replacement template
2. Notify all service owners using deprecated template
3. Migration plan (90-day timeline)
4. Disable new issuance (existing certs continue to renew to new template)
5. After final cert expires, remove template from Keyfactor
6. Update documentation

---

## Compliance Matrix

| Template | SOC 2 | PCI-DSS | ISO 27001 | FedRAMP | Notes |
|----------|-------|---------|-----------|---------|-------|
| TLS-Server-Internal | ✅ | ✅ | ✅ | ✅ | Standard TLS for internal services |
| TLS-Server-Public | ✅ | ✅ | ✅ | ✅ | Meets CA/Browser Forum Baseline Requirements |
| TLS-Server-Wildcard | ⚠️ | ⚠️ | ⚠️ | ❌ | Requires justification; FedRAMP prohibits wildcard |
| TLS-Client-mTLS | ✅ | ✅ | ✅ | ✅ | Strong authentication |
| K8s-Ingress-TLS | ✅ | ✅ | ✅ | ✅ | Short-lived reduces risk |
| K8s-ServiceMesh-mTLS | ✅ | ✅ | ✅ | ✅ | 24h lifetime exceeds compliance requirements |
| Device-Auth-EST | ✅ | ✅ | ✅ | ✅ | Device authentication |
| Device-Auth-SCEP | ✅ | ✅ | ✅ | ✅ | Mobile device management |
| Windows-Domain-Computer | ✅ | ✅ | ✅ | ✅ | Standard domain auth |
| Code-Signing-Standard | ✅ | N/A | ✅ | ✅ | HSM protection mandatory |

---

## Contact Information

**Policy Owner**: Adrian Johnson <adrian207@gmail.com>  
**PKI Team**: pki-team@contoso.com  
**Support**: #pki-support (Slack)

**Document Version**: 1.0  
**Last Updated**: October 22, 2025  
**Next Review**: January 22, 2026 (Quarterly)

