# Keyfactor Implementation Project Tracker
## Phase-by-Phase Checklist

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Date**: October 22, 2025  
**Version**: 1.0

---

## How to Use This Tracker

- [ ] = Not started
- [ ] 🔄 = In progress
- [ ] ✅ = Complete
- [ ] ⏸️ = Blocked
- [ ] ❌ = Cancelled

**Update this document weekly** in project status meetings.

---

## Phase 0: Readiness & Decisions (Weeks 1-2)

**Target Dates**: [Insert Start] - [Insert End]  
**Owner**: Architecture Team + Management

### Decisions

- [ ] **Decision: Keyfactor Deployment Model**
  - Options: SaaS vs Self-Hosted
  - Decision: ________________
  - Rationale: ________________
  - Approved by: ________________
  - Date: ________________

- [ ] **Decision: CA Strategy**
  - Options: Keep AD CS, Deploy EJBCA, Hybrid
  - Decision: ________________
  - Rationale: ________________
  - Approved by: ________________
  - Date: ________________

- [ ] **Decision: HSM Selection** (if EJBCA)
  - Options: Azure Managed HSM, Network HSM (Thales/Utimaco), None
  - Decision: ________________
  - Rationale: ________________
  - Approved by: ________________
  - Date: ________________

- [ ] **Decision: Secrets Platform**
  - Options: Azure Key Vault only, HashiCorp Vault only, Both
  - Decision: ________________
  - Rationale: ________________
  - Approved by: ________________
  - Date: ________________

- [ ] **Decision: First Enrollment Rail**
  - Options: Kubernetes (cert-manager), Windows (Auto-Enrollment), ACME
  - Decision: ________________
  - Rationale: ________________
  - Owner: ________________
  - Date: ________________

### Procurement

- [ ] Keyfactor Command licenses ordered
  - Vendor: Keyfactor
  - SKU: ________________
  - Quantity/Tier: ________________
  - Cost: $________________
  - PO#: ________________
  - Expected delivery: ________________

- [ ] HSM ordered (if applicable)
  - Vendor: ________________
  - Model: ________________
  - Cost: $________________
  - PO#: ________________
  - Expected delivery: ________________

- [ ] Implementation services SOW signed (if external help)
  - Vendor: ________________
  - Cost: $________________
  - Duration: ________________ weeks
  - Start date: ________________

### Team Formation

- [ ] **PKI Administrator** assigned
  - Name: ________________
  - Email: ________________
  - Allocation: _____% time

- [ ] **Keyfactor Operator** assigned
  - Name: ________________
  - Email: ________________
  - Allocation: _____% time

- [ ] **Platform Engineer** assigned
  - Name: ________________
  - Email: ________________
  - Allocation: _____% time

- [ ] **Automation Engineer** assigned
  - Name: ________________
  - Email: ________________
  - Allocation: _____% time

- [ ] **Security Reviewer** assigned
  - Name: ________________
  - Email: ________________
  - Allocation: _____% time

### Documentation & Planning

- [ ] Architecture documentation reviewed by stakeholders
- [ ] Threat model reviewed and approved by security team
- [ ] Success criteria and KPIs defined
- [ ] Project charter signed
- [ ] RACI matrix documented
- [ ] Communication plan established

### Training

- [ ] Keyfactor admin training scheduled
  - Dates: ________________
  - Attendees: ________________
  - Format: On-site / Virtual / Self-paced

- [ ] PKI security training scheduled (internal)
  - Date: ________________
  - Attendees: ________________

### Exit Criteria

- [ ] All decisions documented and approved
- [ ] Budget approved and POs issued
- [ ] Team assigned and trained (initial)
- [ ] Architecture review board sign-off

**Phase 0 Status**: [ ] Not Started | [ ] In Progress | [ ] Complete | [ ] Blocked

---

## Phase 1: Discovery & Baseline (Weeks 3-5)

**Target Dates**: [Insert Start] - [Insert End]  
**Owner**: Keyfactor Operator + Platform Engineer

### Deploy Keyfactor Command

