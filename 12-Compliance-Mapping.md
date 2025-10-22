# Keyfactor Compliance Mapping
## Regulatory Framework and Control Mapping

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use - Confidential  
**Target Audience**: Compliance team, auditors, CISO, legal

---

## Document Purpose

This document maps the Keyfactor PKI platform's security controls to applicable regulatory and compliance frameworks. It provides auditors and compliance teams with detailed control mappings, evidence artifacts, and compliance status for SOC 2, PCI-DSS, ISO 27001, and FedRAMP.

---

## Table of Contents

1. [Compliance Framework Overview](#1-compliance-framework-overview)
2. [SOC 2 Type II Mapping](#2-soc-2-type-ii-mapping)
3. [PCI-DSS v4.0 Mapping](#3-pci-dss-v40-mapping)
4. [ISO 27001:2022 Mapping](#4-iso-270012022-mapping)
5. [FedRAMP Moderate Mapping](#5-fedramp-moderate-mapping)
6. [Evidence Collection](#6-evidence-collection)
7. [Control Testing](#7-control-testing)
8. [Compliance Status Dashboard](#8-compliance-status-dashboard)

---

## 1. Compliance Framework Overview

### 1.1 Applicable Frameworks

| Framework | Version | Applicability | Status | Last Audit |
|-----------|---------|--------------|--------|------------|
| **SOC 2 Type II** | 2023 TSC | All services | ✅ Compliant | Q3 2025 |
| **PCI-DSS** | v4.0 | Payment card cert management | ✅ Compliant | Q2 2025 |
| **ISO 27001** | 2022 | Information security | ✅ Certified | Q1 2025 |
| **FedRAMP** | Moderate | Federal cloud services | 🚧 In Progress | Target: Q1 2026 |
| **HIPAA** | 2013 | Healthcare cert management | ✅ Compliant | Q3 2025 |
| **NIST CSF** | v1.1 | Overall security framework | ✅ Aligned | Q3 2025 |

---

### 1.2 Compliance Scope

**In-Scope Systems**:
- Keyfactor Command platform (web application, API)
- Certificate Authorities (AD CS, EJBCA)
- HSM infrastructure (Thales Luna)
- SQL Server database
- Orchestrator agents
- Supporting infrastructure (network, storage, backup)

**Out-of-Scope**:
- End-user workstations
- Certificate end-use (application-specific usage)
- Third-party certificate stores (customer-managed)

---

### 1.3 Shared Responsibility Model

| Component | Keyfactor Platform Owner | Service Owner | Auditor |
|-----------|-------------------------|---------------|---------|
| **PKI Infrastructure** | Responsible | Consumes services | Reviews |
| **Certificate Issuance** | Provides capability | Requests certificates | Audits requests |
| **Certificate Usage** | - | Responsible | Reviews usage |
| **Access Control** | Enforces RBAC | Requests access | Reviews access |
| **Audit Logging** | Collects and retains | Views relevant logs | Reviews all logs |
| **Compliance Evidence** | Provides infrastructure evidence | Provides usage evidence | Reviews all evidence |

---

## 2. SOC 2 Type II Mapping

### 2.1 Trust Services Criteria Overview

**SOC 2 Report Period**: January 1, 2025 - December 31, 2025  
**Auditor**: Deloitte & Touche LLP  
**Opinion**: Unqualified (no exceptions)

**Trust Services Categories**:
- CC: Common Criteria
- A: Availability
- C: Confidentiality
- P: Processing Integrity
- PI: Privacy *(Not applicable - no PII processed)*

---

### 2.2 Common Criteria (CC) Mapping

#### CC6: Logical and Physical Access Controls

| Control | TSC | Keyfactor Implementation | Evidence | Test Frequency |
|---------|-----|-------------------------|----------|----------------|
| **CC6.1** Logical access (users) | CC6.1 | Azure AD SSO + MFA, RBAC roles | User access review report, MFA enrollment | Quarterly |
| **CC6.2** Logical access (privileged) | CC6.2 | Smart card auth for admins, break-glass procedures | Privileged access review, break-glass log | Quarterly |
| **CC6.3** Logical access (credentials) | CC6.3 | 14-char minimum password, 90-day rotation | Password policy config, audit log | Annual |
| **CC6.4** Logical access (new/modified) | CC6.4 | Access request workflow in ServiceNow | Access request tickets | Quarterly (sample) |
| **CC6.5** Logical access (removed) | CC6.5 | Automated deprovisioning on termination | Terminated employee report, access removal log | Quarterly |
| **CC6.6** Physical access | CC6.6 | Badge access to data center, video surveillance | Badge access log, visitor log | Semi-annual |
| **CC6.7** Logical access (removal) | CC6.7 | 90-day inactive account review | Inactive account report | Quarterly |
| **CC6.8** Logical access (restriction) | CC6.8 | Firewall rules, network segmentation | Firewall rule review, network diagram | Annual |

**Control Effectiveness**: ✅ No exceptions noted

---

#### CC7: System Operations

| Control | TSC | Keyfactor Implementation | Evidence | Test Frequency |
|---------|-----|-------------------------|----------|----------------|
| **CC7.1** Threat detection | CC7.1 | IDS/IPS (Snort), SIEM (Splunk), anomaly detection | SIEM alerts, threat detection report | Quarterly |
| **CC7.2** Monitoring | CC7.2 | 24/7 SOC, Grafana dashboards, PagerDuty alerts | Monitoring dashboard, alert response log | Quarterly |
| **CC7.3** Change detection | CC7.3 | File integrity monitoring (Tripwire), config versioning | FIM alerts, Git commit log | Quarterly |
| **CC7.4** Incident response | CC7.4 | Documented IR procedures, tabletop exercises | IR runbook, incident tickets, exercise reports | Annual |
| **CC7.5** Service resiliency | CC7.5 | HA architecture, DR site, failover testing | DR test results, uptime reports | Semi-annual |

**Control Effectiveness**: ✅ No exceptions noted

---

#### CC8: Change Management

| Control | TSC | Keyfactor Implementation | Evidence | Test Frequency |
|---------|-----|-------------------------|----------|----------------|
| **CC8.1** Change management | CC8.1 | ITIL change process, change board approval | Change tickets, approval emails | Quarterly (sample) |

**Control Effectiveness**: ✅ No exceptions noted

---

### 2.3 Availability (A1) Mapping

| Control | TSC | Keyfactor Implementation | Evidence | Test Frequency | Target | Actual |
|---------|-----|-------------------------|----------|----------------|--------|--------|
| **A1.1** Availability commitments | A1.1 | SLA: 99.9% uptime, RTO: 4hr, RPO: 1hr | SLA document | Annual | 99.9% | 99.95% ✅ |
| **A1.2** Availability monitoring | A1.2 | Grafana monitoring, uptime tracking | Uptime reports | Quarterly | 99.9% | 99.95% ✅ |
| **A1.3** Capacity management | A1.3 | Quarterly capacity reviews, growth projections | Capacity reports | Quarterly | 80% max | 65% ✅ |

**Control Effectiveness**: ✅ Exceeded availability target

---

### 2.4 Confidentiality (C1) Mapping

| Control | TSC | Keyfactor Implementation | Evidence | Test Frequency |
|---------|-----|-------------------------|----------|----------------|
| **C1.1** Data classification | C1.1 | Formal data classification policy, CA keys = Critical | Data classification policy | Annual |
| **C1.2** Encryption (at rest) | C1.2 | SQL TDE, BitLocker, AES-256 for backups | Encryption verification report | Semi-annual |
| **C1.3** Encryption (in transit) | C1.3 | TLS 1.2/1.3 only, mutual TLS for APIs | TLS scan results (Qualys SSL Labs) | Quarterly |
| **C1.4** Data disposal | C1.4 | Secure erase (7-pass overwrite), documented destruction | Disposal log, certificate of destruction | Annual |

**Control Effectiveness**: ✅ No exceptions noted

---

## 3. PCI-DSS v4.0 Mapping

### 3.1 PCI-DSS Applicability

**Scope**: Certificates used for payment card processing infrastructure

**Merchant Level**: Level 1 (processes > 6M transactions/year)

**Assessor**: PCI QSA (Qualified Security Assessor)

**Last Assessment**: Q2 2025

**Report on Compliance (ROC) Status**: Compliant

---

### 3.2 PCI-DSS Requirements Mapping

#### Requirement 1: Install and maintain network security controls

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **1.2.1** | Firewall rules documented | Firewall rules document, change control | Firewall rule export, change tickets | ✅ Compliant |
| **1.2.5** | Restrict inbound/outbound traffic | Default-deny firewall policy, allow-list only | Firewall config review | ✅ Compliant |
| **1.3.1** | DMZ implementation | 4-tier architecture (external, DMZ, backend, secure) | Network diagram | ✅ Compliant |
| **1.4.2** | Restrict connections between untrusted networks | No direct internet access to backend, jump box for admin | Network flow analysis | ✅ Compliant |

---

#### Requirement 2: Apply secure configurations

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **2.2.1** | Configuration standards | Windows/Linux hardening standards (CIS Benchmarks) | Hardening scripts, CIS scan results | ✅ Compliant |
| **2.2.2** | Vendor defaults changed | All default passwords changed, unnecessary services disabled | Configuration review checklist | ✅ Compliant |
| **2.2.4** | Inventory of system components | CMDB with all Keyfactor components | CMDB export | ✅ Compliant |
| **2.2.7** | Encrypted admin access | SSH key-based (Linux), RDP over VPN (Windows), no Telnet | SSH config, VPN logs | ✅ Compliant |

---

#### Requirement 3: Protect stored account data

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **3.2.1** | Limit data storage | No cardholder data (CHD) stored in Keyfactor; certificates only | Data flow diagram | ✅ N/A (No CHD stored) |
| **3.4.1** | Strong cryptography | CA keys in FIPS 140-2 Level 3 HSM, TDE for database | HSM validation cert, TDE config | ✅ Compliant |
| **3.5.1** | Protect cryptographic keys | CA keys never leave HSM, dual control for key operations | HSM access log, SO/CO procedures | ✅ Compliant |

---

#### Requirement 4: Protect cardholder data with strong cryptography during transmission

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **4.2.1** | Strong cryptography for transmission | TLS 1.2/1.3 only, strong cipher suites | TLS configuration, Qualys SSL scan (A+) | ✅ Compliant |
| **4.2.2** | No unencrypted PANs | N/A - No PANs transmitted | Data flow diagram | ✅ N/A |

---

#### Requirement 6: Develop and maintain secure systems and software

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **6.2.1** | Inventory of software | Software inventory in CMDB, version tracking | CMDB software inventory | ✅ Compliant |
| **6.2.2** | Security patches | Monthly patching cycle, critical patches within 30 days | Patch management reports | ✅ Compliant |
| **6.3.3** | Vulnerability identification | Quarterly vulnerability scans (Qualys) | Scan reports | ✅ Compliant |
| **6.4.2** | Code reviews | Code review for custom scripts, documented in Git | Git pull requests with reviews | ✅ Compliant |

---

#### Requirement 8: Identify users and authenticate access

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **8.2.1** | Unique user IDs | All users have unique Azure AD accounts | User list export | ✅ Compliant |
| **8.3.1** | MFA for all access | MFA required for all users (Microsoft Authenticator) | MFA enrollment report | ✅ Compliant |
| **8.3.2** | Strong authentication | Smart cards for admins, certificate-based for APIs | Smart card policy, API cert config | ✅ Compliant |
| **8.3.6** | Limit repeated access attempts | Account lockout after 5 failed attempts | Account lockout policy | ✅ Compliant |

---

#### Requirement 10: Log and monitor all access to system components

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **10.2.1** | Audit logs for all users | All certificate operations logged (issuance, revocation, etc.) | Audit log sample | ✅ Compliant |
| **10.2.2** | Audit logs for privileged users | Admin actions logged separately, reviewed weekly | Privileged access log, review notes | ✅ Compliant |
| **10.3.1** | Accurate time | NTP sync to [time.nist.gov](http://time.nist.gov), monitored | NTP config, time sync status | ✅ Compliant |
| **10.4.1** | Log review | Daily automated review, weekly manual review | Log review reports, SIEM alerts | ✅ Compliant |
| **10.7.2** | Log protection | Append-only logs, write-once storage, SIEM forwarding | Log integrity config | ✅ Compliant |

---

#### Requirement 12: Support information security with organizational policies

| Requirement | PCI-DSS Control | Keyfactor Implementation | Evidence | Compliance Status |
|------------|----------------|-------------------------|----------|-------------------|
| **12.1.1** | Information security policy | PKI Security Policy, reviewed annually | Policy document, review sign-off | ✅ Compliant |
| **12.3.1** | Acceptable use policy | Acceptable Use Policy, acknowledged by all users | AUP document, user acknowledgments | ✅ Compliant |
| **12.6.1** | Security awareness training | Annual security training, quarterly phishing tests | Training completion report | ✅ Compliant |
| **12.8.1** | Service provider management | Keyfactor vendor SLA, annual review | Vendor SLA, review notes | ✅ Compliant |

---

**PCI-DSS Overall Compliance Status**: ✅ **COMPLIANT** (No findings)

---

## 4. ISO 27001:2022 Mapping

### 4.1 ISO 27001 Certification Status

**Certification Body**: BSI (British Standards Institution)

**Certificate Number**: ISO27001-2025-CONTOSO-PKI

**Certification Date**: January 15, 2025

**Expiry Date**: January 15, 2028 (3-year cert)

**Surveillance Audits**: Semi-annual (next: July 2026)

**Scope**: Certificate lifecycle management services

---

### 4.2 Annex A Controls Mapping

#### A.5: Organizational Controls

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.5.1** | Policies for information security | PKI Security Policy, reviewed annually by CISO | Policy document v3.2 | ✅ Implemented |
| **A.5.2** | Information security roles | RACI matrix, roles defined in RBAC model | RACI matrix, role definitions | ✅ Implemented |
| **A.5.7** | Threat intelligence | Subscription to Keyfactor security bulletins, CISA alerts | Email subscriptions, bulletin archive | ✅ Implemented |
| **A.5.10** | Acceptable use | Acceptable Use Policy (AUP), signed by all users | AUP v2.1, signature log | ✅ Implemented |
| **A.5.23** | Information security in cloud services | Azure cloud security baseline applied | Azure security config | ✅ Implemented |

---

#### A.8: Asset Management

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.8.1** | Inventory of assets | CMDB with all PKI assets (servers, HSMs, certificates) | CMDB export dated 2025-10-20 | ✅ Implemented |
| **A.8.2** | Ownership of assets | Asset owners assigned in CMDB, quarterly review | Asset ownership report | ✅ Implemented |
| **A.8.3** | Acceptable use | AUP covers asset usage, acknowledged by users | AUP acknowledgment log | ✅ Implemented |
| **A.8.10** | Information deletion | Secure deletion policy (7-pass overwrite), disposal log | Disposal log, shred certificates | ✅ Implemented |

---

#### A.9: Access Control

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.9.1** | Access control policy | RBAC policy, least privilege principle | RBAC policy v4.0 | ✅ Implemented |
| **A.9.2** | User access management | Formal access request/approval workflow | ServiceNow tickets | ✅ Implemented |
| **A.9.3** | User responsibilities | Users acknowledge responsibilities in AUP | AUP acknowledgments | ✅ Implemented |
| **A.9.4** | System and application access | MFA for all access, smart cards for privileged | MFA enrollment report | ✅ Implemented |

---

#### A.10: Cryptography

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.10.1** | Cryptographic controls | Cryptographic standards document (RSA 2048+, AES-256, TLS 1.2+) | Crypto standards v2.0 | ✅ Implemented |

---

#### A.12: Operations Security

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.12.1** | Operational procedures | Documented runbooks for all operations | Runbook index (15 procedures) | ✅ Implemented |
| **A.12.2** | Protection from malware | Antivirus (Windows Defender), endpoint protection | AV status report | ✅ Implemented |
| **A.12.3** | Backup | Daily backups, 30-day retention, tested monthly | Backup logs, restore test results | ✅ Implemented |
| **A.12.4** | Logging and monitoring | Comprehensive audit logging, 7-year retention | Audit log config, retention policy | ✅ Implemented |
| **A.12.6** | Vulnerability management | Quarterly scans (Qualys), patch within 30 days | Vulnerability scan reports | ✅ Implemented |

---

#### A.13: Communications Security

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.13.1** | Network security | Firewall segmentation, IDS/IPS (Snort) | Network diagram, firewall rules | ✅ Implemented |
| **A.13.2** | Information transfer | TLS 1.2/1.3 for all data in transit | TLS configuration, SSL Labs A+ | ✅ Implemented |

---

#### A.14: System Acquisition, Development and Maintenance

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.14.1** | Security requirements | Security requirements in change tickets | Change ticket template | ✅ Implemented |
| **A.14.2** | Security in development | Secure coding guidelines, code review process | Secure coding policy, Git reviews | ✅ Implemented |

---

#### A.16: Incident Management

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.16.1** | Incident response | Incident response plan, runbook, 24/7 on-call | IR runbook, PagerDuty schedule | ✅ Implemented |

---

#### A.17: Business Continuity

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.17.1** | Business continuity | DR plan (RTO: 4hr, RPO: 1hr), semi-annual tests | DR plan v3.0, DR test reports | ✅ Implemented |
| **A.17.2** | Redundancies | HA architecture, DR site, HSM redundancy | Architecture diagram, DR site inventory | ✅ Implemented |

---

#### A.18: Compliance

| Control | ISO 27001 Annex A | Keyfactor Implementation | Evidence | Status |
|---------|-------------------|-------------------------|----------|--------|
| **A.18.1** | Compliance with legal requirements | Legal hold process, data residency controls | Legal hold procedure, data map | ✅ Implemented |
| **A.18.2** | Independent review | Annual internal audit, ISO 27001 external audit | Internal audit report, ISO cert | ✅ Implemented |

---

**ISO 27001 Overall Status**: ✅ **CERTIFIED** (No major nonconformities)

---

## 5. FedRAMP Moderate Mapping

### 5.1 FedRAMP Authorization Status

**Status**: Authorization in Progress (Target: Q1 2026)

**Baseline**: Moderate Impact Level

**Sponsoring Agency**: TBD

**3PAO (Third Party Assessment Organization)**: A-LIGN

**Current Phase**: Security Assessment (pre-authorization)

---

### 5.2 NIST SP 800-53 Rev 5 Control Families

**Total Controls**: 325 (FedRAMP Moderate baseline)

**Implementation Status**:
- Fully Implemented: 285 (88%)
- Partially Implemented: 35 (11%)
- Planned: 5 (1%)

---

### 5.3 Key Control Mappings

#### AC: Access Control

| Control | NIST 800-53 | Keyfactor Implementation | Evidence | Status |
|---------|-------------|-------------------------|----------|--------|
| **AC-2** | Account Management | Automated provisioning/deprovisioning, 90-day review | User access review reports | ✅ Implemented |
| **AC-2(1)** | Automated System Account Management | Azure AD integration, ServiceNow workflow | Integration diagram | ✅ Implemented |
| **AC-3** | Access Enforcement | RBAC enforced by application and AD groups | RBAC policy, test results | ✅ Implemented |
| **AC-6** | Least Privilege | Role-based permissions, quarterly reviews | Permissions matrix | ✅ Implemented |
| **AC-6(1)** | Least Privilege - Authorize Access to Security Functions | PKI Admin role restricted (max 2 users) | Role assignment list | ✅ Implemented |
| **AC-7** | Unsuccessful Logon Attempts | Account lockout after 5 failures, 30-min duration | Lockout policy config | ✅ Implemented |
| **AC-17** | Remote Access | VPN required, MFA enforced | VPN config, MFA report | ✅ Implemented |

---

#### AU: Audit and Accountability

| Control | NIST 800-53 | Keyfactor Implementation | Evidence | Status |
|---------|-------------|-------------------------|----------|--------|
| **AU-2** | Event Logging | All security-relevant events logged | Audit logging config | ✅ Implemented |
| **AU-3** | Content of Audit Records | Logs include: timestamp, user, action, outcome | Sample audit logs | ✅ Implemented |
| **AU-4** | Audit Log Storage | 7-year retention, append-only storage | Storage config, retention policy | ✅ Implemented |
| **AU-6** | Audit Record Review | Daily automated review, weekly manual | Review reports, SIEM rules | ✅ Implemented |
| **AU-9** | Protection of Audit Information | Logs write-once, SIEM forwarding, hash verification | Log protection config | ✅ Implemented |
| **AU-11** | Audit Record Retention | 7-year retention per compliance requirements | Retention policy document | ✅ Implemented |

---

#### CM: Configuration Management

| Control | NIST 800-53 | Keyfactor Implementation | Evidence | Status |
|---------|-------------|-------------------------|----------|--------|
| **CM-2** | Baseline Configuration | OS/app hardening baselines (CIS) | Baseline configs, scan results | ✅ Implemented |
| **CM-3** | Configuration Change Control | ITIL change management, change board | Change tickets, board minutes | ✅ Implemented |
| **CM-6** | Configuration Settings | Hardening applied per CIS benchmarks | CIS scan reports (90%+ compliance) | ✅ Implemented |
| **CM-7** | Least Functionality | Unnecessary services disabled | Service inventory, disabled services list | ✅ Implemented |
| **CM-8** | System Component Inventory | CMDB with all components | CMDB export | ✅ Implemented |

---

#### CP: Contingency Planning

| Control | NIST 800-53 | Keyfactor Implementation | Evidence | Status |
|---------|-------------|-------------------------|----------|--------|
| **CP-2** | Contingency Plan | DR/BCP plan (RTO: 4hr, RPO: 1hr) | DR plan v3.0 | ✅ Implemented |
| **CP-3** | Contingency Training | Annual DR training, tabletop exercises | Training records, exercise reports | ✅ Implemented |
| **CP-4** | Contingency Plan Testing | Semi-annual DR failover tests | DR test reports (Q1, Q3 2025) | ✅ Implemented |
| **CP-6** | Alternate Storage Site | DR site 100 miles from primary | DR site lease, inventory | ✅ Implemented |
| **CP-7** | Alternate Processing Site | Warm standby in DR site | DR architecture diagram | ✅ Implemented |
| **CP-9** | System Backup | Daily backups, monthly restore tests | Backup logs, restore test results | ✅ Implemented |
| **CP-10** | System Recovery and Reconstitution | Documented recovery procedures | Recovery runbooks | ✅ Implemented |

---

#### IA: Identification and Authentication

| Control | NIST 800-53 | Keyfactor Implementation | Evidence | Status |
|---------|-------------|-------------------------|----------|--------|
| **IA-2** | User Identification and Authentication | Unique user IDs (Azure AD) | User list | ✅ Implemented |
| **IA-2(1)** | MFA for Network Access | MFA required for all users | MFA enrollment (100%) | ✅ Implemented |
| **IA-2(2)** | MFA for Local/Non-Network Access | Smart card for privileged local access | Smart card policy | ✅ Implemented |
| **IA-2(12)** | PIV-Compliant Credentials | Smart cards are PIV-compliant | Smart card cert policy OID | 🚧 In Progress |
| **IA-5** | Authenticator Management | 14-char minimum, 90-day rotation | Password policy | ✅ Implemented |
| **IA-5(1)** | Password-Based Authentication | Passwords hashed (bcrypt), salted | Password storage config | ✅ Implemented |

---

#### IR: Incident Response

| Control | NIST 800-53 | Keyfactor Implementation | Evidence | Status |
|---------|-------------|-------------------------|----------|--------|
| **IR-2** | Incident Response Training | Annual IR training, quarterly tabletop | Training records | ✅ Implemented |
| **IR-4** | Incident Handling | Documented IR procedures, 24/7 on-call | IR runbook, PagerDuty | ✅ Implemented |
| **IR-5** | Incident Monitoring | SIEM monitoring, automated alerts | SIEM config, alert log | ✅ Implemented |
| **IR-6** | Incident Reporting | All incidents logged in ServiceNow, reported to CISO | Incident tickets | ✅ Implemented |
| **IR-7** | Incident Response Assistance | Keyfactor 24/7 support, HSM vendor support | Support contracts | ✅ Implemented |
| **IR-8** | Incident Response Plan | Comprehensive IR plan covering P1-P4 incidents | IR plan v2.0 | ✅ Implemented |

---

#### SC: System and Communications Protection

| Control | NIST 800-53 | Keyfactor Implementation | Evidence | Status |
|---------|-------------|-------------------------|----------|--------|
| **SC-7** | Boundary Protection | Firewall segmentation (4 zones), IDS/IPS | Network diagram, firewall rules | ✅ Implemented |
| **SC-8** | Transmission Confidentiality/Integrity | TLS 1.2/1.3 for all data in transit | TLS config, SSL Labs A+ | ✅ Implemented |
| **SC-12** | Cryptographic Key Management | CA keys in FIPS 140-2 Level 3 HSM | HSM validation cert, key mgmt procedures | ✅ Implemented |
| **SC-13** | Cryptographic Protection | FIPS-approved algorithms (RSA 2048+, AES-256) | Crypto standards doc | ✅ Implemented |
| **SC-28** | Protection of Information at Rest | SQL TDE, BitLocker, encrypted backups | Encryption config | ✅ Implemented |

---

**FedRAMP Status**: 🚧 **AUTHORIZATION IN PROGRESS** (88% controls implemented, on track for Q1 2026)

---

## 6. Evidence Collection

### 6.1 Evidence Artifacts by Framework

| Evidence Type | SOC 2 | PCI-DSS | ISO 27001 | FedRAMP | Storage Location | Owner |
|--------------|-------|---------|-----------|---------|------------------|-------|
| **Policies & Procedures** | ✅ | ✅ | ✅ | ✅ | SharePoint/Compliance | Compliance Team |
| **System Configurations** | ✅ | ✅ | ✅ | ✅ | Git/Confluence | PKI Team |
| **Access Reviews** | ✅ | ✅ | ✅ | ✅ | SharePoint/Access Reviews | HR + IT Security |
| **Audit Logs** | ✅ | ✅ | ✅ | ✅ | Splunk (7-year retention) | Security Ops |
| **Vulnerability Scans** | ✅ | ✅ | ✅ | ✅ | Qualys | Security Ops |
| **Penetration Tests** | ✅ | ✅ | ✅ | ✅ | Secure file share (encrypted) | CISO |
| **DR Test Results** | ✅ | ✅ | ✅ | ✅ | SharePoint/DR | PKI Team |
| **Change Tickets** | ✅ | ✅ | ✅ | ✅ | ServiceNow | Change Management |
| **Incident Tickets** | ✅ | ✅ | ✅ | ✅ | ServiceNow | Security Ops |
| **Training Records** | ✅ | ✅ | ✅ | ✅ | LMS (Learning Management System) | HR |
| **Vendor Contracts** | ✅ | ✅ | ✅ | ✅ | Legal file share | Legal |
| **Certificates** | ✅ | ✅ | ✅ | ✅ | Keyfactor database | PKI Team |

---

### 6.2 Evidence Collection Schedule

| Evidence | Collection Frequency | Responsible Party | Reviewer | Due Date |
|----------|---------------------|-------------------|----------|----------|
| User Access Review | Quarterly | IT Security Manager | CISO | 15th of last month of quarter |
| Privileged Access Review | Quarterly | PKI Lead | CISO | 15th of last month of quarter |
| Vulnerability Scan | Monthly | Security Engineer | Security Manager | 5th of each month |
| Penetration Test | Annual | External Vendor | CISO | Q3 (September) |
| DR Test | Semi-annual | PKI Team | IT Director | January, July |
| Backup Restore Test | Monthly | Backup Admin | PKI Lead | 1st Sunday of month |
| Policy Review | Annual | Compliance Team | CISO | December |
| Change Audit Sample | Quarterly | Internal Auditor | Audit Manager | 20th of last month of quarter |
| Incident Review | Quarterly | Security Ops | CISO | End of quarter |
| Training Completion | Quarterly | HR | IT Director | End of quarter |

---

### 6.3 Evidence Request Process

**For External Auditors**:

```
Evidence Request Workflow

1. Auditor submits evidence request via secure portal
   Template: [Control ID] [Evidence Type] [Time Period]
   Example: "CC6.1 - User access review - Q3 2025"

2. Compliance team receives and triages request
   SLA: Acknowledge within 1 business day

3. Evidence owner prepares artifact
   - Generate report/export from source system
   - Redact sensitive information if needed (PII, passwords)
   - Watermark as "Confidential - Audit Use Only"

4. Compliance team reviews for completeness
   - Verify artifact matches request
   - Ensure appropriate time period covered
   - Check for sensitive data

5. Evidence uploaded to auditor portal
   SLA: Provide evidence within 5 business days

6. Auditor reviews and may request clarifications

7. All evidence archived for future reference
   Retention: 7 years
```

---

## 7. Control Testing

### 7.1 Control Testing Methodology

**Testing Approach**: Three Lines of Defense

| Line | Responsible Party | Frequency | Scope |
|------|------------------|-----------|-------|
| **1st Line** | Process owners (PKI team, IT Security) | Continuous | Self-assessment, operational monitoring |
| **2nd Line** | Compliance team, Risk management | Quarterly | Sample-based testing, metrics review |
| **3rd Line** | Internal audit, External auditors | Annual | Independent assessment, full scope |

---

### 7.2 Sample Control Tests

#### Test 1: Access Control Effectiveness (SOC 2 CC6.1, PCI 8.2.1, ISO A.9.2)

**Control**: Access is granted based on approved requests only

**Test Procedure**:
1. Select sample of 25 users provisioned in last quarter
2. Obtain access request tickets from ServiceNow
3. Verify:
   - Request submitted by authorized person (user's manager)
   - Request includes business justification
   - Request approved by appropriate authority (PKI Lead for cert managers)
   - Access granted matches request (role, scope)
   - Access granted within 2 business days of approval

**Expected Result**: 100% of sampled users have approved access requests

**Test Results** (Q3 2025):
- Sample Size: 25 users
- Users with approved requests: 25
- Pass Rate: 100% ✅
- Exceptions: None

---

#### Test 2: Audit Log Integrity (SOC 2 CC7.3, PCI 10.7.2, ISO A.12.4)

**Control**: Audit logs are protected from unauthorized modification

**Test Procedure**:
1. Select sample of 10 random audit log files from last quarter
2. Retrieve hash values from integrity monitoring system
3. Recalculate hash for each log file
4. Compare calculated hash with stored hash
5. Verify logs are on append-only storage

**Expected Result**: 100% of log files have matching hashes

**Test Results** (Q3 2025):
- Sample Size: 10 log files (1TB total)
- Files with matching hashes: 10
- Pass Rate: 100% ✅
- Exceptions: None

---

#### Test 3: Encryption in Transit (SOC 2 C1.3, PCI 4.2.1, ISO A.13.2, FedRAMP SC-8)

**Control**: All data transmissions use strong encryption (TLS 1.2+)

**Test Procedure**:
1. Scan all external-facing endpoints with Qualys SSL Labs
2. Review TLS configuration on internal systems
3. Verify:
   - TLS 1.2 or 1.3 in use
   - Strong cipher suites only (no RC4, 3DES, etc.)
   - Valid certificates with proper chain
   - No SSL/TLS vulnerabilities (Heartbleed, POODLE, etc.)

**Expected Result**: All endpoints score A or higher, no weak protocols

**Test Results** (Q3 2025):
- Endpoints tested: 8
- A+ rating: 6
- A rating: 2
- Below A: 0
- Pass Rate: 100% ✅
- Exceptions: None

---

#### Test 4: Change Management (SOC 2 CC8.1, PCI 6.4.2, ISO A.14.1, FedRAMP CM-3)

**Control**: All changes are approved before implementation

**Test Procedure**:
1. Select sample of 30 changes from last quarter
2. Obtain change tickets from ServiceNow
3. Verify:
   - Change request submitted with justification
   - Change assessed for risk and impact
   - Change approved by Change Board (or emergency approval for P1)
   - Change implemented during approved window
   - Post-implementation validation completed

**Expected Result**: 100% of changes have documented approval

**Test Results** (Q3 2025):
- Sample Size: 30 changes
- Changes with approval: 29
- Changes without approval: 1 (emergency P1 - retrospectively approved)
- Pass Rate: 96.7% ⚠️
- Exceptions: 1 emergency change (approved within 24 hours, documented in IR ticket)
- Management Response: Emergency change procedure validated as working correctly. P1 emergencies require retrospective approval per policy.

---

## 8. Compliance Status Dashboard

### 8.1 Overall Compliance Scorecard

```
┌────────────────────────────────────────────────────────────┐
│         KEYFACTOR PKI - COMPLIANCE SCORECARD               │
│                 Quarter: Q3 2025                           │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  SOC 2 Type II                                              │
│  Status: ✅ COMPLIANT | Exceptions: 0                      │
│  Last Audit: Q3 2025 | Next: Q3 2026                       │
│  Auditor: Deloitte | Opinion: Unqualified                  │
│                                                             │
│  PCI-DSS v4.0                                               │
│  Status: ✅ COMPLIANT | Findings: 0                        │
│  Last Assessment: Q2 2025 | Next: Q2 2026                  │
│  Assessor: QSA Firm | ROC: Compliant                       │
│                                                             │
│  ISO 27001:2022                                             │
│  Status: ✅ CERTIFIED | Nonconformities: 0                 │
│  Certification Date: Jan 2025 | Expiry: Jan 2028           │
│  Next Surveillance: Jul 2026                                │
│                                                             │
│  FedRAMP Moderate                                           │
│  Status: 🚧 IN PROGRESS | Implementation: 88%              │
│  Target Authorization: Q1 2026                              │
│  Controls: 285/325 implemented                              │
│                                                             │
├────────────────────────────────────────────────────────────┤
│  Overall Compliance Health: ✅ EXCELLENT                   │
│  Risk Level: 🟢 LOW                                        │
└────────────────────────────────────────────────────────────┘
```

---

### 8.2 Key Metrics

| Metric | Target | Q1 2025 | Q2 2025 | Q3 2025 | Trend |
|--------|--------|---------|---------|---------|-------|
| SOC 2 Exceptions | 0 | 0 ✅ | 0 ✅ | 0 ✅ | ➡️ Stable |
| PCI Findings | 0 | 1 ⚠️ | 0 ✅ | 0 ✅ | ⬇️ Improving |
| ISO Nonconformities | 0 | 0 ✅ | 0 ✅ | 0 ✅ | ➡️ Stable |
| FedRAMP Progress | 100% | 75% | 82% | 88% | ⬆️ On Track |
| Control Test Pass Rate | ≥95% | 98% ✅ | 97% ✅ | 99% ✅ | ⬆️ Improving |
| Audit Findings Closure | 100% in 90d | 100% ✅ | 100% ✅ | 100% ✅ | ➡️ Stable |
| Policy Review Completion | 100% | 100% ✅ | 100% ✅ | 100% ✅ | ➡️ Stable |
| Training Completion | 100% | 98% ⚠️ | 100% ✅ | 100% ✅ | ⬆️ Improving |

---

## Appendix A: Audit Schedule

### Upcoming Audits (Next 12 Months)

| Date | Framework | Type | Auditor | Preparation Lead |
|------|-----------|------|---------|-----------------|
| Jan 2026 | SOC 2 | Planning | Deloitte | Compliance Manager |
| Feb 2026 | FedRAMP | 3PAO Assessment | A-LIGN | PKI Lead |
| Mar 2026 | FedRAMP | Authorization | GSA | CISO |
| Apr 2026 | PCI-DSS | QSA Assessment | PCI QSA | Security Manager |
| Jul 2026 | ISO 27001 | Surveillance Audit | BSI | Compliance Manager |
| Sep 2026 | Penetration Test | External Test | Offensive Security | Security Engineer |
| Oct 2026 | Internal Audit | Control Testing | Internal Audit | All Teams |

---

## Appendix B: Contact Information

### Compliance Team

| Role | Name | Email | Phone |
|------|------|-------|-------|
| **Chief Compliance Officer** | [Name] | [Email] | [Phone] |
| **Compliance Manager** | [Name] | [Email] | [Phone] |
| **SOC 2 Coordinator** | [Name] | [Email] | [Phone] |
| **PCI-DSS Coordinator** | [Name] | [Email] | [Phone] |
| **ISO 27001 Coordinator** | [Name] | [Email] | [Phone] |
| **FedRAMP Coordinator** | [Name] | [Email] | [Phone] |

### Auditor Contacts

| Firm | Framework | Contact | Email | Phone |
|------|-----------|---------|-------|-------|
| **Deloitte** | SOC 2 | [Auditor Name] | [Email] | [Phone] |
| **QSA Firm** | PCI-DSS | [Assessor Name] | [Email] | [Phone] |
| **BSI** | ISO 27001 | [Auditor Name] | [Email] | [Phone] |
| **A-LIGN** | FedRAMP | [3PAO Name] | [Email] | [Phone] |

---

## Document Maintenance

**Review Schedule**: Quarterly or after audit findings  
**Owner**: Chief Compliance Officer, Compliance Team  
**Last Reviewed**: October 22, 2025  
**Next Review**: January 22, 2026 or after next audit

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial version |

---

**CLASSIFICATION**: INTERNAL USE - CONFIDENTIAL  
**Contains compliance audit information and control details**

**For compliance questions, contact**: compliance-team@contoso.com or adrian207@gmail.com

**End of Compliance Mapping Document**

