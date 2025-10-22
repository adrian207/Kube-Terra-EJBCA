# Keyfactor Certificate Lifecycle Management
## Executive Design Document

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Status**: Design Phase  
**Classification**: Internal Use

---

## Document Control

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Author** | Adrian Johnson | | 2025-10-22 |
| **Technical Reviewer** | [PKI Architect] | | |
| **Security Reviewer** | [CISO/Delegate] | | |
| **Business Owner** | [VP Infrastructure] | | |
| **Approved By** | [Enterprise Architect] | | |

---

## Executive Summary

### Objective

Implement Keyfactor as the enterprise certificate lifecycle management platform to eliminate manual certificate operations through policy-driven automation, multi-layer RBAC authorization, and event-based renewals integrated with existing infrastructure.

### Business Problem

Current certificate management is characterized by:
- **Manual processes**: Certificate requests require 5+ approval emails and manual CSR generation
- **Outages**: 40% of production incidents in past year related to expired certificates
- **No visibility**: Unknown certificate inventory across cloud, on-prem, and Kubernetes
- **Compliance gaps**: Unable to demonstrate certificate ownership or revocation procedures
- **Security risks**: Weak keys (1024-bit RSA), certificates issued to departed employees

### Solution Overview

Deploy Keyfactor Command as centralized certificate lifecycle platform with:
- **Automated discovery** of all certificates across infrastructure
- **Policy-driven issuance** with identity-based RBAC and SAN validation
- **Zero-touch renewals** for 95%+ of certificates
- **Integration** with Azure Key Vault, HashiCorp Vault, Kubernetes, AD CS/EJBCA
- **Self-service enrollment** via ACME, EST, SCEP, auto-enrollment, cert-manager

### Expected Outcomes

| Metric | Current State | Target State | Timeline |
|--------|---------------|--------------|----------|
| Certificate-related outages | 12/year | <1/year | 6 months |
| Manual effort (hours/month) | 120 | <10 | 6 months |
| Auto-renewal rate | ~20% | ≥95% | 6 months |
| Time to issue (standard cert) | 2-5 days | <2 minutes | 3 months |
| Certificate visibility | ~60% | ≥98% | 3 months |
| Policy compliance | Unknown | 100% | 6 months |

### Investment

**[Inference]**: Costs vary based on deployment model and scale; consult Keyfactor for specific pricing.

| Component | Estimated Cost | Notes |
|-----------|----------------|-------|
| Keyfactor Command licenses | $XXX,XXX/year | SaaS or self-hosted |
| HSM/Managed HSM (if new CA) | $XX,XXX/year | For EJBCA deployment |
| Implementation services | $XXX,XXX | 6-month project |
| Training | $XX,XXX | Operations and admin teams |
| **Total Year 1** | **$XXX,XXX** | Includes licenses + implementation |
| **Annual recurring (Year 2+)** | **$XXX,XXX** | Licenses + support |