**If SaaS**:
- [ ] Tenant activated
  - Tenant URL: ________________
  - Admin account created: ________________
  - Date: ________________

- [ ] SSO configured (Entra ID)
  - IdP configured: ________________
  - Test login successful: ________________
  - Date: ________________

**If Self-Hosted**:
- [ ] Infrastructure provisioned
  - VMs/Containers: ________________ (count)
  - Load balancer: ________________
  - Database: ________________ (SQL/PostgreSQL)
  - Date: ________________

- [ ] Keyfactor Command installed
  - Version: ________________
  - Nodes: ________________
  - Date: ________________

- [ ] Load balancer configured
  - URL: https://________________
  - Health check verified: ________________
  - Date: ________________

### Integrate Certificate Authority

**If AD CS**:
- [ ] CA Gateway installed on AD CS server
  - Server: ________________
  - Version: ________________
  - Date: ________________

- [ ] CA integrated in Keyfactor
  - CA Name: ________________
  - Test issuance successful: ________________
  - Date: ________________

**If EJBCA**:
- [ ] EJBCA cluster deployed
  - Nodes: ________________
  - Version: ________________
  - Date: ________________

- [ ] HSM integrated
  - HSM type: ________________
  - CA keypair generated in HSM: ________________
  - Date: ________________

- [ ] Certificate hierarchy configured
  - Root CA: ________________
  - Issuing Sub-CA(s): ________________
  - Date: ________________

- [ ] CRL/OCSP configured
  - CRL URL: ________________
  - OCSP URL: ________________
  - Responders deployed: ________________
  - Date: ________________

- [ ] EJBCA integrated in Keyfactor
  - API URL: ________________
  - Test issuance successful: ________________
  - Date: ________________

### Deploy Orchestrators

**Orchestrator 1**:
- [ ] Network zone: ________________
- [ ] Deployed to server/container: ________________
- [ ] Status: Online
- [ ] Date: ________________

**Orchestrator 2**:
- [ ] Network zone: ________________
- [ ] Deployed to server/container: ________________
- [ ] Status: Online
- [ ] Date: ________________

**Orchestrator 3** (if applicable):
- [ ] Network zone: ________________
- [ ] Deployed to server/container: ________________
- [ ] Status: Online
- [ ] Date: ________________

### Configure Discovery

- [ ] **Discovery Job: Kubernetes**
  - Clusters: ________________
  - Namespaces: ________________ (or * for all)
  - Schedule: ________________
  - Date: ________________

- [ ] **Discovery Job: Windows/IIS**
  - Target servers: ________________
  - Certificate stores: LocalMachine\My, ________________
  - Schedule: ________________
  - Date: ________________

- [ ] **Discovery Job: Azure Key Vault**
  - Subscriptions: ________________
  - Resource groups: ________________ (or * for all)
  - Schedule: ________________
  - Date: ________________

- [ ] **Discovery Job: AWS**
  - Accounts: ________________
  - Regions: ________________
  - Schedule: ________________
  - Date: ________________

### Run Discovery & Build Inventory

- [ ] Initial discovery scan completed
  - Total certificates discovered: ________________
  - Date: ________________

- [ ] Inventory exported to CSV
  - File: ________________
  - Date: ________________

- [ ] CMDB mapping completed
  - Certificates matched: _______ / _______ (_____%)
  - Date: ________________

- [ ] Manual ownership mapping
  - Unmapped certificates contacted for claims
  - Ownership ≥90%: ________________
  - Date: ________________

- [ ] Risk report generated
  - Expired: ________________
  - Expiring <30d: ________________
  - Weak keys (<2048-bit): ________________
  - Unknown issuers: ________________
  - Unowned: ________________
  - Date: ________________

- [ ] Risk report presented to leadership
  - Meeting date: ________________
  - Attendees: ________________
  - Approval to proceed: ________________

### Define Policy Catalog v1.0

- [ ] **Template: TLS-Server-Internal**
  - Defined in Keyfactor: ________________
  - Authorization rules configured: ________________
  - Test issuance successful: ________________
  - Date: ________________

