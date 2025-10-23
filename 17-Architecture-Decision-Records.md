# Architecture Decision Records (ADRs)
## Key Technical Decisions for Keyfactor PKI Implementation

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 23, 2025  
**Classification**: Internal Use  
**Target Audience**: Architecture review board, technical leadership, implementation team

---

## Document Purpose

This document records significant architectural and technical decisions made during the Keyfactor PKI implementation design. Each decision record follows a standard format documenting the context, decision, rationale, alternatives considered, consequences, and approval status.

---

## Table of Contents

1. [ADR Template](#adr-template)
2. [ADR-001: Deployment Model Selection](#adr-001-deployment-model-selection)
3. [ADR-002: Certificate Authority Strategy](#adr-002-certificate-authority-strategy)
4. [ADR-003: HSM Selection](#adr-003-hsm-selection)
5. [ADR-004: Secrets Management Platform](#adr-004-secrets-management-platform)
6. [ADR-005: Kubernetes Certificate Automation](#adr-005-kubernetes-certificate-automation)
7. [ADR-006: Automation Approach](#adr-006-automation-approach)
8. [ADR-007: Database Platform](#adr-007-database-platform)
9. [ADR-008: Supported Enrollment Protocols](#adr-008-supported-enrollment-protocols)
10. [ADR-009: Network Architecture](#adr-009-network-architecture)
11. [ADR-010: Monitoring and Observability Platform](#adr-010-monitoring-and-observability-platform)

---

## ADR Template

```markdown
# ADR-XXX: [Decision Title]

**Status**: [Proposed | Accepted | Rejected | Deprecated | Superseded]
**Date**: YYYY-MM-DD
**Deciders**: [List of people involved]
**Technical Story**: [Ticket/Issue reference]

## Context and Problem Statement

[Describe the context and problem requiring a decision]

## Decision Drivers

* [Driver 1]
* [Driver 2]
* [Driver 3]

## Considered Options

* [Option 1]
* [Option 2]
* [Option 3]

## Decision Outcome

**Chosen option**: "[Option X]", because [justification]

### Positive Consequences

* [Positive consequence 1]
* [Positive consequence 2]

### Negative Consequences

* [Negative consequence 1]
* [Negative consequence 2]

## Pros and Cons of the Options

### [Option 1]

* **Pros**
  * [Pro 1]
  * [Pro 2]
* **Cons**
  * [Con 1]
  * [Con 2]

[Repeat for each option]

## Links

* [Related ADRs]
* [Related documentation]
```

---

## ADR-001: Deployment Model Selection

**Status**: Accepted  
**Date**: 2025-10-15  
**Deciders**: CISO, VP Infrastructure, Enterprise Architect, PKI Lead  
**Technical Story**: ARCH-2025-001

### Context and Problem Statement

We need to decide whether to deploy Keyfactor Command as a SaaS (cloud-hosted) solution or self-hosted in our data center. This decision impacts operational overhead, security boundaries, compliance, cost, and time-to-value.

### Decision Drivers

* **Security and Compliance**: SOC 2 Type II, PCI-DSS, data residency requirements
* **Operational Overhead**: Available staff for platform management
* **Time to Value**: Speed of implementation
* **Cost**: Total cost of ownership over 5 years
* **Reliability**: SLA requirements and disaster recovery
* **Integration**: Network connectivity to existing systems
* **Control**: Level of customization and control needed

### Considered Options

1. **Keyfactor Command SaaS** (cloud-hosted by Keyfactor)
2. **Self-Hosted on-premises** (in our data center)
3. **Self-Hosted in Azure** (IaaS deployment)
4. **Hybrid** (SaaS for management, self-hosted CA)

### Decision Outcome

**Chosen option**: "Keyfactor Command SaaS", because:

1. **Faster time to value**: Operational in weeks vs months
2. **Reduced operational overhead**: No infrastructure management
3. **Built-in HA/DR**: 99.9% SLA provided by Keyfactor
4. **Automatic updates**: Platform updates without downtime
5. **Compliance**: Keyfactor SaaS is SOC 2 Type II certified
6. **Cost-effective**: Lower TCO than self-hosted infrastructure
7. **Focus on value**: Team can focus on PKI policy and automation vs infrastructure

### Positive Consequences

* ✅ Implementation timeline reduced from 24 weeks to 16 weeks
* ✅ No infrastructure provisioning or patching overhead
* ✅ Predictable monthly costs (OpEx vs CapEx)
* ✅ Access to Keyfactor support and expertise
* ✅ Automatic platform updates and security patches
* ✅ Built-in monitoring and alerting

### Negative Consequences

* ⚠️ Dependency on Keyfactor's SaaS availability
* ⚠️ Network connectivity required to SaaS endpoint
* ⚠️ Less control over platform customization
* ⚠️ Data stored in Keyfactor's cloud (certificate metadata, not private keys)

### Mitigation Strategies

* **Availability**: Implement local caching for critical operations
* **Connectivity**: Redundant internet connections with failover
* **Customization**: Work with Keyfactor on feature requests
* **Data**: Ensure contractual data protection and access controls

## Pros and Cons of the Options

### Option 1: Keyfactor Command SaaS

* **Pros**
  * Fastest deployment (2-4 weeks)
  * No infrastructure management
  * 99.9% SLA with built-in HA/DR
  * Automatic updates and patches
  * Lower TCO ($150K/year vs $300K/year self-hosted)
  * SOC 2 Type II compliance
  * Access to Keyfactor's expertise
* **Cons**
  * Dependency on internet connectivity
  * Data stored in Keyfactor's cloud
  * Less control over platform
  * Subscription-based pricing (ongoing cost)

### Option 2: Self-Hosted On-Premises

* **Pros**
  * Full control over platform and data
  * No dependency on external services
  * One-time license cost
  * Can run fully air-gapped
* **Cons**
  * Longer deployment (6+ months)
  * Requires infrastructure (servers, storage, backup)
  * Operational overhead (patching, updates, monitoring)
  * Need 24/7 on-call support
  * Higher TCO ($300K/year)
  * HA/DR configuration complexity
  * Slower access to new features

### Option 3: Self-Hosted in Azure (IaaS)

* **Pros**
  * Control over platform
  * Cloud-native scalability
  * Integration with Azure services
  * Faster than on-prem deployment
* **Cons**
  * Still requires infrastructure management
  * Azure costs (compute, storage, networking)
  * Operational overhead for updates
  * Longer deployment than SaaS
  * Need Azure expertise

### Option 4: Hybrid (SaaS + Self-Hosted CA)

* **Pros**
  * Management in SaaS, CA on-prem
  * Meets air-gap CA requirements
  * Balance of convenience and control
* **Cons**
  * Most complex architecture
  * Network connectivity between environments
  * Highest operational overhead
  * Requires both SaaS and on-prem infrastructure

### Links

* [01 - Executive Design Document](./01-Executive-Design-Document.md) § 3 Architecture Overview
* [04 - Architecture Diagrams](./04-Architecture-Diagrams.md)
* Cost comparison: [22-Cost-Analysis.md](./22-Cost-Analysis.md)

---

## ADR-002: Certificate Authority Strategy

**Status**: Accepted  
**Date**: 2025-10-15  
**Deciders**: CISO, PKI Lead, Windows Team Lead, Security Architect  
**Technical Story**: ARCH-2025-002

### Context and Problem Statement

We need to decide which Certificate Authority (CA) technology to use for internal certificate issuance. We currently have Microsoft Active Directory Certificate Services (AD CS) deployed but it's underutilized and requires Windows expertise. We must decide whether to continue with AD CS, migrate to EJBCA, use a cloud-native CA, or adopt a hybrid approach.

### Decision Drivers

* **Existing Investment**: AD CS already deployed with 2 issuing CAs
* **Windows Dependency**: AD CS requires Windows Server and AD expertise
* **Feature Requirements**: ACME protocol support, REST API, cloud-native features
* **Compliance**: FIPS 140-2 Level 3 HSM requirement
* **Integration**: GPO auto-enrollment for Windows endpoints
* **Cost**: Licensing and operational costs
* **Risk**: Migration complexity vs technical debt

### Considered Options

1. **Keep AD CS** (modernize with Keyfactor integration)
2. **Migrate to EJBCA** (open-source, feature-rich)
3. **Hybrid: AD CS for Windows + EJBCA for cloud/Kubernetes**
4. **Cloud-native CA** (AWS Private CA, Azure Managed CA, Google CAS)

### Decision Outcome

**Chosen option**: "Hybrid: AD CS for Windows + EJBCA for cloud/Kubernetes", because:

1. **Preserve existing investment**: AD CS handles ~40% of our certificates (Windows domain-joined systems)
2. **Leverage GPO auto-enrollment**: Seamless Windows certificate deployment
3. **Cloud-native features**: EJBCA provides ACME, REST API, modern enrollment
4. **Future-proof**: EJBCA aligns with cloud-first strategy
5. **Risk mitigation**: Phased migration vs big-bang replacement
6. **Best of both worlds**: Windows-integrated + cloud-native capabilities

### Positive Consequences

* ✅ No disruption to existing Windows auto-enrollment
* ✅ ACME protocol support for Let's Encrypt-compatible clients
* ✅ Modern REST API for cloud and Kubernetes workloads
* ✅ Reduced Windows dependency for non-domain workloads
* ✅ Open-source EJBCA = no additional licensing costs
* ✅ Phased migration reduces risk

### Negative Consequences

* ⚠️ Two CA platforms to operate and maintain
* ⚠️ Increased complexity in CA failover scenarios
* ⚠️ Need EJBCA expertise in addition to AD CS
* ⚠️ Template management across two platforms

### Migration Path

**Phase 1** (Months 1-3): Deploy EJBCA, integrate with Keyfactor
**Phase 2** (Months 4-6): Migrate Kubernetes and cloud workloads to EJBCA
**Phase 3** (Months 7-12): Evaluate full AD CS retirement for non-Windows workloads
**Long-term**: Maintain AD CS for Windows, EJBCA for everything else

## Pros and Cons of the Options

### Option 1: Keep AD CS

* **Pros**
  * No migration effort
  * Existing expertise
  * GPO auto-enrollment works natively
  * Windows-integrated
* **Cons**
  * No native ACME support
  * Limited REST API
  * Windows Server dependency
  * Not cloud-native
  * Requires domain join for auto-enrollment
  * Legacy technology

### Option 2: Migrate to EJBCA

* **Pros**
  * Open-source (no license costs)
  * Modern features (ACME, EST, REST API)
  * Cloud-native architecture
  * Strong community support
  * Kubernetes-friendly
  * Multi-tenant capable
* **Cons**
  * Migration effort for all certificates
  * Loss of GPO auto-enrollment for Windows
  * New technology = learning curve
  * Need to replace Windows enrollment mechanisms

### Option 3: Hybrid (AD CS + EJBCA) ⭐ CHOSEN

* **Pros**
  * Best of both worlds
  * Phased migration (low risk)
  * Preserve Windows auto-enrollment
  * Modern features for cloud/K8s
  * Reduced Windows dependency
  * Future flexibility
* **Cons**
  * Two platforms to operate
  * Template management complexity
  * Higher initial effort
  * Need expertise in both

### Option 4: Cloud-Native CA

* **Pros**
  * Managed service (low operational overhead)
  * Cloud-native integration
  * Scalable and highly available
* **Cons**
  * Vendor lock-in (AWS, Azure, or Google)
  * Ongoing cloud costs (expensive at scale)
  * Limited control
  * Not suitable for on-prem workloads

### Links

* [KEYFACTOR-INTEGRATIONS-GUIDE.md](./KEYFACTOR-INTEGRATIONS-GUIDE.md) - EJBCA integration details
* [14-Integration-Specifications.md](./14-Integration-Specifications.md) § 5 AD CS, § 6 EJBCA
* [21-Migration-Strategy.md](./21-Migration-Strategy.md) - CA migration plan

---

## ADR-003: HSM Selection

**Status**: Accepted  
**Date**: 2025-10-16  
**Deciders**: CISO, PKI Lead, Security Architect, Infrastructure Lead  
**Technical Story**: ARCH-2025-003

### Context and Problem Statement

Certificate Authority private keys require FIPS 140-2 Level 3 protection per security policy and compliance requirements. We must select an HSM solution that balances security, cost, operational complexity, and integration requirements.

### Decision Drivers

* **Compliance**: FIPS 140-2 Level 3 mandatory for CA keys
* **Security**: Physical and logical protection of cryptographic keys
* **High Availability**: No single point of failure
* **Cost**: CapEx vs OpEx, 5-year TCO
* **Cloud Strategy**: Alignment with Azure-first cloud adoption
* **Operational Overhead**: Management, firmware updates, key ceremonies
* **Performance**: Signing operations per second

### Considered Options

1. **Azure Managed HSM** (cloud-native, managed service)
2. **Network HSM (Thales Luna)** (on-premises hardware)
3. **AWS CloudHSM** (if using AWS infrastructure)
4. **Hybrid** (Azure Managed HSM + on-prem for backup)

### Decision Outcome

**Chosen option**: "Azure Managed HSM", because:

1. **FIPS 140-2 Level 3 certified**: Meets compliance requirements
2. **Managed service**: No hardware procurement, maintenance, or firmware updates
3. **High availability**: Built-in redundancy across Azure availability zones
4. **Azure-native**: Seamless integration with Azure Key Vault, EJBCA in Azure
5. **Lower TCO**: ~$40K/year vs $150K+ for on-prem HSM
6. **Rapid deployment**: Operational in days vs months
7. **Cloud-first alignment**: Supports Azure-first strategy

### Positive Consequences

* ✅ FIPS 140-2 Level 3 compliance
* ✅ No hardware management overhead
* ✅ Built-in HA and disaster recovery
* ✅ Automatic firmware updates (managed by Azure)
* ✅ Pay-as-you-go pricing (OpEx)
* ✅ Rapid deployment (< 1 week)
* ✅ Integration with Azure services
* ✅ Dedicated HSM partition per tenant

### Negative Consequences

* ⚠️ Dependency on Azure cloud availability
* ⚠️ Cannot run fully air-gapped CA
* ⚠️ Vendor lock-in to Azure
* ⚠️ Ongoing subscription cost

### Mitigation Strategies

* **Availability**: Azure SLA 99.99% for Managed HSM
* **Air-gap**: If offline root CA needed, use network HSM for root only
* **Lock-in**: Export key backup using Azure Key Backup (encrypted)
* **Cost**: Predictable monthly costs, budget accordingly

## Pros and Cons of the Options

### Option 1: Azure Managed HSM ⭐ CHOSEN

* **Pros**
  * FIPS 140-2 Level 3 certified
  * Managed service (low operational overhead)
  * Built-in HA across availability zones
  * No hardware procurement
  * Rapid deployment
  * Azure-native integration
  * Lower TCO ($40K/year)
  * Automatic updates
* **Cons**
  * Dependency on Azure
  * Ongoing subscription cost
  * Not suitable for air-gapped environments
  * Vendor lock-in

### Option 2: Network HSM (Thales Luna)

* **Pros**
  * FIPS 140-2 Level 3 certified
  * Full control over hardware
  * Can operate air-gapped
  * One-time purchase
  * No cloud dependency
* **Cons**
  * High upfront cost ($100K+ hardware)
  * Requires HA pair ($200K+)
  * Operational overhead (firmware, updates)
  * Physical security requirements
  * Longer deployment (2-3 months)
  * Need specialized expertise
  * HA/DR complexity

### Option 3: AWS CloudHSM

* **Pros**
  * FIPS 140-2 Level 3 certified
  * Managed service
  * AWS-native integration
* **Cons**
  * Not aligned with Azure-first strategy
  * Would require AWS infrastructure
  * Cross-cloud complexity
  * Not considered further

### Option 4: Hybrid (Azure + On-prem)

* **Pros**
  * Root CA in air-gapped on-prem HSM
  * Issuing CAs in Azure Managed HSM
  * Maximum security for root CA
* **Cons**
  * Most complex architecture
  * Highest cost (both solutions)
  * Operational overhead for both
  * Not necessary for our threat model

### Links

* [11-Security-Controls.md](./11-Security-Controls.md) § 2.2 HSM Integration
* [13-Threat-Model.md](./13-Threat-Model.md) - CA Key Compromise scenario
* [22-Cost-Analysis.md](./22-Cost-Analysis.md) - HSM cost comparison

---

## ADR-004: Secrets Management Platform

**Status**: Accepted  
**Date**: 2025-10-17  
**Deciders**: Security Architect, Cloud Architect, DevOps Lead  
**Technical Story**: ARCH-2025-004

### Context and Problem Statement

We need a secrets management platform to store certificates, private keys, and other secrets for applications and services. We must decide between Azure Key Vault, HashiCorp Vault, or a hybrid approach to balance cloud-native integration, multi-cloud support, and existing investments.

### Decision Drivers

* **Cloud Strategy**: Azure-first, but multi-cloud presence (AWS, on-prem)
* **Existing Investment**: Already using Azure Key Vault for some workloads
* **Multi-cloud Requirements**: AWS workloads need secrets management
* **Kubernetes Integration**: Native integration with K8s workloads
* **Advanced Features**: Dynamic secrets, secrets rotation, PKI engine
* **Cost**: Licensing and operational costs
* **Operational Overhead**: Management complexity

### Considered Options

1. **Azure Key Vault only**
2. **HashiCorp Vault only**
3. **Hybrid: Azure Key Vault + HashiCorp Vault** (workload-specific)
4. **CyberArk** (enterprise PAM solution)

### Decision Outcome

**Chosen option**: "Hybrid: Azure Key Vault + HashiCorp Vault", because:

1. **Azure Key Vault for Azure workloads**: Native integration, managed service
2. **HashiCorp Vault for multi-cloud/K8s**: AWS, on-prem, Kubernetes workloads
3. **Best of both worlds**: Azure-native + multi-cloud flexibility
4. **Existing investment**: Leverage existing Azure Key Vault deployments
5. **Advanced features**: Vault provides dynamic secrets, PKI engine, secrets rotation
6. **Future-proof**: Support for multi-cloud strategy

### Positive Consequences

* ✅ Azure Key Vault: Managed service, Azure-native, low overhead
* ✅ HashiCorp Vault: Multi-cloud, advanced features, Kubernetes integration
* ✅ Workload-appropriate: Use the right tool for each environment
* ✅ Flexibility: Not locked into single vendor
* ✅ Existing expertise: Teams already familiar with both platforms

### Negative Consequences

* ⚠️ Two platforms to manage and integrate
* ⚠️ Need expertise in both solutions
* ⚠️ Potential confusion on which platform to use
* ⚠️ Integration complexity with Keyfactor

### Decision Matrix

| Workload Type | Platform | Rationale |
|--------------|----------|-----------|
| **Azure VMs/App Services** | Azure Key Vault | Native integration, managed identities |
| **Azure Kubernetes (AKS)** | HashiCorp Vault | CSI driver, better K8s support |
| **AWS Workloads** | HashiCorp Vault | Multi-cloud, no AWS dependency |
| **On-Premises** | HashiCorp Vault | Not cloud-dependent |
| **Windows Servers (domain)** | Windows Certificate Store | GPO deployment |

## Pros and Cons of the Options

### Option 1: Azure Key Vault Only

* **Pros**
  * Managed service (low overhead)
  * Azure-native integration
  * Built-in RBAC with Azure AD
  * FIPS 140-2 Level 2 (Standard) or Level 3 (Premium)
  * Lower cost for Azure workloads
* **Cons**
  * Azure-only (not multi-cloud)
  * Limited dynamic secrets capabilities
  * No advanced PKI features
  * Poor AWS integration

### Option 2: HashiCorp Vault Only

* **Pros**
  * Multi-cloud support
  * Advanced features (dynamic secrets, PKI engine)
  * Strong Kubernetes integration
  * Open-source (free) or Enterprise
* **Cons**
  * Self-managed (operational overhead)
  * Higher cost for managed Vault (HCP Vault)
  * Less Azure-native than Key Vault
  * Requires infrastructure

### Option 3: Hybrid (Azure Key Vault + HashiCorp Vault) ⭐ CHOSEN

* **Pros**
  * Best tool for each workload
  * Azure Key Vault for Azure-native
  * HashiCorp Vault for multi-cloud/K8s
  * Flexibility and future-proof
  * Leverage existing investments
* **Cons**
  * Two platforms to manage
  * Need expertise in both
  * Integration complexity
  * Higher operational overhead

### Option 4: CyberArk

* **Pros**
  * Enterprise PAM solution
  * Strong audit and compliance features
  * Centralized secrets management
* **Cons**
  * Expensive ($200K+ annually)
  * Complex deployment
  * Overkill for our requirements
  * Not cloud-native

### Links

* [14-Integration-Specifications.md](./14-Integration-Specifications.md) § 2 Azure Key Vault, § 3 HashiCorp Vault
* [KEYFACTOR-INTEGRATIONS-GUIDE.md](./KEYFACTOR-INTEGRATIONS-GUIDE.md) - Orchestrator details

---

## ADR-005: Kubernetes Certificate Automation

**Status**: Accepted  
**Date**: 2025-10-18  
**Deciders**: Kubernetes Lead, DevOps Lead, PKI Lead  
**Technical Story**: ARCH-2025-005

### Context and Problem Statement

We need an automated certificate management solution for Kubernetes workloads that supports hundreds of microservices across multiple clusters. The solution must integrate with Keyfactor, support standard protocols, and provide a Kubernetes-native developer experience.

### Decision Drivers

* **Kubernetes-native**: CRD-based, familiar to developers
* **Automation**: Zero-touch certificate lifecycle
* **Integration**: Works with Keyfactor and our CAs
* **Standard protocols**: ACME, EST support
* **Multi-cluster**: Works across dev, staging, production clusters
* **Vendor support**: Active maintenance and community
* **Ease of use**: Minimal operational overhead

### Considered Options

1. **cert-manager + Keyfactor External Issuer**
2. **Keyfactor Kubernetes Secrets Agent**
3. **External secrets operator + Key Vault**
4. **Custom solution (DIY)**

### Decision Outcome

**Chosen option**: "cert-manager + Keyfactor External Issuer", because:

1. **De facto standard**: cert-manager is the industry-standard for K8s certificate management
2. **Kubernetes-native**: Uses Certificate CRD, familiar to developers
3. **Keyfactor integration**: Official Keyfactor external issuer available
4. **Multiple issuer support**: Can use Keyfactor, Let's Encrypt, self-signed for different environments
5. **Active development**: CNCF project with strong community
6. **No vendor lock-in**: Can switch issuers without changing workload configurations

### Positive Consequences

* ✅ Developers use standard `Certificate` CRD
* ✅ Automatic renewal before expiration
* ✅ Secrets automatically updated in pods
* ✅ Works with Ingress, Service Mesh (Istio), and application certificates
* ✅ Strong community and documentation
* ✅ Can use Let's Encrypt for dev/test, Keyfactor for production

### Negative Consequences

* ⚠️ Requires cert-manager deployment in each cluster
* ⚠️ External issuer is maintained by community (not Keyfactor official)
* ⚠️ Need Kubernetes and PKI expertise
* ⚠️ API access required from K8s cluster to Keyfactor

## Pros and Cons of the Options

### Option 1: cert-manager + Keyfactor External Issuer ⭐ CHOSEN

* **Pros**
  * Industry standard
  * Kubernetes-native (CRD-based)
  * Active CNCF project
  * Strong community support
  * Multiple issuer support
  * Well-documented
  * No vendor lock-in
* **Cons**
  * Requires cert-manager deployment
  * External issuer = community supported
  * API connectivity required

### Option 2: Keyfactor Kubernetes Secrets Agent

* **Pros**
  * Official Keyfactor solution
  * Direct integration
* **Cons**
  * Less Kubernetes-native
  * Smaller community
  * Vendor-specific
  * Less flexibility

### Option 3: External Secrets Operator + Key Vault

* **Pros**
  * Can sync certs from Key Vault
  * Multi-cloud secrets support
* **Cons**
  * Not certificate-focused
  * No automatic renewal
  * Manual certificate management
  * Extra layer of indirection

### Option 4: Custom Solution

* **Pros**
  * Full control
  * Tailored to our needs
* **Cons**
  * Development and maintenance overhead
  * Reinventing the wheel
  * No community support
  * Risk of bugs and security issues

### Links

* [07-Enrollment-Rails-Guide.md](./07-Enrollment-Rails-Guide.md) § Kubernetes cert-manager
* [14-Integration-Specifications.md](./14-Integration-Specifications.md) § 4 Kubernetes
* [KEYFACTOR-INTEGRATIONS-GUIDE.md](./KEYFACTOR-INTEGRATIONS-GUIDE.md)

---

## ADR-006: Automation Approach

**Status**: Accepted  
**Date**: 2025-10-19  
**Deciders**: DevOps Lead, PKI Lead, Infrastructure Architect  
**Technical Story**: ARCH-2025-006

### Context and Problem Statement

We need to automate certificate renewal, deployment, and service reload workflows. The solution must handle hundreds of certificates across diverse infrastructure (Windows, Linux, Azure, AWS, Kubernetes, network devices) with minimal manual intervention.

### Decision Drivers

* **Zero-touch goal**: 95%+ certificates renew automatically
* **Event-driven**: Real-time response to certificate events
* **Platform diversity**: Windows, Linux, cloud, containers, appliances
* **Integration**: ServiceNow, Slack, monitoring platforms
* **Reliability**: Failed automation must not cause outages
* **Maintainability**: Easy to troubleshoot and extend

### Considered Options

1. **Event-driven (webhooks) + Orchestrators**
2. **Polling-based automation (scheduled jobs)**
3. **Agent-based (push model)**
4. **Hybrid: Webhooks for apps, GPO for Windows**

### Decision Outcome

**Chosen option**: "Hybrid: Webhooks for apps, GPO for Windows", because:

1. **Event-driven webhooks**: Real-time automation for cloud and app workloads
2. **GPO auto-enrollment**: Native Windows certificate management
3. **Keyfactor orchestrators**: Automated deployment to certificate stores (Azure KV, F5, etc.)
4. **Best fit per platform**: Use native mechanisms where available
5. **Scalability**: Event-driven scales better than polling
6. **Extensibility**: Easy to add new webhook handlers

### Positive Consequences

* ✅ Real-time certificate deployment (< 5 minutes)
* ✅ Native Windows experience (GPO auto-enrollment)
* ✅ Scalable event-driven architecture
* ✅ Easy to extend with new integrations
* ✅ Reduced polling overhead
* ✅ ServiceNow integration for change management

### Negative Consequences

* ⚠️ Webhook endpoint must be highly available
* ⚠️ Multiple automation mechanisms to maintain
* ⚠️ Requires event-driven mindset
* ⚠️ Debugging distributed async workflows

## Pros and Cons of the Options

### Option 1: Event-Driven (Webhooks) + Orchestrators ⭐ CHOSEN

* **Pros**
  * Real-time response
  * Scalable architecture
  * Reduced overhead vs polling
  * Event-driven = modern architecture
  * Easy to integrate (webhook consumers)
* **Cons**
  * Requires HA webhook endpoints
  * Async = harder to debug
  * Need retry and dead-letter queues

### Option 2: Polling-Based (Scheduled Jobs)

* **Pros**
  * Simple to understand
  * Easier to debug
  * No webhook infrastructure
* **Cons**
  * Delayed response (poll interval)
  * Higher overhead (constant polling)
  * Not scalable
  * Batch-oriented vs real-time

### Option 3: Agent-Based (Push Model)

* **Pros**
  * Direct control
  * No network dependencies
* **Cons**
  * Agent deployment and maintenance
  * Agent versioning complexity
  * Firewall rules for inbound connections
  * Not suitable for cloud workloads

### Option 4: Hybrid ⭐ CHOSEN VARIATION

* **Pros**
  * Best tool for each platform
  * Windows: GPO auto-enrollment
  * Cloud/Apps: Webhooks
  * Appliances: Orchestrators
* **Cons**
  * Multiple mechanisms
  * Platform-specific knowledge required

### Links

* [06-Automation-Playbooks.md](./06-Automation-Playbooks.md)
* [automation/webhooks/](./automation/webhooks/) - Webhook scripts
* [05-Implementation-Runbooks.md](./05-Implementation-Runbooks.md) § Phase 4

---

## ADR-007: Database Platform

**Status**: Accepted  
**Date**: 2025-10-20  
**Deciders**: DBA Team, Infrastructure Lead, Keyfactor Architect  
**Technical Story**: ARCH-2025-007

### Context and Problem Statement

Keyfactor Command requires a relational database for certificate metadata, audit logs, and configuration. Since we chose Keyfactor SaaS (ADR-001), this decision primarily affects EJBCA and any self-hosted components.

### Decision Drivers

* **SaaS deployment**: Keyfactor Command DB is managed by Keyfactor
* **EJBCA requirement**: Need DB for EJBCA if deployed
* **Existing expertise**: SQL Server DBA team in-house
* **Cost**: Licensing (SQL Server) vs open-source (PostgreSQL)
* **Cloud-native**: Azure-managed database services
* **Performance**: Transaction volume and query performance

### Considered Options

1. **Azure SQL Database** (PaaS, SQL Server)
2. **Azure Database for PostgreSQL** (PaaS, open-source)
3. **SQL Server on VMs** (IaaS)
4. **PostgreSQL on VMs** (IaaS)

### Decision Outcome

**Chosen option**: "Azure Database for PostgreSQL (PaaS)", for EJBCA, because:

1. **EJBCA compatibility**: Native PostgreSQL support
2. **No SQL Server licensing**: Significant cost savings
3. **PaaS benefits**: Managed service, automatic backups, HA
4. **Cloud-native**: Azure-managed, built-in security
5. **Cost-effective**: ~$200/month vs $5K+/month for Azure SQL
6. **Modern database**: PostgreSQL is preferred for modern apps

**Note**: Keyfactor Command database is managed by Keyfactor (SaaS deployment).

### Positive Consequences

* ✅ No SQL Server licensing costs for EJBCA
* ✅ Azure-managed service (automatic backups, HA, patching)
* ✅ Built-in security features
* ✅ Flexible pricing tiers
* ✅ Native EJBCA support

### Negative Consequences

* ⚠️ Team needs PostgreSQL expertise (currently SQL Server focused)
* ⚠️ Different tooling than SQL Server

### Mitigation Strategies

* **Training**: PostgreSQL training for DBA team
* **Tooling**: Use Azure Data Studio (supports PostgreSQL)
* **Support**: PostgreSQL has excellent documentation and community

## Pros and Cons of the Options

### Option 1: Azure SQL Database

* **Pros**
  * Existing SQL Server expertise
  * Familiar tooling
  * Azure PaaS (managed service)
* **Cons**
  * Expensive (~$5K/month for production)
  * Licensing costs
  * EJBCA: Less native support

### Option 2: Azure Database for PostgreSQL ⭐ CHOSEN

* **Pros**
  * Native EJBCA support
  * Open-source (no licensing)
  * Cost-effective (~$200/month)
  * Azure PaaS (managed service)
  * Modern database
* **Cons**
  * Need PostgreSQL expertise
  * Different tooling

### Option 3: SQL Server on VMs (IaaS)

* **Pros**
  * Full control
  * Existing expertise
* **Cons**
  * Operational overhead
  * Patching and maintenance
  * Expensive licensing
  * HA/DR complexity

### Option 4: PostgreSQL on VMs (IaaS)

* **Pros**
  * Full control
  * No licensing costs
* **Cons**
  * Operational overhead
  * Manual HA/DR setup
  * Patching and maintenance

### Links

* [KEYFACTOR-INTEGRATIONS-GUIDE.md](./KEYFACTOR-INTEGRATIONS-GUIDE.md) § EJBCA
* [22-Cost-Analysis.md](./22-Cost-Analysis.md) - Database cost comparison

---

## ADR-008: Supported Enrollment Protocols

**Status**: Accepted  
**Date**: 2025-10-21  
**Deciders**: PKI Lead, Security Architect, DevOps Lead, Windows Lead  
**Technical Story**: ARCH-2025-008

### Context and Problem Statement

We need to decide which certificate enrollment protocols to support for different workload types. The goal is to provide appropriate enrollment mechanisms for Windows, Linux, cloud, Kubernetes, IoT, and network devices while maintaining security and operational efficiency.

### Decision Drivers

* **Workload diversity**: Windows, Linux, containers, IoT, network devices
* **Security**: Automated enrollment without shared secrets
* **Standards compliance**: Industry-standard protocols
* **Developer experience**: Easy enrollment for developers
* **Operational overhead**: Minimize manual processes
* **Backward compatibility**: Support legacy systems

### Considered Options

1. **Full protocol suite** (ACME, EST, SCEP, GPO, API)
2. **ACME-only** (modern standard)
3. **API-only** (centralized control)
4. **Minimal set** (GPO for Windows, API for everything else)

### Decision Outcome

**Chosen option**: "Full protocol suite (ACME, EST, SCEP, GPO, API)", because:

1. **ACME**: Cloud-native workloads, Linux servers, Kubernetes
2. **EST**: Modern secure enrollment, future-focused
3. **SCEP**: Network devices (Cisco, Palo Alto, F5)
4. **GPO Auto-Enrollment**: Windows domain-joined systems
5. **API**: Custom integrations, orchestration
6. **Coverage**: Appropriate protocol for every workload type

### Positive Consequences

* ✅ Native protocol support for each platform
* ✅ ACME for Let's Encrypt compatibility
* ✅ SCEP for network device enrollment
* ✅ GPO for seamless Windows deployment
* ✅ API for custom integrations
* ✅ Standards-compliant

### Negative Consequences

* ⚠️ More protocols to configure and maintain
* ⚠️ Security considerations per protocol
* ⚠️ Documentation and training for each

### Protocol-to-Workload Mapping

| Workload Type | Protocol | Rationale |
|--------------|----------|-----------|
| **Kubernetes** | ACME (cert-manager) | K8s-native, automatic renewal |
| **Linux servers** | ACME (certbot) | Standard protocol, easy automation |
| **Windows (domain)** | GPO Auto-Enrollment | Native AD CS integration |
| **Windows (non-domain)** | ACME or API | Cloud workloads without AD |
| **Network devices** | SCEP | Cisco, Palo Alto, F5 support SCEP |
| **IoT devices** | EST | Secure bootstrap, modern standard |
| **Cloud apps** | API | Direct Keyfactor API integration |
| **Manual requests** | Web Portal | Self-service for special cases |

## Pros and Cons of the Options

### Option 1: Full Protocol Suite ⭐ CHOSEN

* **Pros**
  * Support for all workload types
  * Native protocol for each platform
  * Standards-compliant
  * Maximum flexibility
* **Cons**
  * More protocols to manage
  * Training required
  * Security considerations per protocol

### Option 2: ACME-Only

* **Pros**
  * Single protocol to manage
  * Modern and secure
  * Let's Encrypt compatible
* **Cons**
  * No Windows auto-enrollment
  * Limited network device support
  * Not suitable for all use cases

### Option 3: API-Only

* **Pros**
  * Centralized control
  * Consistent interface
* **Cons**
  * Not standards-compliant
  * Custom integration for every platform
  * Poor developer experience

### Option 4: Minimal Set

* **Pros**
  * Simpler to manage
  * Reduced attack surface
* **Cons**
  * Limited platform support
  * Manual processes for unsupported platforms

### Links

* [07-Enrollment-Rails-Guide.md](./07-Enrollment-Rails-Guide.md) - Complete enrollment protocol guide
* [14-Integration-Specifications.md](./14-Integration-Specifications.md)

---

## ADR-009: Network Architecture

**Status**: Accepted  
**Date**: 2025-10-22  
**Deciders**: Network Architect, Security Architect, Infrastructure Lead  
**Technical Story**: ARCH-2025-009

### Context and Problem Statement

We need to design the network architecture for Keyfactor integration, including orchestrator deployment, CA connectivity, secrets platform access, and certificate distribution. The architecture must balance security (network segmentation), accessibility (workloads need certificates), and operational efficiency.

### Decision Drivers

* **Security**: Network segmentation, least privilege access
* **Availability**: No single point of failure
* **Scalability**: Support for growth
* **Cloud and on-prem**: Hybrid environment
* **Latency**: Minimize certificate distribution delays
* **Firewall rules**: Minimize complexity

### Considered Options

1. **Hub-and-spoke** (centralized orchestrators)
2. **Distributed** (orchestrators in each zone)
3. **Hybrid** (central + zone-specific)
4. **Flat network** (no segmentation - not secure)

### Decision Outcome

**Chosen option**: "Hybrid (central + zone-specific orchestrators)", because:

1. **Central orchestrators**: For Azure Key Vault, HashiCorp Vault, cloud platforms
2. **Zone-specific orchestrators**: For on-prem network zones (DMZ, internal)
3. **Security**: Minimal firewall rules, segmented network
4. **Performance**: Local orchestrators = low latency
5. **Scalability**: Add orchestrators as needed per zone

### Network Architecture Diagram

```
                    ┌─────────────────────┐
                    │ Keyfactor Command   │
                    │ (SaaS)              │
                    └──────────┬──────────┘
                               │ HTTPS (outbound)
          ┌────────────────────┼────────────────────┐
          │                    │                    │
    ┌─────▼──────┐      ┌─────▼──────┐      ┌─────▼──────┐
    │ Azure Zone │      │  DMZ Zone  │      │ Internal   │
    │Orchestrator│      │Orchestrator│      │ Zone Orch  │
    └─────┬──────┘      └─────┬──────┘      └─────┬──────┘
          │                    │                    │
    ┌─────▼──────┐      ┌─────▼──────┐      ┌─────▼──────┐
    │Azure Key   │      │   Reverse  │      │  Windows   │
    │Vault       │      │   Proxies  │      │  Servers   │
    │            │      │   F5 LBs   │      │  Linux VMs │
    └────────────┘      └────────────┘      └────────────┘
```

### Positive Consequences

* ✅ Network segmentation maintained
* ✅ Minimal firewall rules (orchestrator → Keyfactor = HTTPS outbound)
* ✅ Low latency within each zone
* ✅ Scalable (add orchestrators per zone)
* ✅ No inbound firewall rules required

### Negative Consequences

* ⚠️ Multiple orchestrators to deploy and manage
* ⚠️ Need orchestrator high availability per zone

### Firewall Rules Required

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| Orchestrators | Keyfactor SaaS | 443/HTTPS | API communication |
| Orchestrators | Azure Key Vault | 443/HTTPS | Certificate deployment |
| Orchestrators | F5 LBs | 443/HTTPS | iControl API |
| Orchestrators | Windows Servers | 5985/WinRM | Certificate deployment |
| Orchestrators | Linux Servers | 22/SSH | Certificate deployment |

## Pros and Cons of the Options

### Option 1: Hub-and-Spoke (Centralized)

* **Pros**
  * Fewer orchestrators to manage
  * Centralized control
* **Cons**
  * Requires inbound firewall rules to all zones
  * Single point of failure
  * Latency for remote zones
  * Complex firewall configuration

### Option 2: Distributed (Per-Zone)

* **Pros**
  * No cross-zone traffic
  * Low latency within zone
  * Simple firewall rules
* **Cons**
  * Many orchestrators to manage
  * Potential for configuration drift

### Option 3: Hybrid (Central + Zone-Specific) ⭐ CHOSEN

* **Pros**
  * Balance of centralization and distribution
  * Minimal firewall complexity
  * Low latency
  * Scalable
* **Cons**
  * More orchestrators than hub-spoke
  * Need zone-specific configuration

### Option 4: Flat Network

* **Pros**
  * No firewall rules needed
* **Cons**
  * ❌ Insecure - not acceptable
  * ❌ Does not meet security requirements

### Links

* [04-Architecture-Diagrams.md](./04-Architecture-Diagrams.md) § Network Architecture
* [11-Security-Controls.md](./11-Security-Controls.md) § Network Segmentation

---

## ADR-010: Monitoring and Observability Platform

**Status**: Accepted  
**Date**: 2025-10-23  
**Deciders**: Operations Lead, DevOps Lead, Cloud Architect  
**Technical Story**: ARCH-2025-010

### Context and Problem Statement

We need a monitoring and observability platform for the PKI infrastructure to track certificate expiry, renewal success rates, orchestrator health, CA availability, and security events. The solution must integrate with existing tools and provide actionable alerts.

### Decision Drivers

* **Existing platform**: Azure Monitor already deployed
* **Integration**: SIEM, ITSM, notification platforms
* **Visibility**: Dashboards for operations and leadership
* **Alerting**: Proactive alerts before issues become outages
* **Cost**: Leverage existing investments
* **Compliance**: 7-year log retention for audit

### Considered Options

1. **Azure Monitor + Log Analytics** (cloud-native)
2. **Grafana + Prometheus** (open-source)
3. **Splunk** (enterprise SIEM)
4. **Hybrid: Azure Monitor + Grafana**

### Decision Outcome

**Chosen option**: "Hybrid: Azure Monitor + Grafana", because:

1. **Azure Monitor**: Primary platform for Azure workloads, logs, metrics
2. **Grafana**: Unified dashboards across multiple data sources
3. **Azure Log Analytics**: 7-year retention for compliance
4. **Azure Sentinel**: Security event correlation (SIEM)
5. **Flexibility**: Can visualize data from Keyfactor, Azure, on-prem
6. **Cost-effective**: Leverage existing Azure investment

### Positive Consequences

* ✅ Unified dashboards (Grafana) across all data sources
* ✅ Azure-native monitoring for cloud workloads
* ✅ 7-year log retention (compliance)
* ✅ Azure Sentinel for security event correlation
* ✅ Existing team expertise
* ✅ Integrate with ServiceNow, Slack, Teams

### Negative Consequences

* ⚠️ Two platforms to maintain (Azure Monitor + Grafana)
* ⚠️ Need Grafana hosting (Azure Container Instances)
* ⚠️ Data duplication (logs in Azure Monitor + Grafana queries)

### Monitoring Strategy

| Component | Monitoring Platform | Metrics/Logs |
|-----------|-------------------|--------------|
| **Keyfactor SaaS** | Azure Monitor | API metrics, audit logs via webhook |
| **Orchestrators** | Azure Monitor | Health, job success/failure |
| **Azure Key Vault** | Azure Monitor | Access logs, certificate operations |
| **EJBCA** | Prometheus + Grafana | CA metrics, enrollment requests |
| **Certificates** | Grafana Dashboard | Expiry tracking, renewal status |
| **Security Events** | Azure Sentinel | Failed auth, unauthorized access |

## Pros and Cons of the Options

### Option 1: Azure Monitor + Log Analytics

* **Pros**
  * Azure-native (managed service)
  * Already deployed
  * 7-year retention
  * Azure Sentinel integration
  * Team expertise
* **Cons**
  * Limited on-prem monitoring
  * Dashboard customization limits
  * Azure-centric

### Option 2: Grafana + Prometheus

* **Pros**
  * Open-source
  * Beautiful dashboards
  * Multi-source data visualization
  * Strong community
* **Cons**
  * Need to host Grafana/Prometheus
  * Operational overhead
  * Log retention solution needed
  * Not Azure-native

### Option 3: Splunk

* **Pros**
  * Enterprise SIEM
  * Powerful query language
  * Strong compliance features
* **Cons**
  * Expensive (~$100K+/year)
  * Overkill for our needs
  * Steep learning curve

### Option 4: Hybrid (Azure Monitor + Grafana) ⭐ CHOSEN

* **Pros**
  * Best of both worlds
  * Azure Monitor: Data platform, retention
  * Grafana: Visualization, dashboards
  * Flexible and cost-effective
* **Cons**
  * Two platforms to maintain
  * Need to host Grafana

### Links

* [09-Monitoring-KPIs.md](./09-Monitoring-KPIs.md) - Complete monitoring strategy
* [08-Operations-Manual.md](./08-Operations-Manual.md) § Monitoring
* [04-Architecture-Diagrams.md](./04-Architecture-Diagrams.md) § Monitoring Architecture

---

## ADR Summary Table

| ADR | Decision | Status | Date | Impact |
|-----|----------|--------|------|--------|
| ADR-001 | Keyfactor SaaS Deployment | ✅ Accepted | 2025-10-15 | High |
| ADR-002 | Hybrid CA (AD CS + EJBCA) | ✅ Accepted | 2025-10-15 | High |
| ADR-003 | Azure Managed HSM | ✅ Accepted | 2025-10-16 | High |
| ADR-004 | Azure Key Vault + HashiCorp Vault | ✅ Accepted | 2025-10-17 | Medium |
| ADR-005 | cert-manager + Keyfactor Issuer | ✅ Accepted | 2025-10-18 | Medium |
| ADR-006 | Event-Driven Automation (Webhooks) | ✅ Accepted | 2025-10-19 | High |
| ADR-007 | Azure PostgreSQL for EJBCA | ✅ Accepted | 2025-10-20 | Low |
| ADR-008 | Full Protocol Suite (ACME/EST/SCEP/GPO/API) | ✅ Accepted | 2025-10-21 | Medium |
| ADR-009 | Hybrid Network Architecture | ✅ Accepted | 2025-10-22 | Medium |
| ADR-010 | Azure Monitor + Grafana | ✅ Accepted | 2025-10-23 | Medium |

---

## Change Management Process

### Proposing New ADRs

1. Create draft ADR using template
2. Socialize with stakeholders
3. Present to architecture review board
4. Update status to "Accepted" or "Rejected"
5. Communicate decision to team

### Updating Existing ADRs

1. Create new ADR that supersedes the old one
2. Update old ADR status to "Superseded by ADR-XXX"
3. Document reason for change

### ADR Review Schedule

- **Quarterly**: Review all accepted ADRs for currency
- **Annual**: Full architecture review
- **As-needed**: When technology landscape changes significantly

---

## Document Maintenance

**Review Schedule**: Quarterly  
**Owner**: Enterprise Architect + PKI Lead  
**Last Reviewed**: October 23, 2025  
**Next Review**: January 23, 2026

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-23 | Adrian Johnson | Initial ADR document with 10 key decisions |

---

**For architecture questions, contact**: adrian207@gmail.com

**End of Architecture Decision Records**

