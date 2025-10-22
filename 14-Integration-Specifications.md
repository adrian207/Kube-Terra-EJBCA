# Keyfactor Integration Specifications
## Technical Integration Details and API Specifications

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use  
**Target Audience**: Integration engineers, developers, architects

---

## Document Purpose

This document provides comprehensive technical specifications for integrating Keyfactor with various platforms and services. It includes API specifications, configuration examples, data flow diagrams, authentication methods, and error handling for each integration.

---

## Table of Contents

1. [Integration Architecture Overview](#1-integration-architecture-overview)
2. [Azure Key Vault Integration](#2-azure-key-vault-integration)
3. [HashiCorp Vault Integration](#3-hashicorp-vault-integration)
4. [Kubernetes cert-manager Integration](#4-kubernetes-cert-manager-integration)
5. [Active Directory Certificate Services (AD CS)](#5-active-directory-certificate-services-ad-cs)
6. [EJBCA Integration](#6-ejbca-integration)
7. [Keyfactor API Reference](#7-keyfactor-api-reference)
8. [Error Handling and Retry Logic](#8-error-handling-and-retry-logic)
9. [Performance and Scaling](#9-performance-and-scaling)
10. [Security Considerations](#10-security-considerations)

---

## 1. Integration Architecture Overview

### 1.1 Integration Patterns

```
┌─────────────────────────────────────────────────────────────┐
│                    Integration Patterns                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Pattern 1: Certificate Authority Integration                │
│  ┌──────────┐  CSR   ┌──────────┐  CSR   ┌──────────┐     │
│  │Keyfactor │───────>│ Gateway  │───────>│   CA     │     │
│  │          │<───────│          │<───────│ (AD CS/  │     │
│  └──────────┘  Cert  └──────────┘  Cert  │  EJBCA)  │     │
│                                            └──────────┘     │
│                                                              │
│  Pattern 2: Secret Store Integration (Orchestrator)         │
│  ┌──────────┐        ┌─────────────┐      ┌──────────┐    │
│  │Keyfactor │<──────>│ Orchestrator│<────>│ Azure KV │    │
│  │          │  Jobs  │   Agent     │ API  │ HashiCorp│    │
│  └──────────┘        └─────────────┘      └──────────┘    │
│                                                              │
│  Pattern 3: Enrollment Protocol (Direct)                    │
│  ┌──────────┐        ┌──────────┐        ┌──────────┐     │
│  │  Client  │ ACME/  │Keyfactor │  API   │   CA     │     │
│  │ (K8s/App)│  EST   │ Protocol │        │          │     │
│  │          │ SCEP   │ Gateway  │        │          │     │
│  └──────────┘        └──────────┘        └──────────┘     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Integration Matrix

| Integration | Type | Direction | Protocol | Auth Method |
|------------|------|-----------|----------|-------------|
| **Azure Key Vault** | Secret Store | Bi-directional | HTTPS/REST | Service Principal |
| **HashiCorp Vault** | Secret Store | Bi-directional | HTTPS/REST | AppRole/Token |
| **Kubernetes cert-manager** | Enrollment | Inbound | HTTPS/REST | API Key |
| **AD CS** | CA | Bi-directional | DCOM/RPC | Kerberos |
| **EJBCA** | CA | Bi-directional | HTTPS/REST | Client Certificate |
| **AWS ACM** | Secret Store | Bi-directional | HTTPS/REST | IAM Role |
| **F5 BIG-IP** | Certificate Store | Outbound | iControl REST | Basic/Token |
| **Palo Alto** | Certificate Store | Outbound | XML API | API Key |

---

## 2. Azure Key Vault Integration

### 2.1 Overview

**Purpose**: Store and manage certificates in Azure Key Vault  
**Orchestrator**: Azure Key Vault Orchestrator  
**Communication**: HTTPS REST API  
**Authentication**: Azure Service Principal (Client ID + Secret or Certificate)

### 2.2 Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Azure Key Vault Integration                  │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Keyfactor Platform                                      │
│  ┌─────────────────────────────────────────┐            │
│  │  Keyfactor Command                       │            │
│  │  ┌─────────────┐                         │            │
│  │  │   Job       │ 1. Schedule job         │            │
│  │  │  Scheduler  │──────┐                  │            │
│  │  └─────────────┘      │                  │            │
│  │                       │                  │            │
│  │  ┌─────────────┐      │                  │            │
│  │  │  Cert DB    │<─────┘                  │            │
│  │  └─────────────┘                         │            │
│  └──────────────────┬──────────────────────┘            │
│                     │ 2. Job request                     │
│                     v                                     │
│  ┌──────────────────────────────────────┐               │
│  │ Azure Key Vault Orchestrator          │               │
│  │ (Windows Service on VM/Container)     │               │
│  │                                        │               │
│  │  ┌──────────────┐   ┌───────────┐   │               │
│  │  │ Management   │   │ Inventory │   │               │
│  │  │ (Add/Remove) │   │ Discovery │   │               │
│  │  └──────────────┘   └───────────┘   │               │
│  └────────────┬─────────────────────────┘               │
│               │ 3. Azure API calls                       │
│               v                                           │
│  ┌──────────────────────────────────────┐               │
│  │ Azure Active Directory                │               │
│  │ (Authentication)                      │               │
│  └────────────┬──────────────────────────┘               │
│               │ 4. Token                                  │
│               v                                           │
│  ┌──────────────────────────────────────┐               │
│  │ Azure Key Vault                       │               │
│  │  ┌────────────┐  ┌────────────┐     │               │
│  │  │Certificates│  │  Secrets   │     │               │
│  │  └────────────┘  └────────────┘     │               │
│  └───────────────────────────────────────┘               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 2.3 API Specifications

#### Authentication

```http
POST https://login.microsoftonline.com/{tenant-id}/oauth2/v2.0/token
Content-Type: application/x-www-form-urlencoded

client_id={client-id}
&scope=https://vault.azure.net/.default
&client_secret={client-secret}
&grant_type=client_credentials
```

**Response**:
```json
{
  "token_type": "Bearer",
  "expires_in": 3599,
  "ext_expires_in": 3599,
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### Import Certificate

```http
POST https://{vault-name}.vault.azure.net/certificates/{cert-name}/import?api-version=7.3
Authorization: Bearer {access-token}
Content-Type: application/json

{
  "value": "{base64-encoded-pfx}",
  "pwd": "{password}",
  "policy": {
    "key_props": {
      "exportable": true,
      "kty": "RSA",
      "key_size": 2048,
      "reuse_key": false
    },
    "secret_props": {
      "contentType": "application/x-pkcs12"
    }
  }
}
```

**Response**:
```json
{
  "id": "https://contoso-vault.vault.azure.net/certificates/webapp-cert/abc123",
  "kid": "https://contoso-vault.vault.azure.net/keys/webapp-cert/abc123",
  "sid": "https://contoso-vault.vault.azure.net/secrets/webapp-cert/abc123",
  "x5t": "KPbB-hKU8Fz...",
  "cer": "MIIDQTCCAimgAwIBA...",
  "attributes": {
    "enabled": true,
    "nbf": 1697990400,
    "exp": 1729526400,
    "created": 1697990400,
    "updated": 1697990400
  }
}
```

#### List Certificates (Inventory)

```http
GET https://{vault-name}.vault.azure.net/certificates?api-version=7.3
Authorization: Bearer {access-token}
```

**Response**:
```json
{
  "value": [
    {
      "id": "https://contoso-vault.vault.azure.net/certificates/webapp-cert",
      "x5t": "KPbB-hKU8Fz...",
      "attributes": {
        "enabled": true,
        "nbf": 1697990400,
        "exp": 1729526400,
        "created": 1697990400,
        "updated": 1697990400
      },
      "tags": {
        "Environment": "Production",
        "Owner": "webapp-team"
      }
    }
  ],
  "nextLink": null
}
```

#### Delete Certificate

```http
DELETE https://{vault-name}.vault.azure.net/certificates/{cert-name}?api-version=7.3
Authorization: Bearer {access-token}
```

### 2.4 Configuration Example

**Orchestrator Configuration** (`appsettings.json`):
```json
{
  "Orchestrator": {
    "AgentId": "azure-kv-orch-01",
    "KeyfactorApiUrl": "https://keyfactor.contoso.com/KeyfactorAPI",
    "AuthenticationMethod": "OAuth",
    "PollingInterval": "00:05:00"
  },
  "AzureKeyVault": {
    "TenantId": "12345678-1234-1234-1234-123456789012",
    "ClientId": "87654321-4321-4321-4321-210987654321",
    "ClientSecret": "stored-in-azure-kv-or-config",
    "VaultUrl": "https://contoso-vault.vault.azure.net",
    "RetryAttempts": 3,
    "RetryDelaySeconds": 5
  }
}
```

**Certificate Store Registration** (Keyfactor):
```json
{
  "ContainerId": 1,
  "ClientMachine": "azure-kv-orch-01",
  "StorePath": "https://contoso-vault.vault.azure.net",
  "Approved": true,
  "CreateIfMissing": false,
  "Properties": {
    "TenantId": "12345678-1234-1234-1234-123456789012",
    "ApplicationId": "87654321-4321-4321-4321-210987654321",
    "AzureCloud": "public",
    "VaultName": "contoso-vault"
  },
  "AgentId": "azure-kv-orch-01",
  "InventorySchedule": {
    "Immediate": false,
    "Interval": {
      "Minutes": 360
    },
    "Daily": {
      "Time": "02:00:00"
    }
  }
}
```

### 2.5 Error Handling

| Error Code | Meaning | Retry? | Action |
|-----------|---------|--------|--------|
| 401 Unauthorized | Token expired/invalid | Yes | Refresh token and retry |
| 403 Forbidden | Insufficient permissions | No | Check Service Principal permissions |
| 404 Not Found | Certificate doesn't exist | No | Skip or log warning |
| 429 Too Many Requests | Rate limit exceeded | Yes | Exponential backoff |
| 500 Internal Server Error | Azure issue | Yes | Retry with backoff |

---

## 3. HashiCorp Vault Integration

### 3.1 Overview

**Purpose**: Store certificates and manage PKI secrets in HashiCorp Vault  
**Orchestrator**: HashiCorp Vault Orchestrator  
**Communication**: HTTPS REST API  
**Authentication**: AppRole, Token, or Kubernetes Service Account

### 3.2 Architecture

```
┌──────────────────────────────────────────────────────────┐
│           HashiCorp Vault Integration                     │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Keyfactor Platform                                      │
│  ┌──────────────────────────────────────┐               │
│  │  Keyfactor Orchestrator               │               │
│  │  ┌────────────┐  ┌────────────┐      │               │
│  │  │   Add/     │  │ Inventory  │      │               │
│  │  │  Remove    │  │ Discovery  │      │               │
│  │  └────────────┘  └────────────┘      │               │
│  └───────────┬──────────────────────────┘               │
│              │                                            │
│              │ 1. AppRole Login                          │
│              v                                            │
│  ┌──────────────────────────────────────┐               │
│  │ HashiCorp Vault                       │               │
│  │  ┌────────────────────────┐          │               │
│  │  │   Auth (AppRole)        │          │               │
│  │  │   Returns: client_token │          │               │
│  │  └────────────────────────┘          │               │
│  │                ↓                       │               │
│  │  ┌────────────────────────┐          │               │
│  │  │   PKI Secrets Engine    │          │               │
│  │  │   /pki/cert/{name}      │          │               │
│  │  └────────────────────────┘          │               │
│  │                                        │               │
│  │  ┌────────────────────────┐          │               │
│  │  │   KV Secrets Engine     │          │               │
│  │  │   /secret/certs/{name}  │          │               │
│  │  └────────────────────────┘          │               │
│  └───────────────────────────────────────┘               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 3.3 API Specifications

#### Authentication (AppRole)

```http
POST https://vault.contoso.com:8200/v1/auth/approle/login
Content-Type: application/json

{
  "role_id": "12345678-1234-1234-1234-123456789012",
  "secret_id": "87654321-4321-4321-4321-210987654321"
}
```

**Response**:
```json
{
  "auth": {
    "client_token": "s.XXXXXXXXXXXXXX",
    "accessor": "0e9e354a-520f-df04-6867-ee81cae3d42d",
    "policies": ["default", "pki-operator"],
    "token_policies": ["default", "pki-operator"],
    "lease_duration": 2764800,
    "renewable": true
  }
}
```

#### Write Certificate (KV v2)

```http
POST https://vault.contoso.com:8200/v1/secret/data/certs/webapp-cert
X-Vault-Token: s.XXXXXXXXXXXXXX
Content-Type: application/json

{
  "data": {
    "certificate": "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----",
    "ca_chain": "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----",
    "metadata": {
      "subject": "CN=webapp01.contoso.com",
      "issuer": "CN=Contoso Enterprise CA",
      "serial_number": "1A2B3C4D5E6F7890",
      "not_before": "2025-10-22T00:00:00Z",
      "not_after": "2026-10-22T00:00:00Z",
      "thumbprint": "ABC123DEF456..."
    }
  }
}
```

#### Read Certificate (KV v2)

```http
GET https://vault.contoso.com:8200/v1/secret/data/certs/webapp-cert
X-Vault-Token: s.XXXXXXXXXXXXXX
```

**Response**:
```json
{
  "data": {
    "data": {
      "certificate": "-----BEGIN CERTIFICATE-----...",
      "private_key": "-----BEGIN PRIVATE KEY-----...",
      "ca_chain": "-----BEGIN CERTIFICATE-----...",
      "metadata": {
        "subject": "CN=webapp01.contoso.com",
        "not_after": "2026-10-22T00:00:00Z"
      }
    },
    "metadata": {
      "created_time": "2025-10-22T14:30:00Z",
      "version": 1
    }
  }
}
```

#### List Certificates (Inventory)

```http
LIST https://vault.contoso.com:8200/v1/secret/metadata/certs
X-Vault-Token: s.XXXXXXXXXXXXXX
```

**Response**:
```json
{
  "data": {
    "keys": [
      "webapp-cert",
      "api-cert",
      "database-cert"
    ]
  }
}
```

#### Delete Certificate

```http
DELETE https://vault.contoso.com:8200/v1/secret/data/certs/webapp-cert
X-Vault-Token: s.XXXXXXXXXXXXXX
```

### 3.4 Configuration Example

**Orchestrator Configuration**:
```json
{
  "Vault": {
    "Address": "https://vault.contoso.com:8200",
    "AuthMethod": "AppRole",
    "AppRole": {
      "RoleId": "stored-in-config-or-env",
      "SecretId": "stored-in-config-or-env",
      "MountPath": "approle"
    },
    "SecretsEngine": {
      "Type": "kv-v2",
      "MountPath": "secret",
      "CertificatePath": "certs"
    },
    "TlsConfig": {
      "SkipVerify": false,
      "CaCert": "/path/to/ca.crt"
    }
  }
}
```

**Certificate Store Registration**:
```json
{
  "ClientMachine": "vault-orch-01",
  "StorePath": "https://vault.contoso.com:8200/secret/certs",
  "Properties": {
    "VaultAddress": "https://vault.contoso.com:8200",
    "MountPoint": "secret",
    "SecretEngine": "kv-v2",
    "AuthMethod": "approle"
  },
  "InventorySchedule": {
    "Daily": {
      "Time": "03:00:00"
    }
  }
}
```

### 3.5 Error Handling

| Error Code | Meaning | Retry? | Action |
|-----------|---------|--------|--------|
| 400 Bad Request | Invalid request format | No | Fix request and resubmit |
| 403 Permission Denied | Insufficient policy | No | Update Vault policy |
| 404 Not Found | Path doesn't exist | No | Create path or skip |
| 412 Precondition Failed | Check-and-Set failed | Yes | Retry with latest version |
| 429 Rate Limit | Too many requests | Yes | Backoff and retry |
| 500 Internal Error | Vault server error | Yes | Retry with exponential backoff |
| 503 Service Unavailable | Vault sealed/unavailable | Yes | Wait and retry, alert ops |

---

## 4. Kubernetes cert-manager Integration

### 4.1 Overview

**Purpose**: Automated certificate issuance for Kubernetes workloads  
**Integration Type**: External Issuer  
**Communication**: HTTPS REST API (Keyfactor API)  
**Authentication**: API Key or Client Certificate

### 4.2 Architecture

```
┌──────────────────────────────────────────────────────────┐
│         Kubernetes cert-manager Integration               │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Kubernetes Cluster                                      │
│  ┌──────────────────────────────────────┐               │
│  │  Application Pod                      │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  Needs TLS Certificate      │      │               │
│  │  └────────────────────────────┘      │               │
│  └──────────────────────────────────────┘               │
│                ↓ 1. Certificate Request                  │
│  ┌──────────────────────────────────────┐               │
│  │  cert-manager (Controller)            │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  Certificate Resource       │      │               │
│  │  │  (CRD)                      │      │               │
│  │  └────────────────────────────┘      │               │
│  │                ↓                       │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │ Keyfactor External Issuer   │      │               │
│  │  │ (Webhook)                   │      │               │
│  │  └────────────────────────────┘      │               │
│  └───────────┬──────────────────────────┘               │
│              │ 2. API Call                                │
│              v                                            │
│  ┌──────────────────────────────────────┐               │
│  │  Keyfactor Command                    │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  REST API Endpoint          │      │               │
│  │  │  /Certificates              │      │               │
│  │  └────────────────────────────┘      │               │
│  │                ↓                       │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  Certificate Issuance       │      │               │
│  │  └────────────────────────────┘      │               │
│  └───────────┬──────────────────────────┘               │
│              │ 3. Certificate Response                   │
│              v                                            │
│  ┌──────────────────────────────────────┐               │
│  │  cert-manager                         │               │
│  │  (Stores cert in Secret)              │               │
│  └──────────────────────────────────────┘               │
│                ↓ 4. Mount Secret                         │
│  ┌──────────────────────────────────────┐               │
│  │  Application Pod                      │               │
│  │  (Uses Certificate)                   │               │
│  └──────────────────────────────────────┘               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 4.3 Certificate Resource (CRD)

**Kubernetes Certificate Manifest**:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webapp-tls
  namespace: production
spec:
  secretName: webapp-tls-secret
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
  subject:
    organizations:
      - Contoso Inc
  commonName: webapp01.contoso.com
  dnsNames:
    - webapp01.contoso.com
    - www.contoso.com
  issuerRef:
    name: keyfactor-issuer
    kind: ClusterIssuer
    group: keyfactor.com
```

**Keyfactor Issuer Configuration**:
```yaml
apiVersion: keyfactor.com/v1alpha1
kind: ClusterIssuer
metadata:
  name: keyfactor-issuer
spec:
  keyfactorApi:
    url: https://keyfactor.contoso.com/KeyfactorAPI
    caName: Contoso-Enterprise-CA
    certificateTemplate: KubernetesWorkload
    authSecret:
      name: keyfactor-api-credentials
      namespace: cert-manager
```

**API Credentials Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keyfactor-api-credentials
  namespace: cert-manager
type: Opaque
stringData:
  username: k8s-cert-manager@contoso.com
  password: <api-key-or-password>
  # OR use certificate-based auth
  # client-cert: <base64-encoded-cert>
  # client-key: <base64-encoded-key>
```

### 4.4 API Flow

**1. Submit Certificate Request**:
```http
POST https://keyfactor.contoso.com/KeyfactorAPI/Certificates/Enroll
Authorization: Basic <base64(username:password)>
Content-Type: application/json

{
  "CSR": "-----BEGIN CERTIFICATE REQUEST-----\nMIIC...\n-----END CERTIFICATE REQUEST-----",
  "CertificateTemplate": "KubernetesWorkload",
  "CertificateAuthority": "Contoso-Enterprise-CA",
  "Metadata": {
    "Namespace": "production",
    "PodName": "webapp-pod-abc123",
    "RequestedBy": "cert-manager"
  },
  "SANs": {
    "DNS": ["webapp01.contoso.com", "www.contoso.com"]
  },
  "IncludeChain": true,
  "CertificateFormat": "PEM"
}
```

**2. Response (Synchronous Issuance)**:
```json
{
  "CertificateId": 12345,
  "Thumbprint": "ABC123DEF456...",
  "SerialNumber": "1A2B3C4D5E6F7890",
  "IssuedDN": "CN=webapp01.contoso.com, O=Contoso Inc",
  "IssuerDN": "CN=Contoso Enterprise CA",
  "NotBefore": "2025-10-22T00:00:00Z",
  "NotAfter": "2026-01-20T00:00:00Z",
  "Certificates": [
    "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----",
    "-----BEGIN CERTIFICATE-----\nMIIE...\n-----END CERTIFICATE-----"
  ]
}
```

**3. cert-manager Creates Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-tls-secret
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # base64 certificate
  tls.key: LS0tLS1CRUdJTi... # base64 private key
  ca.crt: LS0tLS1CRUdJTi...  # base64 CA chain
```

### 4.5 Configuration Example

**Keyfactor External Issuer Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keyfactor-external-issuer
  namespace: cert-manager
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keyfactor-external-issuer
  template:
    metadata:
      labels:
        app: keyfactor-external-issuer
    spec:
      serviceAccountName: keyfactor-issuer
      containers:
      - name: issuer
        image: keyfactor/external-issuer:v1.0.0
        env:
        - name: KEYFACTOR_API_URL
          value: "https://keyfactor.contoso.com/KeyfactorAPI"
        - name: DEFAULT_CA
          value: "Contoso-Enterprise-CA"
        - name: LOG_LEVEL
          value: "info"
        volumeMounts:
        - name: api-credentials
          mountPath: /etc/keyfactor
          readOnly: true
      volumes:
      - name: api-credentials
        secret:
          secretName: keyfactor-api-credentials
```

### 4.6 Error Handling

| Error | Scenario | Action |
|-------|----------|--------|
| **401 Unauthorized** | Invalid credentials | Check API credentials in secret |
| **403 Forbidden** | Template not allowed | Verify user has access to template |
| **422 Unprocessable Entity** | Invalid CSR or SAN | Check Certificate spec, validate CSR |
| **500 Internal Server Error** | Keyfactor error | Retry with backoff, check Keyfactor logs |
| **503 Service Unavailable** | CA offline | Wait and retry, alert ops |

---

## 5. Active Directory Certificate Services (AD CS)

### 5.1 Overview

**Purpose**: Microsoft CA integration for Windows environments  
**Communication**: DCOM/RPC (traditional), HTTPS/REST (via gateway)  
**Authentication**: Kerberos (Windows Integrated), Client Certificate

### 5.2 Architecture

```
┌──────────────────────────────────────────────────────────┐
│              AD CS Integration Architecture               │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Keyfactor Platform                                      │
│  ┌──────────────────────────────────────┐               │
│  │  Keyfactor Command                    │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  Certificate Request        │      │               │
│  │  └────────────────────────────┘      │               │
│  └───────────┬──────────────────────────┘               │
│              │ 1. CSR + Metadata                         │
│              v                                            │
│  ┌──────────────────────────────────────┐               │
│  │  AD CS Gateway (optional)             │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  REST API to DCOM Proxy     │      │               │
│  │  └────────────────────────────┘      │               │
│  └───────────┬──────────────────────────┘               │
│              │ 2. DCOM/RPC (certadm.dll)                │
│              v                                            │
│  ┌──────────────────────────────────────┐               │
│  │  Windows Server (CA)                  │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  Certification Authority    │      │               │
│  │  │  (certsrv)                  │      │               │
│  │  └────────────────────────────┘      │               │
│  │                ↓                       │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  Certificate Database       │      │               │
│  │  └────────────────────────────┘      │               │
│  │                ↓                       │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  HSM (Key Storage)          │      │               │
│  │  └────────────────────────────┘      │               │
│  └───────────────────────────────────────┘               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 5.3 PowerShell API (certreq)

**Submit Certificate Request**:
```powershell
# Generate CSR
$subject = "CN=webapp01.contoso.com"
$san = @("DNS=webapp01.contoso.com", "DNS=www.contoso.com")

$inf = @"
[Version]
Signature=`$Windows NT$

[NewRequest]
Subject = "$subject"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1

[Extensions]
2.5.29.17 = "{text}"
$($san -join '&')
"@

$inf | Out-File "request.inf"
certreq -new "request.inf" "request.csr"

# Submit to CA
certreq -submit -config "CA-SERVER\Contoso-Enterprise-CA" -attrib "CertificateTemplate:WebServer" "request.csr" "certificate.cer"
```

### 5.4 COM API (ICertRequest)

**C# Example**:
```csharp
using CERTCLILib;
using CERTENROLLLib;

public class AdCsClient
{
    public string SubmitRequest(string csr, string template, string caConfig)
    {
        try
        {
            // Create request object
            var certRequest = new CCertRequest();
            
            // Submit CSR
            var disposition = certRequest.Submit(
                CR_IN_BASE64 | CR_IN_PKCS10,
                csr,
                $"CertificateTemplate:{template}",
                caConfig
            );
            
            // Check status
            if (disposition == CR_DISP_ISSUED)
            {
                // Get certificate
                string certificate = certRequest.GetCertificate(CR_OUT_BASE64);
                return certificate;
            }
            else if (disposition == CR_DISP_UNDER_SUBMISSION)
            {
                int requestId = certRequest.GetRequestId();
                throw new Exception($"Request pending approval. Request ID: {requestId}");
            }
            else
            {
                string errorInfo = certRequest.GetDispositionMessage();
                throw new Exception($"Request failed: {errorInfo}");
            }
        }
        catch (Exception ex)
        {
            throw new Exception($"AD CS submission error: {ex.Message}", ex);
        }
    }
}
```

### 5.5 Configuration Example

**CA Gateway Configuration** (`appsettings.json`):
```json
{
  "CertificateAuthorities": [
    {
      "Name": "Contoso-Enterprise-CA",
      "Config": "CA-SERVER1.contoso.com\\Contoso-Enterprise-CA",
      "Type": "ActiveDirectory",
      "Authentication": "Kerberos",
      "Templates": [
        {
          "Name": "WebServer",
          "DisplayName": "Web Server",
          "KeySize": 2048,
          "ValidityPeriod": "1 year",
          "ApprovalRequired": false
        },
        {
          "Name": "CodeSigning",
          "DisplayName": "Code Signing",
          "KeySize": 4096,
          "ValidityPeriod": "3 years",
          "ApprovalRequired": true
        }
      ]
    }
  ]
}
```

**Keyfactor CA Configuration**:
```json
{
  "CAName": "Contoso-Enterprise-CA",
  "CAType": "ADCS",
  "Host": "ca-server1.contoso.com",
  "LogicalName": "Contoso-Enterprise-CA",
  "Properties": {
    "AuthenticationType": "Kerberos",
    "ServiceAccount": "CONTOSO\\svc-keyfactor",
    "AllowRenewExpired": false,
    "AllowKeyReuse": false,
    "RFCEnforcement": true
  }
}
```

### 5.6 Error Handling

| Error Code | Hex | Meaning | Action |
|-----------|-----|---------|--------|
| -2146893811 | 0x80090010D | Certificate template not found | Verify template published to CA |
| -2147024891 | 0x080070005 | Access denied | Check service account permissions |
| -2146875374 | 0x080094812 | Policy module denied request | Check template permissions and policy |
| -2147024809 | 0x080070057 | Invalid parameter | Verify CSR format and attributes |
| 0 | 0x0 | Issued | Certificate issued successfully |
| 3 | 0x3 | Under submission | Manual approval required |
| 5 | 0x5 | Denied | Request denied by policy |

---

## 6. EJBCA Integration

### 6.1 Overview

**Purpose**: Open-source CA integration for enterprise PKI  
**Communication**: HTTPS REST API, Web Services (SOAP)  
**Authentication**: Client Certificate (mutual TLS)

### 6.2 Architecture

```
┌──────────────────────────────────────────────────────────┐
│                EJBCA Integration Architecture             │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Keyfactor Platform                                      │
│  ┌──────────────────────────────────────┐               │
│  │  Keyfactor Command                    │               │
│  └───────────┬──────────────────────────┘               │
│              │ 1. HTTPS + Client Cert                    │
│              v                                            │
│  ┌──────────────────────────────────────┐               │
│  │  EJBCA REST API / Web Services        │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  /ejbca/ejbca-rest-api/v1   │      │               │
│  │  │  - Certificate enrollment    │      │               │
│  │  │  - Certificate status        │      │               │
│  │  │  - Revocation                │      │               │
│  │  └────────────────────────────┘      │               │
│  └───────────┬──────────────────────────┘               │
│              │ 2. Process request                        │
│              v                                            │
│  ┌──────────────────────────────────────┐               │
│  │  EJBCA Core                           │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  Certificate Profiles       │      │               │
│  │  └────────────────────────────┘      │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  End Entity Profiles        │      │               │
│  │  └────────────────────────────┘      │               │
│  │  ┌────────────────────────────┐      │               │
│  │  │  CA Database                │      │               │
│  │  └────────────────────────────┘      │               │
│  └───────────────────────────────────────┘               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### 6.3 REST API Specifications

**Base URL**: `https://ejbca.contoso.com:8443/ejbca/ejbca-rest-api/v1`

#### Enroll Certificate

```http
POST /certificate/enrollkeystore
Content-Type: application/json
Accept: application/json
X-Keyfactor-Requested-With: XMLHttpRequest
Client Certificate: (mutual TLS)

{
  "username": "webapp01",
  "password": "enrollment-password",
  "certificate_profile_name": "WebServer",
  "end_entity_profile_name": "KeyfactorWebServer",
  "certificate_authority_name": "Contoso-SubCA",
  "token_type": "PKCS12",
  "key_alg": "RSA",
  "key_spec": "2048"
}
```

**Response**:
```json
{
  "certificate": "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----",
  "certificate_chain": [
    "-----BEGIN CERTIFICATE-----\nMIIE...\n-----END CERTIFICATE-----"
  ],
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----",
  "serial_number": "1A2B3C4D5E6F7890"
}
```

#### Check Certificate Status

```http
GET /certificate/status?certificate_serial_number=1A2B3C4D5E6F7890&issuer_dn=CN=Contoso-SubCA
Client Certificate: (mutual TLS)
```

**Response**:
```json
{
  "serial_number": "1A2B3C4D5E6F7890",
  "issuer_dn": "CN=Contoso-SubCA, O=Contoso Inc, C=US",
  "status": "ACTIVE",
  "revocation_reason": null,
  "revocation_date": null,
  "expiration_date": "2026-10-22T00:00:00Z"
}
```

#### Revoke Certificate

```http
PUT /certificate/1A2B3C4D5E6F7890/revoke
Content-Type: application/json
Client Certificate: (mutual TLS)

{
  "issuer_dn": "CN=Contoso-SubCA, O=Contoso Inc, C=US",
  "reason": "KEY_COMPROMISE",
  "date": "2025-10-22T14:30:00Z"
}
```

### 6.4 Configuration Example

**EJBCA CA Configuration** (Keyfactor):
```json
{
  "CAName": "EJBCA-SubCA",
  "CAType": "EJBCA",
  "Properties": {
    "BaseUrl": "https://ejbca.contoso.com:8443/ejbca/ejbca-rest-api/v1",
    "AuthenticationType": "ClientCertificate",
    "ClientCertificatePath": "C:\\Certs\\keyfactor-client.pfx",
    "ClientCertificatePassword": "stored-in-config-encrypted",
    "DefaultCertificateProfile": "WebServer",
    "DefaultEndEntityProfile": "KeyfactorWebServer",
    "VerifyServerCertificate": true,
    "Timeout": 30
  }
}
```

**End Entity Profile Mapping**:
```json
{
  "TemplateName": "WebServer",
  "EJBCAMapping": {
    "EndEntityProfile": "KeyfactorWebServer",
    "CertificateProfile": "WebServer",
    "CertificateAuthority": "Contoso-SubCA",
    "SubjectDnAttributes": {
      "CN": "{CommonName}",
      "O": "Contoso Inc",
      "C": "US"
    },
    "SubjectAltNames": {
      "DNS": "{SANs.DNS}"
    },
    "KeyGeneration": "OnServer",
    "KeyAlgorithm": "RSA",
    "KeySize": 2048
  }
}
```

### 6.5 Error Handling

| HTTP Status | Error | Action |
|------------|-------|--------|
| 400 Bad Request | Invalid parameters | Check request payload format |
| 401 Unauthorized | Client cert invalid/expired | Renew client certificate |
| 403 Forbidden | Insufficient permissions | Check end entity profile permissions |
| 404 Not Found | Entity/profile not found | Verify profile names |
| 409 Conflict | Username already exists | Use unique username or modify request |
| 500 Internal Server Error | EJBCA error | Check EJBCA logs, retry |

---

## 7. Keyfactor API Reference

### 7.1 Authentication

**Basic Authentication**:
```http
POST https://keyfactor.contoso.com/KeyfactorAPI/Auth/Login
Content-Type: application/json

{
  "username": "apiuser@contoso.com",
  "password": "password"
}
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

**OAuth2 (Recommended)**:
```http
POST https://keyfactor.contoso.com/KeyfactorAPI/OAuth/Token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={client_id}
&client_secret={client_secret}
&scope=keyfactor-api
```

### 7.2 Core API Endpoints

#### List Certificates

```http
GET https://keyfactor.contoso.com/KeyfactorAPI/Certificates?pq.queryString=(Status%20-eq%20%22Active%22)&pq.pageReturned=1&pq.returnLimit=100
Authorization: Bearer {access_token}
```

#### Enroll Certificate

```http
POST https://keyfactor.contoso.com/KeyfactorAPI/Certificates/Enroll
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "CSR": "-----BEGIN CERTIFICATE REQUEST-----...",
  "Template": "WebServer",
  "CertificateAuthority": "Contoso-Enterprise-CA",
  "Metadata": {
    "Owner": "webapp-team@contoso.com",
    "Application": "WebApp-Production"
  },
  "SANs": {
    "DNS": ["webapp01.contoso.com"]
  }
}
```

#### Revoke Certificate

```http
DELETE https://keyfactor.contoso.com/KeyfactorAPI/Certificates/12345/Revoke
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "RevocationReason": 1,
  "Comment": "Key compromise suspected",
  "EffectiveDate": "2025-10-22T14:30:00Z"
}
```

---

## 8. Error Handling and Retry Logic

### 8.1 Retry Strategy

**Exponential Backoff with Jitter**:
```python
import time
import random

def retry_with_backoff(func, max_retries=3, base_delay=1, max_delay=60):
    """
    Retry function with exponential backoff and jitter
    """
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            
            # Calculate delay with jitter
            delay = min(base_delay * (2 ** attempt) + random.uniform(0, 1), max_delay)
            
            print(f"Attempt {attempt + 1} failed: {str(e)}")
            print(f"Retrying in {delay:.2f} seconds...")
            time.sleep(delay)
```

### 8.2 Retry Decision Matrix

| Error Type | Retry? | Max Attempts | Strategy |
|-----------|--------|--------------|----------|
| Network timeout | Yes | 3 | Exponential backoff |
| 401 Unauthorized | Yes (once) | 2 | Refresh token, retry |
| 403 Forbidden | No | 0 | Authorization issue, log and fail |
| 404 Not Found | No | 0 | Resource doesn't exist |
| 429 Rate Limit | Yes | 5 | Exponential backoff + respect Retry-After header |
| 500 Server Error | Yes | 3 | Exponential backoff |
| 502/503/504 Gateway | Yes | 5 | Long backoff (server recovery) |

### 8.3 Error Logging

```python
import logging

def log_integration_error(integration_name, error_type, details):
    """
    Structured error logging for integration failures
    """
    logger = logging.getLogger(f"keyfactor.integration.{integration_name}")
    
    error_details = {
        "integration": integration_name,
        "error_type": error_type,
        "timestamp": datetime.utcnow().isoformat(),
        "details": details
    }
    
    logger.error(f"Integration error: {json.dumps(error_details)}")
    
    # Send to monitoring system
    send_to_monitoring(error_details)
```

---

## 9. Performance and Scaling

### 9.1 Performance Benchmarks

| Integration | Operation | Avg Latency | Throughput | Notes |
|------------|-----------|-------------|------------|-------|
| **Azure Key Vault** | Import certificate | 200ms | 100/min | Rate limited by Azure |
| **Azure Key Vault** | List certificates | 150ms | 200/min | Pagination recommended |
| **HashiCorp Vault** | Write secret | 50ms | 500/min | Depends on Vault config |
| **Kubernetes cert-manager** | Enroll cert | 2-5s | 10/min | Includes CA processing time |
| **AD CS** | Submit CSR | 500ms | 50/min | DCOM overhead |
| **EJBCA REST** | Enroll cert | 1-3s | 20/min | Depends on key generation |

### 9.2 Scaling Recommendations

**Orchestrators**:
- 1 orchestrator per 500-1000 certificates
- Separate orchestrators for different cloud regions
- Use multiple orchestrators for high-volume stores

**API Rate Limits**:
- Implement client-side rate limiting
- Use batch operations where available
- Cache frequently accessed data

**Database**:
- Index frequently queried fields
- Use read replicas for inventory operations
- Archive old certificate records

---

## 10. Security Considerations

### 10.1 Authentication Best Practices

| Integration | Recommendation | Rationale |
|------------|----------------|-----------|
| **Azure Key Vault** | Managed Identity (where possible) | No credential storage |
| **HashiCorp Vault** | AppRole with limited TTL | Principle of least privilege |
| **Kubernetes** | Service Account Token | Native K8s auth |
| **AD CS** | Service Account with Kerberos | Windows integrated auth |
| **EJBCA** | Client Certificate | Mutual TLS |

### 10.2 Network Security

**TLS Requirements**:
- TLS 1.2 minimum (TLS 1.3 preferred)
- Certificate validation enabled
- Strong cipher suites only

**Network Segmentation**:
- Orchestrators in DMZ or dedicated VLAN
- Firewall rules restricting inbound/outbound
- No direct internet access for orchestrators

### 10.3 Credential Management

**Secrets Storage**:
- Never hardcode credentials
- Use Azure Key Vault or HashiCorp Vault for secrets
- Rotate credentials regularly (90 days)
- Encrypt configuration files

**Example** (secure configuration):
```json
{
  "AzureKeyVault": {
    "TenantId": "from-environment",
    "ClientId": "from-azure-keyvault",
    "ClientSecret": "from-azure-keyvault:akv:secret/keyfactor-client-secret",
    "VaultUrl": "https://contoso-vault.vault.azure.net"
  }
}
```

---

## Appendix A: Quick Reference

### Common API Endpoints

| Service | Endpoint | Method | Auth |
|---------|----------|--------|------|
| **Keyfactor** | `/KeyfactorAPI/Certificates` | GET | Bearer |
| **Keyfactor** | `/KeyfactorAPI/Certificates/Enroll` | POST | Bearer |
| **Azure KV** | `/certificates/{name}/import` | POST | Bearer |
| **HashiCorp** | `/v1/secret/data/{path}` | POST | Token |
| **EJBCA** | `/certificate/enrollkeystore` | POST | Client Cert |

---

## Appendix B: Troubleshooting

**Common Issues**:

1. **Certificate import fails in Azure Key Vault**
   - Check: PFX format, password correctness, permissions
   - Solution: Verify Service Principal has "Certificate Import" permission

2. **Orchestrator disconnects frequently**
   - Check: Network stability, firewall rules, certificate expiry
   - Solution: Review orchestrator logs, verify heartbeat interval

3. **cert-manager certificates not renewing**
   - Check: renewBefore threshold, issuer status, API credentials
   - Solution: Verify Keyfactor API connectivity and quota

---

## Document Maintenance

**Review Schedule**: Quarterly or when APIs change  
**Owner**: Integration Engineering Team  
**Last Reviewed**: October 22, 2025  
**Next Review**: January 22, 2026

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial comprehensive specifications |

---

**For integration support, contact**: adrian207@gmail.com

**End of Integration Specifications Document**