- [ ] **Template: TLS-Server-Public** (if in scope)
  - Defined: ________________
  - Configured: ________________
  - Tested: ________________
  - Date: ________________

- [ ] **Template: TLS-Client-mTLS** (if in scope)
  - Defined: ________________
  - Configured: ________________
  - Tested: ________________
  - Date: ________________

- [ ] **Template: K8s-Ingress-TLS** (if Kubernetes pilot)
  - Defined: ________________
  - Configured: ________________
  - Tested: ________________
  - Date: ________________

- [ ] **Template: Windows-Domain-Computer** (if Windows pilot)
  - Defined: ________________
  - Configured: ________________
  - Tested: ________________
  - Date: ________________

- [ ] Policy catalog documented
  - Location: [03-Policy-Catalog.md](./03-Policy-Catalog.md)
  - Published to internal wiki: ________________
  - Date: ________________

### Exit Criteria

- [ ] Certificate inventory ≥90% complete
- [ ] Ownership metadata ≥90% mapped
- [ ] Risk report approved by leadership
- [ ] 3-5 templates defined and tested
- [ ] Keyfactor operational with CA issuing certs

**Phase 1 Status**: [ ] Not Started | [ ] In Progress | [ ] Complete | [ ] Blocked

---

## Phase 2: CA & HSM Foundation (Weeks 6-9)

**Target Dates**: [Insert Start] - [Insert End]  
**Owner**: PKI Administrator + Security Team

### (See checklist items in Phase 1 "Integrate Certificate Authority" section if not completed there)

### Additional Phase 2 Tasks

- [ ] Certificate templates normalized
  - AD CS templates mapped to Keyfactor: ________________
  - OR EJBCA profiles created: ________________
  - Date: ________________

- [ ] CRL/OCSP monitoring configured
  - CRL freshness check: Every _____ hours
  - OCSP response time alert: >_____ ms
  - Health dashboard: ________________
  - Date: ________________

- [ ] CA backup procedures documented
  - Backup location: ________________
  - Restore tested: ________________
  - Date: ________________

- [ ] HSM key ceremony documented (if applicable)
  - Ceremony date: ________________
  - Witnesses: ________________
  - Video recorded: ________________
  - Documentation: ________________

### Exit Criteria

- [ ] CA integrated and issuing via Keyfactor
- [ ] HSM protecting issuing CA keys (if EJBCA)
- [ ] CRL/OCSP operational and monitored
- [ ] Templates normalized and tested
- [ ] End-to-end issuance working: request → Keyfactor → CA → certificate
- [ ] Revocation working: revoke → CRL/OCSP updated <1 hour

**Phase 2 Status**: [ ] Not Started | [ ] In Progress | [ ] Complete | [ ] Blocked

---

## Phase 3: Enrollment Rails (Weeks 10-13)

**Target Dates**: [Insert Start] - [Insert End]  
**Owner**: Platform Engineer + Keyfactor Operator

### Kubernetes + cert-manager (Week 10)

- [ ] cert-manager installed
  - Cluster: ________________
  - Version: ________________
  - Date: ________________

- [ ] Keyfactor Issuer plugin installed
  - Plugin: ________________
  - Version: ________________
  - Date: ________________

- [ ] Keyfactor API credentials created
  - ServiceAccount: cert-manager
  - API key generated: ________________
  - Secret created in K8s: ________________
  - Date: ________________

- [ ] ClusterIssuer configured
  - Name: keyfactor-issuer
  - Template: ________________
  - Status: Ready
  - Date: ________________

- [ ] Test application deployed
  - App: ________________
  - Certificate issued: ________________
  - Ingress serving HTTPS: ________________
  - Date: ________________

- [ ] Renewal tested
  - Cert lifetime reduced to 1hr for test: ________________
  - Auto-renewal verified: ________________
  - Date: ________________

- [ ] Scaled to 5+ apps
  - Apps: ________________
  - Date: ________________

### Windows Auto-Enrollment (Week 11)

- [ ] GPO created
  - Name: Certificate Auto-Enrollment - Pilot Servers
  - OU: ________________
  - Date: ________________

