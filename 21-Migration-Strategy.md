# Migration Strategy
## Transitioning from Legacy PKI to Keyfactor

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 23, 2025  
**Classification**: Internal Use  
**Target Audience**: Implementation team, operations, service owners

---

## Document Purpose

This document outlines the strategy for migrating from current manual and semi-automated certificate management processes to the Keyfactor-based automated PKI platform. It includes migration phases, risk mitigation strategies, rollback procedures, and success criteria.

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Migration Principles](#2-migration-principles)
3. [Migration Phases](#3-migration-phases)
4. [Certificate Migration Approach](#4-certificate-migration-approach)
5. [Application Migration Patterns](#5-application-migration-patterns)
6. [Risk Mitigation](#6-risk-mitigation)
7. [Rollback Procedures](#7-rollback-procedures)
8. [Success Criteria](#8-success-criteria)

---

## 1. Current State Assessment

### 1.1 Current Certificate Landscape

**Inventory**:
- Total certificates: ~2,500
  - Windows servers: ~1,000 (40%)
  - Linux servers: ~600 (24%)
  - Cloud services (Azure/AWS): ~400 (16%)
  - Kubernetes workloads: ~300 (12%)
  - Network devices: ~150 (6%)
  - Other: ~50 (2%)

**Current Management Processes**:
| Process | Current Method | Pain Points | Automation Level |
|---------|---------------|-------------|------------------|
| **Certificate Request** | Email PKI team | Manual, slow (2-5 days) | 0% |
| **Approval** | Email approval chain | Inconsistent, no audit trail | 0% |
| **Issuance** | Manual CSR→CA | Error-prone, time-consuming | 10% (AD CS only) |
| **Deployment** | Manual copy/paste | Mistakes common, downtime risk | 5% (GPO for Windows) |
| **Renewal** | Email reminders | Often missed, frequent outages | 5% (AD CS auto-renew) |
| **Revocation** | Manual request | Slow, inconsistent | 0% |
| **Inventory** | Spreadsheets | Out of date, incomplete | 0% |

**Current Tools**:
- Certificate Authority: Microsoft AD CS (2 issuing CAs)
- Inventory: Excel spreadsheets (last updated 6 months ago)
- Monitoring: Manual review of expiry dates
- Deployment: Manual (scp, RDP, copy-paste)

### 1.2 Challenges to Address

**Operational Challenges**:
- 📊 **No visibility**: ~40% of certificates not in inventory
- ⏰ **Manual renewal**: 12 cert-related outages/year
- 🕐 **Slow issuance**: 2-5 day turnaround time
- 👥 **No automation**: 120 hours/month of manual effort
- 🔒 **Shadow IT**: Unknown number of unauthorized certificates
- 📉 **No compliance reporting**: Manual audit preparation (weeks)

**Technical Debt**:
- Weak keys still in use (RSA 1024, MD5 signatures)
- Expired certificates still deployed (~50)
- Self-signed certificates in production (~30)
- Wildcard certificates overused (security risk)
- No certificate pinning or validation

---

## 2. Migration Principles

### 2.1 Core Principles

**1. Zero-Downtime Migration**
- No production service interruptions during migration
- Parallel operation of old and new systems during transition
- Gradual cutover per application/service

**2. Risk-Based Prioritization**
- Start with low-risk, high-value applications
- Build confidence before migrating critical systems
- Pilot in dev/test before production

**3. Automation First**
- Every migrated certificate must use automated enrollment
- Manual processes only for exceptional cases
- Document and automate migration procedures

**4. Reversibility**
- Maintain ability to roll back to old process
- Keep old certificates active until new ones proven
- Clear rollback criteria and procedures

**5. Knowledge Transfer**
- Train team before migration
- Document procedures and lessons learned
- Build internal expertise gradually

### 2.2 Success Criteria

**Phase-Based Goals**:
- **Phase 1** (Discovery): 95%+ of certificates discovered and inventoried
- **Phase 2** (Pilot): 5 applications migrated successfully, zero incidents
- **Phase 3** (Rollout): 50% of certificates under Keyfactor management
- **Phase 4** (Completion): 95%+ automation rate, < 1 outage/year

---

## 3. Migration Phases

### 3.1 Phase Overview

```
Phase 0: Foundation (Weeks 1-4)
  ├─ Deploy Keyfactor SaaS
  ├─ Integrate with AD CS
  ├─ Deploy pilot orchestrators
  └─ Team training

Phase 1: Discovery & Inventory (Weeks 5-8)
  ├─ Network scan for certificates
  ├─ Orchestrator discovery jobs
  ├─ Tag ownership and metadata
  └─ Build accurate inventory

Phase 2: Pilot Projects (Weeks 9-14)
  ├─ Select 5 pilot applications
  ├─ Migrate to automated enrollment
  ├─ Validate and tune
  └─ Document lessons learned

Phase 3: Phased Rollout (Weeks 15-40)
  ├─ Windows servers (Weeks 15-22)
  ├─ Kubernetes workloads (Weeks 23-28)
  ├─ Cloud services (Weeks 29-34)
  ├─ Linux servers (Weeks 35-40)
  └─ Network devices (Weeks 41-44)

Phase 4: Long Tail & Cleanup (Weeks 45-52)
  ├─ Special cases and exceptions
  ├─ Decommission old processes
  ├─ Revoke/replace old certificates
  └─ Final validation
```

### 3.2 Phase 0: Foundation (Weeks 1-4)

**Objectives**:
- Keyfactor SaaS environment operational
- AD CS integrated with Keyfactor
- Team trained and ready
- Pilot orchestrators deployed

**Tasks**:
| Week | Task | Owner | Deliverable |
|------|------|-------|-------------|
| 1 | Keyfactor SaaS provisioning | Keyfactor + Cloud Team | Tenant URL, admin access |
| 1 | AD CS integration setup | PKI Admin | CA connected to Keyfactor |
| 2 | Azure Key Vault orchestrator deploy | Cloud Team | Azure orch operational |
| 2 | Windows orchestrator deploy (pilot zone) | Windows Team | Windows orch operational |
| 3 | Team training (Keyfactor Admin) | PKI Admin | Training complete |
| 3 | Team training (Orchestrator operators) | Operations | Training complete |
| 4 | Test certificate issuance | PKI Admin | Test cert issued via Keyfactor |
| 4 | Pilot application selection | Application Teams | 5 pilot apps identified |

**Success Criteria**:
- ✅ Keyfactor accessible and operational
- ✅ Test certificate issued and deployed successfully
- ✅ Team members trained
- ✅ Pilot applications selected

### 3.3 Phase 1: Discovery & Inventory (Weeks 5-8)

**Objectives**:
- Discover all certificates (95%+ coverage)
- Build accurate inventory with metadata
- Identify certificate owners
- Assess certificate health

**Discovery Methods**:

**1. Network Scanning**:
```bash
# SSL/TLS certificate discovery
nmap -p 443 --script ssl-cert 10.0.0.0/8 -oX scan-results.xml

# Parse and import to Keyfactor
python scripts/import-scan-results.py scan-results.xml
```

**2. Orchestrator Discovery**:
- Azure Key Vault: Discover all certificates in subscriptions
- Windows Certificate Stores: Discover on domain controllers and servers
- Linux Filesystem: Discover in common paths (/etc/ssl, /etc/pki, etc.)

**3. Cloud Provider APIs**:
```bash
# Azure: Discover certificates in Key Vaults
az keyvault certificate list --vault-name <vault> | \
  python scripts/import-azure-certs.py

# AWS: Discover certificates in ACM
aws acm list-certificates --region us-east-1 | \
  python scripts/import-aws-certs.py
```

**4. Application Surveys**:
- Survey service owners for certificate locations
- Document certificates not discovered automatically

**Tagging Strategy**:
```json
{
  "owner": "team-name@contoso.com",
  "application": "WebApp Production",
  "environment": "Production",
  "cost_center": "IT-12345",
  "compliance": "PCI-DSS",
  "renewal_method": "Manual",
  "migration_priority": "Medium",
  "migration_wave": "3"
}
```

**Week-by-Week**:
| Week | Task | Expected Results |
|------|------|------------------|
| 5 | Network scan + Azure discovery | 1,500 certs discovered |
| 6 | Windows orchestrator discovery | 1,000 certs discovered |
| 7 | Linux/filesystem discovery | 600 certs discovered |
| 8 | Manual inventory + tagging | 2,500+ total, 95% tagged |

**Success Criteria**:
- ✅ 95%+ of certificates discovered
- ✅ 100% of discovered certs tagged with owner
- ✅ Inventory database accurate and up-to-date
- ✅ Certificate health assessed (expiry, key strength, etc.)

### 3.4 Phase 2: Pilot Projects (Weeks 9-14)

**Pilot Selection Criteria**:
- ✅ Non-critical services (can tolerate issues)
- ✅ Supportive service owners (willing to experiment)
- ✅ Mix of platforms (Windows, Linux, K8s, Azure)
- ✅ Representative of larger population
- ❌ No customer-facing production systems yet

**Selected Pilot Applications**:

| Application | Platform | Current Process | Target Method | Complexity |
|-------------|----------|-----------------|---------------|------------|
| **Internal Wiki** | Linux/NGINX | Manual renewal | ACME (certbot) | Low |
| **Dev Portal** | Azure App Service | Manual upload | Azure Key Vault | Low |
| **Test API** | Kubernetes | Manual YAML | cert-manager | Medium |
| **Jump Server** | Windows Server | GPO (existing) | GPO (Keyfactor CA) | Low |
| **Internal Dashboard** | Linux/Apache | Manual renewal | ACME (certbot) | Low |

**Pilot Migration Process**:

**Week 9-10**: Wiki + Dev Portal
1. Request new certificate via Keyfactor (ACME/API)
2. Deploy new certificate alongside old
3. Test with new certificate
4. Cutover traffic to new certificate
5. Monitor for 1 week
6. Revoke old certificate

**Week 11-12**: Test API + Jump Server
1. Configure cert-manager for K8s
2. Update Windows GPO to use Keyfactor CA
3. Deploy and test
4. Monitor and validate

**Week 13-14**: Dashboard + Lessons Learned
1. Complete final pilot migration
2. Document lessons learned
3. Update procedures based on pilot feedback
4. Present results to stakeholders

**Success Criteria**:
- ✅ All 5 pilots migrated successfully
- ✅ Zero production incidents during pilot
- ✅ Auto-renewal tested and validated
- ✅ Lessons learned documented
- ✅ Stakeholder approval to proceed

### 3.5 Phase 3: Phased Rollout (Weeks 15-44)

**Migration Waves**:

**Wave 1: Windows Servers (Weeks 15-22)**
- **Count**: ~1,000 certificates
- **Method**: Update GPO to use Keyfactor-integrated AD CS
- **Approach**: Gradual rollout by OU (Organizational Unit)
  - Week 15-16: Dev/Test servers
  - Week 17-18: Internal servers
  - Week 19-20: DMZ servers
  - Week 21-22: Production servers
- **Risk**: Low (GPO auto-enrollment already in use)

**Wave 2: Kubernetes Workloads (Weeks 23-28)**
- **Count**: ~300 certificates
- **Method**: Deploy cert-manager + Keyfactor external issuer
- **Approach**: Namespace-by-namespace rollout
  - Week 23-24: Dev clusters
  - Week 25-26: Staging clusters
  - Week 27-28: Production clusters
- **Risk**: Medium (new technology for team)

**Wave 3: Cloud Services (Azure/AWS) (Weeks 29-34)**
- **Count**: ~400 certificates
- **Method**: Keyfactor orchestrators + Azure Key Vault integration
- **Approach**: Application-by-application migration
  - Week 29-30: Non-prod Azure services
  - Week 31-32: Production Azure services
  - Week 33-34: AWS services
- **Risk**: Medium (multiple service types)

**Wave 4: Linux Servers (Weeks 35-40)**
- **Count**: ~600 certificates
- **Method**: ACME (certbot) enrollment
- **Approach**: Server-by-server, grouped by application
  - Week 35-36: Internal web servers
  - Week 37-38: Application servers
  - Week 39-40: Database servers (if applicable)
- **Risk**: Medium (manual intervention per server)

**Wave 5: Network Devices (Weeks 41-44)**
- **Count**: ~150 certificates
- **Method**: SCEP enrollment
- **Approach**: Device-by-device, grouped by type
  - Week 41-42: Switches and routers
  - Week 43-44: Load balancers (F5, etc.)
- **Risk**: High (manual configuration, potential outage risk)

**Weekly Rollout Process** (repeatable):
```
Monday: Select targets for the week (10-20% of wave)
Tuesday: Communicate to service owners, schedule maintenance windows
Wednesday: Migrate first batch, monitor
Thursday: Migrate second batch, monitor
Friday: Review results, address issues, prepare for next week
```

### 3.6 Phase 4: Long Tail & Cleanup (Weeks 45-52)

**Objectives**:
- Migrate remaining edge cases and exceptions
- Decommission old manual processes
- Revoke/replace old certificates
- Final validation and documentation

**Tasks**:
| Week | Task | Owner |
|------|------|-------|
| 45-46 | Migrate special cases (VPN, code signing, etc.) | PKI Admin |
| 47-48 | Decommission old processes (old ticket queue, manual scripts) | Operations |
| 49 | Revoke old certificates no longer in use | PKI Admin |
| 50 | Replace weak certificates (RSA 1024, MD5, self-signed) | Operations |
| 51 | Final inventory validation and cleanup | Operations |
| 52 | Post-migration report and retrospective | Project Team |

**Success Criteria**:
- ✅ 95%+ of certificates under Keyfactor management
- ✅ < 5% exceptions/manual processes
- ✅ No RSA 1024 or weaker keys in production
- ✅ Zero self-signed certificates in production
- ✅ Old manual processes fully decommissioned

---

## 4. Certificate Migration Approach

### 4.1 Migration Strategies

**Strategy 1: Parallel Deployment (Recommended)**
```
1. Request new certificate via Keyfactor
2. Deploy new certificate alongside old (different port or host if needed)
3. Test new certificate (limited traffic)
4. Cutover traffic to new certificate
5. Monitor for stability period (1-7 days)
6. Revoke old certificate
```

**Pros**: Zero downtime, easy rollback
**Cons**: Requires dual configuration temporarily

---

**Strategy 2: Direct Replacement**
```
1. Request new certificate via Keyfactor
2. Schedule maintenance window
3. Replace old certificate with new
4. Restart service
5. Validate
```

**Pros**: Simple, fast
**Cons**: Requires maintenance window, higher risk

---

**Strategy 3: Blue-Green Deployment** (for critical services)
```
1. Stand up new environment (green) with Keyfactor-issued cert
2. Test green environment
3. Cutover traffic to green
4. Monitor
5. Decommission old environment (blue)
```

**Pros**: Safest, easy rollback
**Cons**: Requires duplicate infrastructure

### 4.2 Pre-Migration Checklist

**For Each Certificate**:
- [ ] Current certificate identified and documented
- [ ] Owner identified and notified
- [ ] Migration strategy selected
- [ ] Maintenance window scheduled (if needed)
- [ ] Rollback plan documented
- [ ] Service owner approval obtained
- [ ] Monitoring in place
- [ ] Change ticket created (ServiceNow)

### 4.3 Migration Procedure Template

```markdown
# Certificate Migration: [Application Name]

**Date**: YYYY-MM-DD
**Owner**: name@contoso.com
**Maintenance Window**: YYYY-MM-DD HH:MM - HH:MM

## Pre-Migration
- [ ] Backup current configuration
- [ ] Document current certificate (serial, thumbprint, expiry)
- [ ] Test Keyfactor enrollment (in dev/test)
- [ ] Notify stakeholders

## Migration Steps
1. Request new certificate via Keyfactor
   - Method: [ACME / API / GPO / etc.]
   - Template: [template-name]
   - SANs: [list]

2. Download certificate (if manual deployment)
   - Format: [PEM / PFX]
   - Location: [path]

3. Deploy new certificate
   - Method: [Orchestrator / Manual / CI/CD]
   - Configuration: [details]

4. Validate certificate
   - openssl s_client -connect [host]:443 -servername [host]
   - Verify expiry, subject, SANs

5. Cutover traffic (if parallel deployment)
   - Update DNS / load balancer / firewall
   - Monitor for errors

## Post-Migration
- [ ] Monitor for 24-48 hours
- [ ] Verify auto-renewal configured
- [ ] Revoke old certificate (after stability period)
- [ ] Update documentation
- [ ] Close change ticket

## Rollback Plan
If issues occur:
1. Revert to old certificate configuration
2. Restart service
3. Notify PKI team
4. Document issue for analysis
```

---

## 5. Application Migration Patterns

### 5.1 Pattern: Windows IIS Web Server

**Current**: Manual PFX upload, manual renewal
**Target**: Keyfactor orchestrator auto-deployment

**Migration Steps**:
```powershell
# 1. Deploy Keyfactor orchestrator (if not present)
# 2. Register IIS server as certificate store in Keyfactor
# 3. Request certificate via Keyfactor
# 4. Orchestrator automatically deploys to IIS
# 5. Verify binding

# Verification
Get-WebBinding -Name "Default Web Site" -Protocol https
```

**Auto-Renewal**: ✅ Automatic via orchestrator

---

### 5.2 Pattern: NGINX on Linux

**Current**: Manual certbot with Let's Encrypt
**Target**: ACME with Keyfactor

**Migration Steps**:
```bash
# 1. Update ACME server configuration
export ACME_SERVER="https://keyfactor.contoso.com/acme"

# 2. Request new certificate
sudo certbot certonly \
  --standalone \
  --server $ACME_SERVER \
  -d webapp.contoso.com

# 3. Update NGINX configuration
sudo vim /etc/nginx/sites-available/default
# ssl_certificate /etc/letsencrypt/live/webapp.contoso.com/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/webapp.contoso.com/privkey.pem;

# 4. Test and reload
sudo nginx -t
sudo systemctl reload nginx

# 5. Verify
openssl s_client -connect webapp.contoso.com:443 -servername webapp.contoso.com
```

**Auto-Renewal**: ✅ Automatic via certbot timer

---

### 5.3 Pattern: Kubernetes Microservices

**Current**: Manual certificate Secret creation
**Target**: cert-manager with Keyfactor external issuer

**Migration Steps**:
```yaml
# 1. Create Certificate resource
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-cert
  namespace: production
spec:
  secretName: api-tls
  issuerRef:
    name: keyfactor-issuer
    kind: ClusterIssuer
  commonName: api.contoso.com
  dnsNames:
    - api.contoso.com

# 2. Apply and wait for issuance
kubectl apply -f certificate.yaml
kubectl wait --for=condition=Ready certificate/api-cert -n production

# 3. Update Ingress or Pod to use new secret
# (cert-manager creates secret automatically)

# 4. Verify
kubectl describe certificate api-cert -n production
kubectl get secret api-tls -n production -o yaml
```

**Auto-Renewal**: ✅ Automatic via cert-manager

---

### 5.4 Pattern: Azure App Service

**Current**: Manual PFX upload via portal
**Target**: Azure Key Vault integration with Keyfactor orchestrator

**Migration Steps**:
```bash
# 1. Keyfactor orchestrator deploys cert to Azure Key Vault (automatic)

# 2. Grant App Service access to Key Vault
az webapp config ssl bind \
  --certificate-source AzureKeyVault \
  --certificate-name api-contoso-com \
  --resource-group my-rg \
  --name my-app-service \
  --ssl-type SNI

# 3. Verify
az webapp config ssl list --resource-group my-rg --name my-app-service
```

**Auto-Renewal**: ✅ Automatic via orchestrator

---

## 6. Risk Mitigation

### 6.1 Identified Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Production outage during migration** | Medium | High | Parallel deployment, maintenance windows, rollback plan |
| **Auto-renewal failure** | Medium | Medium | Monitoring, alerting, 30-day advance renewal |
| **Certificate binding issues** | Medium | Medium | Test in dev/test first, validation scripts |
| **Service owner resistance** | High | Medium | Communication, training, pilot successes |
| **Discovery incomplete** | Medium | Low | Multiple discovery methods, manual surveys |
| **Keyfactor SaaS outage** | Low | High | SLA with Keyfactor, local caching |
| **AD CS integration issues** | Low | High | Test environment validation, vendor support |

### 6.2 Risk Mitigation Strategies

**1. Comprehensive Testing**
- Test every migration pattern in dev/test first
- Validate auto-renewal in non-prod environments
- Load testing for high-volume applications

**2. Communication and Training**
- Monthly migration status updates to stakeholders
- Training sessions for service owners
- Office hours for migration support

**3. Monitoring and Alerting**
- Certificate expiry monitoring (30, 15, 7 days)
- Renewal failure alerts
- Service health dashboards

**4. Gradual Rollout**
- Start with low-risk applications
- Pause if issues arise
- Build momentum with quick wins

**5. Rollback Capability**
- Keep old certificates active during stability period
- Document rollback procedures
- Test rollback in non-prod

---

## 7. Rollback Procedures

### 7.1 Rollback Decision Criteria

**Trigger rollback if**:
- Production service unavailable for > 15 minutes
- Certificate validation failures across multiple services
- Keyfactor platform unavailable for > 2 hours
- Discovered security issue with new certificates

**Do NOT rollback for**:
- Single service issues (troubleshoot individually)
- Minor performance degradation
- Cosmetic or non-critical issues

### 7.2 Rollback Procedure

**Per-Application Rollback**:
```bash
# 1. Identify issue and document
# 2. Revert to old certificate configuration
#    - Restore old cert/key files
#    - Update service configuration
#    - Restart service

# 3. Verify service operational
# 4. Notify PKI team and stakeholders
# 5. Schedule troubleshooting and retry
```

**Platform-Wide Rollback** (emergency):
```
1. Stop all ongoing migrations immediately
2. Communicate to all teams: "Migration paused"
3. Revert recently migrated applications (last 24-48 hours)
4. Troubleshoot and resolve platform issue
5. Resume migration after issue resolved and tested
```

### 7.3 Rollback Communication Template

```
Subject: [URGENT] Certificate Migration Rollback - [Application Name]

Team,

We have initiated a rollback of the certificate migration for [Application Name] due to [issue description].

**Status**: Service restored to previous configuration
**Impact**: [None / Minor / Moderate]
**Root Cause**: Under investigation
**Next Steps**:
- Troubleshoot issue
- Schedule retry after fix
- Update procedures to prevent recurrence

**Timeline**:
- Issue detected: HH:MM
- Rollback initiated: HH:MM
- Service restored: HH:MM

For questions: #pki-support or pki-team@contoso.com
```

---

## 8. Success Criteria

### 8.1 Phase-Level Success Criteria

**Phase 0 (Foundation)**:
- ✅ Keyfactor SaaS operational
- ✅ AD CS integrated
- ✅ Pilot orchestrators deployed
- ✅ Team trained

**Phase 1 (Discovery)**:
- ✅ 95%+ certificates discovered
- ✅ 100% of discovered certs tagged
- ✅ Accurate inventory

**Phase 2 (Pilot)**:
- ✅ 5 pilots migrated successfully
- ✅ Zero production incidents
- ✅ Auto-renewal validated

**Phase 3 (Rollout)**:
- ✅ 95%+ certificates migrated
- ✅ < 2 incidents during rollout
- ✅ All waves completed on schedule

**Phase 4 (Cleanup)**:
- ✅ 95%+ automation rate
- ✅ Old processes decommissioned
- ✅ No weak keys in production

### 8.2 Overall Success Metrics

**Technical Metrics**:
- ✅ **Auto-renewal rate**: ≥ 95%
- ✅ **Certificate visibility**: ≥ 98% discovered
- ✅ **Time to issue**: < 2 minutes (was 2-5 days)
- ✅ **Manual effort**: < 10 hours/month (was 120 hours/month)
- ✅ **Certificate-related outages**: < 1/year (was 12/year)

**Business Metrics**:
- ✅ **Cost savings**: $649K/year
- ✅ **ROI**: 87% return on investment
- ✅ **Payback period**: < 18 months
- ✅ **User satisfaction**: > 90% (service owner survey)

### 8.3 Post-Migration Review

**Schedule**: 30 days after Phase 4 completion

**Review Topics**:
1. Were success criteria met?
2. Lessons learned and best practices
3. Outstanding issues and remediation plan
4. Celebrate successes and recognize contributors
5. Continuous improvement opportunities

---

## 9. Communication Plan

### 9.1 Stakeholder Communication

| Audience | Frequency | Channel | Content |
|----------|-----------|---------|---------|
| **Executive Leadership** | Monthly | Email | Progress update, metrics, risks |
| **Service Owners** | Bi-weekly | Email + Slack | Migration schedule, actions needed |
| **Operations Team** | Weekly | Slack | Detailed status, issues, next week plan |
| **PKI Team** | Daily | Slack | Real-time updates, troubleshooting |
| **All Staff** | Milestone | Email | Major milestones, overall progress |

### 9.2 Communication Templates

**Service Owner Notification** (2 weeks before migration):
```
Subject: [Action Required] Certificate Migration - [Application Name]

Hello [Service Owner],

Your application [Application Name] is scheduled for certificate migration to the new Keyfactor platform:

**What**: Migrate from manual certificate management to automated
**When**: [Date] during maintenance window [Time]
**Impact**: Brief service restart (< 5 minutes)
**Your Action**: Review and approve migration plan (link below)

**Benefits**:
- Automatic renewal (no more manual renewals!)
- Faster issuance (< 2 minutes vs 2-5 days)
- Better monitoring and alerting

**Migration Plan**: [link]
**Questions**: #pki-support or reply to this email

Thank you!
PKI Migration Team
```

---

## Document Maintenance

**Review Schedule**: After each migration phase, update lessons learned  
**Owner**: PKI Lead + Project Manager  
**Last Reviewed**: October 23, 2025  
**Next Review**: After Phase 2 completion (Week 14)

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-23 | Adrian Johnson | Initial migration strategy document |

---

**For migration questions, contact**: adrian207@gmail.com or #pki-support

**End of Migration Strategy**

