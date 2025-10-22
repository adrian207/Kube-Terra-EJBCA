# Keyfactor Security Controls
## Security Architecture and Control Framework

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use - Confidential  
**Target Audience**: Security architects, CISO, auditors, compliance team

---

## Document Purpose

This document defines the complete security control framework for the Keyfactor certificate lifecycle management platform, including cryptographic controls, access management, audit logging, and security architecture. This document supports security audits, compliance assessments, and security architecture reviews.

---

## Table of Contents

1. [Security Architecture Overview](#1-security-architecture-overview)
2. [Cryptographic Controls](#2-cryptographic-controls)
3. [Access Control and RBAC](#3-access-control-and-rbac)
4. [Audit Logging and Monitoring](#4-audit-logging-and-monitoring)
5. [Network Security](#5-network-security)
6. [Data Protection](#6-data-protection)
7. [Key Management](#7-key-management)
8. [Certificate Revocation](#8-certificate-revocation)
9. [Separation of Duties](#9-separation-of-duties)
10. [Security Monitoring and Response](#10-security-monitoring-and-response)
11. [Security Hardening](#11-security-hardening)
12. [Disaster Recovery and Business Continuity](#12-disaster-recovery-and-business-continuity)

---

## 1. Security Architecture Overview

### 1.1 Security Design Principles

The Keyfactor PKI platform is designed and operated according to these core security principles:

| Principle | Implementation | Verification Method |
|-----------|----------------|-------------------|
| **Defense in Depth** | Multiple security layers: network, application, database, HSM | Security architecture review |
| **Least Privilege** | Minimum permissions required for each role | Quarterly access reviews |
| **Separation of Duties** | No single person can compromise the PKI | Role assignment audit |
| **Zero Trust** | Verify every access, assume breach | Continuous authentication monitoring |
| **Secure by Default** | All systems deployed with hardened configurations | Configuration audits |
| **Fail Secure** | Security failures result in denial, not bypass | Penetration testing |
| **Auditability** | All security-relevant actions logged immutably | Log integrity checks |
| **Cryptographic Agility** | Ability to update crypto algorithms quickly | Crypto inventory review |

---

### 1.2 Security Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL ZONE                                │
│  ┌────────────┐         ┌────────────┐         ┌────────────┐      │
│  │   Users    │◄────────┤  Internet  │────────►│   CRL/     │      │
│  │  (HTTPS)   │         │  Clients   │         │   OCSP     │      │
│  └────────────┘         └────────────┘         └────────────┘      │
└─────────────────┬──────────────────────────────────────┬────────────┘
                  │                                       │
            ┌─────▼─────────┐                     ┌──────▼──────┐
            │  WAF / ALB    │                     │ CDN / Cache │
            │  (TLS Termn)  │                     └─────────────┘
            └──────┬────────┘
┌──────────────────┴──────────────────────────────────────────────────┐
│                         DMZ ZONE                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Keyfactor Application Servers                   │   │
│  │  (Windows Server 2022, IIS, .NET Framework)                 │   │
│  │  - TLS 1.2/1.3 only                                         │   │
│  │  - Certificate-based auth to backend                        │   │
│  │  - Application-level RBAC                                   │   │
│  └──────┬──────────────────────────────────────────┬───────────┘   │
│         │                                            │               │
└─────────┴────────────────────────────────────────────┴───────────────┘
          │                                            │
    ┌─────▼────────┐                          ┌───────▼─────────┐
    │   Database   │                          │  Orchestrators  │
    │   (SQL TDE)  │                          │  (Agents)       │
    └──────┬───────┘                          └─────────────────┘
           │
┌──────────┴─────────────────────────────────────────────────────────┐
│                    SECURE BACKEND ZONE                              │
│  ┌────────────────┐         ┌────────────────┐                     │
│  │ Certificate    │◄────────┤      HSM       │                     │
│  │ Authorities    │         │   (FIPS 140-2  │                     │
│  │ (AD CS/EJBCA) │         │    Level 3)     │                     │
│  └────────────────┘         └────────────────┘                     │
│                                                                      │
│  Network Segmentation:                                              │
│  - Firewall between all zones                                       │
│  - No direct internet access to backend                             │
│  - HSM only accessible from CA servers                              │
└─────────────────────────────────────────────────────────────────────┘

Security Boundaries:
━━━━━  Zone boundary with firewall
─────  Encrypted connection (TLS 1.2+)
```

---

### 1.3 Security Zones and Trust Boundaries

| Zone | Trust Level | Systems | Access Control | Monitoring |
|------|-------------|---------|----------------|------------|
| **External** | Untrusted | Internet, public users | Public access, rate limited | WAF, DDoS protection |
| **DMZ** | Low trust | Keyfactor web servers | Authenticated users only | IDS/IPS, full logging |
| **Backend** | Medium trust | Database, orchestrators | Service accounts only | Database audit, file integrity |
| **Secure** | High trust | CAs, HSM | Physical + logical controls | Video surveillance, audit logs |

**Network Segmentation**:
- All zones separated by firewalls with default-deny
- Only required ports open between zones
- No direct connectivity from external to backend
- HSM isolated on dedicated network segment

**Firewall Rules** (Simplified):

```
External → DMZ:
  ALLOW: TCP 443 (HTTPS) to Load Balancer
  ALLOW: TCP 80 (HTTP) to CRL/OCSP servers
  DENY: All other traffic

DMZ → Backend:
  ALLOW: TCP 1433 (SQL) from App Servers to Database
  ALLOW: TCP 5672 (RabbitMQ) from App Servers to Message Broker
  ALLOW: TCP 443 (HTTPS) from Orchestrators to App Servers
  DENY: All other traffic

Backend → Secure:
  ALLOW: DCOM (135, 445) from Keyfactor to AD CS
  ALLOW: TCP 1792 (HSM) from CA Servers to HSM
  DENY: All other traffic

All Zones → Management:
  ALLOW: TCP 22 (SSH) from Jump Box
  ALLOW: TCP 3389 (RDP) from Jump Box
  DENY: All other management traffic
```

---

## 2. Cryptographic Controls

### 2.1 HSM Integration

**Hardware Security Module (HSM)**: Thales Luna Network HSM

**FIPS Compliance**: FIPS 140-2 Level 3 validated

**Key Storage**:
- All CA private keys stored in HSM
- Keys never leave HSM boundary
- Multi-factor authentication required for HSM access
- Cryptographic operations performed inside HSM

**HSM Architecture**:

```
Primary Data Center (DC1):
┌────────────────────────────────────┐
│  HSM Cluster - Primary             │
│  ┌──────────┐      ┌──────────┐   │
│  │  HSM-1   │◄────►│  HSM-2   │   │
│  │ (Active) │      │(Standby) │   │
│  └──────────┘      └──────────┘   │
│       ▲                  ▲         │
│       └──────────────────┘         │
│          Replication                │
└───────────┬────────────────────────┘
            │
            │ Encrypted Channel
            │
┌───────────▼────────────────────────┐
│  HSM Cluster - DR (DC2)            │
│  ┌──────────┐      ┌──────────┐   │
│  │  HSM-3   │◄────►│  HSM-4   │   │
│  │(DR Active│      │(DR Stanby│   │
│  └──────────┘      └──────────┘   │
└────────────────────────────────────┘
```

**HSM Access Control**:

| Role | Access Method | Authentication | Permitted Operations |
|------|---------------|----------------|---------------------|
| **Security Officer (SO)** | Physical + smart card | Multi-factor (card + PIN) | HSM configuration, user management |
| **Crypto Officer (CO)** | Smart card | Multi-factor (card + PIN) | Key generation, backup, rotation |
| **CA Service Account** | Certificate + password | Certificate-based | Sign certificate requests only |
| **Auditor** | Read-only console | Smart card | View audit logs, no modifications |

**Key Generation Ceremony**:

```
CA Root Key Generation Ceremony - Checklist

Location: Secure data center, HSM room
Date: ________________
Attendees: 
  Security Officer 1: ________________ (Signature)
  Security Officer 2: ________________ (Signature)
  Crypto Officer: ________________ (Signature)
  Witness/Auditor: ________________ (Signature)
  Video Recording: Yes □ No □

Pre-Ceremony:
□ Room access logged and verified
□ All attendees authenticated (badges checked)
□ Video recording started
□ HSM status verified (online, healthy)
□ Network connections verified
□ Backup HSM ready

Ceremony Steps:
□ SO1 and SO2 authenticate to HSM (dual control)
□ Verify HSM date/time correct
□ Review key generation parameters:
   Algorithm: RSA □ ECC □  
   Key Size: 2048 □ 4096 □
   Key Label: ____________________
   Key Exportability: Non-exportable ☑
□ Generate key pair in HSM
□ Record key handle/identifier: ________________
□ Generate self-signed root certificate
□ Verify certificate details (subject, validity, etc.)
□ Export public key and certificate
□ Test signing operation
□ Backup key material to encrypted USB (dual custody)
□ Store backup in safe (location: ________)

Post-Ceremony:
□ All attendees sign attestation
□ Video recording preserved
□ Documentation filed
□ HSM audit log reviewed
□ Network access to HSM re-enabled

Ceremony Completion Time: ________________
Status: Success □ Aborted □
If Aborted, Reason: ____________________
```

---

### 2.2 Cryptographic Standards

**Approved Algorithms**:

| Purpose | Algorithm | Key Size/Curve | Validity | Retirement Date |
|---------|-----------|----------------|----------|----------------|
| **Asymmetric (Current)** | RSA | 2048-bit minimum | Active | 2030 |
| **Asymmetric (Preferred)** | RSA | 4096-bit | Active | No planned retirement |
| **Asymmetric (Next-Gen)** | ECC | P-384 (NIST) | Active | No planned retirement |
| **Hashing (Current)** | SHA-256 | 256-bit | Active | No planned retirement |
| **Hashing (Legacy)** | SHA-1 | 160-bit | **PROHIBITED** | Retired 2020 |
| **Symmetric** | AES | 256-bit | Active | No planned retirement |
| **TLS Protocol** | TLS 1.2 | - | Active | 2025 (min version) |
| **TLS Protocol** | TLS 1.3 | - | Preferred | - |
| **TLS Protocol** | TLS 1.0/1.1 | - | **PROHIBITED** | Retired 2020 |

**Certificate Validity Periods**:

| Certificate Type | Maximum Validity | Rationale |
|-----------------|------------------|-----------|
| Root CA | 20 years | Industry standard for root CAs |
| Subordinate CA | 10 years | Allows for crypto agility |
| TLS/SSL Certificates | 398 days (13 months) | CA/Browser Forum baseline requirement |
| Code Signing | 3 years | Industry standard |
| Client Authentication | 2 years | Balance security and usability |
| Email (S/MIME) | 2 years | User convenience |

**Cryptographic Key Usage**:

```
Certificate Templates - Key Usage Configuration

TLS Server Certificate:
  Key Usage: Digital Signature, Key Encipherment
  Extended Key Usage: Server Authentication (1.3.6.1.5.5.7.3.1)
  
TLS Client Certificate:
  Key Usage: Digital Signature
  Extended Key Usage: Client Authentication (1.3.6.1.5.5.7.3.2)
  
Code Signing Certificate:
  Key Usage: Digital Signature
  Extended Key Usage: Code Signing (1.3.6.1.5.5.7.3.3)
  
Email Certificate:
  Key Usage: Digital Signature, Key Encipherment
  Extended Key Usage: Email Protection (1.3.6.1.5.5.7.3.4)
```

---

### 2.3 Post-Quantum Cryptography Readiness

**Current Status**: Monitoring NIST PQC standardization

**Preparation**:
- HSM vendor confirmed PQC algorithm support in future firmware
- Keyfactor platform architecture supports algorithm updates
- Certificate templates designed for crypto agility
- Migration plan being developed for post-2030 timeline

**PQC Migration Roadmap** (Preliminary):

```
2025-2027: Monitoring and Planning
  - Track NIST PQC standard finalization
  - Evaluate HSM vendor PQC roadmap
  - Assess application compatibility

2027-2028: Testing and Pilots
  - Lab testing of PQC algorithms
  - Hybrid certificates (classical + PQC)
  - Limited production pilots

2029-2030: Production Migration
  - Update CA infrastructure
  - Issue hybrid certificates
  - Migrate high-value certificates

2031+: Full PQC Deployment
  - All new certificates PQC-enabled
  - Legacy classical-only certs in renewal cycle
```

---

## 3. Access Control and RBAC

### 3.1 Role-Based Access Control Model

**Keyfactor RBAC Roles**:

| Role | Permissions | Assignment Criteria | Review Frequency |
|------|-------------|-------------------|------------------|
| **PKI Administrator** | Full platform access, user management, CA configuration | PKI team lead only (max 2 users) | Quarterly |
| **CA Operator** | Certificate issuance, renewal, revocation approval | PKI operators (5-10 users) | Quarterly |
| **Certificate Manager** | View certificates, request certificates, manage owned certificates | Service owners, DevOps (100-500 users) | Semi-annually |
| **Read-Only Auditor** | View-only access to all data, audit logs | Security team, compliance (5-10 users) | Quarterly |
| **Orchestrator Admin** | Manage orchestrators, certificate stores | Infrastructure team (10-20 users) | Quarterly |
| **Template Manager** | Create and modify certificate templates | PKI architects (2-3 users) | Quarterly |

**RBAC Matrix**:

| Action | PKI Admin | CA Operator | Cert Manager | Auditor | Orch Admin | Template Mgr |
|--------|-----------|-------------|--------------|---------|------------|--------------|
| **View Certificates** | ✅ | ✅ | ✅ (owned only) | ✅ | ✅ | ✅ |
| **Request Certificate** | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Approve Request** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Revoke Certificate** | ✅ | ✅ | ✅ (owned only) | ❌ | ❌ | ❌ |
| **Emergency Revoke** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Manage Users** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Configure CA** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Create Template** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Modify Template** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Manage Orchestrator** | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| **View Audit Logs** | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| **Export Private Keys** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Note**: Private key export is **disabled globally** for security.

---

### 3.2 Authentication Mechanisms

**Multi-Factor Authentication (MFA)**:

| User Type | Authentication Method | MFA Required | Session Timeout |
|-----------|---------------------|--------------|----------------|
| **PKI Administrators** | Smart card + PIN | ✅ Always | 15 minutes |
| **CA Operators** | Smart card + PIN | ✅ Always | 30 minutes |
| **Certificate Managers** | AD password + MFA (Microsoft Authenticator) | ✅ Always | 60 minutes |
| **Service Accounts** | Certificate-based (no interactive login) | N/A | N/A |
| **API Access** | OAuth2 + Client Certificate | ✅ Certificate required | Token: 1 hour |

**Authentication Flow**:

```
User Authentication Flow (Interactive)

1. User → WAF: HTTPS request
2. WAF → Keyfactor: Forward request
3. Keyfactor → Azure AD: SAML authentication request
4. Azure AD → User: Prompt for credentials
5. User → Azure AD: Username + password
6. Azure AD → User: Prompt for MFA (Microsoft Authenticator)
7. User → Azure AD: MFA code
8. Azure AD → Keyfactor: SAML assertion (with claims)
9. Keyfactor: Check RBAC roles
10. Keyfactor → User: Authenticated session (cookie)

Service Account Authentication (API)

1. API Client → Keyfactor: HTTPS request with client certificate
2. Keyfactor: Verify certificate (chain, revocation, expiry)
3. Keyfactor: Check certificate DN against authorized service accounts
4. Keyfactor: Issue OAuth2 access token (1 hour validity)
5. API Client → Keyfactor: Subsequent requests with access token
6. Keyfactor: Validate token, check RBAC, process request
```

**Failed Authentication Handling**:

```
Failed Login Policy

Account Lockout:
  Threshold: 5 failed attempts
  Lockout Duration: 30 minutes (auto-unlock) or admin unlock
  Lockout Scope: Per user account
  
Alert Thresholds:
  Warning: 10 failed logins from same IP in 15 minutes
  Critical: 50 failed logins from same IP in 15 minutes (possible brute-force)
  
IP Blocking (WAF):
  Automatic block after 20 failed attempts from same IP
  Block duration: 1 hour
  Whitelist: Internal IP ranges excluded from auto-block
```

---

### 3.3 Authorization Framework

See [02-RBAC-Authorization-Framework.md](./02-RBAC-Authorization-Framework.md) for complete authorization model including:
- Identity-based RBAC
- SAN validation against asset inventory
- Resource binding (device ownership verification)
- Template policy enforcement

**Authorization Decision Point (ADP)**:

```python
# Authorization logic (simplified)
def authorize_certificate_request(user, csr, template):
    """
    Multi-layer authorization check
    Returns: (allowed: bool, reason: str)
    """
    # Layer 1: Identity-based RBAC
    if not user.has_role("CertificateManager"):
        return (False, "User does not have CertificateManager role")
    
    # Layer 2: Template access control
    if template not in user.allowed_templates:
        return (False, f"User not authorized for template {template}")
    
    # Layer 3: SAN validation
    for san in csr.subject_alternative_names:
        if not asset_inventory.is_authorized(user, san):
            return (False, f"User not authorized for SAN: {san}")
    
    # Layer 4: Resource binding (device ownership)
    for san in csr.subject_alternative_names:
        device = asset_inventory.get_device(san)
        if device and device.owner != user.email:
            return (False, f"User does not own device: {san}")
    
    # Layer 5: Policy compliance
    if not template.validate_csr(csr):
        return (False, "CSR does not meet template policy requirements")
    
    # All checks passed
    return (True, "Authorized")
```

---

## 4. Audit Logging and Monitoring

### 4.1 Audit Log Requirements

**Logging Scope**: All security-relevant events

**Log Retention**: 
- Online: 90 days (hot storage)
- Archive: 7 years (cold storage, compliance requirement)

**Log Integrity**: 
- Logs written to append-only storage
- Daily hash verification
- Tamper detection alerts

**Events Logged**:

| Event Category | Examples | Retention | Alert Threshold |
|----------------|----------|-----------|----------------|
| **Authentication** | Login success/failure, MFA events, session creation | 7 years | 5 failures in 5 min |
| **Authorization** | Access denied, privilege escalation attempts | 7 years | Any denial |
| **Certificate Operations** | Issuance, renewal, revocation, approval | 7 years | Emergency revocation |
| **Configuration Changes** | Template changes, CA config, user role assignments | 7 years | Any change |
| **HSM Operations** | Key generation, signing operations, HSM access | 7 years | Any failure |
| **System Events** | Service start/stop, errors, performance degradation | 90 days | Critical errors |

---

### 4.2 Audit Log Format

**Log Standard**: Common Event Format (CEF) for SIEM integration

**Sample Audit Log Entry**:

```json
{
  "timestamp": "2025-10-22T14:35:22.123Z",
  "event_id": "EVT-2025-1022-123456",
  "event_type": "CertificateIssued",
  "severity": "INFO",
  "user": {
    "username": "john.doe@contoso.com",
    "user_id": "USR-12345",
    "role": "CertificateManager",
    "ip_address": "10.1.2.34",
    "session_id": "SES-789012"
  },
  "certificate": {
    "certificate_id": "CERT-567890",
    "subject": "CN=webapp01.contoso.com",
    "serial_number": "1A2B3C4D5E6F7890",
    "template": "WebServer",
    "sans": ["webapp01.contoso.com", "www.contoso.com"],
    "validity_start": "2025-10-22T14:35:00Z",
    "validity_end": "2026-10-22T14:35:00Z"
  },
  "ca": {
    "ca_name": "Contoso Enterprise CA",
    "ca_id": "CA-001"
  },
  "request": {
    "request_id": "REQ-345678",
    "request_time": "2025-10-22T14:30:00Z",
    "approval_required": false,
    "auto_approved": true
  },
  "metadata": {
    "application": "WebApp-Production",
    "owner": "webapp-team@contoso.com",
    "environment": "production",
    "cost_center": "IT-WEB-001"
  },
  "source": {
    "system": "keyfactor-prod-01",
    "component": "CertificateService",
    "version": "10.1.2"
  },
  "hash": "SHA256:abcdef1234567890..." // Log entry integrity hash
}
```

---

### 4.3 Audit Trail Queries

**Common Audit Queries**:

```sql
-- 1. Certificate issuance by user (last 30 days)
SELECT 
    event_time,
    user_name,
    certificate_subject,
    template_name,
    ca_name
FROM AuditLog
WHERE event_type = 'CertificateIssued'
    AND event_time >= DATEADD(DAY, -30, GETDATE())
    AND user_name = 'john.doe@contoso.com'
ORDER BY event_time DESC;

-- 2. Failed authorization attempts (potential security issue)
SELECT 
    event_time,
    user_name,
    attempted_action,
    denial_reason,
    ip_address
FROM AuditLog
WHERE event_type = 'AuthorizationDenied'
    AND event_time >= DATEADD(DAY, -7, GETDATE())
GROUP BY user_name
HAVING COUNT(*) > 10
ORDER BY COUNT(*) DESC;

-- 3. Emergency certificate revocations
SELECT 
    event_time,
    user_name,
    certificate_subject,
    revocation_reason,
    comments
FROM AuditLog
WHERE event_type = 'CertificateRevoked'
    AND revocation_reason = 'KeyCompromise'
    AND event_time >= DATEADD(DAY, -90, GETDATE())
ORDER BY event_time DESC;

-- 4. Configuration changes (high-risk events)
SELECT 
    event_time,
    user_name,
    change_type,
    object_modified,
    before_value,
    after_value
FROM AuditLog
WHERE event_type IN ('ConfigurationChange', 'TemplateModified', 'RoleAssignment')
    AND event_time >= DATEADD(DAY, -30, GETDATE())
ORDER BY event_time DESC;

-- 5. HSM access audit
SELECT 
    event_time,
    user_name,
    hsm_operation,
    key_label,
    operation_result
FROM AuditLog
WHERE event_type LIKE 'HSM%'
    AND event_time >= DATEADD(DAY, -7, GETDATE())
ORDER BY event_time DESC;
```

---

### 4.4 SIEM Integration

**SIEM Platform**: Splunk Enterprise

**Log Forwarding**:
```powershell
# Splunk Universal Forwarder configuration
# File: C:\Program Files\SplunkUniversalForwarder\etc\apps\keyfactor\local\inputs.conf

[monitor://C:\ProgramData\Keyfactor\Logs\audit]
disabled = false
index = keyfactor_audit
sourcetype = keyfactor:audit:json
whitelist = \.json$

[monitor://C:\ProgramData\Keyfactor\Logs\application]
disabled = false
index = keyfactor_app
sourcetype = keyfactor:application:log
```

**Splunk Queries**:

```spl
# Dashboard: Certificate Operations Overview
index=keyfactor_audit event_type="Certificate*"
| stats count by event_type
| sort -count

# Alert: Suspicious Activity (multiple failed authorizations)
index=keyfactor_audit event_type="AuthorizationDenied"
| stats count by user_name, ip_address
| where count > 10
| table user_name, ip_address, count

# Alert: Emergency Revocations
index=keyfactor_audit event_type="CertificateRevoked" revocation_reason="KeyCompromise"
| table timestamp, user_name, certificate_subject, comments

# Report: Compliance - All Certificate Operations
index=keyfactor_audit event_type="Certificate*"
| eval date=strftime(_time, "%Y-%m-%d")
| stats count by date, event_type, user_name
| outputlookup keyfactor_compliance_report.csv
```

---

## 5. Network Security

### 5.1 Network Segmentation

**VLAN Assignment**:

| VLAN ID | Name | Systems | Security Level |
|---------|------|---------|----------------|
| **VLAN 10** | External/DMZ | WAF, Load Balancers | Low trust |
| **VLAN 20** | Application | Keyfactor App Servers | Medium trust |
| **VLAN 30** | Data | SQL Server, RabbitMQ | High trust |
| **VLAN 40** | PKI Secure | CAs, HSM | Very high trust |
| **VLAN 50** | Management | Jump boxes, monitoring | Administrative |

**Inter-VLAN Routing**: Default deny, explicit allow rules only

---

### 5.2 TLS/SSL Configuration

**TLS Policy**:

```
TLS Configuration (IIS on Keyfactor Servers)

Protocols:
  TLS 1.2: Enabled ✅
  TLS 1.3: Enabled ✅
  TLS 1.1: Disabled ❌ (deprecated)
  TLS 1.0: Disabled ❌ (deprecated)
  SSL 3.0: Disabled ❌ (insecure)
  SSL 2.0: Disabled ❌ (insecure)

Cipher Suites (Priority Order):
  1. TLS_AES_256_GCM_SHA384 (TLS 1.3)
  2. TLS_AES_128_GCM_SHA256 (TLS 1.3)
  3. TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 (TLS 1.2)
  4. TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 (TLS 1.2)

Key Exchange:
  ECDHE (Elliptic Curve Diffie-Hellman Ephemeral): Preferred ✅
  DHE (Diffie-Hellman Ephemeral): Allowed ✅
  RSA: Disabled ❌ (no forward secrecy)

Certificate Requirements:
  Server Certificate: RSA 2048-bit minimum
  Client Certificate: Required for API access
  Certificate Pinning: Implemented for mobile apps
```

**TLS Configuration Script** (PowerShell):

```powershell
# Disable weak protocols
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Name 'Enabled' -Value 0 -PropertyType DWORD

New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' -Name 'Enabled' -Value 0 -PropertyType DWORD

# Enable strong protocols
New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Name 'Enabled' -Value 1 -PropertyType DWORD

New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Name 'Enabled' -Value 1 -PropertyType DWORD

# Disable weak ciphers
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128' -Name 'Enabled' -Value 0 -PropertyType DWORD
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56/56' -Name 'Enabled' -Value 0 -PropertyType DWORD
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168' -Name 'Enabled' -Value 0 -PropertyType DWORD

# Restart required
Restart-Computer -Force
```

---

### 5.3 WAF Configuration

**Web Application Firewall**: Azure Application Gateway with WAF v2

**WAF Rules**:

| Rule Set | Version | Status | Purpose |
|----------|---------|--------|---------|
| OWASP Core Rule Set | 3.2 | Enabled | Protects against common web attacks |
| Bot Protection | Latest | Enabled | Blocks malicious bots |
| IP Reputation | Latest | Enabled | Blocks known malicious IPs |
| Rate Limiting | Custom | Enabled | DDoS protection |

**Custom WAF Rules**:

```json
{
  "customRules": [
    {
      "name": "RateLimitCertificateAPI",
      "priority": 1,
      "ruleType": "RateLimitRule",
      "rateLimitDuration": "OneMin",
      "rateLimitThreshold": 100,
      "matchConditions": [
        {
          "matchVariable": "RequestUri",
          "operator": "Contains",
          "matchValue": ["/KeyfactorAPI/Certificates"]
        }
      ],
      "action": "Block"
    },
    {
      "name": "BlockSQLInjection",
      "priority": 2,
      "ruleType": "MatchRule",
      "matchConditions": [
        {
          "matchVariable": "QueryString",
          "operator": "Contains",
          "matchValue": ["'", "OR 1=1", "UNION SELECT"]
        }
      ],
      "action": "Block"
    },
    {
      "name": "RequireClientCertForAPI",
      "priority": 3,
      "ruleType": "MatchRule",
      "matchConditions": [
        {
          "matchVariable": "RequestUri",
          "operator": "BeginsWith",
          "matchValue": ["/KeyfactorAPI/"]
        },
        {
          "matchVariable": "RequestHeader",
          "selector": "X-Client-Cert",
          "operator": "NotExists"
        }
      ],
      "action": "Block"
    }
  ]
}
```

---

## 6. Data Protection

### 6.1 Data Classification

| Data Type | Classification | Encryption Required | Access Control | Retention |
|-----------|----------------|-------------------|----------------|-----------|
| **CA Private Keys** | Critical | HSM | SO/CO only | Lifetime of CA |
| **Certificate Private Keys** | Highly Sensitive | HSM or encrypted storage | Key owner only | Cert lifetime + 7 years |
| **Audit Logs** | Sensitive | TDE | Auditors, admins | 7 years |
| **Certificate Metadata** | Internal | TDE | Authenticated users | Cert lifetime + 7 years |
| **User Credentials** | Highly Sensitive | Hashed (bcrypt) | Identity system only | User lifetime |
| **Configuration** | Confidential | Encrypted backups | Admins only | Current + 1 year |

---

### 6.2 Data Encryption

**Data at Rest**:

| Component | Encryption Method | Key Management |
|-----------|------------------|----------------|
| **SQL Database** | Transparent Data Encryption (TDE) | SQL Server managed, backed up to HSM |
| **File Shares** | BitLocker/EFS | Active Directory managed |
| **Backups** | AES-256 encryption | Backup software managed, keys in HSM |
| **Log Archives** | AES-256 encryption | Azure Key Vault managed |

**SQL Server TDE Configuration**:

```sql
-- Enable TDE on Keyfactor database
USE master;
GO

-- Create master key
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword123!';
GO

-- Create certificate for TDE
CREATE CERTIFICATE TDE_Certificate
WITH SUBJECT = 'Certificate for TDE on Keyfactor DB';
GO

-- Backup certificate (CRITICAL - store securely)
BACKUP CERTIFICATE TDE_Certificate
TO FILE = '\\secure-location\TDE_Certificate.cer'
WITH PRIVATE KEY (
    FILE = '\\secure-location\TDE_Certificate_Key.pvk',
    ENCRYPTION BY PASSWORD = 'AnotherStrongPassword456!'
);
GO

-- Create database encryption key
USE Keyfactor;
GO

CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDE_Certificate;
GO

-- Enable encryption
ALTER DATABASE Keyfactor
SET ENCRYPTION ON;
GO

-- Verify encryption status
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    encryption_state,
    encryption_state_desc = CASE encryption_state
        WHEN 0 THEN 'No encryption'
        WHEN 1 THEN 'Unencrypted'
        WHEN 2 THEN 'Encryption in progress'
        WHEN 3 THEN 'Encrypted'
        WHEN 4 THEN 'Key change in progress'
        WHEN 5 THEN 'Decryption in progress'
    END,
    percent_complete,
    encryptor_type
FROM sys.dm_database_encryption_keys
WHERE DB_NAME(database_id) = 'Keyfactor';
```

**Data in Transit**:

| Connection | Protocol | Authentication |
|------------|----------|----------------|
| User → Keyfactor Portal | TLS 1.2/1.3 | Password + MFA |
| Keyfactor → Database | TLS 1.2 + IPsec | Certificate |
| Keyfactor → CA | TLS 1.2 + DCOM | Kerberos |
| Keyfactor → HSM | TLS 1.2 + IPsec | Certificate + password |
| Orchestrator → Keyfactor | TLS 1.2 (mutual) | Client certificate |

---

### 6.3 Data Backup Security

**Backup Encryption**:
- All backups encrypted with AES-256
- Encryption keys stored in HSM
- Key rotation every 90 days

**Backup Storage**:
- Primary: On-premise NAS with replication
- Secondary: Azure Blob Storage (encrypted)
- Backup retention: 30 days (daily), 12 months (monthly), 7 years (yearly)

**Backup Access Control**:
- Backup operator role (write-only to backup location)
- Restore requires dual authorization (PKI Admin + CISO)
- All backup/restore operations audited

**Backup Verification**:
- Monthly restore test to isolated environment
- Integrity verification (checksum) daily
- DR failover test quarterly

---

## 7. Key Management

### 7.1 Key Lifecycle

```
Key Lifecycle Stages

1. Generation
   ├─ In HSM (CA keys)
   ├─ On endpoint (certificate keys)
   └─ Cryptographically random (FIPS 140-2 approved RNG)

2. Storage
   ├─ CA private keys: HSM only, never exported
   ├─ Certificate private keys: Encrypted local storage or HSM
   └─ Public keys: Database, certificates

3. Usage
   ├─ Key usage restrictions enforced (certificate key usage extension)
   ├─ Signing operations audited
   └─ Usage monitoring for anomalies

4. Rotation
   ├─ CA key rotation: Every 5-10 years (planned)
   ├─ Certificate keys: New key with each renewal (recommended)
   └─ Encryption keys: Every 90 days

5. Archival
   ├─ Old CA keys: Retained in HSM for signature verification
   ├─ Certificate keys: Retained if required for decrypt/verify
   └─ Archival period: Certificate lifetime + 7 years

6. Destruction
   ├─ HSM: Secure erase (overwrite with random data 7x)
   ├─ File system: Secure delete (shred/sdelete)
   └─ Destruction logged and verified
```

---

### 7.2 Key Escrow Policy

**Policy**: Key escrow is **NOT** performed for certificate private keys

**Rationale**:
- Private keys are owned by certificate owners
- Key escrow creates significant security risk
- Non-repudiation cannot be guaranteed with escrowed keys
- Industry best practice: No key escrow

**Exceptions** (with explicit business justification and CISO approval):
- Code signing keys (for business continuity)
- Document encryption keys (for data recovery)

**Escrow Procedure** (if approved):
1. Generate key pair in HSM
2. Export private key encrypted with escrow key
3. Store encrypted key in secure vault (dual custody)
4. Original key delivered to certificate owner
5. Escrow key access requires M-of-N threshold (3 of 5)

---

### 7.3 Key Recovery

**CA Key Recovery**:

**Scenario**: CA private key lost or inaccessible

**Prevention**:
- CA keys stored in HSM with redundancy (4 HSMs in cluster)
- HSM failover automatic
- Keys backed up during generation ceremony

**Recovery Procedure**:
```
CA Key Recovery Procedure

Prerequisites:
□ Incident declared and documented
□ CISO approval obtained
□ Dual custody (2 Security Officers)

Steps:
1. Retrieve key backup from secure vault
   Location: Fire-rated safe in SOC
   Access: Requires 2 of 3 keys (SO1, SO2, CISO)

2. Authenticate to backup HSM
   Method: Smart card + PIN (both SOs)

3. Import key material into HSM
   hsm> partition login
   hsm> object import -file backup.key -label CA-ROOT-KEY

4. Verify key integrity
   Compare public key hash with original
   Test signature operation

5. Restore CA service
   Update CA configuration to use restored key
   Test certificate issuance

6. Post-recovery:
   - Full audit of CA operations since incident
   - Verify no unauthorized certificates issued
   - Update incident documentation

Estimated Time: 2-4 hours
```

---

## 8. Certificate Revocation

### 8.1 CRL Distribution

**CRL Publishing Schedule**:
- **Full CRL**: Every 24 hours
- **Delta CRL**: Every hour
- **Emergency CRL**: On-demand (key compromise)

**CRL Distribution Points**:

| CDP | URL | Availability | Caching |
|-----|-----|--------------|---------|
| **Primary** | http://crl.contoso.com/contoso-ca.crl | 99.9% SLA | CDN (CloudFlare) |
| **Backup** | http://crl-backup.contoso.com/contoso-ca.crl | 99% SLA | On-premise |
| **LDAP** | ldap://dc.contoso.com/CN=Contoso-CA,CN=CDP | Internal only | Active Directory |

**CRL Configuration** (CA):

```powershell
# Configure CRL distribution points
certutil -setreg CA\CRLPublicationURLs "1:C:\Windows\System32\CertSrv\CertEnroll\%3%8.crl\n2:http://crl.contoso.com/%3%8.crl\n3:http://crl-backup.contoso.com/%3%8.crl"

# Set CRL periods
certutil -setreg CA\CRLPeriodUnits 1
certutil -setreg CA\CRLPeriod "Days"
certutil -setreg CA\CRLDeltaPeriodUnits 1
certutil -setreg CA\CRLDeltaPeriod "Hours"

# Restart CA service
net stop certsvc && net start certsvc

# Publish new CRL
certutil -CRL
```

**CRL Monitoring**:
- Check CRL publication success every hour
- Alert if CRL not updated in 25 hours
- Monitor CDN cache hit rate (target: > 95%)
- Alert if CRL size grows unexpectedly (> 10MB)

---

### 8.2 OCSP Configuration

**OCSP Responder**: EJBCA OCSP Responder (for EJBCA-issued certs), AD CS Online Responder (for AD CS-issued certs)

**OCSP URL**: http://ocsp.contoso.com

**OCSP Configuration**:

```
OCSP Service Level Agreement

Response Time: < 200ms (P95)
Availability: 99.9%
Cache Duration: 1 hour
Signing Certificate: Dedicated OCSP signing cert (renewed annually)

OCSP Response Status:
- good: Certificate valid and not revoked
- revoked: Certificate has been revoked
- unknown: Certificate not found in CA database
```

**OCSP Responder Deployment**:

```
High Availability OCSP Setup

Load Balancer (F5 BIG-IP)
     |
     ├─ OCSP Responder 1 (Primary DC)
     ├─ OCSP Responder 2 (Primary DC)
     ├─ OCSP Responder 3 (DR DC)
     └─ OCSP Responder 4 (DR DC)

Database: 
- Shared database (read replicas)
- CRL parsed into database every hour
- OCSP responders query database for revocation status
```

---

### 8.3 Revocation Response Times

| Revocation Reason | CRL Update | OCSP Update | Alert |
|-------------------|------------|-------------|-------|
| **Key Compromise** | Immediate (5 min) | Immediate (1 min) | Critical (PagerDuty) |
| **CA Compromise** | Immediate (5 min) | Immediate (1 min) | Critical (CISO call) |
| **Certificate Superseded** | Next scheduled (< 24 hours) | Next scheduled (< 1 hour) | Info |
| **Cessation of Operation** | Next scheduled (< 24 hours) | Next scheduled (< 1 hour) | Info |
| **Affiliation Changed** | Next scheduled (< 24 hours) | Next scheduled (< 1 hour) | Info |

---

## 9. Separation of Duties

### 9.1 Critical Functions Requiring Dual Control

| Function | Requires | Approval Process |
|----------|----------|------------------|
| **CA Key Generation** | 2 Security Officers | In-person ceremony, video recorded |
| **CA Configuration Changes** | PKI Admin + CISO | Change ticket + email approval |
| **Emergency Certificate Issuance** | CA Operator + CISO | Documented business justification |
| **HSM Firmware Update** | 2 Security Officers + Vendor Engineer | Scheduled maintenance window |
| **Break-Glass Account Usage** | PKI Admin + CISO | Security incident ticket |
| **Backup Restoration** | PKI Admin + CISO | Documented recovery scenario |
| **User Role Assignment (Admin)** | PKI Admin + HR Manager | Access request ticket |

---

### 9.2 Segregation of Duties Matrix

**Incompatible Role Combinations** (same person cannot have both):

| Role A | Role B | Risk |
|--------|--------|------|
| PKI Administrator | CA Operator | Single person could issue and approve certificates without oversight |
| Certificate Manager (Requester) | CA Operator (Approver) | Self-approval of certificate requests |
| Orchestrator Admin | Database Admin | Could modify cert inventory and deployment records |
| Security Officer (HSM) | Crypto Officer (HSM) | Single person could generate and export keys |
| Auditor | Any operational role | Auditor independence compromised |

**Enforcement**:
- Identity management system enforces incompatible role checks
- Quarterly access reviews verify compliance
- Exception process requires CISO approval and compensating controls

---

## 10. Security Monitoring and Response

### 10.1 Security Monitoring

**24/7 Security Operations Center (SOC)** monitors:

| Monitoring Domain | Tools | Alert Criteria |
|------------------|-------|----------------|
| **Intrusion Detection** | Snort, Suricata | Suspicious network activity |
| **Log Analysis** | Splunk | Failed auth, config changes, revocations |
| **Vulnerability Scanning** | Qualys, Nessus | New vulnerabilities (weekly scan) |
| **File Integrity** | Tripwire | Unauthorized file changes |
| **Anomaly Detection** | ML-based (Azure Sentinel) | Unusual patterns in cert operations |

**Security Dashboards**:

```
SOC Dashboard - PKI Security

┌─────────────────────────────────────────────┐
│ Failed Authentication (Last Hour)          │
│ Total: 23 | Threshold: < 50 ✅             │
│                                             │
│ Unique IPs: 8                               │
│ Top Sources:                                │
│   10.1.2.45: 8 failures                     │
│   203.0.113.22: 5 failures ⚠                │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ High-Risk Operations (Last 24h)            │
│                                             │
│ Emergency Revocations: 0 ✅                │
│ Config Changes: 2 (reviewed ✅)            │
│ Break-Glass Access: 0 ✅                   │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ System Health                               │
│                                             │
│ CA Availability: 100% ✅                   │
│ HSM Status: All online ✅                  │
│ OCSP Response Time: 45ms ✅                │
│ CRL Last Updated: 23 minutes ago ✅         │
└─────────────────────────────────────────────┘
```

---

### 10.2 Incident Response Integration

See [10-Incident-Response-Procedures.md](./10-Incident-Response-Procedures.md) for complete procedures.

**Security Incident Classification**:

| Severity | Examples | Response Time |
|----------|----------|---------------|
| **SEV-1 (Critical)** | Key compromise, CA breach, ransomware | 15 minutes |
| **SEV-2 (High)** | Suspected unauthorized access, malware detection | 1 hour |
| **SEV-3 (Medium)** | Repeated failed auth, policy violations | 4 hours |
| **SEV-4 (Low)** | Security alerts, audit findings | 1 business day |

**Security Incident Response Team (SIRT)**:
- Incident Commander: Security Manager
- Technical Lead: PKI Lead
- Communications: PR/Legal
- Forensics: Security Engineer
- SMEs: On-demand (HSM vendor, Keyfactor support)

---

## 11. Security Hardening

### 11.1 Operating System Hardening

**Windows Server 2022** (Keyfactor servers, CA servers):

```powershell
# Disable unnecessary services
$disableServices = @(
    "RemoteRegistry",
    "SSDPSRV",
    "upnphost",
    "WMPNetworkSvc",
    "WSearch",
    "TapiSrv"
)

foreach ($service in $disableServices) {
    Set-Service -Name $service -StartupType Disabled
    Stop-Service -Name $service -Force
}

# Enable Windows Firewall (all profiles)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Configure audit policy
auditpol /set /category:"Account Logon" /success:enable /failure:enable
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
auditpol /set /category:"Object Access" /success:enable /failure:enable
auditpol /set /category:"Policy Change" /success:enable /failure:enable
auditpol /set /category:"Privilege Use" /failure:enable
auditpol /set /category:"System" /success:enable /failure:enable

# Disable SMBv1
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# Enable credential guard
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -Value 1 -PropertyType DWORD -Force

# Set minimum password length
net accounts /minpwlen:14

# Set account lockout policy
net accounts /lockoutthreshold:5
net accounts /lockoutduration:30
net accounts /lockoutwindow:30

# Disable anonymous access
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 1 -PropertyType DWORD -Force
```

**Linux** (EJBCA servers, orchestrators):

```bash
#!/bin/bash
# Linux hardening script (RHEL 8)

# Disable unnecessary services
systemctl disable avahi-daemon
systemctl disable cups
systemctl disable bluetooth

# Configure firewall (firewalld)
firewall-cmd --set-default-zone=drop
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-port=8443/tcp
firewall-cmd --reload

# Set file permissions
chmod 700 /root
chmod 600 /etc/ssh/sshd_config
chmod 644 /etc/passwd
chmod 600 /etc/shadow

# SSH hardening
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config
systemctl restart sshd

# Enable SELinux
setenforce 1
sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config

# Configure auditd
systemctl enable auditd
systemctl start auditd

# Install and configure fail2ban
yum install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

---

### 11.2 Application Hardening

**IIS Hardening** (Keyfactor web application):

```powershell
# Remove unnecessary HTTP headers
Import-Module WebAdministration

# Remove Server header
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST" -Filter "system.webServer/security/requestFiltering" -Name "removeServerHeader" -Value $true

# Add security headers
Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -Value @{name='X-Content-Type-Options';value='nosniff'}
Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -Value @{name='X-Frame-Options';value='SAMEORIGIN'}
Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -Value @{name='X-XSS-Protection';value='1; mode=block'}
Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -Value @{name='Strict-Transport-Security';value='max-age=31536000; includeSubDomains'}
Add-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -Value @{name='Content-Security-Policy';value="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"}

# Disable directory browsing
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/directoryBrowse" -Name "enabled" -Value $false

# Request filtering
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/security/requestFiltering/requestLimits" -Name "maxAllowedContentLength" -Value 10485760  # 10 MB
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/security/requestFiltering/requestLimits" -Name "maxUrl" -Value 2048
Set-WebConfigurationProperty -PSPath "MACHINE/WEBROOT/APPHOST/KeyfactorSite" -Filter "system.webServer/security/requestFiltering/requestLimits" -Name "maxQueryString" -Value 1024
```

---

### 11.3 Database Hardening

**SQL Server Security Checklist**:

```sql
-- 1. Disable xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;

-- 2. Disable OLE Automation
EXEC sp_configure 'Ole Automation Procedures', 0;
RECONFIGURE;

-- 3. Disable SQL Server Agent XPs (if not needed)
EXEC sp_configure 'Agent XPs', 0;
RECONFIGURE;

-- 4. Set strong sa password
ALTER LOGIN sa WITH PASSWORD = 'VeryStrongPassword123!@#', CHECK_POLICY = ON;
ALTER LOGIN sa DISABLE;  -- Disable sa, use Windows auth only

-- 5. Remove unnecessary accounts
-- Review and remove default accounts except sa (disabled)
SELECT name, type_desc, is_disabled 
FROM sys.server_principals 
WHERE type IN ('S', 'U') 
    AND name NOT IN ('sa');
-- DROP LOGIN [unnecessary_login];

-- 6. Configure audit
USE master;
CREATE SERVER AUDIT KeyfactorAudit
TO FILE (FILEPATH = 'C:\SQLAudit\', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 50);

CREATE SERVER AUDIT SPECIFICATION KeyfactorServerAuditSpec
FOR SERVER AUDIT KeyfactorAudit
ADD (FAILED_LOGIN_GROUP),
ADD (SUCCESSFUL_LOGIN_GROUP),
ADD (DATABASE_OBJECT_CHANGE_GROUP),
ADD (SCHEMA_OBJECT_CHANGE_GROUP);

ALTER SERVER AUDIT KeyfactorAudit WITH (STATE = ON);
ALTER SERVER AUDIT SPECIFICATION KeyfactorServerAuditSpec WITH (STATE = ON);

-- 7. Enable TDE (see section 6.2)

-- 8. Restrict database access
USE Keyfactor;
-- Only grant necessary permissions to service accounts
REVOKE CONNECT FROM [public];
GRANT CONNECT TO [CONTOSO\KeyfactorService];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [CONTOSO\KeyfactorService];
-- Do NOT grant sysadmin or db_owner
```

---

## 12. Disaster Recovery and Business Continuity

### 12.1 DR Architecture

**Recovery Objectives**:
- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 1 hour

**DR Site**: Secondary data center (100 miles from primary)

**DR Components**:
- Standby Keyfactor servers (warm standby)
- SQL Server Always On Availability Group (synchronous replication)
- HSM cluster with DR nodes
- Replicated backup storage

---

### 12.2 Failover Procedures

See [08-Operations-Manual.md](./08-Operations-Manual.md) Section 5 for detailed backup and recovery procedures.

**Automated Failover** (Database):
- SQL Server Always On automatic failover
- Failover time: < 30 seconds
- No data loss (synchronous replication)

**Manual Failover** (Application):
```
Application Failover Procedure

1. Declare disaster (approval required)
2. Update DNS: keyfactor.contoso.com → DR IP
3. Start Keyfactor services in DR site
4. Verify database connectivity
5. Test certificate issuance
6. Notify stakeholders
7. Monitor operations

Estimated Time: 2 hours
```

---

### 12.3 BC/DR Testing

**Testing Schedule**:
- **Tabletop Exercise**: Quarterly
- **DR Failover Test**: Semi-annually
- **Full DR Drill**: Annually

**Last DR Test Results** (Example):

```
DR Test Report - Q3 2025

Test Date: 2025-09-15
Test Type: Full failover and failback
Duration: 6 hours

Results:
✅ Database failover: 25 seconds (target: < 30s)
✅ Application start: 15 minutes (target: < 30 min)
✅ Certificate issuance test: Success
✅ Orchestrator reconnection: 5 minutes (target: < 10 min)
✅ Failback to primary: 4 hours (target: < 4 hours)

Issues Identified:
⚠ OCSP responders took 8 minutes to sync (target: 5 min)
⚠ 2 orchestrators failed to reconnect automatically

Action Items:
1. Tune OCSP database replication
2. Update orchestrator reconnection logic
3. Update runbook with lessons learned

Overall Assessment: PASS with minor improvements needed
```

---

## Appendix A: Security Compliance Checklist

**Monthly Security Review Checklist**:

```markdown
Security Compliance Checklist - [Month/Year]

□ Access Reviews
  □ User access reviewed (all accounts)
  □ Privileged access reviewed (admins, operators)
  □ Service account access reviewed
  □ Inactive accounts disabled
  □ Departed employee access revoked

□ Cryptographic Controls
  □ HSM status verified (all nodes online)
  □ HSM firmware up-to-date
  □ CA certificates validity checked (> 90 days remaining)
  □ Weak certificates identified and remediated (none with RSA < 2048)

□ Audit and Logging
  □ Audit logs reviewed (no gaps)
  □ Critical events investigated
  □ SIEM dashboards reviewed
  □ Log retention verified (7 years available)

□ Vulnerability Management
  □ Vulnerability scan completed
  □ Critical vulnerabilities patched (within 30 days)
  □ Penetration test findings addressed

□ Backup and DR
  □ Backups completed successfully
  □ Backup restore tested
  □ DR site verified operational
  □ Backup encryption verified

□ Incident Response
  □ Security incidents reviewed
  □ Post-incident actions completed
  □ Runbooks updated based on lessons learned

□ Compliance
  □ SOC 2 controls tested
  □ PCI-DSS requirements verified
  □ ISO 27001 compliance confirmed

Reviewed By: _________________ Date: _________
Approved By: _________________ Date: _________
```

---

## Appendix B: Security Metrics

**Key Security Metrics** (tracked monthly):

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Security incidents | 0 | 0 | ✅ |
| Vulnerability remediation (critical) | 100% within 30 days | 100% | ✅ |
| Failed login attempts | < 1% | 0.3% | ✅ |
| Certificates with weak crypto | 0 | 0 | ✅ |
| Audit log completeness | 100% | 100% | ✅ |
| Access review completion | 100% | 100% | ✅ |
| Backup success rate | 100% | 99.7% | ⚠️ |
| DR test pass rate | 100% | 100% | ✅ |

---

## Document Maintenance

**Review Schedule**: Quarterly or after security incidents  
**Owner**: CISO, PKI Architecture Team  
**Last Reviewed**: October 22, 2025  
**Next Review**: January 22, 2026

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial version |

---

**CLASSIFICATION**: INTERNAL USE - CONFIDENTIAL  
**Contains detailed security architecture and controls information**

**For security questions, contact**: security-team@contoso.com or adrian207@gmail.com

**End of Security Controls Document**

