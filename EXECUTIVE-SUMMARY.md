# Keyfactor Certificate Lifecycle Management
## Executive Summary & One-Page Overview

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Date**: October 22, 2025  
**Version**: 1.0

---

## The Problem

**Current State**:
- **12 production outages/year** caused by expired certificates
- **120 hours/month** spent on manual certificate operations
- **2-5 days** to issue a standard certificate (manual approvals, CSR generation, installation)
- **~60% visibility** - unknown certificates across cloud, on-prem, Kubernetes
- **No policy enforcement** - weak keys (1024-bit), certificates for departed employees
- **Compliance gaps** - unable to demonstrate certificate inventory or revocation procedures

**Business Impact**:
- Lost revenue from outages (estimated $XXX,XXX per incident)
- Operational inefficiency (high-value engineers doing repetitive tasks)
- Security risk (unmanaged certificates, compromised keys)
- Compliance violations (SOC 2, PCI-DSS audit findings)

---

## The Solution

**Keyfactor Command** as centralized certificate lifecycle management platform with:

### 1. Automated Discovery
- Scan all infrastructure (on-prem, Azure, AWS, Kubernetes)
- Build complete certificate inventory with ownership metadata
- Continuous monitoring for unmanaged/rogue certificates

### 2. Policy-Driven Issuance
- **Multi-layer authorization**:
  - Layer 1: Identity RBAC (WHO can request)
  - Layer 2: SAN validation (WHAT domains)
  - Layer 3: Resource binding (WHERE can it be deployed)
  - Layer 4: Template policy (HOW it's issued)
- Deny-by-default, fail-closed security model
- Self-service enrollment via ACME, cert-manager, API

### 3. Zero-Touch Renewals
- Auto-renew certificates 30 days before expiry
- Event-driven webhooks trigger deployment automation:
  1. Keyfactor renews certificate
  2. Webhook fires → automation pipeline
  3. Update Key Vault / HashiCorp Vault
  4. Deploy to endpoint (IIS, Kubernetes, load balancer)
  5. Reload service (zero downtime)
  6. Log to ServiceNow
- **95%+ auto-renewal rate** (no manual intervention)

### 4. Centralized Visibility & Control
- Real-time dashboards: expiring certs, renewal success, policy violations
- Immutable audit logs: every issuance, renewal, revocation, denial
- SIEM integration: Azure Sentinel / Splunk for security events

---

## Expected Outcomes

| Metric | Current | Target | Timeline |
|--------|---------|--------|----------|
| **Certificate outages** | 12/year | <1/year | 6 months |
| **Manual effort** | 120 hrs/month | <10 hrs/month | 6 months |
| **Auto-renewal rate** | ~20% | ≥95% | 6 months |
| **Time to issue** | 2-5 days | <2 minutes | 3 months |
| **Certificate visibility** | ~60% | ≥98% | 3 months |
| **Policy compliance** | Unknown | 100% | 6 months |

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────┐
│  ENROLLMENT: ACME | EST | SCEP | GPO | cert-manager    │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│          KEYFACTOR COMMAND (Control Plane)              │
│  • Multi-layer authorization (RBAC + SAN + Resource)    │
│  • Policy engine (templates, approval workflows)        │
│  • Discovery & inventory                                │
│  • Webhook automation                                   │
└────────────────────────┬────────────────────────────────┘
                         │
           ┌─────────────┼─────────────┐
           │             │             │
           ▼             ▼             ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │    CA    │   │ Secrets  │   │ Endpoints│
    │ AD CS or │   │ Key Vault│   │ IIS, K8s │
    │  EJBCA   │   │  + Vault │   │Load Bal. │
    │  (HSM)   │   │          │   │          │
    └──────────┘   └──────────┘   └──────────┘
```

---

## Key Innovations

### 1. Defense-in-Depth Authorization
**Problem**: Traditional PKI: "Are you authenticated?" → Yes → Issue cert (no domain or resource checks)

**Solution**: 4 independent layers (ALL must pass):
- ✓ Identity RBAC: User in authorized group?
- ✓ SAN validation: Domain in allowed patterns?
- ✓ Resource binding: Requester owns target server?
- ✓ Template policy: Technical requirements met?

**Result**: Prevent unauthorized issuance (e.g., developer can't request *.prod.contoso.com)

### 2. Event-Driven Automation (Not Polling)
**Problem**: Traditional: Poll for expiring certs → manual renewal → manual deployment → hope you don't forget

**Solution**: Webhook-driven automation
```
T-30d → Keyfactor auto-renews → Webhook → Pipeline:
  1. Fetch new cert from Keyfactor
  2. Update Key Vault (new secret version)
  3. Deploy to IIS/K8s/load balancer
  4. Reload service (zero downtime)
  5. Verify + log to ServiceNow
```

**Result**: 95%+ renewals with zero manual intervention

### 3. Secrets Separation (Zero Trust)
**Problem**: Traditional: CA stores private keys → single point of compromise

**Solution**: Private keys NEVER leave secure enclaves
- Kubernetes: `cert-manager` generates key on pod, submits CSR
- Windows: Auto-enrollment generates key on server (non-exportable)
- Code signing: Key in HSM, signing via API (never exported)

**Result**: Keyfactor coordinates lifecycle but never sees private keys

---

## Investment

[Inference]: Costs vary by deployment model and scale; consult Keyfactor for specific pricing.

| Component | Estimated Annual Cost |
|-----------|----------------------|
| Keyfactor Command licenses | $XXX,XXX |
| HSM (if new EJBCA) | $XX,XXX |
| Implementation services (Year 1) | $XXX,XXX |
| **Total Year 1** | **$XXX,XXX** |
| **Annual recurring (Year 2+)** | **$XXX,XXX** |

**ROI**: [Inference] 18-month payback
- **Cost avoidance**: 12 outages/year × $XXX,XXX/outage = $X,XXX,XXX/year
- **Operational savings**: 110 hours/month × $XXX/hour = $XXX,XXX/year
- **Total annual benefit**: $X,XXX,XXX

---

## Implementation Timeline

```
Phase 0: Readiness & Decisions        [Weeks 1-2]   ████
Phase 1: Discovery & Baseline         [Weeks 3-5]   ████
Phase 2: CA & HSM Integration         [Weeks 6-9]   ████
Phase 3: Enrollment Rails             [Weeks 10-13] ████
Phase 4: Automation & Eventing        [Weeks 14-16] ████
Phase 5: Pilot & Scale                [Weeks 17-21] ████
Phase 6: Operate & Optimize (ongoing) [Week 22+]    ████████...

Total: 24 weeks (6 months) to full implementation
```

**First Milestone** (Sprint 1): **2 weeks** - Prove end-to-end automation with pilot workload

---

## Security & Compliance

### Security Controls
- **HSM protection**: Issuing CA private keys in FIPS 140-2 Level 3 HSM
- **Multi-layer authorization**: Fail-closed, deny-by-default
- **Separation of duties**: PKI Admin ≠ Keyfactor Operator ≠ Service Owner
- **Immutable audit logs**: 7-year retention, SIEM integration
- **Break-glass procedures**: Dual control, MFA required

### Compliance Mapping
- **SOC 2 Type II**: CC6.1 (access control), CC6.6/7 (encryption), CC7.2 (monitoring)
- **PCI-DSS v4.0**: Req 4.2.1 (strong cryptography), Req 6.3.3 (cert lifecycle), Req 10.2 (audit)
- **ISO 27001:2022**: A.5.15 (access control), A.8.24 (cryptography), A.8.9 (config mgmt)

---

## Risks & Mitigations

| Risk | Impact | Mitigation | Residual |
|------|--------|------------|----------|
| **CA private key compromise** | Critical | HSM protection, quorum access, annual audit | Low |
| **Keyfactor platform outage** | High | SaaS multi-region OR self-hosted HA; renewals staged 30d early | Low |
| **Automation bugs** | High | Extensive testing, canary deployments, rollback automation | Low |
| **Poor adoption** | High | Training, self-service docs, executive sponsorship, early wins | Low |

---

## Success Criteria (Gate for Production Rollout)

**Phase 5 Exit Criteria** (Required before production scale):
- ✅ ≥90% of pilot certificates under Keyfactor management
- ✅ ≥95% auto-renewal rate for pilot workloads (sustained 30 days)
- ✅ <2 minute time-to-issue for standard templates
- ✅ Zero service disruptions from renewals (tested with ≥50 renewals)
- ✅ Dashboard operational with KPIs tracking
- ✅ Break-glass procedures tested
- ✅ Operations team trained and confident

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Platform** | Keyfactor Command (SaaS or self-hosted) | Certificate lifecycle orchestration |
| **CA** | AD CS (existing) or EJBCA (new, HSM-backed) | Certificate issuance |
| **Secrets** | Azure Key Vault + HashiCorp Vault | App secrets storage |
| **K8s** | cert-manager + Keyfactor ClusterIssuer | K8s automation |
| **Automation** | Azure Logic Apps / AWS Lambda | Webhook handlers |
| **Observability** | Azure Monitor / Grafana + Azure Sentinel | Dashboards, alerts, SIEM |
| **ITSM** | ServiceNow | Change records, incidents |

---

## Key Decision Points (Requires Approval)

### 1. Deployment Model
- **Option A**: Keyfactor Command SaaS (managed by vendor)
  - Pros: Low operational burden, auto-updates, multi-region HA
  - Cons: Requires outbound connectivity, shared responsibility model
- **Option B**: Self-hosted (on-prem or your cloud)
  - Pros: Full control, network isolation
  - Cons: High operational burden, manual updates

**Recommendation**: [TBD by architecture board]

### 2. CA Strategy
- **Option A**: Keep existing AD CS, integrate with Keyfactor
  - Pros: No migration, familiar to team
  - Cons: Windows-dependent, software keys (no HSM), limited HA
- **Option B**: Deploy new EJBCA with HSM
  - Pros: HSM-backed, platform-independent, modern API
  - Cons: New platform to learn, HSM procurement

**Recommendation**: Hybrid - Start with AD CS (Phase 1-3), deploy EJBCA (Phase 4), migrate over time

### 3. HSM Selection (if EJBCA)
- **Option A**: Azure Managed HSM
  - Pros: Fully managed, no hardware maintenance, pay-as-you-go
  - Cons: Azure-only
- **Option B**: Network HSM (Thales, Utimaco)
  - Pros: On-prem, multi-cloud compatible
  - Cons: CapEx, hardware maintenance

**Recommendation**: Azure Managed HSM (lower TCO)

---

## Next Steps

### Immediate (This Week)
1. **Review** this summary and full documentation suite
2. **Schedule** architecture review board meeting (90 min)
3. **Identify** stakeholders for approval (CISO, VP Infra, Enterprise Architect)

### Week 1-2 (Phase 0)
1. **Approve** architecture decisions (deployment model, CA strategy, HSM)
2. **Procure** licenses (Keyfactor, HSM if applicable)
3. **Assign** implementation team (PKI Admin, Platform Engineer, Automation Engineer)
4. **Kickoff** Phase 1 (discovery)

### Week 3-4 (Sprint 1)
1. **Deploy** Keyfactor Command
2. **Run** discovery on pilot scope
3. **Build** certificate inventory with ownership
4. **Deploy** one enrollment rail (Kubernetes OR Windows OR ACME)
5. **Demonstrate** end-to-end automation to stakeholders

---

## Documentation Suite

**Complete documentation** (22 documents planned, 5 completed):

✅ **Core Documents** (Read First):
- [README.md](./README.md) - Navigation guide
- [01 - Executive Design Document](./01-Executive-Design-Document.md) - Complete technical design ⭐
- [02 - RBAC Authorization Framework](./02-RBAC-Authorization-Framework.md) - Security model ⭐
- [03 - Policy Catalog](./03-Policy-Catalog.md) - Certificate templates
- [04 - Architecture Diagrams](./04-Architecture-Diagrams.md) - Visual architecture

🚀 **Quick Start**:
- [18 - Quick Start - First Sprint](./18-Quick-Start-First-Sprint.md) - 2-week implementation guide ⭐

📋 **Additional** (Planned):
- Implementation runbooks, automation playbooks, operations manual, monitoring/KPIs, incident response, security controls, threat model, integration specs, compliance mapping, and more

**Repository**: [Insert Git URL]

---

## Contact & Support

**Project Lead**: Adrian Johnson  
**Email**: adrian207@gmail.com  
**Support**: #pki-support (Slack) or pki-team@contoso.com

---

## Approval Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **CISO** | [Name] | _________________ | _______ |
| **VP Infrastructure** | [Name] | _________________ | _______ |
| **Enterprise Architect** | [Name] | _________________ | _______ |
| **CFO / Budget Owner** | [Name] | _________________ | _______ |

---

## Status

**Current Status**: ✅ Design Phase Complete - Ready for Architecture Review

**Next Milestone**: Phase 0 Kickoff (Target: [Insert Date])

---

**Let's eliminate certificate outages and manual toil.**  
**Welcome to automated, policy-driven certificate lifecycle management.**

---

*Adrian Johnson | adrian207@gmail.com | October 22, 2025*