- [ ] Auto-enrollment configured in GPO
  - Computer Config → Cert Services Client - Auto-Enrollment: Enabled
  - Date: ________________

- [ ] Certificate template published (AD CS)
  - Template: Windows-Domain-Computer
  - Permissions: Domain Computers (Enroll)
  - Date: ________________

- [ ] GPO applied to pilot servers
  - Servers: ________________ (count: _____)
  - Date: ________________

- [ ] GPO forced on pilot servers
  - Command: gpupdate /force
  - Certs issued: _______ / _______ servers
  - Date: ________________

- [ ] Keyfactor orchestrator configured for IIS
  - Store type: IIS
  - Servers: ________________
  - Auto-bind enabled: ________________
  - Date: ________________

- [ ] Renewal tested
  - Test server: ________________
  - IIS binding updated automatically: ________________
  - Date: ________________

### ACME for Web Servers (Week 12)

- [ ] ACME directory configured in Keyfactor
  - URL: https://keyfactor.contoso.com/acme/________________
  - Template: ________________
  - Allowed domains: ________________
  - Date: ________________

- [ ] DNS integration configured (for DNS-01)
  - Provider: Azure DNS / Route53 / Other
  - Zones: ________________
  - Date: ________________

- [ ] ACME client installed on pilot server
  - Server: ________________
  - Client: certbot / win-acme / acme.sh
  - Date: ________________

- [ ] Certificate requested via ACME
  - Domain: ________________
  - Challenge: HTTP-01 / DNS-01
  - Certificate issued: ________________
  - Date: ________________

- [ ] Automatic renewal configured
  - Method: cron / Scheduled Task
  - Test run: ________________
  - Date: ________________

- [ ] Scaled to 5+ servers
  - Servers: ________________
  - Date: ________________

### SCEP for Intune Devices (Week 13, optional)

- [ ] SCEP endpoint configured in Keyfactor
  - URL: ________________
  - Template: Device-Auth-SCEP
  - Date: ________________

- [ ] SCEP profile created in Intune
  - Profile name: ________________
  - Template: Device
  - Subject: CN={{DeviceId}}
  - Date: ________________

- [ ] Profile assigned to pilot device group
  - Group: ________________
  - Devices: _______ (count)
  - Date: ________________

- [ ] Devices enrolled
  - Successful enrollments: _______ / _______
  - Certs visible in Keyfactor: ________________
  - Date: ________________

### Exit Criteria

- [ ] 3-4 enrollment rails operational
- [ ] Pilot workloads issuing and renewing certs automatically
- [ ] No critical issues blocking scale
- [ ] Procedures documented for each rail

**Phase 3 Status**: [ ] Not Started | [ ] In Progress | [ ] Complete | [ ] Blocked

---

## Phase 4: Automation & Eventing (Weeks 14-16)

**Target Dates**: [Insert Start] - [Insert End]  
**Owner**: Automation Engineer + Platform Engineer

### Webhook Infrastructure

- [ ] Webhooks configured in Keyfactor
  - Event: certificate_issued
  - Event: certificate_renewed
  - Event: certificate_expiring (T-30d, T-7d, T-1d)
  - Event: certificate_revoked
  - Event: renewal_failed
  - Date: ________________

- [ ] Webhook receiver deployed
  - Platform: Azure Logic App / AWS Lambda / Other
  - URL: ________________
  - Authentication: HMAC / mTLS
  - Date: ________________

- [ ] Webhook delivery tested
  - Test event sent: ________________
  - Received successfully: ________________
  - Date: ________________

### Automation Playbooks

- [ ] **IIS Web Server Renewal Automation**
  - Pipeline: ________________
  - Steps: Fetch cert → Key Vault → Deploy → Verify → Log
  - Test server: ________________
  - Test result: ________________
  - Date: ________________

- [ ] **Kubernetes Automation** (cert-manager handles, but verify)
  - cert-manager auto-renewal verified: ________________
  - Monitoring configured: ________________
  - Date: ________________

- [ ] **Load Balancer Automation** (if in scope)
  - Load balancer: ________________ (F5, Azure App Gateway, etc.)
  - Pipeline: ________________
  - Test result: ________________
  - Date: ________________

