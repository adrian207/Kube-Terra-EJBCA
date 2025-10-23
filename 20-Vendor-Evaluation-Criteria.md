# Vendor Evaluation Criteria
## Selection Criteria for Keyfactor and PKI Components

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 23, 2025  
**Classification**: Internal Use  
**Target Audience**: Decision makers, procurement, architecture team

---

## Document Purpose

This document outlines the evaluation criteria used to select Keyfactor and related PKI components. It provides the scoring methodology, vendor comparison matrix, and justification for technology selections to support procurement and vendor management processes.

---

## Table of Contents

1. [Evaluation Framework](#1-evaluation-framework)
2. [Keyfactor Platform Evaluation](#2-keyfactor-platform-evaluation)
3. [Certificate Authority Selection](#3-certificate-authority-selection)
4. [HSM Vendor Evaluation](#4-hsm-vendor-evaluation)
5. [Secrets Management Platform](#5-secrets-management-platform)
6. [Support and Services](#6-support-and-services)
7. [Total Cost of Ownership](#7-total-cost-of-ownership)
8. [Risk Assessment](#8-risk-assessment)

---

## 1. Evaluation Framework

### 1.1 Evaluation Methodology

**Scoring System**:
- **5 = Excellent**: Exceeds requirements, best-in-class
- **4 = Good**: Meets all requirements with minor gaps
- **3 = Acceptable**: Meets core requirements, some limitations
- **2 = Poor**: Significant gaps, workarounds needed
- **1 = Unacceptable**: Does not meet requirements
- **0 = Not applicable / Not evaluated**

**Weighting**:
- **Critical (3x)**: Must-have requirements, deal breakers
- **High (2x)**: Important requirements, significant impact
- **Medium (1x)**: Desirable features, moderate impact
- **Low (0.5x)**: Nice-to-have, minimal impact

**Final Score** = Σ(Score × Weight) / Σ(Weight)

### 1.2 Evaluation Criteria Categories

| Category | Weight | Description |
|----------|--------|-------------|
| **Functionality** | Critical (3x) | Feature completeness, capabilities |
| **Security** | Critical (3x) | Security controls, compliance |
| **Integration** | High (2x) | APIs, protocols, platform support |
| **Scalability** | High (2x) | Performance, capacity, growth |
| **Usability** | Medium (1x) | User experience, documentation |
| **Vendor Strength** | Medium (1x) | Financial stability, market position |
| **Support** | High (2x) | Support quality, SLAs |
| **Cost** | High (2x) | TCO, licensing, value for money |

---

## 2. Keyfactor Platform Evaluation

### 2.1 Vendors Evaluated

1. **Keyfactor Command** (Selected)
2. **Venafi Trust Protection Platform**
3. **DigiCert CertCentral**
4. **Build In-House Solution**

### 2.2 Evaluation Scorecard

| Criteria | Weight | Keyfactor | Venafi | DigiCert | In-House |
|----------|--------|-----------|--------|----------|----------|
| **Functionality** |
| Certificate discovery | Critical | 5 | 5 | 3 | 2 |
| Lifecycle automation | Critical | 5 | 4 | 3 | 3 |
| Multi-CA support | Critical | 5 | 5 | 2 | 4 |
| Policy enforcement | Critical | 5 | 4 | 3 | 4 |
| Orchestrators (cert stores) | High | 5 | 5 | 3 | 2 |
| API completeness | High | 5 | 4 | 4 | 5 |
| ACME/EST/SCEP support | High | 5 | 3 | 2 | 3 |
| **Subtotal** | | **5.0** | **4.3** | **2.9** | **3.3** |
| **Security** |
| RBAC granularity | Critical | 5 | 4 | 3 | 5 |
| HSM integration | Critical | 5 | 5 | 4 | 4 |
| Audit logging | Critical | 5 | 5 | 4 | 4 |
| Compliance reporting | High | 4 | 5 | 3 | 2 |
| Zero-trust architecture | High | 4 | 4 | 3 | 5 |
| **Subtotal** | | **4.6** | **4.6** | **3.4** | **4.0** |
| **Integration** |
| Azure integration | High | 5 | 4 | 5 | 4 |
| Kubernetes (cert-manager) | High | 5 | 3 | 2 | 4 |
| HashiCorp Vault | High | 4 | 3 | 2 | 5 |
| ServiceNow | Medium | 4 | 5 | 3 | 3 |
| CI/CD pipelines | Medium | 4 | 3 | 3 | 5 |
| **Subtotal** | | **4.4** | **3.6** | **3.0** | **4.2** |
| **Scalability** |
| Performance (certs/hour) | High | 5 | 5 | 4 | 3 |
| Multi-tenant capable | High | 5 | 4 | 3 | 4 |
| Geographic distribution | Medium | 4 | 5 | 5 | 3 |
| **Subtotal** | | **4.7** | **4.7** | **4.0** | **3.3** |
| **Usability** |
| User interface | Medium | 4 | 3 | 4 | 2 |
| Documentation quality | Medium | 4 | 4 | 3 | 2 |
| Learning curve | Medium | 4 | 3 | 4 | 5 |
| **Subtotal** | | **4.0** | **3.3** | **3.7** | **3.0** |
| **Vendor Strength** |
| Market position | Medium | 4 | 5 | 5 | 0 |
| Financial stability | Medium | 4 | 4 | 5 | 0 |
| Customer base | Medium | 4 | 5 | 4 | 0 |
| Innovation / roadmap | Medium | 5 | 4 | 3 | 5 |
| **Subtotal** | | **4.3** | **4.5** | **4.3** | **2.5** |
| **Support** |
| Support availability | High | 5 | 5 | 4 | 1 |
| Support quality | High | 4 | 4 | 4 | 1 |
| SLA guarantees | High | 5 | 5 | 4 | 1 |
| Community / resources | Medium | 4 | 3 | 3 | 3 |
| **Subtotal** | | **4.5** | **4.3** | **3.8** | **1.5** |
| **Cost** |
| Initial investment | High | 4 | 2 | 3 | 1 |
| Ongoing costs | High | 4 | 3 | 4 | 3 |
| Value for money | High | 5 | 3 | 4 | 2 |
| **Subtotal** | | **4.3** | **2.7** | **3.7** | **2.0** |
| **WEIGHTED TOTAL** | | **4.65** | **4.16** | **3.51** | **3.20** |

### 2.3 Decision Rationale

**Winner: Keyfactor Command (Score: 4.65/5.0)**

**Strengths**:
- ✅ Best-in-class certificate lifecycle automation
- ✅ Excellent multi-CA support (AD CS, EJBCA, public CAs)
- ✅ Comprehensive orchestrator ecosystem (20+ platforms)
- ✅ Strong API and modern protocol support (ACME, EST, SCEP)
- ✅ Competitive pricing, especially for SaaS deployment
- ✅ Excellent Azure and Kubernetes integration

**Weaknesses**:
- ⚠️ Smaller market share than Venafi (but growing rapidly)
- ⚠️ Community resources less extensive than larger vendors

**Why Not Venafi** (Score: 4.16/5.0):
- More expensive (3x cost difference for our scale)
- Complex licensing model
- Heavier on-premises focus (less cloud-native)
- Overkill for our current needs

**Why Not DigiCert CertCentral** (Score: 3.51/5.0):
- Focused primarily on public certificate management
- Limited orchestrator options for internal PKI
- Weaker automation capabilities

**Why Not In-House** (Score: 3.20/5.0):
- 18+ months development time
- Ongoing maintenance burden
- No vendor support
- Higher TCO when factoring in engineering time

---

## 3. Certificate Authority Selection

### 3.1 CA Options Evaluated

1. **Microsoft AD CS** (Keep existing)
2. **EJBCA** (Add for cloud/K8s)
3. **AWS Private CA**
4. **Azure Managed CA** (preview)
5. **DigiCert Private CA**

### 3.2 Evaluation Scorecard

| Criteria | Weight | AD CS | EJBCA | AWS Private CA | Azure Managed CA | DigiCert |
|----------|--------|-------|-------|----------------|------------------|----------|
| **Functionality** |
| Windows integration | Critical | 5 | 2 | 1 | 3 | 2 |
| ACME support | High | 2 | 5 | 4 | 5 | 4 |
| REST API | High | 2 | 5 | 5 | 5 | 5 |
| HSM support | Critical | 5 | 5 | 5 | 5 | 5 |
| **Subtotal** | | **3.5** | **4.3** | **3.8** | **4.5** | **4.0** |
| **Cost** |
| Licensing | High | 5 | 5 | 2 | 3 | 1 |
| Infrastructure | High | 3 | 4 | 5 | 5 | 5 |
| **Subtotal** | | **4.0** | **4.5** | **3.5** | **4.0** | **3.0** |
| **Integration** |
| Keyfactor support | Critical | 5 | 5 | 4 | 3 | 5 |
| Cloud-native | High | 2 | 4 | 5 | 5 | 4 |
| **Subtotal** | | **3.5** | **4.5** | **4.5** | **4.0** | **4.5** |
| **Operational** |
| Management overhead | High | 3 | 3 | 5 | 5 | 5 |
| Expertise required | High | 5 | 3 | 4 | 4 | 3 |
| **Subtotal** | | **4.0** | **3.0** | **4.5** | **4.5** | **4.0** |
| **WEIGHTED TOTAL** | | **3.75** | **4.08** | **4.08** | **4.25** | **3.88** |

### 3.3 Decision Rationale

**Decision: Hybrid - Keep AD CS + Add EJBCA**

**AD CS** (for Windows domain workloads):
- ✅ Already deployed and operational
- ✅ Seamless GPO auto-enrollment for Windows
- ✅ Existing team expertise
- ✅ No additional licensing costs
- ⚠️ Limited modern protocol support (no ACME)

**EJBCA** (for cloud and Kubernetes):
- ✅ Open-source (no licensing costs)
- ✅ Modern protocols (ACME, EST, REST API)
- ✅ Cloud-native architecture
- ✅ Excellent Keyfactor integration
- ⚠️ Need to build EJBCA expertise

**Alternatives Rejected**:
- **AWS Private CA**: Expensive at scale ($400/month per CA + per-certificate fees)
- **Azure Managed CA**: Still in preview, limited availability
- **DigiCert Private CA**: Very expensive ($10K+ per CA annually)

---

## 4. HSM Vendor Evaluation

### 4.1 HSM Options

1. **Azure Managed HSM** (Selected)
2. **Thales Luna Network HSM**
3. **Entrust nShield**
4. **AWS CloudHSM**

### 4.2 Evaluation Scorecard

| Criteria | Weight | Azure Managed HSM | Thales Luna | Entrust nShield | AWS CloudHSM |
|----------|--------|-------------------|-------------|-----------------|--------------|
| **Security** |
| FIPS 140-2 Level | Critical | 5 (Level 3) | 5 (Level 3) | 5 (Level 3) | 5 (Level 3) |
| Physical security | Critical | 5 | 5 | 5 | 5 |
| Key isolation | Critical | 5 | 5 | 5 | 5 |
| **Subtotal** | | **5.0** | **5.0** | **5.0** | **5.0** |
| **Integration** |
| Azure integration | High | 5 | 3 | 3 | 1 |
| EJBCA support | High | 5 | 5 | 5 | 4 |
| Multi-cloud | Medium | 3 | 5 | 5 | 1 |
| **Subtotal** | | **4.3** | **4.3** | **4.3** | **2.0** |
| **Operational** |
| Management overhead | High | 5 | 2 | 2 | 4 |
| HA/DR built-in | High | 5 | 3 | 3 | 4 |
| Firmware updates | Medium | 5 | 2 | 2 | 4 |
| **Subtotal** | | **5.0** | **2.3** | **2.3** | **4.0** |
| **Cost** |
| Initial cost | High | 5 | 1 | 1 | 4 |
| Ongoing cost | High | 4 | 4 | 4 | 3 |
| TCO (5 years) | High | 5 | 2 | 2 | 4 |
| **Subtotal** | | **4.7** | **2.3** | **2.3** | **3.7** |
| **WEIGHTED TOTAL** | | **4.75** | **3.48** | **3.48** | **3.68** |

**5-Year TCO**:
- **Azure Managed HSM**: $200K ($40K/year)
- **Thales Luna**: $350K ($100K hardware + $50K/year support)
- **Entrust nShield**: $380K ($120K hardware + $52K/year support)
- **AWS CloudHSM**: $240K ($48K/year)

### 4.3 Decision Rationale

**Winner: Azure Managed HSM (Score: 4.75/5.0)**

**Justification**:
- ✅ Lowest TCO for our Azure-first strategy
- ✅ Managed service (no hardware management)
- ✅ Built-in HA/DR across availability zones
- ✅ FIPS 140-2 Level 3 certified
- ✅ Seamless Azure integration
- ✅ Rapid deployment (< 1 week vs 2-3 months)

**Trade-off**: Vendor lock-in to Azure (acceptable given our cloud strategy)

---

## 5. Secrets Management Platform

### 5.1 Evaluation Summary

| Criteria | Azure Key Vault | HashiCorp Vault | CyberArk |
|----------|----------------|----------------|----------|
| **Azure integration** | 5 | 3 | 3 |
| **Multi-cloud support** | 2 | 5 | 4 |
| **Cost (TCO)** | 5 | 4 | 1 |
| **Dynamic secrets** | 2 | 5 | 3 |
| **Operational overhead** | 5 | 3 | 2 |
| **Kubernetes support** | 3 | 5 | 2 |
| **WEIGHTED SCORE** | **3.7** | **4.2** | **2.5** |

**Decision: Hybrid - Azure Key Vault + HashiCorp Vault**

**Rationale**: Use the right tool for each workload
- Azure Key Vault for Azure-native workloads (managed service, low cost)
- HashiCorp Vault for Kubernetes and multi-cloud (advanced features, flexibility)

---

## 6. Support and Services

### 6.1 Support Requirements

| Requirement | Keyfactor | Venafi | DigiCert |
|------------|-----------|--------|----------|
| **24/7 support availability** | ✅ Yes (SaaS) | ✅ Yes (Premium) | ✅ Yes |
| **Response time (P1)** | < 1 hour | < 1 hour | < 2 hours |
| **Response time (P2)** | < 4 hours | < 4 hours | < 8 hours |
| **Dedicated CSM** | ✅ Yes | ✅ Yes | ❌ No |
| **Professional services** | ✅ Available | ✅ Available | ✅ Limited |
| **Training** | ✅ Online + on-site | ✅ Online + on-site | ✅ Online only |
| **Community forum** | ✅ Yes | ✅ Yes | ✅ Yes |

### 6.2 Keyfactor Support Tiers

**Selected: Premium Support (included with SaaS)**

**Includes**:
- 24/7/365 support access
- < 1 hour response for P1 (production down)
- < 4 hours response for P2 (degraded)
- Dedicated Customer Success Manager
- Quarterly business reviews
- Access to Professional Services team
- Product roadmap visibility

**Cost**: $0 additional (included in SaaS subscription)

---

## 7. Total Cost of Ownership

### 7.1 5-Year TCO Comparison

| Component | Keyfactor (Selected) | Venafi | In-House |
|-----------|---------------------|--------|----------|
| **Platform** |
| Initial license/setup | $0 (SaaS) | $250K | $0 |
| Annual subscription | $150K/year = $750K | $200K/year = $1M | $0 |
| **Infrastructure** |
| Servers/cloud | $0 (SaaS) | $100K | $150K |
| Annual infrastructure | $0 | $20K/year = $100K | $30K/year = $150K |
| **CA & HSM** |
| AD CS (existing) | $0 | $0 | $0 |
| EJBCA setup | $20K (consulting) | $20K | $50K (dev) |
| Azure Managed HSM | $40K/year = $200K | $40K/year = $200K | $40K/year = $200K |
| **Personnel** |
| PKI admin (1 FTE) | $150K/year = $750K | $150K/year = $750K | $150K/year = $750K |
| Platform admin (0.5 FTE) | $0 (managed) | $75K/year = $375K | $75K/year = $375K |
| Developer time | $0 | $0 | $300K (initial) + $100K/year = $800K |
| **Training & Support** |
| Training | $15K | $20K | $10K |
| Annual support | $0 (included) | $40K/year = $200K | $0 |
| **TOTAL (5 years)** | **$1.735M** | **$2.845M** | **$2.485M** |

**TCO Winner: Keyfactor ($1.735M)**
- **39% less expensive** than Venafi
- **30% less expensive** than in-house solution
- Lower operational overhead
- Faster time to value

### 7.2 Cost Avoidance (Benefits)

**Current State** (manual processes):
- Certificate-related outages: 12/year × $50K = **$600K/year**
- Manual effort: 120 hours/month × $75/hour × 12 = **$108K/year**
- Shadow IT certificates: Security risk (unquantified, but significant)

**Future State** (with Keyfactor):
- Outages: < 1/year × $50K = **$50K/year**
- Manual effort: < 10 hours/month × $75/hour × 12 = **$9K/year**
- Shadow IT: Near zero (discovery and enforcement)

**Annual Savings**: $600K + $108K - $50K - $9K = **$649K/year**
**5-Year Savings**: **$3.245M**
**5-Year ROI**: ($3.245M - $1.735M) / $1.735M = **87% return**
**Payback Period**: < 18 months

---

## 8. Risk Assessment

### 8.1 Vendor Risk

| Risk | Keyfactor | Mitigation |
|------|-----------|------------|
| **Vendor viability** | Low | Strong financials, growing customer base, PE backing |
| **Product discontinuation** | Low | Core product, large install base |
| **SaaS availability** | Medium | 99.9% SLA, multi-region redundancy |
| **Vendor lock-in** | Medium | Standard protocols (ACME, EST), exportable data |
| **Security breach** | Low | SOC 2 Type II, ISO 27001, robust security |

### 8.2 Implementation Risk

| Risk | Level | Mitigation |
|------|-------|------------|
| **Integration complexity** | Medium | Phased implementation, POC in dev environment |
| **Team expertise gap** | Medium | Training, vendor professional services |
| **Migration from manual** | High | Gradual rollout, pilot projects first |
| **Change management** | High | Communication plan, service owner onboarding |
| **CA integration issues** | Medium | Vendor support, test environment validation |

### 8.3 Risk vs. Reward

**Risk**: $1.735M investment + implementation effort  
**Reward**: $3.245M in savings + risk reduction + automation

**Conclusion**: Benefits significantly outweigh risks

---

## 9. Procurement Recommendations

### 9.1 Contract Terms

**Keyfactor SaaS Agreement**:
- **Term**: 3-year contract (with annual renewal option)
- **Pricing**: $150K/year, locked for 3 years
- **SLA**: 99.9% uptime guarantee
- **Support**: Premium support included
- **Terms**: 90-day termination notice

**Negotiation Points**:
- ✅ Secured 3-year price lock
- ✅ Premium support at no additional cost
- ✅ Unlimited certificates included
- ✅ Unlimited orchestrators
- ⚠️ Professional services quoted separately ($200/hour)

### 9.2 Azure Managed HSM

- **Pricing**: Standard tier, pay-as-you-go
- **Estimated**: $3,400/month (~$40K/year)
- **Commitment**: None (consumption-based)

### 9.3 EJBCA

- **License**: Open-source, free
- **Consulting**: $20K one-time setup
- **Support**: Community-based (free) or commercial support ($10K/year - optional)

---

## 10. Vendor Scorecard Summary

| Vendor | Category | Score | Rank |
|--------|----------|-------|------|
| **Keyfactor** | CLM Platform | 4.65/5.0 | 🥇 1st |
| Venafi | CLM Platform | 4.16/5.0 | 2nd |
| DigiCert | CLM Platform | 3.51/5.0 | 3rd |
| **Azure Managed HSM** | HSM | 4.75/5.0 | 🥇 1st |
| Thales Luna | HSM | 3.48/5.0 | 2nd |
| **EJBCA** | CA | 4.08/5.0 | 🥇 1st (tie) |
| Azure Managed CA | CA | 4.25/5.0 | 🥇 1st |
| **AD CS** | CA (Windows) | 3.75/5.0 | Keep existing |
| **HashiCorp Vault** | Secrets (Multi-cloud) | 4.2/5.0 | 🥇 1st |
| **Azure Key Vault** | Secrets (Azure) | 3.7/5.0 | 🥇 1st (Azure) |

---

## Document Maintenance

**Review Schedule**: Annually or when re-procurement is needed  
**Owner**: Enterprise Architecture + Procurement  
**Last Reviewed**: October 23, 2025  
**Next Review**: October 2026 (or before contract renewal)

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-23 | Adrian Johnson | Initial vendor evaluation criteria and selection rationale |

---

**For procurement questions, contact**: adrian207@gmail.com

**End of Vendor Evaluation Criteria**