**ROI**: [Inference]: Estimated 18-month payback through reduced outages (estimated $XXX,XXX impact/incident) and operational efficiency (120 → 10 hours/month at $XXX/hour burdened cost).

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Current State Assessment](#2-current-state-assessment)
3. [Target Architecture](#3-target-architecture)
4. [Authorization and Security Model](#4-authorization-and-security-model)
5. [Policy Framework](#5-policy-framework)
6. [Enrollment Rails](#6-enrollment-rails)
7. [Automation and Integration](#7-automation-and-integration)
8. [Implementation Roadmap](#8-implementation-roadmap)
9. [Operational Model](#9-operational-model)
10. [Risk Analysis](#10-risk-analysis)
11. [Success Criteria and KPIs](#11-success-criteria-and-kpis)
12. [Governance](#12-governance)
13. [Appendices](#13-appendices)

---

## 1. Introduction

### 1.1 Purpose

This document defines the technical architecture and implementation strategy for enterprise certificate lifecycle management using Keyfactor Command. It serves as the authoritative reference for implementation teams, security reviewers, and operational stakeholders.

### 1.2 Scope

**In Scope**:
- All TLS/SSL certificates for web servers, APIs, load balancers (on-prem and cloud)
- Client authentication certificates for mTLS
- Kubernetes ingress and service mesh certificates
- Windows domain-joined server certificates
- Device certificates (VPN, network equipment)
- Code signing certificates (future phase)
- Document signing certificates (future phase)

**Out of Scope** (Initial Implementation):
- User email certificates (S/MIME) - evaluate in Phase 7
- Smart card certificates - existing system remains
- Third-party public certificates (Let's Encrypt for non-critical) - may integrate later

### 1.3 Audience

| Audience | Use of This Document |
|----------|---------------------|
| **Architecture Review Board** | Approve design and integration approach |
| **Security/Compliance Team** | Validate controls, RBAC, threat model |
| **Implementation Engineers** | Build and configure system components |
| **Operations Team** | Understand operational model and procedures |
| **Service Owners** | Understand how to request and manage certificates |
| **Management** | Understand investment, timeline, ROI |

### 1.4 References

- [02 - RBAC and Authorization Framework](./02-RBAC-Authorization-Framework.md)
- [03 - Policy Catalog](./03-Policy-Catalog.md)
- [04 - Architecture Diagrams](./04-Architecture-Diagrams.md)
- [05 - Implementation Runbooks](./05-Implementation-Runbooks.md)
- [11 - Security Controls](./11-Security-Controls.md)
- [13 - Threat Model](./13-Threat-Model.md)

---

## 2. Current State Assessment

### 2.1 Existing Certificate Infrastructure

**Certificate Authorities**:
- Active Directory Certificate Services (AD CS) - 2 issuing CAs
- Internal Root CA (offline, Windows Server 2016)
- Issuing Subordinate CAs (online, software keys - **RISK**)

**Current Issuance Methods**:
- **Windows servers**: GPO auto-enrollment (functional, ~30% of servers)
- **Web servers**: Manual CSR generation + email approval + manual installation
- **Kubernetes**: mix of self-signed, manual cert-manager config per cluster
- **Cloud**: mix of Azure-managed, Key Vault-stored, manually uploaded

**Certificate Inventory**:
- **Known certificates**: ~2,500 (estimated from AD CS database)
- **Unknown certificates**: Unknown quantity across cloud, network devices, file systems
- **Expired but still deployed**: ~150 certificates discovered in recent scan

**Secrets Management**:
- **Azure Key Vault**: Used by ~40% of Azure workloads
- **HashiCorp Vault**: Used by ~20% of workloads (primarily Kubernetes)
- **File systems**: ~30% of certificates stored on disk with weak ACLs
- **Configuration databases**: ~10% embedded in configs

### 2.2 Pain Points

| Problem | Impact | Frequency | Cost |
|---------|--------|-----------|------|
| **Expired certificates causing outages** | Production downtime | ~12x/year | High |
| **No visibility into certificate inventory** | Security/compliance risk | Continuous | High |
| **Manual issuance taking days** | Delays deployments | ~50x/month | Medium |
| **Weak keys (1024-bit RSA)** | Security vulnerability | ~200 certs | Medium |
| **Certificates for departed employees** | Unauthorized access risk | ~30 certs | High |
| **Inconsistent processes across teams** | Quality issues | Continuous | Medium |
| **No automated renewal** | Operational burden | ~200 renewals/month | High |
| **Approval bottlenecks** | Business delays | ~50x/month | Medium |

### 2.3 Compliance Gaps

- **SOC 2**: No demonstrable certificate inventory or access controls
- **PCI-DSS**: Certificate revocation procedures not documented or tested
- **ISO 27001**: Cryptographic key management controls insufficient
- **Internal Policy**: Minimum key size (2048-bit) not enforced

### 2.4 Root Cause Analysis

**Systemic Issues**:
1. **No centralized platform**: Certificate management distributed across teams
2. **No policy enforcement**: Manual processes can't enforce technical requirements
3. **No automation**: Renewals require "heroics" from operations
4. **No observability**: Unknown-unknowns in certificate inventory
5. **No ownership model**: Unclear who is responsible for each certificate

---

## 3. Target Architecture

### 3.1 Architecture Principles

1. **Centralized Control, Distributed Execution**: Keyfactor manages policy and orchestration; enrollment happens at endpoints
2. **Defense in Depth**: Multi-layer authorization (identity + domain + resource)
3. **Policy as Code**: All certificate policies defined in version-controlled templates
4. **Zero Trust**: Verify every issuance request; no implicit trust
5. **Event-Driven Automation**: Renewals trigger webhook chains, not polling
6. **Secrets Separation**: Private keys remain in secure stores; Keyfactor coordinates, doesn't store
7. **Observability First**: Full visibility before enforcement
8. **Gradual Adoption**: Phased rollout with opt-in then mandatory modes

### 3.2 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     ENROLLMENT PROTOCOLS                             │
│  ACME  │  EST  │  SCEP  │  Auto-Enrollment  │  cert-manager  │  API │
└────────┬────────────────────────────────────────────────────────┬───┘
         │                                                         │
         ▼                                                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│              KEYFACTOR COMMAND (Certificate Lifecycle Platform)      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   Discovery  │  │  Policy       │  │  Orchestration│             │
│  │   & Inventory│  │  Engine       │  │  & Webhooks   │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │  RBAC: Identity + SAN + Resource Authorization            │      │
│  └──────────────────────────────────────────────────────────┘      │
└────────┬──────────────────────────┬──────────────────────┬─────────┘
         │                          │                      │
         ▼                          ▼                      ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│  Certificate     │   │  Secrets Stores   │   │  Target          │
│  Authorities     │   │                   │   │  Endpoints       │
│                  │   │  ┌─────────────┐  │   │                  │
│  • AD CS         │   │  │ Azure       │  │   │  • IIS/Apache   │
│  • EJBCA (new)   │   │  │ Key Vault   │  │   │  • Kubernetes   │
│  • Public CAs    │   │  └─────────────┘  │   │  • Load Balancers│
│                  │   │  ┌─────────────┐  │   │  • Network Gear │
│                  │   │  │ HashiCorp   │  │   │  • Cloud Services│
│                  │   │  │ Vault       │  │   │                  │
│                  │   │  └─────────────┘  │   │                  │
└──────────────────┘   └──────────────────┘   └──────────────────┘
         │                          │                      │
         └──────────────────────────┴──────────────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────┐
                    │  Observability & Audit    │
                    │  • Dashboards             │
                    │  • Alerts                 │
                    │  • SIEM Integration       │
                    │  • ITSM (ServiceNow)      │
                    └───────────────────────────┘
```

### 3.3 Component Breakdown

#### 3.3.1 Certificate Authority Layer

**Decision Point**: Keep AD CS vs migrate to EJBCA

**Option A: Keep AD CS (Brownfield)**
- **Pros**: No migration, familiar to team, existing infrastructure
- **Cons**: Windows-dependent, software keys (no HSM), limited HA
- **Recommendation**: [Inference]: Start here if timeline is critical; plan EJBCA migration for Phase 7

**Option B: Introduce EJBCA (Greenfield)**
- **Pros**: HSM-backed, platform-independent, true HA, modern REST API
- **Cons**: New platform to learn, HSM procurement, migration complexity
- **Recommendation**: [Inference]: Choose if modernization is priority and HSM budget approved

**Hybrid Approach** (Recommended):
1. **Phase 1-3**: Integrate existing AD CS, begin issuing through Keyfactor
2. **Phase 4**: Deploy EJBCA cluster with HSM
3. **Phase 5-6**: Issue new certificates from EJBCA; renew AD CS certs to EJBCA
4. **Phase 7**: Decommission AD CS issuing CAs

**Certificate Hierarchy**:
```
Enterprise Root CA (Offline)
  validity: 20 years
  key: RSA 4096 (air-gapped)
  │
  ├─ Issuing Sub-CA 1 (AD CS - Legacy)
  │    validity: 10 years
  │    key: RSA 4096 (software - to be replaced)
  │    use: Windows domain certs during transition
  │
  ├─ Issuing Sub-CA 2 (EJBCA - Infrastructure)
  │    validity: 10 years
  │    key: RSA 4096 (HSM)
  │    use: TLS server, TLS client, device auth
  │
  └─ Issuing Sub-CA 3 (EJBCA - Code Signing)
       validity: 7 years
       key: RSA 4096 (HSM)
       use: Code signing, document signing
```

**CRL/OCSP Distribution**:
- **CRL**: Published to CDN, 24-hour validity, 6-hour refresh
- **OCSP**: 2+ responders per issuing CA (geo-redundant)
- **OCSP Stapling**: Enabled on all TLS endpoints
- **Monitoring**: CRL/OCSP response time <200ms p99

#### 3.3.2 Keyfactor Command

**Deployment Model Decision**:

| Consideration | SaaS | Self-Hosted |
|---------------|------|-------------|
| **Operational Burden** | Low (Keyfactor manages) | High (you manage) |
| **Control** | Limited (shared responsibility) | Full |
| **Network Isolation** | Requires outbound access | Full isolation possible |
| **Compliance** | SOC 2, ISO certified | Your responsibility |
| **Cost** | Higher subscription | Lower recurring, higher capital |
| **Updates** | Automatic | Manual |
| **Scaling** | Automatic | Manual |

**Recommendation**: [Inference]: SaaS for most enterprises unless data residency or network isolation requirements mandate self-hosted.

**Core Components**:

1. **Command Portal**: Web UI for administration, reporting, manual operations
2. **Policy Engine**: Evaluates authorization and template rules for every request
3. **Workflow Engine**: Manages approval chains (ServiceNow/Jira integration)
4. **Orchestrators**: Agents deployed to network zones for discovery and enrollment
5. **API Gateway**: REST API for integrations and self-service
6. **Webhook Publisher**: Fires events on issuance, renewal, expiration, revocation

**Orchestrator Deployment**:
```
Network Zone          | Orchestrator Count | Purpose
----------------------|-------------------|----------------------------------
On-Prem DataCenter    | 2 (HA pair)       | Discover IIS, Apache, F5
Azure Hub VNet        | 2 (HA pair)       | Discover VMs, Key Vault, App Gateway
AWS VPC               | 2 (HA pair)       | Discover EC2, ALB, Secrets Manager
Kubernetes Prod       | N/A               | cert-manager integration (no agent)
DMZ                   | 2 (HA pair)       | Discover edge load balancers
```

**High Availability**:
- **SaaS**: Multi-region by default
- **Self-Hosted**: 3-node cluster (2 active, 1 standby), shared SQL Always-On, load balancer

#### 3.3.3 Secrets Management Layer

**Strategy**: Keyfactor coordinates issuance; secrets stay in Vault/Key Vault

**Azure Key Vault**:
- **Use Case**: Azure-hosted apps, Windows servers, public TLS certs
- **Integration**: Keyfactor API → Key Vault REST API (managed identity auth)
- **Secret Versioning**: New cert = new secret version; apps poll or receive event
- **RBAC**: Service-specific Key Vaults with app identity permissions

**HashiCorp Vault**:
- **Use Case**: Kubernetes, on-prem services, multi-cloud
- **Integration**: 
  - Option 1: Keyfactor → Vault API (AppRole auth)
  - Option 2: Vault PKI engine → Keyfactor as upstream CA
- **Secret Rotation**: Vault triggers rotation; Keyfactor issues; Vault stores
- **Lease Management**: Short-lived certs (24h) for high-security workloads

**Integration Pattern**:
```
Certificate Renewal Trigger (T-30d)
  │
  ├─ Keyfactor generates new keypair (or accepts CSR)
  │
  ├─ Keyfactor requests issuance from CA
  │
  ├─ Keyfactor webhook fires: "certificate_renewed"
  │
  ├─ Automation pipeline (Logic App / Lambda / Argo Workflow):
  │    ├─ Fetch new cert + key from Keyfactor API
  │    ├─ Write to Key Vault / Vault:
  │    │    - Path: /secret/data/myapp/tls
  │    │    - New version created
  │    ├─ Notify app (webhook / event bus)
  │    └─ Log to ITSM
  │
  └─ Application:
       - Polls secret version or receives event
       - Reloads config (graceful restart)
       - Validates new cert
       - Logs success/failure
```

#### 3.3.4 Enrollment Rails (See Section 6)

#### 3.3.5 Observability and Integration

**SIEM Integration** (Azure Sentinel / Splunk):
- Certificate issuance/renewal/revocation events
- Authorization failures (denied requests)
- Policy violations
- Orchestrator health
- CA availability

**ITSM Integration** (ServiceNow):
- Create change records for production cert deployments
- Approval workflows for high-risk templates
- Incident creation on renewal failures
- CMDB updates with certificate ownership

**Monitoring** (Grafana / Azure Monitor):
- Dashboard: Certificate expiration timeline (30/60/90 day buckets)
- Dashboard: Renewal success rate (daily)
- Dashboard: Unmanaged certificate count
- Alert: Certificate expiring <7 days
- Alert: Renewal failed 3+ times
- Alert: CRL/OCSP responder down

---

## 4. Authorization and Security Model

### 4.1 Multi-Layer Authorization

Every certificate request passes through **four authorization layers**:

#### Layer 1: Identity-Based RBAC (WHO can request)
- User/service authenticated via AD, Entra ID, Kubernetes SA, API key
- Mapped to role (e.g., "Web-App-Developer", "Infrastructure-Admin")
- Role grants access to specific templates

#### Layer 2: SAN Validation (WHAT domains/resources)
- Requested SANs validated against role's allowed patterns
- DNS validation for public domains (proof of control)
- Deny if SAN outside authorized scope

#### Layer 3: Resource Binding (WHERE can it be used)
- Certificate tied to specific target (server, K8s namespace, Key Vault)
- Requester must be owner or authorized operator for that resource
- Validated against **asset inventory** (CSV, database, cloud, or CMDB - see [ASSET-INVENTORY-INTEGRATION-GUIDE.md](./ASSET-INVENTORY-INTEGRATION-GUIDE.md))

#### Layer 4: Template Policy (HOW it's issued)
- Technical constraints: key type/size, EKU, lifetime
- Approval requirements if high-risk (wildcard, extended validity)
- Delivery method and secret storage

**Example Authorization Flow**:
```
Request: User "jane.doe@contoso.com" requests cert for "myapp.dev.contoso.com"
  │
  ├─ Layer 1: Identity RBAC
  │    ├─ User authenticated via Entra ID ✓
  │    ├─ User in group "APP-WebDevs" ✓
  │    └─ Group authorized for template "TLS-Server-Internal" ✓
  │
  ├─ Layer 2: SAN Validation
  │    ├─ Requested SAN: "myapp.dev.contoso.com"
  │    ├─ Allowed patterns: ["*.dev.contoso.com", "*.test.contoso.com"]
  │    ├─ Pattern match: ✓
  │    └─ DNS validation: resolves to 10.1.5.23 ✓
  │
  ├─ Layer 3: Resource Binding
  │    ├─ Target server: "vm-myapp-dev-01"
  │    ├─ Server owner in asset inventory: "team-web-apps"
  │    ├─ User "jane.doe" member of "team-web-apps" ✓
  │    └─ Delivery target: KeyVault "kv-myapp-dev" (user has access) ✓
  │
  └─ Layer 4: Template Policy
       ├─ Key: RSA 3072 ✓
       ├─ Lifetime: 730 days ✓
       ├─ EKU: serverAuth ✓
       ├─ Approval: auto-approved for dev environment ✓
       └─ Result: APPROVED → Issue certificate
```

**Detailed RBAC model**: See [02 - RBAC and Authorization Framework](./02-RBAC-Authorization-Framework.md)

### 4.2 Separation of Duties

| Role | Permissions | Restrictions |
|------|-------------|-------------|
| **PKI Administrator** | Manage CA, issue emergency certs, revoke | Cannot modify audit logs; requires peer approval for root key access |
| **Keyfactor Operator** | Configure templates, orchestrators, integrations | Cannot issue certs directly; cannot access CA private keys |
| **Security Auditor** | Read-only access to all policies, logs, inventory | Cannot modify anything |
| **Service Owner** | Request certs for owned services, view inventory | Cannot request for other teams; cannot revoke others' certs |
| **Developer** | Self-service issuance via ACME/API | Limited to dev/test templates; rate-limited |

**Audit Requirements**:
- All actions logged with user identity, timestamp, before/after state
- Privileged actions (revocation, policy changes) require MFA
- Quarterly access review for admin roles
- Logs retained 7 years, immutable

### 4.3 HSM and Key Protection

**Issuing CA Private Keys**:
- **Storage**: FIPS 140-2 Level 3 HSM (network HSM) or Azure Managed HSM
- **Access**: Quorum-based (3 of 5 key custodians)
- **Backup**: Key shares stored in bank safe deposit boxes (geo-separated)
- **Rotation**: Every 5 years or on compromise

**Certificate Private Keys**:
- **Preferred**: Generated on endpoint or in user's Key Vault/Vault instance
- **Keyfactor Role**: Accepts CSR; never sees private key
- **Exception**: Central key generation only for legacy devices that can't generate keys
- **Protection**: Keys never leave HSM/Key Vault/Vault; API-based signing only

**Key Ceremony** (for new Root CA):
- Witnessed by 2+ auditors
- Video recorded and stored
- All USB drives/media destroyed after key transfer to HSM
- Documented in [11 - Security Controls](./11-Security-Controls.md)

### 4.4 CRL and OCSP Resilience

**CRL Distribution**:
- **Primary CDP**: `http://crl.contoso.com/<ca-name>.crl` (CDN-backed)
- **Secondary CDP**: `http://crl2.contoso.com/<ca-name>.crl` (different provider)
- **Validity**: 24 hours
- **Publishing**: Every 6 hours + on-demand for revocations
- **Monitoring**: Alert if CRL not updated within 7 hours

**OCSP Responders**:
- **Topology**: 2 responders per issuing CA (East + West datacenters or Azure regions)
- **Response Caching**: 1 hour for "good", 10 minutes for "revoked"
- **Signing**: Dedicated OCSP signing cert (delegated trust)
- **Monitoring**: Synthetic checks every 5 minutes from multiple locations

**OCSP Stapling**:
- Enabled on all internet-facing TLS endpoints
- Reduces client latency and OCSP responder load

---

## 5. Policy Framework

### 5.1 Template Structure

Every certificate template enforces:
- **Authorization rules** (identity RBAC + SAN validation)
- **Technical policy** (key type, size, EKU, lifetime)
- **Approval workflow** (auto vs manual)
- **Delivery method** (target endpoint + secrets store)
- **Renewal behavior** (window, notification)

### 5.2 Standard Templates

**Full catalog**: See [03 - Policy Catalog](./03-Policy-Catalog.md)

**Summary**:

| Template Name | Use Case | Authorized Roles | Key | Lifetime | Auto-Approve |
|---------------|----------|------------------|-----|----------|--------------|
| **TLS-Server-Internal** | Internal web/API | Infra Admins, Web Devs | RSA 3072 / ECDSA P-256 | 730d | Yes |
| **TLS-Server-Public** | Internet-facing web | Infra Admins only | RSA 3072 / ECDSA P-256 | 398d | Yes (non-wildcard) |
| **TLS-Server-Wildcard** | Wildcard domains | Infra Admins | ECDSA P-256 | 398d | Requires CISO approval |
| **TLS-Client-mTLS** | Service-to-service auth | App teams | RSA 3072 / ECDSA P-256 | 365d | Yes |
| **K8s-Ingress-TLS** | Kubernetes ingress | K8s SA only | ECDSA P-256 | 90d | Yes |
| **K8s-ServiceMesh-mTLS** | Istio/Linkerd | K8s SA only | ECDSA P-256 | 24h | Yes |
| **Device-Auth-EST** | Servers, IoT | Device provisioners | RSA 3072 | 365d | If device in CMDB |
| **Device-Auth-SCEP** | Intune-managed devices | Intune profile | RSA 2048 | 365d | Yes |
| **Code-Signing-Standard** | Sign binaries | Designated devs | RSA 3072 (HSM) | 365d | Manager approval |
| **Windows-Domain-Computer** | Domain servers | GPO auto-enroll | RSA 3072 | 730d | Yes |

### 5.3 Policy Enforcement

**Deny Scenarios** (Hard Blocks):
- SAN not in authorized domain list
- Key size below minimum (RSA <3072, ECDSA <256)
- Lifetime exceeds policy (public >398d, internal >730d)
- Requester not in authorized group
- Target resource not owned by requester

**Warning Scenarios** (Soft Blocks, Logged):
- SAN uses wildcard (requires approval)
- Lifetime >365 days (requires justification)
- RSA instead of ECDSA (performance recommendation)

**Drift Detection**:
- Daily scan: certificates issued outside Keyfactor
- Automatic tagging as "unmanaged" + alert security team
- After 30 days: automatic revocation (with 3x notification)

---

## 6. Enrollment Rails

Each enrollment rail supports specific use cases and workload types.

### 6.1 Windows Auto-Enrollment (GPO)

**Use Case**: Windows domain-joined servers and clients

**Architecture**:
```
GPO: "Certificate Auto-Enrollment"
  │
  ├─ Computer Configuration → Windows Settings → Security Settings
  │    → Public Key Policies → Certificate Services Client
  │
  ├─ Setting: "Enabled"
  ├─ Options: "Renew expired certs", "Update pending certs", "Remove revoked certs"
  │
  └─ Certificate Template: "Windows-Domain-Computer"
       ├─ Issued by: AD CS (during transition) or EJBCA
       ├─ Enrollment: Auto-granted to "Domain Computers"
       ├─ Key: RSA 3072, exportable=false
       ├─ EKU: Server Auth, Client Auth
       ├─ SAN: DNS name = computer FQDN
       └─ Lifetime: 730 days, renew at 25% remaining
```

**Keyfactor Integration**:
- Keyfactor orchestrator monitors AD CS for issued certs → imports to inventory
- OR: EJBCA issues via Keyfactor RA → direct tracking

**Renewal Process**:
1. Client auto-renews at 182 days remaining (25% of 730d)
2. New cert issued, old cert replaced in LocalMachine\My store
3. IIS/services auto-bind if configured
4. Keyfactor webhook fires → update CMDB + log to ServiceNow

**Configuration Details**: See [07 - Enrollment Rails Guide](./07-Enrollment-Rails-Guide.md) § Windows Auto-Enrollment

### 6.2 Kubernetes cert-manager

**Use Case**: Kubernetes ingress, service mesh, pod-to-pod mTLS

**Architecture**:
```
cert-manager (K8s operator)
  │
  ├─ ClusterIssuer: "keyfactor-issuer"
  │    ├─ Type: keyfactor-ca-issuer (via plugin)
  │    ├─ Auth: ServiceAccount token → Keyfactor API
  │    └─ Template: "K8s-Ingress-TLS" or "K8s-ServiceMesh-mTLS"
  │
  ├─ Certificate CRD:
  │    apiVersion: cert-manager.io/v1
  │    kind: Certificate
  │    metadata:
  │      name: myapp-tls
  │      namespace: production
  │    spec:
  │      secretName: myapp-tls-secret
  │      issuerRef:
  │        name: keyfactor-issuer
  │        kind: ClusterIssuer
  │      dnsNames:
  │        - myapp.prod.contoso.com
  │      duration: 2160h  # 90 days
  │      renewBefore: 720h  # 30 days
  │
  └─ Secret (auto-created):
       apiVersion: v1
       kind: Secret
       type: kubernetes.io/tls
       data:
         tls.crt: <base64 cert>
         tls.key: <base64 key>
```

**Authorization**:
- ServiceAccount `cert-manager` authenticated to Keyfactor via API key
- Keyfactor validates:
  - ServiceAccount has label `cert-issuer-role: k8s-platform`
  - Requested SAN matches allowed patterns (*.svc.cluster.local, *.contoso.com)
  - Target namespace ownership (CMDB metadata)

**Renewal Process**:
1. cert-manager renews 30 days before expiry
2. Generates new private key (or reuses if keyAlgorithm: ECDSA and renewBefore<50%)
3. Submits CSR to Keyfactor via ClusterIssuer
4. Keyfactor issues cert
5. cert-manager updates Secret (atomic replace)
6. Ingress controller detects Secret change → reloads TLS config (no downtime)

**Integration with Service Mesh** (Istio/Linkerd):
- Service mesh CA: Keyfactor (via cert-manager CA Injector or direct API)
- Short-lived certs (24h) for pod identity
- Automatic rotation via sidecar

**Configuration Details**: See [07 - Enrollment Rails Guide](./07-Enrollment-Rails-Guide.md) § Kubernetes cert-manager

### 6.3 ACME (Automated Certificate Management Environment)

**Use Case**: Web servers (IIS/Apache/Nginx), edge load balancers, developer self-service

**Architecture**:
```
ACME Client (certbot, acme.sh, win-acme, Caddy built-in)
  │
  ├─ ACME Directory: https://keyfactor.contoso.com/acme/<zone>
  │    ├─ /acme/public  → issues from Let's Encrypt (proxy)
  │    ├─ /acme/internal → issues from internal CA via Keyfactor
  │    └─ /acme/dev → dev/test zone with permissive policies
  │
  ├─ Authentication: API key or OAuth2 token (Entra ID)
  │
  ├─ Authorization: User's AD group → allowed DNS zones
  │
  ├─ Challenge Types:
  │    ├─ HTTP-01: Client proves control by hosting file at /.well-known/acme-challenge/
  │    └─ DNS-01: Client proves control by creating TXT record _acme-challenge.<domain>
  │
  └─ Issuance:
       - ACME client requests cert for myapp.contoso.com
       - Keyfactor validates challenge
       - Issues cert from configured template
       - Returns cert to client
       - Client installs and reloads web server
```

**Authorization per Zone**:

| ACME Directory | Allowed Users | Allowed Domains | Challenge | Template | Approval |
|----------------|---------------|-----------------|-----------|----------|----------|
| **/acme/public** | Infra Admins | Public domains owned by company | DNS-01 | TLS-Server-Public | Auto |
| **/acme/internal** | Infra Admins, App Teams | *.contoso.com, *.internal.contoso.com | HTTP-01 or DNS-01 | TLS-Server-Internal | Auto |
| **/acme/dev** | All developers | *.dev.contoso.com, *.test.contoso.com | HTTP-01 | TLS-Server-Internal | Auto |

**DNS-01 Integration**:
- Azure DNS: API integration via managed identity
- Route53: API integration via IAM role
- BIND: RFC 2136 dynamic updates (nsupdate)

**Example Usage**:
```bash
# Developer requests cert for dev app
certbot certonly \
  --server https://keyfactor.contoso.com/acme/dev \
  --email developer@contoso.com \
  --agree-tos \
  --dns-azure \
  --domain myapp.dev.contoso.com

# Cert issued and saved to /etc/letsencrypt/live/myapp.dev.contoso.com/
# Automated renewal via cron: certbot renew --deploy-hook "systemctl reload nginx"
```

**Configuration Details**: See [07 - Enrollment Rails Guide](./07-Enrollment-Rails-Guide.md) § ACME

### 6.4 EST (Enrollment over Secure Transport)

**Use Case**: Services that support RFC 7030 (EST), IoT devices, servers with built-in EST clients

**Architecture**:
```
EST Client (built into device/service)
  │
  ├─ EST Server: https://keyfactor.contoso.com/.well-known/est/<profile>
  │
  ├─ Bootstrap: Client authenticates with shared secret or existing cert
  │
  ├─ /simpleenroll: Client submits CSR → receives cert
  │
  ├─ /simplereenroll: Client renews existing cert (mTLS auth with current cert)
  │
  └─ /csrattrs: Client retrieves CSR requirements (key type, EKU)
```

**Authorization**:
- **Bootstrap**: Shared secret or hardware TPM attestation
- **Renewal**: mTLS with existing cert (validates cert serial is in Keyfactor inventory)
- **Policy**: Keyfactor template "Device-Auth-EST"

**Use Cases**:
- Linux servers with systemd-cryptenroll
- Network devices (routers, switches) with EST support
- IoT gateways

**Configuration Details**: See [07 - Enrollment Rails Guide](./07-Enrollment-Rails-Guide.md) § EST

### 6.5 SCEP (Simple Certificate Enrollment Protocol)

**Use Case**: Intune-managed devices (Windows, iOS, Android), network equipment (Cisco ISE)

**Architecture**:
```
SCEP Client (Intune, Cisco ISE)
  │
  ├─ SCEP Server: Keyfactor SCEP endpoint or NDES (AD CS)
  │
  ├─ Challenge: One-time password or shared secret
  │
  ├─ Enrollment: Client generates keypair → submits CSR → receives cert
  │
  └─ Renewal: Silent renewal via SCEP (if supported by client)
```

**Integration with Intune**:
1. Create SCEP profile in Intune
   - SCEP URL: `https://keyfactor.contoso.com/scep/<profile>`
   - Subject: `CN={{DeviceId}}`
   - SAN: `URI={{AADDeviceId}}`
   - Key size: RSA 2048
   - Validity: 365 days
2. Assign profile to device groups
3. Devices auto-enroll on next check-in

**Authorization**:
- Challenge validated against Intune device registry
- Device must be compliant (patched, no jailbreak, etc.)
- Keyfactor template: "Device-Auth-SCEP"

**Configuration Details**: See [07 - Enrollment Rails Guide](./07-Enrollment-Rails-Guide.md) § SCEP

### 6.6 Direct API / SDK

**Use Case**: Custom applications, CI/CD pipelines, service provisioning automation

**Architecture**:
```python
# Example: Python SDK
from keyfactor import KeyfactorClient

client = KeyfactorClient(
    hostname="keyfactor.contoso.com",
    auth="bearer",
    token=azure_identity.get_token()  # Entra ID token
)

# Request certificate
cert = client.enroll(
    template="TLS-Server-Internal",
    subject="CN=myapp.contoso.com",
    sans=["myapp.contoso.com", "myapp-api.contoso.com"],
    csr=my_csr,  # or generate=True for central key gen
    metadata={
        "owner": "team-platform",
        "costcenter": "12345",
        "environment": "production"
    }
)

# Store in Key Vault
keyvault_client.set_secret(
    "myapp-tls-cert",
    value=cert.pfx_base64,
    content_type="application/x-pkcs12"
)
```

**Authorization**:
- API authenticated via OAuth2 (Entra ID) or API key
- Mapped to role based on token claims
- Standard RBAC + SAN validation applies

**Rate Limiting**:
- 100 requests/hour per user/service principal
- 1000 requests/hour per tenant (burst)

**Configuration Details**: See [14 - Integration Specifications](./14-Integration-Specifications.md) § API

---

## 7. Automation and Integration

### 7.1 Event-Driven Renewal Automation

**Core Pattern**: Webhook → Automation Pipeline → Update Endpoint → Verify

**Example: IIS Web Server**

```
Trigger: Keyfactor fires "certificate_renewed" webhook
  │
  ├─ Webhook payload:
  │    {
  │      "event": "certificate_renewed",
  │      "certificateId": "12345",
  │      "thumbprint": "ABC123...",
  │      "subject": "CN=webapp.contoso.com",
  │      "sans": ["webapp.contoso.com", "www.webapp.contoso.com"],
  │      "notBefore": "2025-10-22T00:00:00Z",
  │      "notAfter": "2027-10-22T23:59:59Z",
  │      "metadata": {
  │        "server": "iis-web-01",
  │        "owner": "team-web"
  │      }
  │    }
  │
  ├─ Azure Logic App receives webhook:
  │    ├─ Parse JSON
  │    ├─ Call Keyfactor API to download PFX (with temp password)
  │    ├─ Write to Key Vault (versioned secret)
  │    ├─ Remote PowerShell to IIS server:
  │    │    $pfx = Get-AzKeyVaultSecret -VaultName "kv-prod" -Name "webapp-tls"
  │    │    Import-PfxCertificate -FilePath $pfx -CertStoreLocation Cert:\LocalMachine\My
  │    │    $thumbprint = (Get-PfxCertificate -FilePath $pfx).Thumbprint
  │    │    Set-WebBinding -Name "Default Web Site" -BindingInformation "*:443:" `
  │    │        -PropertyName "CertificateHash" -Value $thumbprint
  │    │    iisreset /noforce
  │    │
  │    ├─ Verify: HTTP GET https://webapp.contoso.com → check cert thumbprint
  │    │
  │    ├─ On success:
  │    │    - Post change record to ServiceNow
  │    │    - Log to Application Insights
  │    │
  │    └─ On failure:
  │         - Rollback to previous thumbprint
  │         - Create incident in ServiceNow
  │         - Alert on-call engineer
```

**Example: Kubernetes Ingress** (Simpler - cert-manager handles)

```
cert-manager renews certificate (30 days before expiry)
  │
  ├─ Generates new keypair
  ├─ Submits CSR to Keyfactor via ClusterIssuer
  ├─ Receives signed cert
  ├─ Updates Secret "myapp-tls-secret" (atomic replace)
  │
  └─ Ingress controller (nginx/traefik) watches Secret
       - Detects change
       - Reloads TLS config (no connection drop)
       - Logs to stdout (scraped by Loki)
```

**Webhook Handlers**: See [06 - Automation Playbooks](./06-Automation-Playbooks.md)

### 7.2 Integration with Secrets Platforms

**Azure Key Vault**:
- Keyfactor → Key Vault API (via managed identity or service principal)
- Certificate imported as versioned secret
- Apps poll latest version or subscribe to Event Grid notifications
- Example: [14 - Integration Specifications](./14-Integration-Specifications.md) § Azure Key Vault

**HashiCorp Vault**:
- **Option 1**: Keyfactor → Vault API (write to PKI secrets engine)
- **Option 2**: Vault PKI engine configured with Keyfactor as upstream CA (Vault acts as RA)
- Apps retrieve certs via Vault API with short-lived leases
- Example: [14 - Integration Specifications](./14-Integration-Specifications.md) § HashiCorp Vault

### 7.3 CI/CD Integration

**Block Unmanaged Certificates**:

```yaml
# Azure DevOps pipeline step
- task: PowerShell@2
  displayName: 'Validate Certificate is Managed'
  inputs:
    targetType: 'inline'
    script: |
      $cert = Get-Content './config/app-cert.pem' | Out-String
      $response = Invoke-RestMethod -Uri "https://keyfactor.contoso.com/api/v1/certificates/validate" `
          -Method POST -Body (@{certificate=$cert} | ConvertTo-Json) `
          -Headers @{Authorization="Bearer $env:KEYFACTOR_TOKEN"}
      
      if ($response.isManaged -eq $false) {
          Write-Error "Certificate is not managed by Keyfactor. Deployment blocked."
          exit 1
      }
      Write-Host "Certificate is managed. Issuer: $($response.issuer), Expires: $($response.notAfter)"
```

**Auto-Request Certificate in Pipeline**:

```yaml
# GitHub Actions workflow
- name: Request TLS Certificate
  uses: keyfactor/keyfactor-actions/enroll@v1
  with:
    keyfactor-hostname: keyfactor.contoso.com
    auth-token: ${{ secrets.KEYFACTOR_TOKEN }}
    template: TLS-Server-Internal
    common-name: ${{ env.APP_FQDN }}
    sans: ${{ env.APP_FQDN }},${{ env.APP_FQDN_ALT }}
    output-path: ./certs/app.pfx
    keyvault-upload: true
    keyvault-name: kv-${{ env.ENVIRONMENT }}
    keyvault-secret-name: ${{ env.APP_NAME }}-tls
```

---

## 8. Implementation Roadmap

### 8.1 Phased Approach

**Philosophy**: Crawl → Walk → Run → Fly
- **Crawl**: Deploy, discover, observe (no enforcement)
- **Walk**: Automate one rail end-to-end with pilot group
- **Run**: Scale to all services, enable policy enforcement
- **Fly**: Continuous optimization, advanced use cases (short-lived certs, SPIFFE)

### 8.2 Timeline Overview

```
Phase 0: Readiness             [Weeks 1-2]        ████
Phase 1: Discovery             [Weeks 3-5]        ████
Phase 2: CA & HSM              [Weeks 6-9]        ████
Phase 3: Enrollment Rails      [Weeks 10-13]      ████
Phase 4: Automation            [Weeks 14-16]      ████
Phase 5: Pilot & Scale         [Weeks 17-21]      ████
Phase 6: Operate & Optimize    [Ongoing]          ████████████...
                                                   
Total Implementation:           24 weeks (6 months)
```

### 8.3 Phase 0: Readiness & Decisions (Weeks 1-2)

**Objectives**:
- Finalize architecture decisions
- Procure licenses and HSM
- Form implementation team
- Define success criteria

**Key Decisions**:

| Decision | Options | Recommendation | Owner |
|----------|---------|----------------|-------|
| **Keyfactor Deployment** | SaaS vs Self-Hosted | [TBD] | Architect |
| **CA Strategy** | Keep AD CS vs EJBCA | Hybrid: AD CS now, EJBCA Phase 7 | PKI Lead |
| **HSM** | Network HSM vs Azure Managed HSM | Azure Managed HSM (lower OpEx) | Security |
| **Secrets Platform** | Key Vault only, Vault only, or both | Both (Key Vault for Azure, Vault for K8s) | Architect |
| **First Enrollment Rail** | Windows, K8s, or ACME | Kubernetes (fastest value) | Architect |

**Deliverables**:
- [ ] Architecture Decision Records (ADRs) - see [17 - Architecture Decision Records](./17-Architecture-Decision-Records.md)
- [ ] Procurement orders submitted (Keyfactor licenses, HSM)
- [ ] Project charter and team RACI
- [ ] Success metrics and KPIs defined
- [ ] Threat model reviewed and approved - [13 - Threat Model](./13-Threat-Model.md)

**Exit Criteria**:
- All decisions documented and approved by architecture board
- Budget approved and purchase orders issued
- Team assigned and trained (initial Keyfactor admin course)

### 8.4 Phase 1: Discovery & Baseline (Weeks 3-5)

**Objectives**:
- Deploy Keyfactor Command and orchestrators
- Discover all certificates across infrastructure
- Build ownership map
- Generate risk report

**Tasks**:

**Week 3: Deploy Keyfactor**
- [ ] Deploy Keyfactor Command (SaaS: activate tenant; Self-Hosted: install 3-node cluster)
- [ ] Configure authentication (Entra ID SSO)
- [ ] Create initial admin users and roles
- [ ] Deploy orchestrators to each network zone (see § 3.3.2)
  - [ ] On-prem datacenter (2x)
  - [ ] Azure Hub VNet (2x)
  - [ ] AWS VPC (2x)
  - [ ] DMZ (2x)

**Week 4: Discovery Scans**
- [ ] Configure discovery jobs:
  - [ ] IP ranges for on-prem network (scan ports 443, 8443, 3389)
  - [ ] Azure subscriptions (Key Vault, App Gateway, VMs, App Services)
  - [ ] AWS accounts (ELB, ALB, EC2, Secrets Manager)
  - [ ] Kubernetes clusters (scan all namespaces for TLS secrets)
  - [ ] File system paths (common cert storage locations)
- [ ] Run discovery scans (expected: 2-3 days for initial scan)
- [ ] Triage discovery results:
  - [ ] Remove duplicates
  - [ ] Exclude CA/intermediate certs (not managed endpoints)
  - [ ] Categorize by certificate type (TLS server, client, device, etc.)

**Week 5: Ownership Mapping & Risk Report**
- [ ] Export certificate inventory to CSV
- [ ] Match to CMDB:
  - [ ] Server hostname → asset owner
  - [ ] DNS name → service owner
  - [ ] Cloud resource tag → cost center
- [ ] Manual mapping for unmapped certs (send to IT teams for claims)
- [ ] Generate risk report:
  - [ ] Expired certificates (immediate action)
  - [ ] Expiring <30 days (urgent)
  - [ ] Expiring 30-90 days (plan renewal)
  - [ ] Weak keys (<2048-bit RSA)
  - [ ] Unknown issuers (potential rogue CAs)
  - [ ] Unowned certificates (security risk)
  - [ ] Wildcard certificates (review necessity)
- [ ] Present risk report to leadership
- [ ] Prioritize remediation (expired → weak keys → unowned)

**Deliverables**:
- [ ] Keyfactor Command operational with ≥90% certificate discovery
- [ ] Certificate inventory with ownership metadata (≥90% mapped)
- [ ] Risk report with prioritized remediation plan
- [ ] Dashboards: expiration timeline, unmanaged certs, weak keys

**Exit Criteria**:
- Certificate inventory ≥90% complete
- Leadership approval to proceed to Phase 2

**Runbook**: See [05 - Implementation Runbooks](./05-Implementation-Runbooks.md) § Phase 1

### 8.5 Phase 2: CA & HSM Foundation (Weeks 6-9)

**Objectives**:
- Integrate existing AD CS or deploy new EJBCA
- Integrate HSM for issuing CA keys
- Configure CRL/OCSP distribution
- Normalize certificate templates in Keyfactor

**Path A: Integrate Existing AD CS** (Weeks 6-7)

- [ ] Install Keyfactor CA Gateway on AD CS server
- [ ] Configure RA/CA accounts and permissions
- [ ] Map AD CS templates to Keyfactor templates
- [ ] Test issuance workflow: Keyfactor → AD CS → certificate
- [ ] Validate revocation: CRL published, OCSP responding

**Path B: Deploy New EJBCA** (Weeks 6-9, parallel with some tasks)

**Week 6: HSM Integration**
- [ ] Provision Azure Managed HSM or network HSM
- [ ] Initialize HSM (key ceremony if required)
- [ ] Generate or import issuing CA keypair in HSM
- [ ] Configure HSM access policies (EJBCA service principal)

**Week 7: EJBCA Cluster**
- [ ] Deploy EJBCA on 3 VMs/containers (active-active-active)
- [ ] Configure shared database (SQL Always-On or PostgreSQL HA)
- [ ] Integrate HSM via PKCS#11 or Azure Key Vault HSM provider
- [ ] Import or generate certificate hierarchy:
  - [ ] Root CA cert (if offline root, import public cert)
  - [ ] Issuing subordinate CA (generate keypair in HSM, get CSR signed by root)
- [ ] Configure AIA and CRL distribution points
  - [ ] AIA: http://aia.contoso.com/<ca-name>.crt (CDN-backed)
  - [ ] CRL: http://crl.contoso.com/<ca-name>.crl (CDN-backed)

**Week 8: OCSP Responders**
- [ ] Deploy OCSP responders (2+ instances, geo-redundant)
- [ ] Generate OCSP signing certificates (delegated from issuing CA)
- [ ] Configure OCSP URLs in issuing CA cert:
  - [ ] Primary: http://ocsp.contoso.com
  - [ ] Secondary: http://ocsp2.contoso.com
- [ ] Test OCSP response:
  ```bash
  openssl ocsp -issuer issuing-ca.crt -cert test-cert.crt \
      -url http://ocsp.contoso.com -resp_text
  ```

**Week 9: Keyfactor Integration**
- [ ] Integrate Keyfactor Command with EJBCA via REST API
- [ ] Configure certificate profiles in EJBCA (map to Keyfactor templates)
- [ ] Test issuance: Keyfactor → EJBCA → certificate
- [ ] Validate revocation: revoke via Keyfactor → CRL updated, OCSP responds "revoked"

**All Paths: Template Normalization**
- [ ] Define standard templates (see [03 - Policy Catalog](./03-Policy-Catalog.md))
- [ ] Configure in Keyfactor:
  - [ ] Template name, description, linked CA
  - [ ] RBAC rules (authorized groups/roles)
  - [ ] SAN validation patterns
  - [ ] Technical policy (key type, size, EKU, lifetime)
  - [ ] Approval workflow (if required)
- [ ] Test each template with sample issuance request

**Deliverables**:
- [ ] CA (AD CS or EJBCA) integrated and issuing via Keyfactor
- [ ] HSM protecting issuing CA private keys (if EJBCA)
- [ ] CRL/OCSP operational and monitored
- [ ] 5-10 certificate templates defined and tested

**Exit Criteria**:
- End-to-end issuance working: request → Keyfactor → CA → certificate → delivery
- Revocation working: revoke → CRL/OCSP updated within SLA (<1 hour)

**Runbook**: See [05 - Implementation Runbooks](./05-Implementation-Runbooks.md) § Phase 2

### 8.6 Phase 3: Enrollment Rails (Weeks 10-13)

**Objective**: Deploy and validate one enrollment rail per week with pilot workloads

**Week 10: Kubernetes cert-manager**

- [ ] Install cert-manager in pilot cluster:
  ```bash
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
  ```
- [ ] Install Keyfactor Issuer plugin (or configure external issuer)
- [ ] Create ClusterIssuer:
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: keyfactor-issuer
  spec:
    keyfactor:
      server: https://keyfactor.contoso.com
      caName: EJBCA-Issuing-CA
      template: K8s-Ingress-TLS
      secretRef:
        name: keyfactor-api-token
        key: token
  ```
- [ ] Deploy test application with Certificate resource:
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: Certificate
  metadata:
    name: test-app-tls
    namespace: test
  spec:
    secretName: test-app-tls-secret
    issuerRef:
      name: keyfactor-issuer
      kind: ClusterIssuer
    dnsNames:
      - test-app.dev.contoso.com
    duration: 2160h  # 90 days
    renewBefore: 720h  # 30 days
  ```
- [ ] Verify:
  - [ ] Certificate issued and stored in secret
  - [ ] Ingress serving TLS with correct cert
  - [ ] Renewal works (temporarily reduce `duration` to 1h, wait for renewal)
- [ ] Scale to 5 more apps in pilot cluster

**Week 11: Windows Auto-Enrollment**

- [ ] Create GPO: "Certificate Auto-Enrollment - Servers"
- [ ] Configure: Computer Config → Policies → Windows Settings → Security Settings → Public Key Policies → Certificate Services Client - Auto-Enrollment
  - [ ] Configuration Model: Enabled
  - [ ] Renew expired certs: Yes
  - [ ] Update pending certs: Yes
  - [ ] Remove revoked certs: Yes
- [ ] Publish certificate template "Windows-Domain-Computer" (AD CS) or equivalent in EJBCA
- [ ] Apply GPO to pilot OU (10-20 servers)
- [ ] Force GPO update: `gpupdate /force` on pilot servers
- [ ] Verify:
  - [ ] Certificates issued and installed in LocalMachine\My
  - [ ] IIS bindings updated (if applicable)
  - [ ] Keyfactor inventory updated with new certs
- [ ] Deploy Keyfactor orchestrator to automate IIS binding updates on renewal
- [ ] Test renewal: Set short lifetime (7 days), wait for auto-renewal

**Week 12: ACME (Internal)**

- [ ] Configure Keyfactor ACME directory:
  - [ ] URL: https://keyfactor.contoso.com/acme/internal
  - [ ] Template: TLS-Server-Internal
  - [ ] Auth: API key or OAuth2 (Entra ID)
  - [ ] Allowed users: INFRA-ServerAdmins, APP-WebDevs
  - [ ] Allowed domains: *.contoso.com, *.internal.contoso.com
  - [ ] Challenge: HTTP-01 and DNS-01
- [ ] Integrate DNS-01 with Azure DNS (for wildcard support)
- [ ] Deploy win-acme on pilot IIS server:
  ```powershell
  wacs.exe --target manual --host webapp01.internal.contoso.com `
      --certificatestore My --acmeurl https://keyfactor.contoso.com/acme/internal `
      --emailaddress admin@contoso.com
  ```
- [ ] Configure automatic renewal (Scheduled Task)
- [ ] Verify:
  - [ ] Certificate issued via ACME
  - [ ] IIS binding updated
  - [ ] Renewal works (task runs, cert renewed)
- [ ] Deploy to 5 more pilot servers (mix of IIS, Apache, Nginx)

**Week 13: SCEP for Intune Devices (Optional, if in scope)**

- [ ] Configure Keyfactor SCEP endpoint or integrate NDES
- [ ] Create SCEP profile in Intune:
  - [ ] Certificate type: Device
  - [ ] Subject: CN={{DeviceId}}
  - [ ] SAN: URI={{AADDeviceId}}
  - [ ] Key size: 2048
  - [ ] Validity: 365 days
  - [ ] SCEP server URL: https://keyfactor.contoso.com/scep/intune
- [ ] Assign to pilot device group (10-20 devices)
- [ ] Verify:
  - [ ] Devices enroll on check-in
  - [ ] Certificates visible in Keyfactor inventory
  - [ ] Devices can authenticate (e.g., to VPN, Wi-Fi)

**Deliverables**:
- [ ] 3-4 enrollment rails operational with pilot workloads
- [ ] End-to-end automation for at least one rail (K8s or Windows)
- [ ] Documented procedures for each rail (see [07 - Enrollment Rails Guide](./07-Enrollment-Rails-Guide.md))

**Exit Criteria**:
- Pilot workloads successfully issuing and renewing certificates with zero manual intervention
- No critical issues identified

**Runbook**: See [05 - Implementation Runbooks](./05-Implementation-Runbooks.md) § Phase 3

### 8.7 Phase 4: Automation & Eventing (Weeks 14-16)

**Objective**: Implement webhook-driven automation for certificate deployment and service reloads

**Week 14: Webhook Infrastructure**

- [ ] Configure Keyfactor webhooks:
  - [ ] Event: `certificate_issued`
  - [ ] Event: `certificate_renewed`
  - [ ] Event: `certificate_expiring` (T-30d, T-7d, T-1d)
  - [ ] Event: `certificate_revoked`
  - [ ] Event: `renewal_failed`
- [ ] Deploy webhook receivers:
  - [ ] Azure Logic Apps (for Azure workloads)
  - [ ] AWS Lambda (for AWS workloads)
  - [ ] Argo Events (for Kubernetes)
- [ ] Implement webhook authentication (HMAC signature or mutual TLS)
- [ ] Test webhook delivery (use webhook.site or similar for testing)

**Week 15: Automation Playbooks**

Implement automation for each workload type:

**IIS Web Servers**:
- [ ] Logic App: On `certificate_renewed`
  1. Fetch new PFX from Keyfactor API
  2. Write to Key Vault (versioned secret)
  3. Remote PowerShell to server:
     - Import PFX to cert store
     - Update IIS binding
     - iisreset /noforce
  4. Verify: HTTPS GET, check thumbprint
  5. Log to ServiceNow
- [ ] Test with pilot server

**Kubernetes**:
- [ ] cert-manager handles automatically (no additional automation needed)
- [ ] Implement monitoring: alert if cert not renewed 7 days before expiry

**Load Balancers (F5, Azure App Gateway)**:
- [ ] Logic App: On `certificate_renewed`
  1. Fetch new cert from Keyfactor
  2. API call to load balancer to update SSL profile
  3. Verify: HTTPS GET via VIP
  4. Log to ServiceNow

**Vault/Key Vault Integration**:
- [ ] Automation: Write renewed cert to Vault/Key Vault as new secret version
- [ ] App notification: Publish event to Event Grid / SNS / NATS
- [ ] Apps: Subscribe to event, reload config on notification

**Week 16: Failure Handling & Break-Glass**

- [ ] Implement retry logic (3 attempts with exponential backoff)
- [ ] Rollback automation: On failure, restore previous cert/config
- [ ] Alerting: Create incident in ServiceNow, page on-call
- [ ] Dead-letter queue: Failed webhooks logged for manual intervention
- [ ] Break-glass procedures (see [10 - Incident Response Procedures](./10-Incident-Response-Procedures.md)):
  - [ ] Manual certificate issuance (bypass automation)
  - [ ] Emergency revocation (direct CRL update)
  - [ ] Rollback to previous cert (documented commands per platform)

**Deliverables**:
- [ ] Webhook-driven automation for top 3 workload types
- [ ] Failure handling and rollback procedures tested
- [ ] Monitoring and alerting operational
- [ ] Runbooks: [06 - Automation Playbooks](./06-Automation-Playbooks.md)

**Exit Criteria**:
- Automated renewal working for pilot workloads with ≥95% success rate
- Failures detected and handled gracefully (rollback + alert)

**Runbook**: See [05 - Implementation Runbooks](./05-Implementation-Runbooks.md) § Phase 4

### 8.8 Phase 5: Pilot & Scale (Weeks 17-21)

**Objective**: Expand from pilot to production scale; measure KPIs; enforce policies

**Week 17-18: Expand Scope**

- [ ] Windows: Expand GPO to all domain servers (phased rollout by OU)
- [ ] Kubernetes: Deploy cert-manager + ClusterIssuer to remaining clusters
- [ ] ACME: Publish to all web/app teams with self-service docs
- [ ] Mandatory management policy: Block unmanaged certificates in CI/CD (warning mode)

**Week 19: Policy Enforcement**

- [ ] Enable SAN validation (deny CSRs with unauthorized domains)
- [ ] Enable key size enforcement (deny <3072-bit RSA, <256-bit ECC)
- [ ] Enable drift detection (tag unmanaged certs, alert security team)
- [ ] Enable lifetime enforcement (deny >398d for public, >730d for internal)

**Week 20: Measure KPIs**

- [ ] Collect baseline metrics:
  - [ ] Auto-renewal rate (target: ≥95%)
  - [ ] Time-to-issue (target: ≤2 min for standard templates)
  - [ ] Renewal MTTR (target: ≤5 min per endpoint)
  - [ ] Unmanaged cert % (target: ≤5% after 30 days)
  - [ ] Certificate-related incidents (target: ≤1/month)
- [ ] Review with stakeholders
- [ ] Identify gaps and remediate

**Week 21: Turn On Enforcement**

- [ ] Mandatory management: CI/CD blocks deployment of unmanaged certs
- [ ] Policy violations: Hard-block (no longer warnings)
- [ ] Drift control: Auto-revoke unmanaged certs after 30-day grace period (with notifications)

**Deliverables**:
- [ ] ≥90% of certificates under Keyfactor management
- [ ] Auto-renewal rate ≥95%
- [ ] KPI dashboard operational and reviewed weekly
- [ ] Policies enforced (no exceptions without approval)

**Exit Criteria**:
- All KPI targets met for 2 consecutive weeks
- No critical issues blocking scale

**Runbook**: See [05 - Implementation Runbooks](./05-Implementation-Runbooks.md) § Phase 5

### 8.9 Phase 6: Operate & Optimize (Ongoing)

**Objective**: Continuous operations, optimization, and expansion to advanced use cases

**Monthly**:
- [ ] Review KPIs and dashboards
- [ ] Triage failed renewals (root cause analysis)
- [ ] Update ownership metadata (quarterly CMDB reconciliation)
- [ ] Rotate on-call schedules and update runbooks

**Quarterly**:
- [ ] Policy review: Are templates still aligned with business needs?
- [ ] Access review: Remove departed employees from admin roles
- [ ] Capacity planning: Is orchestrator capacity sufficient?
- [ ] Vendor review: Keyfactor product updates, new features

**Annually**:
- [ ] CRL/OCSP failover drill (simulate responder failure)
- [ ] Key compromise drill (simulate CA key compromise, full reissuance)
- [ ] DR test: Restore Keyfactor from backup, verify functionality
- [ ] Penetration test: Include PKI infrastructure in scope

**Future Enhancements** (Phase 7+):
- [ ] Short-lived certificates (24-hour for service mesh)
- [ ] SPIFFE/SPIRE integration (workload identity)
- [ ] Code signing workflow (developers sign via API, keys never leave HSM)
- [ ] Document signing (S/MIME for email)
- [ ] Quantum-safe algorithms (post-quantum cryptography) - [Inference]: as standards mature

**Runbook**: See [08 - Operations Manual](./08-Operations-Manual.md)

---

## 9. Operational Model

### 9.1 Roles and Responsibilities

| Role | Responsibilities | Staffing |
|------|------------------|----------|
| **PKI Administrator** | CA operations, emergency issuance/revocation, HSM key access | 2 FTE (primary + backup) |
| **Keyfactor Operator** | Platform config, orchestrators, templates, integrations | 2 FTE |
| **Security Engineer** | Policy review, audit log monitoring, incident response | 1 FTE (shared) |
| **DevOps Engineer** | Webhook automation, CI/CD integration, runbook maintenance | 2 FTE (shared) |
| **On-Call Engineer** | After-hours incident response, break-glass procedures | Rotation (4-5 people) |
| **Service Owners** | Request certs for their services, maintain ownership metadata | N/A (self-service) |

### 9.2 Support Model

**Tier 1: Self-Service**
- Developer portal with enrollment examples
- FAQ and troubleshooting guide (see [19 - Service Owner Guide](./19-Service-Owner-Guide.md))
- Slack/Teams channel for questions (#pki-support)

**Tier 2: Keyfactor Operators**
- Handle policy exceptions, troubleshoot enrollment failures
- SLA: Respond within 4 business hours

**Tier 3: PKI Administrators**
- Handle emergency revocations, CA outages, HSM issues
- SLA: Respond within 1 hour (24/7 on-call)

**Vendor Support**:
- Keyfactor support contract (24/7 for SaaS, business hours for self-hosted)
- HSM vendor support (for hardware issues)

### 9.3 Change Management

**Standard Changes** (Pre-Approved):
- Add new certificate to existing template
- Renew certificate via automation
- Add user to existing role

**Normal Changes** (Approval Required):
- Create new certificate template
- Modify RBAC policies
- Deploy new orchestrator

**Emergency Changes** (CISO Approval):
- Revoke certificate
- Modify CA configuration
- Emergency key rotation

### 9.4 Maintenance Windows

**Scheduled Maintenance**:
- Keyfactor platform updates: Monthly (SaaS: auto; self-hosted: plan 2-hour window)
- Orchestrator updates: Quarterly (rolling, no downtime)
- CA patching: Quarterly (brief issuance pause, <5 min)
- HSM firmware updates: Annually (requires key backup and failover testing)

**Unplanned Maintenance**:
- Orchestrator failure: Failover to secondary (auto, <1 min)
- CA failure: Failover to secondary issuing CA (manual, <15 min) - [Inference]: if HA configured
- Keyfactor platform failure (SaaS): Vendor handles (target: <15 min RTO)

---

## 10. Risk Analysis

### 10.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation | Residual Risk |
|------|------------|--------|------------|---------------|
| **CA private key compromise** | Very Low | Critical | HSM protection, quorum access, annual key ceremony audit | Low |
| **Keyfactor platform outage** | Low | High | SaaS multi-region deployment OR self-hosted HA cluster; renewals staged 30d early | Low |
| **Orchestrator failure** | Medium | Medium | Deploy ≥2 per zone, auto-failover, health monitoring | Very Low |
| **Webhook delivery failure** | Medium | Medium | Retry logic, dead-letter queue, manual fallback, alerts | Low |
| **Unauthorized cert issuance** | Low | High | Multi-layer RBAC, SAN validation, audit logging, SIEM alerts | Low |
| **Mass cert expiration** | Low | High | Auto-renewal at T-30d, escalating alerts T-7d/T-1d, break-glass manual renewal | Low |
| **HSM failure** | Very Low | Critical | Geo-redundant HSMs or Managed HSM with automatic failover | Low |
| **CRL/OCSP unavailable** | Low | High | ≥2 responders, CDN distribution, OCSP stapling, monitoring | Low |
| **Policy too restrictive** | Medium | Medium | Start permissive, tighten iteratively, exception process | Very Low |
| **Poor adoption by teams** | Medium | High | Training, self-service docs, executive sponsorship, show early wins | Low |

### 10.2 Operational Risks

| Risk | Likelihood | Impact | Mitigation | Residual Risk |
|------|------------|--------|------------|---------------|
| **Staff turnover (PKI admin)** | Medium | High | Document all procedures, cross-training, vendor support | Medium |
| **Lack of ownership data** | High | Medium | Monthly CMDB reconciliation, require ownership for new certs | Medium |
| **Automation bugs** | Medium | High | Extensive testing, canary deployments, rollback automation | Low |
| **Change causes outage** | Low | High | Change approval process, test in pre-prod, maintenance windows | Low |

### 10.3 Security Risks

**Full threat model**: See [13 - Threat Model](./13-Threat-Model.md)

**Key Threats**:
1. **Insider threat**: Malicious admin issues unauthorized cert
   - **Mitigation**: Dual approval for high-risk, audit logs, least privilege
2. **Credential compromise**: Attacker gains API key or admin account
   - **Mitigation**: MFA, API key rotation, rate limiting, anomaly detection
3. **Supply chain attack**: Compromised Keyfactor platform or orchestrator
   - **Mitigation**: Vendor security assessment, SBOM review, network segmentation
4. **DNS hijacking**: Attacker validates ACME challenge for unauthorized domain
   - **Mitigation**: DNSSEC, CAA records, manual approval for high-value domains

---

## 11. Success Criteria and KPIs

### 11.1 Implementation Success Criteria

| Phase | Success Criteria |
|-------|------------------|
| **Phase 1** | ≥90% certificate discovery coverage; ownership mapped; risk report generated |
| **Phase 2** | CA integrated, end-to-end issuance working, CRL/OCSP operational |
| **Phase 3** | 3+ enrollment rails operational with pilot workloads; auto-renewal demonstrated |
| **Phase 4** | Webhook automation for top 3 workloads; failure handling tested |
| **Phase 5** | ≥90% certs managed, ≥95% auto-renewal rate, policies enforced |
| **Phase 6** | ≥95% auto-renewal sustained for 90 days, <1 cert-related incident/month |

### 11.2 Operational KPIs

**Primary KPIs** (Tracked Weekly):

| KPI | Target | Current | Trend |
|-----|--------|---------|-------|
| **Auto-Renewal Rate** | ≥95% | [TBD] | |
| **Time-to-Issue (Standard Template)** | ≤2 min | [TBD] | |
| **Renewal MTTR** | ≤5 min/endpoint | [TBD] | |
| **Unmanaged Certificate %** | ≤1% | [TBD] | |
| **Certificate Inventory Coverage** | ≥98% | [TBD] | |

**Secondary KPIs** (Tracked Monthly):

| KPI | Target | Current |
|-----|--------|---------|
| **Certificate-Related Incidents** | ≤1/month | [TBD] |
| **Policy Compliance Rate** | 100% | [TBD] |
| **Key Size Compliance** | 100% ≥3072 RSA / ≥256 ECC | [TBD] |
| **Expiring <30 Days (Excluding Auto-Renewed)** | <10 | [TBD] |
| **Average Cert Lifetime (Public)** | ~398 days | [TBD] |
| **Average Cert Lifetime (Internal)** | ~730 days | [TBD] |
| **mTLS Adoption** | ≥50% internal services | [TBD] |

**Business Value KPIs** (Tracked Quarterly):

| KPI | Target | Current |
|-----|--------|---------|
| **Operational Hours Saved** | ≥100 hrs/month | [TBD] |
| **Cost Avoidance (Outages)** | $XXX,XXX/quarter | [TBD] |
| **Audit Findings (PKI-Related)** | 0 | [TBD] |
| **Time to Deploy New Service (Cert Portion)** | <5 min | [TBD] |

### 11.3 Dashboard Configuration

**Dashboard 1: Certificate Expiration**
- Timeline chart: Certs expiring in 30/60/90/180 days
- Pie chart: By owner/team
- Table: Top 10 expiring soonest (with owner contact)

**Dashboard 2: Renewal Health**
- Line chart: Auto-renewal success rate (daily)
- Bar chart: Failed renewals by reason code
- Alert count: Certs expiring <7 days

**Dashboard 3: Policy Compliance**
- Gauge: % managed vs unmanaged certs
- Bar chart: Key size distribution (1024/2048/3072/4096)
- Table: Policy violations (denied requests with reason)

**Dashboard 4: Operational Metrics**
- Time-series: Time-to-issue (p50, p95, p99)
- Time-series: Renewal MTTR
- Heatmap: Issuance volume by template and day

**Implementation**: See [09 - Monitoring and KPIs](./09-Monitoring-KPIs.md)

---

## 12. Governance

### 12.1 Policy Ownership

| Policy Type | Owner | Approval | Review Cycle |
|-------------|-------|----------|--------------|
| **Certificate Templates** | PKI Architect | Security + Business Owner | Quarterly |
| **RBAC Policies** | Security Team | CISO | Quarterly |
| **Technical Standards** (key size, algorithms) | PKI Architect | CISO | Annually |
| **Enrollment Procedures** | PKI Operators | PKI Admin | Semi-annually |
| **Break-Glass Procedures** | PKI Admin + Security | CISO | Annually |

### 12.2 Compliance Mapping

**SOC 2 Type II**:
- CC6.1 (Logical access): RBAC with MFA, least privilege
- CC6.6 (Encryption): TLS 1.2+ with strong ciphers, key size ≥3072
- CC6.7 (Encryption key management): HSM for CA keys, automated rotation
- CC7.2 (System monitoring): Certificate expiration alerts, renewal monitoring

**PCI-DSS v4.0**:
- Req 4.2.1: Strong cryptography for cardholder data transmission (TLS with Keyfactor-managed certs)
- Req 6.3.3: Certificate inventory and lifecycle management
- Req 10.2: Audit logging of certificate issuance/revocation

**ISO 27001:2022**:
- A.5.15 (Access control): RBAC for certificate issuance
- A.8.24 (Cryptography): Key management in HSM
- A.8.9 (Configuration management): Certificate inventory and ownership

**Full mapping**: See [12 - Compliance Mapping](./12-Compliance-Mapping.md)

### 12.3 Audit Requirements

**Internal Audits** (Quarterly):
- Review access logs for privileged actions
- Verify ownership metadata is current
- Check policy compliance (denied requests, overrides)
- Validate break-glass procedure readiness

**External Audits** (Annually):
- SOC 2 audit includes certificate management controls
- PCI-DSS: Certificate inventory and key management review
- Demonstrate certificate lifecycle from request → issuance → renewal → revocation

**Audit Evidence**:
- Certificate inventory export with ownership
- Issuance/revocation logs for sample period
- RBAC configuration and access reviews
- Renewal automation test results
- Incident response test (key compromise scenario)

---

## 13. Appendices

### 13.1 Glossary

See [16 - Glossary and References](./16-Glossary-References.md)

### 13.2 References

**External Standards**:
- RFC 5280: X.509 Public Key Infrastructure
- RFC 8555: ACME Protocol
- RFC 7030: EST Protocol
- RFC 8894: SCEP Protocol
- CA/Browser Forum Baseline Requirements

**Vendor Documentation**:
- Keyfactor Command Documentation: [vendor link]
- EJBCA Documentation: [vendor link]
- Azure Managed HSM: [microsoft docs link]
- cert-manager Documentation: [cert-manager.io]

**Internal Documentation**:
- [Link to CMDB]
- [Link to ServiceNow change process]
- [Link to on-call playbooks]

### 13.3 Acronyms

| Acronym | Meaning |
|---------|---------|
| **ACME** | Automated Certificate Management Environment |
| **CA** | Certificate Authority |
| **CRL** | Certificate Revocation List |
| **CSR** | Certificate Signing Request |
| **EKU** | Extended Key Usage |
| **EST** | Enrollment over Secure Transport |
| **HSM** | Hardware Security Module |
| **OCSP** | Online Certificate Status Protocol |
| **PKI** | Public Key Infrastructure |
| **RA** | Registration Authority |
| **RBAC** | Role-Based Access Control |
| **SAN** | Subject Alternative Name |
| **SCEP** | Simple Certificate Enrollment Protocol |
| **mTLS** | Mutual TLS (client certificate authentication) |

### 13.4 Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2025-10-15 | Adrian Johnson | Initial draft |
| 0.5 | 2025-10-20 | Adrian Johnson | Added RBAC framework, updated architecture |
| 1.0 | 2025-10-22 | Adrian Johnson | Final review, ready for stakeholder approval |

---

## Approval Signatures

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **PKI Architect** | [Name] | _________________ | _______ |
| **CISO** | [Name] | _________________ | _______ |
| **VP Infrastructure** | [Name] | _________________ | _______ |
| **Enterprise Architect** | [Name] | _________________ | _______ |

---

**Next Steps**:
1. **Review**: Circulate to stakeholders for review (deadline: [date])
2. **Approval**: Architecture board meeting (scheduled: [date])
3. **Kickoff**: Phase 0 kickoff (target: [date])

---

**Document Classification**: Internal Use  
**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025