- [ ] **Vault/Key Vault Integration**
  - Write renewed cert to Key Vault: ________________
  - Publish event to apps: ________________
  - App reload tested: ________________
  - Date: ________________

### Failure Handling

- [ ] Retry logic implemented
  - Max retries: _______
  - Backoff: Exponential / Linear
  - Date: ________________

- [ ] Rollback automation implemented
  - Test rollback: ________________
  - Successful restore of previous cert: ________________
  - Date: ________________

- [ ] Alerting configured
  - Renewal failure → ServiceNow incident: ________________
  - Page on-call after 3 failures: ________________
  - Date: ________________

- [ ] Dead-letter queue configured
  - Failed webhooks logged: ________________
  - Manual review process: ________________
  - Date: ________________

### Break-Glass Procedures

- [ ] Break-glass procedures documented
  - Manual cert issuance: ________________
  - Emergency revocation: ________________
  - Rollback commands: ________________
  - Location: [10-Incident-Response-Procedures.md](./10-Incident-Response-Procedures.md)
  - Date: ________________

- [ ] Break-glass tested
  - Test scenario: Expired cert, manual renewal needed
  - Test result: ________________
  - Date: ________________

### Exit Criteria

- [ ] Webhook automation for top 3 workload types
- [ ] Pilot renewals ≥95% successful (automated)
- [ ] Failures handled gracefully (rollback + alert)
- [ ] Break-glass procedures documented and tested

**Phase 4 Status**: [ ] Not Started | [ ] In Progress | [ ] Complete | [ ] Blocked

---

## Phase 5: Pilot & Scale (Weeks 17-21)

**Target Dates**: [Insert Start] - [Insert End]  
**Owner**: All team members

### Expand Scope (Weeks 17-18)

- [ ] **Windows: Expand GPO**
  - Expanded to OUs: ________________
  - Total servers: _______ (from _____ in pilot)
  - Date: ________________

- [ ] **Kubernetes: Deploy to remaining clusters**
  - Clusters: ________________
  - Total clusters: _______
  - Date: ________________

- [ ] **ACME: Publish to all teams**
  - Documentation published: ________________
  - Self-service guide: ________________
  - Date: ________________

- [ ] **CI/CD enforcement (warning mode)**
  - Pipeline: ________________
  - Block unmanaged certs: Warning only (not hard block)
  - Date: ________________

### Policy Enforcement (Week 19)

- [ ] SAN validation enabled (hard block)
  - Denials logged: _______ (review for false positives)
  - Date: ________________

- [ ] Key size enforcement enabled
  - Minimum RSA: 3072 bits
  - Minimum ECDSA: 256 bits
  - Denials: _______
  - Date: ________________

- [ ] Drift detection enabled
  - Unmanaged certs tagged: _______
  - Alerts sent to security team: ________________
  - Date: ________________

- [ ] Lifetime enforcement enabled
  - Public: ≤398 days
  - Internal: ≤730 days
  - Denials: _______
  - Date: ________________

### Measure KPIs (Week 20)

- [ ] **Auto-renewal rate**: _______ % (target: ≥95%)
- [ ] **Time-to-issue**: _______ minutes (target: ≤2 min)
- [ ] **Renewal MTTR**: _______ minutes (target: ≤5 min)
- [ ] **Unmanaged cert %**: _______ % (target: ≤5%)
- [ ] **Certificate visibility**: _______ % (target: ≥98%)
- [ ] **Cert-related incidents**: _______ (target: ≤1/month)

- [ ] KPI review with stakeholders
  - Meeting date: ________________
  - Gaps identified: ________________
  - Remediation plan: ________________

### Turn On Enforcement (Week 21)

- [ ] **Mandatory management in CI/CD** (hard block)
  - Pipelines updated: ________________
  - Deployment blocked if unmanaged cert: ________________
  - Date: ________________

- [ ] **Policy violations hard-blocked**
  - No longer warnings, all denials enforced
  - Communication sent to teams: ________________
  - Date: ________________

