# Keyfactor Glossary & References
## PKI Terminology and Reference Materials

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use  
**Target Audience**: All PKI stakeholders

---

## Document Purpose

This document provides a comprehensive glossary of PKI and Keyfactor-specific terminology, acronyms, standards references, and vendor documentation links. It serves as a quick reference guide for all stakeholders.

---

## Table of Contents

1. [PKI Terminology](#1-pki-terminology)
2. [Keyfactor-Specific Terms](#2-keyfactor-specific-terms)
3. [Acronyms and Abbreviations](#3-acronyms-and-abbreviations)
4. [Standards and RFCs](#4-standards-and-rfcs)
5. [Vendor Documentation](#5-vendor-documentation)
6. [Tools and Technologies](#6-tools-and-technologies)
7. [Common Certificate Fields](#7-common-certificate-fields)
8. [Revocation Reasons](#8-revocation-reasons)

---

## 1. PKI Terminology

### A

**ACME (Automated Certificate Management Environment)**  
A protocol for automating interactions between certificate authorities and web servers, allowing for automated certificate issuance and renewal. Defined in RFC 8555.

**Active Directory Certificate Services (AD CS)**  
Microsoft's Public Key Infrastructure implementation that provides customizable services for issuing and managing digital certificates.

**Asymmetric Cryptography**  
Encryption method using a pair of keys (public and private) where data encrypted with one key can only be decrypted with the other.

**Authority Information Access (AIA)**  
Certificate extension that provides the location of the issuing CA certificate and OCSP responder URLs.

**Authentication**  
The process of verifying the identity of a user, device, or system.

**Authorization**  
The process of determining whether an authenticated entity has permission to access a resource or perform an action.

---

### C

**CA (Certificate Authority)**  
A trusted entity that issues digital certificates. Examples: DigiCert, Let's Encrypt, internal enterprise CAs.

**Certificate**  
A digital document that binds a public key to an entity (person, organization, device) and is signed by a trusted Certificate Authority.

**Certificate Chain (Certificate Path)**  
The sequence of certificates from the end-entity certificate to the root CA certificate, including all intermediate certificates.

**Certificate Policy (CP)**  
A named set of rules that indicates the applicability of a certificate to a particular community and/or class of application.

**Certificate Practice Statement (CPS)**  
A statement of the practices that a CA employs in issuing, managing, revoking, and renewing certificates.

**Certificate Revocation List (CRL)**  
A list of certificates that have been revoked before their scheduled expiration date, published by the CA.

**Certificate Signing Request (CSR)**  
A message sent from an applicant to a CA to apply for a digital certificate. Contains the public key and identifying information.

**Certificate Store**  
A repository where certificates and their private keys are stored (e.g., Windows Certificate Store, Azure Key Vault, Java Keystore).

**Certificate Template**  
A predefined set of rules and settings for issuing certificates with specific properties (validity period, key usage, extensions).

**Chain of Trust**  
The verification path from an end-entity certificate through intermediate CAs to a trusted root CA.

**Cipher Suite**  
A combination of authentication, encryption, and message authentication code (MAC) algorithms used to secure network connections.

**Common Name (CN)**  
The fully qualified domain name (FQDN) or entity name in a certificate's Subject Distinguished Name.

**CRL Distribution Point (CDP)**  
Certificate extension indicating where the CRL for that certificate can be obtained.

**Cross-Certification**  
The process where two CAs certify each other's public keys, establishing a trust relationship.

---

### D

**Digital Signature**  
A cryptographic technique used to validate the authenticity and integrity of a message, software, or digital document.

**Distinguished Name (DN)**  
A unique identifier for an entity in an X.509 certificate (e.g., CN=webapp.contoso.com, O=Contoso Inc, C=US).

**DCOM (Distributed Component Object Model)**  
Microsoft's proprietary technology for communication between software components on networked computers (used by AD CS).

---

### E

**ECC (Elliptic Curve Cryptography)**  
A public-key cryptography approach based on elliptic curves, providing equivalent security to RSA with smaller key sizes.

**EJBCA**  
Enterprise Java Beans Certificate Authority, an open-source PKI software.

**Encryption**  
The process of encoding data so that only authorized parties can access it.

**End-Entity Certificate**  
A certificate issued to an end-user, device, or server (as opposed to a CA certificate).

**Enrollment**  
The process of requesting and receiving a digital certificate from a CA.

**EST (Enrollment over Secure Transport)**  
A certificate enrollment protocol defined in RFC 7030, using HTTPS for secure communication.

**Extended Key Usage (EKU)**  
Certificate extension that indicates the purposes for which the certificate public key may be used (e.g., Server Authentication, Client Authentication, Code Signing).

**Extended Validation (EV) Certificate**  
A certificate that requires extensive vetting of the requesting organization, displays organization name in browser address bar.

---

### H

**Hash Function**  
A mathematical function that converts input data into a fixed-size string of characters (e.g., SHA-256, SHA-384).

**HSM (Hardware Security Module)**  
A physical computing device that safeguards and manages cryptographic keys and provides secure cryptographic operations.

**HTTPS (HTTP Secure)**  
HTTP protocol over TLS/SSL, providing encrypted communication.

---

### I

**Intermediate CA**  
A CA that is subordinate to a root CA and issues end-entity certificates or additional intermediate CA certificates.

**Issuer**  
The Certificate Authority that signed and issued a certificate.

---

### K

**Key**  
In cryptography, a parameter used in encryption and decryption algorithms.

**Key Algorithm**  
The cryptographic algorithm used to generate keys (e.g., RSA, ECC, DSA).

**Key Ceremony**  
A formal procedure for generating and securing CA private keys, typically involving multiple trusted individuals.

**Key Escrow**  
A system where cryptographic keys are stored with a third party for recovery purposes.

**Key Exchange**  
The process of securely sharing cryptographic keys between parties.

**Key Length (Key Size)**  
The size of a cryptographic key in bits (e.g., RSA 2048-bit, ECC 256-bit).

**Key Pair**  
A public key and its corresponding private key in asymmetric cryptography.

**Key Usage**  
Certificate extension that defines the purpose of the key contained in the certificate (e.g., Digital Signature, Key Encipherment, Certificate Signing).

**Keystore**  
A repository of security certificates and keys (e.g., Java KeyStore .jks file).

---

### M

**Mutual TLS (mTLS)**  
A form of mutual authentication where both client and server authenticate each other using certificates.

---

### O

**OCSP (Online Certificate Status Protocol)**  
A protocol for obtaining the revocation status of a digital certificate in real-time. Defined in RFC 6960.

**OCSP Stapling**  
A method where the web server queries the OCSP responder and includes the response in the TLS handshake.

**OID (Object Identifier)**  
A unique identifier used to name an object in a hierarchical namespace (e.g., 1.3.6.1.5.5.7.3.1 for Server Authentication).

**Orchestrator**  
In Keyfactor context, an agent that manages certificates in remote certificate stores (e.g., Azure Key Vault, F5, IIS).

**Organization (O)**  
The organization name field in a certificate's Subject DN.

**Organizational Unit (OU)**  
A subdivision of an organization in a certificate's Subject DN.

---

### P

**PEM (Privacy Enhanced Mail)**  
A base64 encoded format for certificates and keys, often used in Linux/Unix systems.  
Format: `-----BEGIN CERTIFICATE-----` ... `-----END CERTIFICATE-----`

**PKCS (Public-Key Cryptography Standards)**  
A group of standards published by RSA Security Inc.  
- **PKCS#1**: RSA Cryptography Standard
- **PKCS#7**: Cryptographic Message Syntax
- **PKCS#8**: Private-Key Information Syntax
- **PKCS#10**: Certification Request Syntax (CSR format)
- **PKCS#12**: Personal Information Exchange Syntax (.pfx, .p12 files)

**PKI (Public Key Infrastructure)**  
A framework of policies, procedures, hardware, software, and people that create, manage, distribute, use, store, and revoke digital certificates.

**Private Key**  
The secret key in asymmetric cryptography, known only to the owner, used for decryption and signing.

**Public Key**  
The openly shared key in asymmetric cryptography, used for encryption and signature verification.

---

### R

**Registration Authority (RA)**  
An entity that validates certificate requests and forwards them to a CA for issuance.

**Renewal**  
The process of replacing an expiring certificate with a new one, typically with a new expiration date.

**Revocation**  
The act of invalidating a certificate before its scheduled expiration date.

**Root CA**  
The top-most Certificate Authority in a PKI hierarchy, whose certificate is self-signed and widely trusted.

**RSA (Rivest-Shamir-Adleman)**  
A widely used asymmetric encryption algorithm, named after its inventors.

---

### S

**SAN (Subject Alternative Name)**  
Certificate extension that allows additional identities (DNS names, IP addresses, email addresses) to be bound to a certificate.

**SCEP (Simple Certificate Enrollment Protocol)**  
A protocol for certificate enrollment, commonly used by network devices. Defined in RFC 8894.

**Self-Signed Certificate**  
A certificate that is signed by its own private key rather than by a CA.

**SHA (Secure Hash Algorithm)**  
A family of cryptographic hash functions (SHA-1, SHA-256, SHA-384, SHA-512). SHA-256 and above are currently recommended.

**SSL (Secure Sockets Layer)**  
Deprecated predecessor to TLS, though the term is still commonly used to refer to TLS.

**Subject**  
The entity (person, organization, device) identified in a certificate.

**Subject Distinguished Name**  
The DN field in a certificate that identifies the certificate subject (e.g., CN=webapp.contoso.com, O=Contoso Inc, C=US).

**Subject Public Key Info**  
The field in a certificate containing the public key and algorithm information.

**Subordinate CA**  
Another term for an Intermediate CA.

---

### T

**TLS (Transport Layer Security)**  
A cryptographic protocol for secure communication over a network. Current versions: TLS 1.2, TLS 1.3.

**Trust Anchor**  
A root CA certificate that is inherently trusted (typically pre-installed in operating systems and browsers).

**Trust Store**  
A repository of trusted CA certificates used to validate certificate chains.

---

### V

**Validity Period**  
The time period during which a certificate is valid, defined by "Not Before" and "Not After" dates.

---

### W

**Wildcard Certificate**  
A certificate that secures a domain and all its first-level subdomains (e.g., *.contoso.com covers www.contoso.com, api.contoso.com, but not sub.api.contoso.com).

---

### X

**X.509**  
The ITU-T standard for the format of public key certificates. Version 3 (X.509v3) is the current standard.

---

## 2. Keyfactor-Specific Terms

**Keyfactor Command**  
The central management platform for certificate lifecycle management.

**Keyfactor Universal Orchestrator**  
An agent-based system for automating certificate deployment and discovery on various platforms.

**Certificate Collection**  
A logical grouping of certificates in Keyfactor for management and reporting purposes.

**Certificate Store Type**  
A definition in Keyfactor that describes how to interact with a specific type of certificate store (e.g., Azure Key Vault, IIS, F5).

**Container**  
In Keyfactor, a logical boundary for grouping certificate stores, often corresponding to organizational units or environments.

**Gateway**  
A Keyfactor component that translates requests between Keyfactor Command and a Certificate Authority.

**Metadata**  
Custom key-value pairs associated with certificates in Keyfactor for tracking ownership, application, environment, etc.

**PAM Integration**  
Privileged Access Management integration for secure retrieval of credentials used by orchestrators.

**SSL Certificate**  
While technically referring to SSL protocol certificates, in Keyfactor this typically means any TLS/SSL server authentication certificate.

**Workflow**  
Automated processes in Keyfactor for certificate request approval, renewal, notification, etc.

---

## 3. Acronyms and Abbreviations

| Acronym | Full Name | Category |
|---------|-----------|----------|
| **ACME** | Automated Certificate Management Environment | Protocol |
| **AD CS** | Active Directory Certificate Services | Software |
| **AES** | Advanced Encryption Standard | Encryption |
| **AIA** | Authority Information Access | Extension |
| **API** | Application Programming Interface | Technology |
| **CA** | Certificate Authority | Entity |
| **CDP** | CRL Distribution Point | Extension |
| **CLM** | Certificate Lifecycle Management | Process |
| **CMDB** | Configuration Management Database | System |
| **CN** | Common Name | Field |
| **CP** | Certificate Policy | Document |
| **CPS** | Certificate Practice Statement | Document |
| **CRL** | Certificate Revocation List | Technology |
| **CSR** | Certificate Signing Request | Request |
| **DCOM** | Distributed Component Object Model | Protocol |
| **DER** | Distinguished Encoding Rules | Format |
| **DN** | Distinguished Name | Identifier |
| **DNS** | Domain Name System | Protocol |
| **DR** | Disaster Recovery | Process |
| **ECC** | Elliptic Curve Cryptography | Algorithm |
| **ECDSA** | Elliptic Curve Digital Signature Algorithm | Algorithm |
| **EKU** | Extended Key Usage | Extension |
| **EST** | Enrollment over Secure Transport | Protocol |
| **EV** | Extended Validation | Certificate Type |
| **FIPS** | Federal Information Processing Standards | Standard |
| **FQDN** | Fully Qualified Domain Name | Identifier |
| **HSM** | Hardware Security Module | Hardware |
| **HTTP** | Hypertext Transfer Protocol | Protocol |
| **HTTPS** | HTTP Secure | Protocol |
| **IIS** | Internet Information Services | Software |
| **IP** | Internet Protocol | Protocol |
| **ITSM** | IT Service Management | Process |
| **JSON** | JavaScript Object Notation | Format |
| **KMS** | Key Management Service | Service |
| **KPI** | Key Performance Indicator | Metric |
| **LDAP** | Lightweight Directory Access Protocol | Protocol |
| **MAC** | Message Authentication Code | Technology |
| **mTLS** | Mutual TLS | Protocol |
| **NDES** | Network Device Enrollment Service | Software |
| **NIST** | National Institute of Standards and Technology | Organization |
| **OCSP** | Online Certificate Status Protocol | Protocol |
| **OID** | Object Identifier | Identifier |
| **OU** | Organizational Unit | Field |
| **OV** | Organization Validation | Certificate Type |
| **PAM** | Privileged Access Management | System |
| **PCI-DSS** | Payment Card Industry Data Security Standard | Standard |
| **PEM** | Privacy Enhanced Mail | Format |
| **PFX** | Personal Information Exchange (PKCS#12) | Format |
| **PKI** | Public Key Infrastructure | System |
| **PKCS** | Public-Key Cryptography Standards | Standard |
| **RA** | Registration Authority | Entity |
| **RBAC** | Role-Based Access Control | Security |
| **REST** | Representational State Transfer | API Style |
| **RFC** | Request for Comments | Document Type |
| **RPC** | Remote Procedure Call | Protocol |
| **RSA** | Rivest-Shamir-Adleman | Algorithm |
| **RTO** | Recovery Time Objective | Metric |
| **RPO** | Recovery Point Objective | Metric |
| **SAN** | Subject Alternative Name | Extension |
| **SCEP** | Simple Certificate Enrollment Protocol | Protocol |
| **SHA** | Secure Hash Algorithm | Algorithm |
| **SLA** | Service Level Agreement | Agreement |
| **SLO** | Service Level Objective | Metric |
| **SMTP** | Simple Mail Transfer Protocol | Protocol |
| **SOAP** | Simple Object Access Protocol | Protocol |
| **SOC** | Service Organization Control | Standard |
| **SQL** | Structured Query Language | Language |
| **SSH** | Secure Shell | Protocol |
| **SSL** | Secure Sockets Layer | Protocol (deprecated) |
| **TLS** | Transport Layer Security | Protocol |
| **UAT** | User Acceptance Testing | Process |
| **URI** | Uniform Resource Identifier | Identifier |
| **URL** | Uniform Resource Locator | Identifier |
| **VM** | Virtual Machine | Technology |
| **VPN** | Virtual Private Network | Technology |
| **WAF** | Web Application Firewall | Security |
| **XML** | Extensible Markup Language | Format |

---

## 4. Standards and RFCs

### Core PKI Standards

| RFC/Standard | Title | Description |
|--------------|-------|-------------|
| **RFC 5280** | Internet X.509 Public Key Infrastructure Certificate and CRL Profile | The fundamental standard for X.509 certificates |
| **RFC 6960** | X.509 Internet Public Key Infrastructure Online Certificate Status Protocol (OCSP) | OCSP protocol specification |
| **RFC 8555** | Automatic Certificate Management Environment (ACME) | ACME protocol for automated cert management |
| **RFC 7030** | Enrollment over Secure Transport (EST) | EST enrollment protocol |
| **RFC 8894** | Simple Certificate Enrollment Protocol (SCEP) | SCEP protocol specification |
| **RFC 5246** | The Transport Layer Security (TLS) Protocol Version 1.2 | TLS 1.2 specification |
| **RFC 8446** | The Transport Layer Security (TLS) Protocol Version 1.3 | TLS 1.3 specification |
| **RFC 3647** | Internet X.509 Public Key Infrastructure Certificate Policy and Certification Practices Framework | Framework for CP and CPS |

### PKCS Standards

| Standard | Title | Usage |
|----------|-------|-------|
| **PKCS#1** | RSA Cryptography Specifications | RSA algorithm details |
| **PKCS#7** | Cryptographic Message Syntax | Certificate chains, signed data |
| **PKCS#8** | Private-Key Information Syntax | Private key format |
| **PKCS#10** | Certification Request Syntax | CSR format |
| **PKCS#12** | Personal Information Exchange Syntax | PFX/P12 files (cert + private key) |

### Industry Standards

| Standard | Organization | Description |
|----------|--------------|-------------|
| **X.509 v3** | ITU-T | Digital certificate format |
| **FIPS 140-2** | NIST | Cryptographic module validation |
| **FIPS 140-3** | NIST | Updated crypto module standard (2019) |
| **CA/Browser Forum Baseline Requirements** | CA/Browser Forum | Requirements for publicly-trusted certificates |
| **PCI-DSS** | PCI Security Standards Council | Payment card industry security |
| **SOC 2 Type II** | AICPA | Service organization controls |
| **ISO/IEC 27001** | ISO | Information security management |

### Useful RFCs

| RFC | Title | Relevance |
|-----|-------|-----------|
| **RFC 2818** | HTTP Over TLS | HTTPS specification |
| **RFC 4514** | Lightweight Directory Access Protocol (LDAP): String Representation of Distinguished Names | DN format |
| **RFC 5915** | Elliptic Curve Private Key Structure | ECC private keys |
| **RFC 6125** | Representation and Verification of Domain-Based Application Service Identity | Certificate validation rules |
| **RFC 6962** | Certificate Transparency | CT log requirements |
| **RFC 7468** | Textual Encodings of PKIX, PKCS, and CMS Structures | PEM format specification |

---

## 5. Vendor Documentation

### Keyfactor

| Resource | URL | Description |
|----------|-----|-------------|
| **Keyfactor Documentation** | https://software.keyfactor.com/docs | Official product documentation |
| **Keyfactor GitHub** | https://github.com/Keyfactor | Open-source integrations and tools |
| **Keyfactor Support Portal** | https://support.keyfactor.com | Support tickets and knowledge base |
| **Keyfactor Community** | https://community.keyfactor.com | User community and forums |
| **Keyfactor Training** | https://training.keyfactor.com | Product training and certification |

### Microsoft (AD CS)

| Resource | URL | Description |
|----------|-----|-------------|
| **AD CS Documentation** | https://docs.microsoft.com/windows-server/networking/core-network-guide/cng/server-certs/install-the-certification-authority | Microsoft AD CS guides |
| **Certificate Templates** | https://docs.microsoft.com/windows-server/networking/core-network-guide/cng/server-certs/configure-server-certificate-templates | Template configuration |
| **PowerShell PKI Module** | https://docs.microsoft.com/powershell/module/pki/ | PowerShell PKI cmdlets |

### EJBCA

| Resource | URL | Description |
|----------|-----|-------------|
| **EJBCA Documentation** | https://doc.primekey.com/ejbca | Official EJBCA docs |
| **EJBCA GitHub** | https://github.com/Keyfactor/ejbca-ce | EJBCA Community Edition source |
| **EJBCA REST API** | https://doc.primekey.com/ejbca/ejbca-operations/ejbca-rest-interface | REST API documentation |

### Cloud Providers

| Provider | Resource | URL |
|----------|----------|-----|
| **Azure Key Vault** | Documentation | https://docs.microsoft.com/azure/key-vault/ |
| **Azure Key Vault** | REST API | https://docs.microsoft.com/rest/api/keyvault/ |
| **AWS ACM** | Documentation | https://docs.aws.amazon.com/acm/ |
| **AWS Secrets Manager** | Documentation | https://docs.aws.amazon.com/secretsmanager/ |
| **HashiCorp Vault** | Documentation | https://www.vaultproject.io/docs |
| **HashiCorp Vault** | PKI Secrets Engine | https://www.vaultproject.io/docs/secrets/pki |

### Enrollment Protocols

| Protocol | Documentation | URL |
|----------|---------------|-----|
| **ACME** | Let's Encrypt | https://letsencrypt.org/docs/ |
| **cert-manager** | Kubernetes | https://cert-manager.io/docs/ |
| **certbot** | ACME client | https://certbot.eff.org/docs/ |

---

## 6. Tools and Technologies

### Certificate Tools

| Tool | Purpose | Platform | URL |
|------|---------|----------|-----|
| **OpenSSL** | PKI toolkit | Cross-platform | https://www.openssl.org/ |
| **certutil** | Certificate utility | Windows | Built into Windows |
| **keytool** | Java keystore tool | Java | Included with JDK |
| **xca** | X Certificate and Key Management | Cross-platform | https://hohnstaedt.de/xca/ |
| **Keychain Access** | Certificate management | macOS | Built into macOS |

### Testing and Validation

| Tool | Purpose | URL |
|------|---------|-----|
| **SSL Labs** | TLS configuration testing | https://www.ssllabs.com/ssltest/ |
| **Certificate Decoder** | Certificate analysis | https://www.sslshopper.com/certificate-decoder.html |
| **CSR Decoder** | CSR analysis | https://www.sslshopper.com/csr-decoder.html |
| **What's My Chain Cert?** | Certificate chain validation | https://whatsmychaincert.com/ |

### Development Libraries

| Library | Language | Purpose | URL |
|---------|----------|---------|-----|
| **cryptography** | Python | Cryptographic operations | https://cryptography.io/ |
| **PyOpenSSL** | Python | OpenSSL wrapper | https://www.pyopenssl.org/ |
| **Bouncy Castle** | Java/.NET | Cryptography library | https://www.bouncycastle.org/ |
| **node-forge** | JavaScript | TLS and PKI toolkit | https://github.com/digitalbazaar/forge |
| **golang.org/x/crypto** | Go | Crypto library | https://pkg.go.dev/golang.org/x/crypto |

---

## 7. Common Certificate Fields

### Subject DN Fields

| Field | OID | Description | Example |
|-------|-----|-------------|---------|
| **CN** (Common Name) | 2.5.4.3 | Primary identifier (hostname for servers) | webapp01.contoso.com |
| **O** (Organization) | 2.5.4.10 | Organization name | Contoso Inc |
| **OU** (Organizational Unit) | 2.5.4.11 | Department or division | IT Department |
| **L** (Locality) | 2.5.4.7 | City or locality | Seattle |
| **ST** (State/Province) | 2.5.4.8 | State or province | Washington |
| **C** (Country) | 2.5.4.6 | Two-letter country code | US |
| **E** (Email) | 1.2.840.113549.1.9.1 | Email address | admin@contoso.com |

### Certificate Extensions

| Extension | OID | Purpose |
|-----------|-----|---------|
| **Subject Alternative Name** | 2.5.29.17 | Additional identities (DNS, IP, email) |
| **Key Usage** | 2.5.29.15 | Allowed key operations |
| **Extended Key Usage** | 2.5.29.37 | Certificate purposes |
| **Basic Constraints** | 2.5.29.19 | CA flag and path length |
| **Authority Key Identifier** | 2.5.29.35 | Issuer's public key identifier |
| **Subject Key Identifier** | 2.5.29.14 | Subject's public key identifier |
| **CRL Distribution Points** | 2.5.29.31 | CRL locations |
| **Authority Information Access** | 1.3.6.1.5.5.7.1.1 | OCSP and CA cert locations |
| **Certificate Policies** | 2.5.29.32 | Policy OIDs |

### Key Usage Values

| Value | Bit Position | Purpose |
|-------|--------------|---------|
| **Digital Signature** | 0 | Sign data (not certificates) |
| **Non Repudiation** | 1 | Content commitment |
| **Key Encipherment** | 2 | Encrypt symmetric keys |
| **Data Encipherment** | 3 | Encrypt data directly |
| **Key Agreement** | 4 | Key exchange (e.g., Diffie-Hellman) |
| **Key Cert Sign** | 5 | Sign certificates (CA only) |
| **CRL Sign** | 6 | Sign CRLs (CA only) |
| **Encipher Only** | 7 | Key agreement encryption only |
| **Decipher Only** | 8 | Key agreement decryption only |

### Extended Key Usage OIDs

| Purpose | OID | Description |
|---------|-----|-------------|
| **Server Authentication** | 1.3.6.1.5.5.7.3.1 | TLS/SSL server certificates |
| **Client Authentication** | 1.3.6.1.5.5.7.3.2 | TLS/SSL client certificates |
| **Code Signing** | 1.3.6.1.5.5.7.3.3 | Software code signing |
| **Email Protection** | 1.3.6.1.5.5.7.3.4 | S/MIME email encryption |
| **Time Stamping** | 1.3.6.1.5.5.7.3.8 | RFC 3161 time stamping |
| **OCSP Signing** | 1.3.6.1.5.5.7.3.9 | OCSP response signing |

---

## 8. Revocation Reasons

### RFC 5280 Revocation Reason Codes

| Code | Reason | Description | Usage |
|------|--------|-------------|-------|
| **0** | Unspecified | No specific reason provided | General revocation |
| **1** | Key Compromise | Private key has been compromised | **Emergency revocation** |
| **2** | CA Compromise | CA's private key compromised | **Critical - revoke all issued certs** |
| **3** | Affiliation Changed | Subject's affiliation changed | Employee left company |
| **4** | Superseded | Certificate replaced by a new one | Normal renewal/replacement |
| **5** | Cessation of Operation | Service/server decommissioned | Server retired |
| **6** | Certificate Hold | Temporary suspension (can be un-revoked) | Investigate suspected compromise |
| **8** | Remove from CRL | Certificate is no longer on hold | Un-revoke a held certificate |
| **9** | Privilege Withdrawn | Authorization removed | Access rights revoked |
| **10** | AA Compromise | Attribute Authority compromised | AA-specific |

**Note**: Code 7 is unused, Code 6 (Certificate Hold) is reversible using Code 8.

### Recommended Usage by Scenario

| Scenario | Reason Code | Priority | Actions |
|----------|-------------|----------|---------|
| Private key stolen/exposed | 1 - Key Compromise | P1 - Emergency | Immediate revocation, notify all relying parties |
| CA key compromised | 2 - CA Compromise | P0 - Critical | Revoke all certs, emergency response |
| Employee terminated | 3 - Affiliation Changed | P3 - Normal | Revoke within 24 hours |
| Certificate renewal | 4 - Superseded | P4 - Low | Revoke old cert after new cert deployed |
| Server decommissioned | 5 - Cessation of Operation | P3 - Normal | Revoke within 24 hours |
| Suspected compromise (investigating) | 6 - Certificate Hold | P2 - High | Temporary suspension, investigate |
| Access rights removed | 9 - Privilege Withdrawn | P3 - Normal | Revoke within 24 hours |

---

## Appendix A: Quick Reference Cards

### Certificate Validity Periods (Recommended)

| Certificate Type | Recommended Validity | Maximum Allowed (Public) |
|-----------------|---------------------|-------------------------|
| **Public TLS/SSL** | 90 days | 398 days (CA/B Forum) |
| **Internal TLS/SSL** | 1 year | 5 years |
| **Code Signing** | 1-3 years | 3 years |
| **Client Authentication** | 1-2 years | 3 years |
| **Email (S/MIME)** | 1-2 years | 3 years |
| **Intermediate CA** | 5-10 years | 10 years |
| **Root CA** | 20-25 years | No limit |

### Key Sizes (NIST Recommendations)

| Algorithm | Current (2025) | Recommended (2025+) | Deprecated |
|-----------|---------------|-------------------|-----------|
| **RSA** | 2048-bit minimum | 3072-bit or 4096-bit | 1024-bit |
| **ECC** | 256-bit (P-256) minimum | 384-bit (P-384) | 192-bit |
| **DSA** | 2048-bit | 3072-bit | 1024-bit (deprecated algorithm) |

### Hash Algorithms

| Algorithm | Status | Usage |
|-----------|--------|-------|
| **SHA-256** | ✅ Recommended | Current standard |
| **SHA-384** | ✅ Recommended | High security |
| **SHA-512** | ✅ Recommended | High security |
| **SHA-1** | ❌ Deprecated | DO NOT USE |
| **MD5** | ❌ Deprecated | DO NOT USE |

### TLS Versions

| Version | Status | Notes |
|---------|--------|-------|
| **TLS 1.3** | ✅ Recommended | Fastest, most secure |
| **TLS 1.2** | ✅ Acceptable | Widely supported, secure with proper config |
| **TLS 1.1** | ❌ Deprecated | Disable |
| **TLS 1.0** | ❌ Deprecated | Disable |
| **SSL 3.0** | ❌ Deprecated | Disable (POODLE attack) |
| **SSL 2.0** | ❌ Deprecated | Disable |

---

## Appendix B: Conversion Cheat Sheet

### Certificate Format Conversions

```bash
# PEM to DER
openssl x509 -in cert.pem -outform DER -out cert.der

# DER to PEM
openssl x509 -in cert.der -inform DER -out cert.pem -outform PEM

# PEM to PKCS#12 (PFX)
openssl pkcs12 -export -in cert.pem -inkey key.pem -out cert.pfx

# PKCS#12 to PEM
openssl pkcs12 -in cert.pfx -out cert.pem -nodes

# Extract certificate from PKCS#12
openssl pkcs12 -in cert.pfx -clcerts -nokeys -out cert.pem

# Extract private key from PKCS#12
openssl pkcs12 -in cert.pfx -nocerts -nodes -out key.pem

# View certificate details
openssl x509 -in cert.pem -text -noout

# Verify certificate chain
openssl verify -CAfile ca-chain.pem cert.pem
```

---

## Appendix C: Troubleshooting Quick Reference

### Common OpenSSL Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `unable to get local issuer certificate` | Missing intermediate cert | Add intermediate CA cert to chain |
| `certificate has expired` | Certificate past expiration | Renew certificate |
| `self signed certificate in certificate chain` | Self-signed intermediate | Add intermediate to trusted store |
| `wrong version number` | TLS version mismatch | Check TLS configuration |
| `sslv3 alert handshake failure` | Cipher suite mismatch | Review cipher suite compatibility |

---

## Document Maintenance

**Review Schedule**: Annually or when standards change  
**Owner**: PKI Architecture Team  
**Last Reviewed**: October 22, 2025  
**Next Review**: October 22, 2026

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial comprehensive glossary and references |

---

**For terminology questions or additions, contact**: adrian207@gmail.com

**End of Glossary & References Document**

