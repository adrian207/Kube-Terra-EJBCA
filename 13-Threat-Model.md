# Keyfactor Threat Model
## PKI Security Threat Analysis and Risk Assessment

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use - Confidential - Restricted  
**Target Audience**: CISO, security architects, risk management, security team

---

## Document Purpose

This document provides a comprehensive threat model for the Keyfactor PKI platform, identifying potential threats, attack vectors, risk ratings, and mitigations. It supports security architecture decisions, risk management, and incident response planning.

---

## Table of Contents

1. [Threat Modeling Methodology](#1-threat-modeling-methodology)
2. [Threat Actors](#2-threat-actors)
3. [Asset Identification and Valuation](#3-asset-identification-and-valuation)
4. [Threat Scenarios](#4-threat-scenarios)
5. [Attack Vectors](#5-attack-vectors)
6. [Risk Assessment](#6-risk-assessment)
7. [Mitigation Strategies](#7-mitigation-strategies)
8. [Residual Risks](#8-residual-risks)
9. [Threat Intelligence](#9-threat-intelligence)
10. [Incident Response Integration](#10-incident-response-integration)

---

## 1. Threat Modeling Methodology

### 1.1 Framework: STRIDE

**Microsoft STRIDE Methodology** for threat categorization:

| Threat Type | Security Property Violated | Description |
|------------|---------------------------|-------------|
| **Spoofing** | Authentication | Attacker impersonates another user or system |
| **Tampering** | Integrity | Unauthorized modification of data or code |
| **Repudiation** | Non-repudiation | User denies performing an action (no audit trail) |
| **Information Disclosure** | Confidentiality | Exposure of sensitive information |
| **Denial of Service** | Availability | Service unavailable to legitimate users |
| **Elevation of Privilege** | Authorization | Attacker gains unauthorized privileges |

---

### 1.2 Risk Rating: DREAD

**DREAD Scoring** (0-10 scale for each factor, total 0-50):

| Factor | Description | Scoring Guidance |
|--------|-------------|-----------------|
| **Damage** | How bad would an attack be? | 0 = None, 10 = Complete system compromise |
| **Reproducibility** | How easy is it to reproduce? | 0 = Very difficult, 10 = Trivial |
| **Exploitability** | How much skill/effort required? | 0 = Advanced skills, 10 = Script kiddie |
| **Affected Users** | How many users impacted? | 0 = Individual user, 10 = All users |
| **Discoverability** | How easy to discover vulnerability? | 0 = Hidden, 10 = Obvious |

**Risk Levels**:
- **Critical**: 40-50 (Immediate action required)
- **High**: 30-39 (Address within 30 days)
- **Medium**: 20-29 (Address within 90 days)
- **Low**: 10-19 (Address when feasible)
- **Informational**: 0-9 (Monitor)

---

### 1.3 Attack Tree Methodology

**Attack trees** visualize attack paths, showing:
- Root: Attacker's goal
- Branches: Alternative attack methods
- Leaves: Specific actions/prerequisites
- AND/OR gates: Required combinations

Example structure:
```
Goal: Compromise CA Private Key
├─ OR: Steal from HSM
│  ├─ AND: Physical access to HSM
│  │  ├─ Breach data center security
│  │  └─ Extract keys from HSM (requires SO credentials)
│  └─ AND: Remote exploit
│     ├─ Exploit HSM vulnerability
│     └─ Exfiltrate key material
├─ OR: Steal from backup
│  ├─ Access backup storage
│  └─ Decrypt backup (requires encryption key)
└─ OR: Compromise key ceremony
   ├─ Insider threat (malicious SO)
   └─ Social engineering during ceremony
```

---

## 2. Threat Actors

### 2.1 Threat Actor Profiles

#### Nation-State Actors (APT Groups)

**Characteristics**:
- **Motivation**: Espionage, disruption, strategic advantage
- **Capabilities**: Advanced (zero-days, custom malware, patient reconnaissance)
- **Resources**: Nearly unlimited funding, skilled operators
- **Typical TTPs**: Spear-phishing, supply chain attacks, living-off-the-land
- **Examples**: APT28 (Russia), APT41 (China), Lazarus Group (North Korea)

**Relevance to PKI**:
- High-value target: Compromise of PKI enables widespread MitM attacks
- CA key compromise would enable signing of malicious certificates
- CRL/OCSP disruption could prevent revocation detection

**Likelihood**: Medium (PKI is strategic target but well-defended)

---

#### Cybercriminal Organizations

**Characteristics**:
- **Motivation**: Financial gain (ransomware, fraud, extortion)
- **Capabilities**: Moderate to advanced (purchased exploits, malware-as-a-service)
- **Resources**: Moderate funding, organized teams
- **Typical TTPs**: Ransomware, credential theft, BEC (Business Email Compromise)
- **Examples**: REvil, Conti, LockBit

**Relevance to PKI**:
- Ransomware could encrypt PKI infrastructure
- Stolen code-signing certificates used for malware distribution
- Fraudulent certificate issuance for phishing sites

**Likelihood**: High (financially motivated, broad targeting)

---

#### Insider Threats

**Characteristics**:
- **Motivation**: Financial, revenge, ideology, coercion, negligence
- **Capabilities**: Varies (legitimate access, knowledge of systems)
- **Resources**: Limited to insider's role and access
- **Typical TTPs**: Data exfiltration, sabotage, credential abuse
- **Types**: 
  - Malicious insider (intentional harm)
  - Negligent insider (unintentional breach)
  - Compromised insider (account takeover)

**Relevance to PKI**:
- PKI administrators have elevated privileges
- Insider could issue fraudulent certificates
- Insider could compromise CA keys or HSM
- Negligent insider could misconfigure security controls

**Likelihood**: Medium (insider access mitigated by separation of duties)

---

#### Hacktivists

**Characteristics**:
- **Motivation**: Political, ideological, social causes
- **Capabilities**: Low to moderate (public exploits, DDoS tools)
- **Resources**: Limited funding, loosely organized
- **Typical TTPs**: Website defacement, DDoS, data leaks
- **Examples**: Anonymous, LulzSec

**Relevance to PKI**:
- DDoS attacks on CRL/OCSP infrastructure
- Defacement of PKI web portal
- Leak of certificate inventory

**Likelihood**: Low (PKI not typical hacktivist target)

---

#### Competitors

**Characteristics**:
- **Motivation**: Competitive advantage, corporate espionage
- **Capabilities**: Moderate (hired experts, bribery)
- **Resources**: Moderate to high funding
- **Typical TTPs**: Insider recruitment, reconnaissance, trade secret theft

**Relevance to PKI**:
- Theft of PKI architecture/configuration
- Customer certificate inventory for business intelligence
- Disruption of PKI services to harm reputation

**Likelihood**: Low (strong legal deterrents, limited value)

---

### 2.2 Threat Actor Prioritization

| Threat Actor | Likelihood | Impact | Priority | Focus Areas |
|--------------|-----------|--------|----------|-------------|
| **Nation-State** | Medium | Critical | **HIGH** | HSM, CA compromise, supply chain |
| **Cybercriminals** | High | High | **HIGH** | Ransomware, credential theft, availability |
| **Insider (Malicious)** | Low | Critical | **HIGH** | Separation of duties, audit logging |
| **Insider (Negligent)** | Medium | Medium | **MEDIUM** | Training, mistake-proofing, monitoring |
| **Hacktivists** | Low | Low | **LOW** | DDoS protection, public-facing services |
| **Competitors** | Low | Low | **LOW** | NDAs, physical security |

---

## 3. Asset Identification and Valuation

### 3.1 Critical Assets

| Asset | Description | Confidentiality | Integrity | Availability | Overall Value |
|-------|-------------|----------------|-----------|--------------|---------------|
| **CA Root Private Keys** | Root CA signing keys (in HSM) | CRITICAL | CRITICAL | HIGH | **CRITICAL** |
| **CA Subordinate Private Keys** | Issuing CA signing keys (in HSM) | CRITICAL | CRITICAL | HIGH | **CRITICAL** |
| **HSM Master Keys** | HSM encryption and authentication keys | CRITICAL | CRITICAL | HIGH | **CRITICAL** |
| **Certificate Database** | All issued certificates, metadata | HIGH | CRITICAL | HIGH | **HIGH** |
| **Audit Logs** | Complete audit trail (7 years) | HIGH | CRITICAL | MEDIUM | **HIGH** |
| **Keyfactor Application** | PKI management platform | MEDIUM | HIGH | HIGH | **HIGH** |
| **CRL/OCSP Services** | Revocation checking infrastructure | MEDIUM | CRITICAL | CRITICAL | **HIGH** |
| **Orchestrator Credentials** | Credentials for certificate deployment | HIGH | HIGH | MEDIUM | **MEDIUM** |
| **User Credentials** | Admin and operator credentials | HIGH | HIGH | MEDIUM | **MEDIUM** |
| **Configuration Data** | System configurations, policies | HIGH | HIGH | LOW | **MEDIUM** |

**Asset Valuation Legend**:
- **CRITICAL**: Compromise would cause catastrophic impact (total PKI failure, widespread security breach)
- **HIGH**: Compromise would cause major impact (service disruption, significant security incident)
- **MEDIUM**: Compromise would cause moderate impact (limited service degradation, containable incident)
- **LOW**: Compromise would cause minor impact (inconvenience, easily recoverable)

---

### 3.2 Crown Jewels

**Top 3 Assets Requiring Maximum Protection**:

1. **CA Private Keys (HSM)**: 
   - Compromise = ability to issue fraudulent certificates for any domain
   - Impact: Complete loss of trust in PKI
   - Mitigation: FIPS 140-2 Level 3 HSM, dual control, physical security

2. **HSM Master Keys**:
   - Compromise = access to all CA keys
   - Impact: Complete PKI compromise
   - Mitigation: Split knowledge (M of N), secure backup, tamper detection

3. **Audit Logs**:
   - Compromise = ability to hide malicious activity
   - Impact: Undetectable security incidents, compliance violations
   - Mitigation: Append-only storage, SIEM forwarding, hash verification

---

## 4. Threat Scenarios

### 4.1 Scenario 1: CA Key Compromise

**Threat Type**: Information Disclosure, Elevation of Privilege

**Attack Narrative**:
```
1. Attacker gains physical access to HSM room (tailgating, badge cloning)
2. Attacker exploits HSM firmware vulnerability (CVE-XXXX-YYYY)
3. Attacker extracts CA private key from HSM
4. Attacker uses key to sign malicious certificates
5. Malicious certificates deployed for MitM attacks
6. Detection: Certificate transparency logs show unauthorized certs
```

**DREAD Score**:
- Damage: 10 (Complete PKI compromise)
- Reproducibility: 2 (Requires physical access + exploit)
- Exploitability: 3 (Advanced skills, rare vulnerability)
- Affected Users: 10 (All users of PKI)
- Discoverability: 4 (HSM vulnerabilities occasionally disclosed)
- **Total: 29 (MEDIUM)**

**Existing Mitigations**:
- ✅ FIPS 140-2 Level 3 HSM (tamper-resistant)
- ✅ Physical access controls (badge, biometric, video surveillance)
- ✅ Dual control for HSM operations (requires 2 SOs)
- ✅ HSM firmware kept up-to-date
- ✅ Keys never leave HSM (operations performed internally)
- ✅ Certificate Transparency monitoring

**Residual Risk**: **LOW** (Strong layered defenses, likelihood significantly reduced)

**Response Plan**: See [10-Incident-Response-Procedures.md](./10-Incident-Response-Procedures.md) Section 4.4 "Key Compromise Response"

---

### 4.2 Scenario 2: Ransomware Attack

**Threat Type**: Denial of Service, Tampering

**Attack Narrative**:
```
1. Attacker sends spear-phishing email to PKI operator
2. Operator clicks malicious link, downloads ransomware payload
3. Ransomware spreads laterally across network
4. Keyfactor servers, database, and backups encrypted
5. Certificate issuance and renewal halted
6. Attacker demands ransom for decryption key
7. Detection: Alerts from antivirus, abnormal file activity
```

**DREAD Score**:
- Damage: 8 (PKI services down, potential data loss)
- Reproducibility: 7 (Common attack, many variants)
- Exploitability: 6 (Moderate skills, phishing kits available)
- Affected Users: 10 (All users unable to get certificates)
- Discoverability: 8 (Phishing is obvious attack vector)
- **Total: 39 (HIGH)**

**Existing Mitigations**:
- ✅ Email filtering (Proofpoint) blocks 99%+ of phishing
- ✅ Endpoint protection (Windows Defender ATP)
- ✅ Network segmentation (limits lateral movement)
- ✅ Privileged Access Management (restricts ransomware spread)
- ✅ Offline backups (not encrypted by ransomware)
- ✅ DR site (can failover within 4 hours)
- ✅ Security awareness training (quarterly phishing tests)

**Residual Risk**: **MEDIUM** (Phishing remains effective, but recovery capabilities strong)

**Response Plan**: See [10-Incident-Response-Procedures.md](./10-Incident-Response-Procedures.md) Section 4.3 "Complete Platform Failure"

---

### 4.3 Scenario 3: Malicious Insider (PKI Administrator)

**Threat Type**: Spoofing, Elevation of Privilege, Tampering

**Attack Narrative**:
```
1. Malicious PKI administrator has legitimate access
2. Administrator issues fraudulent certificate for attacker's domain
3. Administrator covers tracks by modifying audit logs
4. Fraudulent certificate used for phishing attacks
5. Detection: External party notices fraudulent cert in CT logs
6. Investigation reveals insider issued certificate without authorization
```

**DREAD Score**:
- Damage: 8 (Fraudulent certificates issued, reputational harm)
- Reproducibility: 8 (Insider can repeat at will)
- Exploitability: 2 (Requires insider access)
- Affected Users: 5 (Users deceived by fraudulent cert)
- Discoverability: 6 (CT logs make detection likely)
- **Total: 29 (MEDIUM)**

**Existing Mitigations**:
- ✅ Separation of duties (PKI Admin cannot approve own requests)
- ✅ Append-only audit logs (cannot be modified)
- ✅ SIEM monitoring (alerts on unusual activity)
- ✅ Certificate Transparency (fraudulent certs visible publicly)
- ✅ Dual authorization for high-risk operations
- ✅ Background checks for privileged users
- ✅ Access reviews (quarterly)

**Residual Risk**: **LOW** (Strong controls limit insider threat)

**Response Plan**: Immediate revocation of fraudulent cert, HR/legal involvement, forensic investigation

---

### 4.4 Scenario 4: Man-in-the-Middle (MitM) via Certificate Spoofing

**Threat Type**: Spoofing, Information Disclosure

**Attack Narrative**:
```
1. Attacker compromises endpoint's certificate store
2. Attacker installs rogue CA certificate as trusted root
3. Attacker intercepts TLS connections (MitM proxy)
4. Attacker decrypts, inspects, re-encrypts traffic
5. User unaware of interception (valid certificate from attacker's CA)
6. Detection: Endpoint detection tools notice rogue certificate
```

**DREAD Score**:
- Damage: 7 (Confidential data exposed for compromised users)
- Reproducibility: 6 (Requires endpoint compromise)
- Exploitability: 5 (Moderate skills, tools available)
- Affected Users: 2 (Individual users)
- Discoverability: 7 (Common attack, well-documented)
- **Total: 27 (MEDIUM)**

**Existing Mitigations**:
- ✅ Certificate pinning (mobile apps, critical services)
- ✅ Endpoint protection (detects rogue certificate installation)
- ✅ User training (recognize certificate warnings)
- ✅ Certificate Transparency (CT logs show unexpected certs)
- ✅ HSTS (HTTP Strict Transport Security) prevents downgrade

**Residual Risk**: **MEDIUM** (Endpoint compromise remains risk)

**Response Plan**: Isolate compromised endpoint, remove rogue certificate, forensic analysis

---

### 4.5 Scenario 5: DDoS Attack on CRL/OCSP Infrastructure

**Threat Type**: Denial of Service

**Attack Narrative**:
```
1. Attacker launches large-scale DDoS attack on CRL distribution points
2. CRL servers overwhelmed, unable to respond
3. Clients cannot check certificate revocation status
4. Some clients fail-open (accept certificates without revocation check)
5. Revoked certificates continue to be trusted
6. Detection: Monitoring alerts on high traffic, service degradation
```

**DREAD Score**:
- Damage: 6 (Revocation checking unavailable, revoked certs may be trusted)
- Reproducibility: 8 (DDoS-for-hire services readily available)
- Exploitability: 8 (Low skills, botnets for rent)
- Affected Users: 10 (All users unable to check revocation)
- Discoverability: 9 (DDoS is obvious attack)
- **Total: 41 (CRITICAL)**

**Existing Mitigations**:
- ✅ CDN for CRL distribution (CloudFlare, high capacity)
- ✅ DDoS protection (CloudFlare, rate limiting)
- ✅ OCSP stapling (clients don't need to contact OCSP server)
- ✅ Multiple CRL distribution points (redundancy)
- ✅ Long CRL validity periods (4-hour caching reduces load)

**Residual Risk**: **LOW** (Strong DDoS mitigation, multiple distribution channels)

**Response Plan**: Activate DDoS mitigation, engage CDN provider, monitor revocation bypass attempts

---

### 4.6 Scenario 6: Supply Chain Attack (Compromised Software Update)

**Threat Type**: Tampering, Elevation of Privilege

**Attack Narrative**:
```
1. Attacker compromises Keyfactor software update server
2. Attacker injects backdoor into Keyfactor software update
3. PKI team installs "legitimate" update with backdoor
4. Backdoor provides attacker with remote access to Keyfactor platform
5. Attacker exfiltrates CA keys, certificate data
6. Detection: Signature verification failure, anomalous network activity
```

**DREAD Score**:
- Damage: 10 (Complete PKI compromise)
- Reproducibility: 3 (Difficult to compromise vendor)
- Exploitability: 4 (Advanced skills, vendor compromise)
- Affected Users: 10 (All users of PKI)
- Discoverability: 5 (Supply chain attacks difficult to detect)
- **Total: 32 (HIGH)**

**Existing Mitigations**:
- ✅ Software update signature verification (GPG signatures)
- ✅ Hash verification (SHA-256 checksums)
- ✅ Vendor security assessment (annual review)
- ✅ Staging environment (test updates before production)
- ✅ Change management (updates approved by CAB)
- ✅ Network monitoring (detect anomalous outbound connections)

**Residual Risk**: **MEDIUM** (Vendor compromise is low-probability but high-impact)

**Response Plan**: Isolate affected systems, engage Keyfactor vendor, forensic analysis, rebuild from known-good backups

---

## 5. Attack Vectors

### 5.1 Network-Based Attacks

| Attack Vector | Description | Likelihood | Impact | Mitigation |
|--------------|-------------|------------|--------|------------|
| **Man-in-the-Middle** | Intercept and modify network traffic | Medium | High | TLS mutual auth, certificate pinning |
| **DDoS** | Overwhelm services with traffic | High | Medium | CDN, rate limiting, DDoS protection |
| **Network Sniffing** | Capture unencrypted network traffic | Low | Low | TLS 1.2+ for all connections |
| **Port Scanning** | Reconnaissance of open ports | High | Low | Firewall, port restrictions, IDS |
| **ARP Spoofing** | Redirect traffic on local network | Low | Medium | ARP inspection, network segmentation |

---

### 5.2 Application-Level Attacks

| Attack Vector | Description | Likelihood | Impact | Mitigation |
|--------------|-------------|------------|--------|------------|
| **SQL Injection** | Inject malicious SQL queries | Low | High | Parameterized queries, input validation |
| **Cross-Site Scripting (XSS)** | Inject malicious scripts in web pages | Low | Medium | Input sanitization, CSP headers |
| **CSRF** | Force user to execute unwanted actions | Low | Medium | CSRF tokens, SameSite cookies |
| **Authentication Bypass** | Circumvent authentication controls | Low | Critical | Strong auth (MFA), secure session mgmt |
| **Privilege Escalation** | Gain elevated permissions | Low | Critical | RBAC, least privilege, code review |
| **API Abuse** | Exploit API without proper auth/rate limiting | Medium | Medium | API rate limiting, client certificates |

---

### 5.3 Physical Attacks

| Attack Vector | Description | Likelihood | Impact | Mitigation |
|--------------|-------------|------------|--------|------------|
| **Data Center Breach** | Unauthorized physical access to servers | Low | Critical | Badge access, biometrics, video surveillance |
| **HSM Theft** | Steal HSM hardware | Very Low | Critical | HSM tamper detection, secure mounting |
| **Shoulder Surfing** | Observe credentials being entered | Low | Low | Privacy screens, secure input areas |
| **Theft of Backup Media** | Steal backup tapes/drives | Low | High | Encrypted backups, secure transport |
| **USB Drop Attack** | Leave malicious USB devices | Medium | Medium | USB port disabled, user training |

---

### 5.4 Social Engineering

| Attack Vector | Description | Likelihood | Impact | Mitigation |
|--------------|-------------|------------|--------|------------|
| **Phishing** | Fraudulent emails to steal credentials | High | High | Email filtering, user training, MFA |
| **Spear Phishing** | Targeted phishing of high-value users | Medium | High | Executive training, email authentication |
| **Pretexting** | Impersonate trusted person (help desk) | Medium | Medium | Verification procedures, callback protocols |
| **Baiting** | Offer something enticing (free USB) | Low | Medium | User training, USB port controls |
| **Tailgating** | Follow authorized person into secure area | Medium | High | Security awareness, access logging |

---

## 6. Risk Assessment

### 6.1 Risk Heat Map

```
           IMPACT →
L    │  Low    Medium   High   Critical
I    │
K  ──┼──────────────────────────────────
E    │
L    │
I  H │            🟡(4)   🔴(2)    🔴(1)
H    │
O  M │   🟢(5)    🟡(3)   🔴(6)
O    │
D  L │            🟢       🟡
     │
   VL│   🟢
     └──────────────────────────────────

Legend:
🔴 Critical Risk (immediate action)
🟡 Moderate Risk (address within 90 days)
🟢 Low Risk (monitor)

Numbered Threats:
(1) CA Key Compromise
(2) Ransomware Attack
(3) Malicious Insider
(4) MitM via Cert Spoofing
(5) DDoS on CRL/OCSP
(6) Supply Chain Attack
```

---

### 6.2 Risk Register

| Risk ID | Threat | Likelihood | Impact | Risk Level | Mitigations | Residual Risk | Owner |
|---------|--------|-----------|--------|------------|-------------|---------------|-------|
| **R-001** | CA Key Compromise | Low | Critical | 🔴 HIGH | HSM, dual control, physical security | 🟢 LOW | PKI Lead |
| **R-002** | Ransomware | Medium | High | 🔴 HIGH | Email filtering, EDR, backups, DR | 🟡 MEDIUM | Security Manager |
| **R-003** | Malicious Insider | Low | High | 🟡 MEDIUM | Separation of duties, audit logs | 🟢 LOW | CISO |
| **R-004** | MitM Attack | Medium | High | 🔴 HIGH | TLS, cert pinning, HSTS | 🟡 MEDIUM | Network Security |
| **R-005** | DDoS on CRL/OCSP | High | Medium | 🟡 MEDIUM | CDN, DDoS protection, OCSP stapling | 🟢 LOW | Infrastructure |
| **R-006** | Supply Chain Attack | Low | Critical | 🔴 HIGH | Signature verification, staging, monitoring | 🟡 MEDIUM | PKI Lead |
| **R-007** | Phishing | High | Medium | 🟡 MEDIUM | Email filtering, training, MFA | 🟢 LOW | Security Awareness |
| **R-008** | SQL Injection | Low | High | 🟡 MEDIUM | Parameterized queries, input validation | 🟢 LOW | Dev Team |
| **R-009** | Data Center Breach | Low | Critical | 🔴 HIGH | Physical security, access controls | 🟢 LOW | Facilities |
| **R-010** | Negligent Insider | Medium | Medium | 🟡 MEDIUM | Training, mistake-proofing, monitoring | 🟡 MEDIUM | HR + IT Security |

---

### 6.3 Top Risks Requiring Action

**Priority 1: Ransomware Defense (R-002)**
- Current Status: 🟡 MEDIUM residual risk
- Action: Implement additional network segmentation, deploy deception technology (honeypots)
- Owner: Security Manager
- Target: Reduce to 🟢 LOW by Q1 2026

**Priority 2: Supply Chain Security (R-006)**
- Current Status: 🟡 MEDIUM residual risk
- Action: Implement Software Bill of Materials (SBOM) verification, increase vendor security assessments
- Owner: PKI Lead
- Target: Reduce to 🟢 LOW by Q2 2026

**Priority 3: Negligent Insider (R-010)**
- Current Status: 🟡 MEDIUM residual risk
- Action: Enhance security training, implement just-in-time privilege escalation
- Owner: HR + IT Security
- Target: Reduce to 🟢 LOW by Q2 2026

---

## 7. Mitigation Strategies

### 7.1 Defense in Depth Layers

```
┌────────────────────────────────────────────────────┐
│  Layer 7: Governance                                │
│  - Policies, procedures, training                  │
└────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────┐
│  Layer 6: Physical                                  │
│  - Badge access, video surveillance, HSM vault     │
└────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────┐
│  Layer 5: Perimeter                                 │
│  - Firewall, WAF, IDS/IPS, DDoS protection        │
└────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────┐
│  Layer 4: Network                                   │
│  - Segmentation, VLANs, access control lists       │
└────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────┐
│  Layer 3: Endpoint                                  │
│  - Antivirus, EDR, patch management, hardening     │
└────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────┐
│  Layer 2: Application                               │
│  - RBAC, MFA, input validation, secure coding      │
└────────────────────────────────────────────────────┘
┌────────────────────────────────────────────────────┐
│  Layer 1: Data                                      │
│  - Encryption (TDE), HSM, key management           │
└────────────────────────────────────────────────────┘
```

**Principle**: Multiple overlapping controls ensure that failure of one layer doesn't compromise the entire system.

---

### 7.2 Preventive Controls

| Control | Purpose | Threat Mitigated | Effectiveness |
|---------|---------|-----------------|---------------|
| **HSM (FIPS 140-2 L3)** | Protect CA keys | Key theft, tampering | ✅ Very High |
| **MFA** | Strengthen authentication | Credential theft, phishing | ✅ High |
| **Network Segmentation** | Limit lateral movement | Ransomware, network attacks | ✅ High |
| **Input Validation** | Prevent injection attacks | SQL injection, XSS | ✅ High |
| **Encryption (TLS, TDE)** | Protect data in transit/at rest | Eavesdropping, data theft | ✅ Very High |
| **Firewall** | Block unauthorized connections | Network attacks | ✅ High |
| **Hardening** | Reduce attack surface | Various exploits | ✅ Moderate |
| **Access Control (RBAC)** | Enforce least privilege | Unauthorized actions | ✅ High |
| **Security Training** | Reduce human error | Phishing, social engineering | ✅ Moderate |

---

### 7.3 Detective Controls

| Control | Purpose | Threat Detected | Response Time |
|---------|---------|----------------|---------------|
| **SIEM** | Centralized log analysis | Anomalous activity, attacks | Real-time |
| **IDS/IPS** | Network intrusion detection | Network attacks | Real-time |
| **Antivirus/EDR** | Malware detection | Malware, ransomware | Real-time |
| **File Integrity Monitoring** | Detect unauthorized changes | Tampering, malware | Real-time |
| **Certificate Transparency** | Detect fraudulent certificates | Rogue certificate issuance | Hours |
| **Access Reviews** | Detect inappropriate access | Privilege creep, orphaned accounts | Quarterly |
| **Vulnerability Scanning** | Identify security weaknesses | Unpatched systems, misconfigurations | Monthly |
| **Penetration Testing** | Validate defenses | Exploitable vulnerabilities | Annual |

---

### 7.4 Corrective Controls

| Control | Purpose | Incident Type | Recovery Time |
|---------|---------|--------------|---------------|
| **Incident Response Plan** | Structured response to incidents | All incidents | Immediate |
| **Backups** | Restore data after loss | Ransomware, data corruption | 4 hours (RTO) |
| **DR Site** | Failover after primary site failure | Disaster, prolonged outage | 4 hours (RTO) |
| **Certificate Revocation** | Invalidate compromised certificates | Key compromise, fraudulent cert | 5 minutes |
| **Patch Management** | Remediate vulnerabilities | Exploitable vulnerabilities | 30 days (critical) |
| **Account Lockout** | Stop brute-force attacks | Credential attacks | Immediate |
| **Break-Glass Procedures** | Emergency access when normal methods fail | System lockout | 30 minutes |

---

## 8. Residual Risks

### 8.1 Accepted Risks

**Risk**: Zero-day vulnerabilities in core components (HSM, OS, Keyfactor platform)

**Justification**: 
- No feasible mitigation for unknown vulnerabilities
- Vendor provides security patches when vulnerabilities discovered
- Monitoring and detective controls in place to identify exploitation

**Compensating Controls**:
- Vendor security bulletins monitored
- Intrusion detection alerts on anomalous behavior
- Regular penetration testing to discover potential issues

**Risk Owner**: CISO  
**Review Frequency**: Annual

---

**Risk**: Sophisticated nation-state attack with unlimited resources

**Justification**:
- Cost of defending against nation-state attack would exceed value of assets
- Nation-state attack is low probability for commercial PKI
- Existing defenses provide reasonable protection

**Compensating Controls**:
- Strong encryption (CA keys never leave HSM)
- Audit logging (detect post-breach indicators)
- Incident response capability (limit damage if breached)

**Risk Owner**: CISO  
**Review Frequency**: Annual

---

**Risk**: Insider threat with extensive knowledge and access

**Justification**:
- Complete mitigation would require excessive overhead (e.g., constant surveillance)
- Trusted insiders necessary for operations
- Strong separation of duties prevents single person from critical actions

**Compensating Controls**:
- Background checks for privileged users
- Dual control for high-risk operations
- Audit logging reviewed by independent team
- Certificate Transparency for public detection

**Risk Owner**: CISO  
**Review Frequency**: Quarterly

---

### 8.2 Risk Appetite Statement

**Board-Approved Risk Appetite**:

> The organization accepts security risks that have a residual likelihood of LOW or MEDIUM and residual impact of MEDIUM or below, after mitigations are applied.
>
> Risks with HIGH or CRITICAL residual impact require CISO approval and quarterly board review.
>
> Risks with HIGH likelihood and HIGH or CRITICAL impact are unacceptable and must be mitigated to LOW or MEDIUM.

**Current Compliance**: ✅ All risks within appetite

---

## 9. Threat Intelligence

### 9.1 Threat Intelligence Sources

| Source | Type | Frequency | Use Case |
|--------|------|-----------|----------|
| **Keyfactor Security Bulletins** | Vendor-specific | As published | Patching, workarounds |
| **CISA Alerts** | Government | Daily | Nation-state threats, critical vulnerabilities |
| **US-CERT** | Government | Daily | Vulnerability notifications |
| **CVE Database** | Public | Continuous | Vulnerability tracking |
| **MITRE ATT&CK** | Framework | Quarterly | TTPs, threat modeling |
| **Threat Intelligence Platform** | Commercial (e.g., Recorded Future) | Real-time | IOCs, threat actor tracking |
| **Security Mailing Lists** | Community | Daily | Emerging threats, best practices |
| **Vendor Security Advisories** | Microsoft, Thales, etc. | As published | Patching, mitigations |

---

### 9.2 Threat Intelligence Process

```
Threat Intelligence Lifecycle

1. Collection
   ├─ Subscribe to threat feeds
   ├─ Monitor security news
   └─ Engage with security community

2. Processing
   ├─ Filter noise (low-confidence IOCs)
   ├─ Correlate with internal telemetry
   └─ Prioritize by relevance to PKI

3. Analysis
   ├─ Assess applicability to environment
   ├─ Determine risk level
   └─ Identify affected systems

4. Dissemination
   ├─ Alert security team (critical threats)
   ├─ Update runbooks (new TTPs)
   └─ Brief management (strategic threats)

5. Action
   ├─ Apply patches/mitigations
   ├─ Update detection rules
   └─ Conduct threat hunting

6. Feedback
   ├─ Validate effectiveness
   ├─ Refine intelligence sources
   └─ Update threat model
```

---

### 9.3 Recent Threat Intelligence (Last 90 Days)

| Date | Threat | Source | Relevance | Action Taken |
|------|--------|--------|-----------|-------------|
| 2025-10-15 | CVE-2025-XXXX (Keyfactor privilege escalation) | Keyfactor | High | Patch applied within 7 days ✅ |
| 2025-10-01 | Ransomware campaign targeting PKI | Threat Intel Provider | High | Alert sent to team, training reinforced ✅ |
| 2025-09-20 | HSM firmware vulnerability | Thales | Critical | Emergency patch applied within 48 hours ✅ |
| 2025-09-10 | Phishing campaign impersonating PKI team | Internal reporting | Medium | Users notified, phishing test conducted ✅ |
| 2025-08-25 | DDoS attacks on certificate authorities | CISA Alert | Medium | DDoS mitigation reviewed, no action needed ✅ |

---

## 10. Incident Response Integration

### 10.1 Threat-to-Incident Mapping

| Threat Scenario | Incident Type | IR Procedure | Primary Responder |
|----------------|--------------|--------------|-------------------|
| CA Key Compromise | P1 - Critical Security Incident | Key Compromise Response (Section 4.4) | CISO + PKI Lead |
| Ransomware | P1 - Critical System Outage | Platform Failure (Section 4.3) | Incident Commander |
| Malicious Insider | P1 - Critical Security Incident | Insider Threat Investigation | CISO + HR + Legal |
| MitM Attack | P2 - High Security Incident | Network Security Incident | Network Security Team |
| DDoS | P2 - High Availability Incident | DDoS Response (Section 4.2) | Infrastructure Team |
| Phishing | P3 - Medium Security Incident | Phishing Response | Security Ops |

**Reference**: See [10-Incident-Response-Procedures.md](./10-Incident-Response-Procedures.md) for complete incident response procedures.

---

### 10.2 Threat Hunting

**Proactive Threat Hunting Schedule**: Monthly

**Focus Areas**:
- Anomalous certificate issuance (unusual volume, patterns)
- Privilege escalation attempts (failed authorization, role changes)
- Lateral movement (unusual network connections)
- Data exfiltration (large outbound transfers)
- Persistence mechanisms (scheduled tasks, registry changes)

**Threat Hunting Queries** (Splunk):

```spl
# Hunt 1: Unusual certificate issuance patterns
index=keyfactor_audit event_type="CertificateIssued"
| stats count by user_name
| where count > 100  # Threshold: 100 certs/day
| table user_name, count

# Hunt 2: After-hours admin activity
index=keyfactor_audit user_role="PKIAdministrator" 
| eval hour=strftime(_time, "%H")
| where hour < 7 OR hour > 18
| table _time, user_name, event_type, ip_address

# Hunt 3: Failed authorization attempts
index=keyfactor_audit event_type="AuthorizationDenied"
| stats count by user_name, attempted_action
| where count > 10
| table user_name, attempted_action, count

# Hunt 4: Suspicious API usage
index=keyfactor_app source="/api/*" status>=400
| stats count by src_ip, uri
| where count > 50
| table src_ip, uri, count
```

---

## Appendix A: Attack Tree - CA Key Compromise

```
GOAL: Compromise CA Private Key
│
├─ OR: Physical Attack on HSM
│  │
│  ├─ AND: Gain Physical Access
│  │  ├─ Bypass Badge Access
│  │  │  ├─ Tailgating
│  │  │  ├─ Badge Cloning
│  │  │  └─ Social Engineering
│  │  └─ Disable Video Surveillance
│  │
│  ├─ AND: Extract Key from HSM
│  │  ├─ Exploit HSM Vulnerability
│  │  ├─ Use Stolen SO Credentials
│  │  └─ Physical Tampering (HSM tamper detection)
│  │
│  └─ Likelihood: VERY LOW ✅
│     (Multiple strong barriers)
│
├─ OR: Remote Exploit of HSM
│  │
│  ├─ Discover HSM Vulnerability (zero-day)
│  ├─ Network Access to HSM (firewalled)
│  ├─ Bypass HSM Authentication
│  │
│  └─ Likelihood: VERY LOW ✅
│     (HSM on isolated network, regular patching)
│
├─ OR: Steal from Backup
│  │
│  ├─ AND: Access Backup Storage
│  │  ├─ Compromise Backup Server
│  │  └─ Physical Access to Backup Media
│  │
│  ├─ AND: Decrypt Backup
│  │  ├─ Obtain Encryption Key (in HSM or secure vault)
│  │  └─ Decrypt Key Material
│  │
│  └─ Likelihood: LOW ✅
│     (Encrypted backups, dual custody)
│
├─ OR: Insider Threat
│  │
│  ├─ AND: Malicious Security Officer (SO)
│  │  ├─ SO Has Legitimate HSM Access
│  │  ├─ Requires 2nd SO for Dual Control ✅
│  │  └─ Actions Logged and Audited ✅
│  │
│  └─ Likelihood: LOW ✅
│     (Dual control, audit logs, background checks)
│
└─ OR: Supply Chain Attack
   │
   ├─ Compromise HSM Firmware
   ├─ Compromise HSM Hardware
   ├─ Compromise CA Software
   │
   └─ Likelihood: LOW ✅
      (Vendor security, signature verification)

OVERALL RESIDUAL RISK: 🟢 LOW
```

---

## Appendix B: Glossary

**APT (Advanced Persistent Threat)**: Nation-state or sophisticated threat actor with advanced capabilities and long-term objectives.

**DREAD**: Risk assessment model (Damage, Reproducibility, Exploitability, Affected users, Discoverability).

**HSM (Hardware Security Module)**: Tamper-resistant device for secure key storage and cryptographic operations.

**IOC (Indicator of Compromise)**: Artifact indicating a potential security breach.

**MitM (Man-in-the-Middle)**: Attack where attacker intercepts communication between two parties.

**STRIDE**: Threat modeling framework (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege).

**TTP (Tactics, Techniques, Procedures)**: Patterns of behavior used by threat actors.

**Zero-day**: Vulnerability unknown to vendor, no patch available.

---

## Document Maintenance

**Review Schedule**: Semi-annually or after major security incidents  
**Owner**: CISO, Security Architecture Team  
**Last Reviewed**: October 22, 2025  
**Next Review**: April 22, 2026

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial version |

---

**CLASSIFICATION**: INTERNAL USE - CONFIDENTIAL - RESTRICTED  
**Contains sensitive threat intelligence and security architecture details**  
**Distribution limited to security team and executive leadership**

**For security questions, contact**: CISO@contoso.com or adrian207@gmail.com

**End of Threat Model Document**