- [ ] **Drift control: Auto-revoke unmanaged certs**
  - Grace period: 30 days (with notifications)
  - Notifications sent: T-30d, T-7d, T-1d
  - First auto-revocation: ________________
  - Date: ________________

### Exit Criteria

- [ ] ≥90% of certificates under Keyfactor management
- [ ] Auto-renewal rate ≥95%
- [ ] All KPI targets met for 2 consecutive weeks
- [ ] Policies enforced (no exceptions without approval)
- [ ] No critical issues blocking production scale

**Phase 5 Status**: [ ] Not Started | [ ] In Progress | [ ] Complete | [ ] Blocked

---

## Phase 6: Operate & Optimize (Ongoing)

**Target Dates**: Week 22+  
**Owner**: Operations Team + PKI Operators

### Operational Activities

#### Monthly

- [ ] **Month 1**: Review KPIs and dashboards
  - Auto-renewal rate: _______ %
  - Failed renewals: _______
  - Unmanaged certs: _______
  - Date: ________________

- [ ] **Month 2**: Triage failed renewals
  - Root cause analysis completed: _______
  - Corrective actions: ________________
  - Date: ________________

- [ ] **Month 3**: CMDB reconciliation
  - Ownership data refreshed: ________________
  - Orphaned certs identified: _______
  - Date: ________________

#### Quarterly

- [ ] **Q1**: Policy review
  - Templates reviewed: ________________
  - Changes needed: ________________
  - Date: ________________

- [ ] **Q1**: Access review
  - Users with PKI roles: _______
  - Removed departed employees: _______
  - Date: ________________

- [ ] **Q2**: Capacity planning
  - Orchestrator capacity sufficient: Yes / No
  - Action: ________________
  - Date: ________________

- [ ] **Q3**: Vendor review
  - Keyfactor product updates: ________________
  - New features to adopt: ________________
  - Date: ________________

#### Annually

- [ ] **Year 1**: CRL/OCSP failover drill
  - Date: ________________
  - Result: ________________

- [ ] **Year 1**: Key compromise drill
  - Scenario: CA key compromise, full reissuance
  - Date: ________________
  - Result: ________________

- [ ] **Year 1**: DR test
  - Restore Keyfactor from backup
  - Date: ________________
  - Result: ________________

- [ ] **Year 1**: Penetration test
  - PKI infrastructure in scope
  - Date: ________________
  - Findings: ________________

### Future Enhancements (Phase 7+)

- [ ] Short-lived certificates (24h for service mesh)
- [ ] SPIFFE/SPIRE integration
- [ ] Code signing workflow
- [ ] Document signing (S/MIME)
- [ ] Quantum-safe algorithms (when standards mature)

**Phase 6 Status**: [ ] Not Started | [ ] In Progress | [ ] Ongoing

---

## Overall Project Status

**Current Phase**: ________________  
**Overall Status**: [ ] On Track | [ ] At Risk | [ ] Blocked  
**Go-Live Date (Phase 5 complete)**: ________________

### Risks & Issues

| # | Risk/Issue | Impact | Owner | Mitigation | Status |
|---|-----------|--------|-------|------------|--------|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |

### Change Log

| Date | Change | Reason | Approved By |
|------|--------|--------|-------------|
| 2025-10-22 | Initial tracker created | Project kickoff | Adrian Johnson |
| | | | |
| | | | |

---

## Weekly Status Report Template

**Week of**: ________________  
**Phase**: ________________  
**Owner**: ________________

**Completed This Week**:
- 
- 

**Planned for Next Week**:
- 
- 

**Blockers**:
- 

**Risks**:
- 

**Metrics** (if Phase 5+):
- Auto-renewal rate: _______ %
- Time-to-issue: _______ min
- Unmanaged certs: _______ %

---

## Contact

**Project Lead**: Adrian Johnson <adrian207@gmail.com>  
**Status Updates**: Weekly (every Friday)  
**Stakeholder Meetings**: Bi-weekly  
**Project Channel**: #pki-implementation (Slack)

---

**Last Updated**: ________________  
**Updated By**: ________________

