# Keyfactor Integrations Guide
## Implementation, Operations, Support & Troubleshooting

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Document Purpose

This guide provides detailed implementation, operational, support, and troubleshooting documentation for all Keyfactor GitHub packages applicable to our certificate lifecycle management implementation.

**Repository**: [Keyfactor GitHub Organization](https://github.com/Keyfactor)

---

## Table of Contents

### Core Components
1. [EJBCA Community Edition](#1-ejbca-community-edition)
2. [EJBCA Vault PKI Engine](#2-ejbca-vault-pki-engine)
3. [EJBCA cert-manager Issuer](#3-ejbca-cert-manager-issuer)
4. [Command cert-manager Issuer](#4-command-cert-manager-issuer)

### Universal Orchestrators
5. [Azure Key Vault Orchestrator](#5-azure-key-vault-orchestrator)
6. [AWS Certificate Manager Orchestrator](#6-aws-certificate-manager-orchestrator)
7. [IIS/WinCert Orchestrator](#7-iiswin-cert-orchestrator)
8. [Remote File Orchestrator](#8-remote-file-orchestrator)
9. [F5 REST Orchestrator](#9-f5-rest-orchestrator)
10. [Palo Alto Firewall Orchestrator](#10-palo-alto-firewall-orchestrator)

### SDKs & Automation
11. [Keyfactor Python Client SDK](#11-keyfactor-python-client-sdk)
12. [EJBCA Python Client SDK](#12-ejbca-python-client-sdk)

### PAM Providers
13. [HashiCorp Vault PAM](#13-hashicorp-vault-pam)
14. [CyberArk PAM](#14-cyberark-pam)

### Infrastructure as Code
15. [Terraform Provider](#15-terraform-provider)

---

## 1. EJBCA Community Edition

**Repository**: [https://github.com/Keyfactor/ejbca-ce](https://github.com/Keyfactor/ejbca-ce)  
**Language**: Java  
**Stars**: 809 ⭐

### Overview

EJBCA® is an open-source Public Key Infrastructure (PKI) and Certificate Authority (CA) software. Use as an alternative to AD CS with HSM support.

### Implementation Phase

**Phase 2**: CA & HSM Foundation (Weeks 6-9)

### Use Cases

- Deploy as primary issuing CA (greenfield)
- Replace AD CS with HSM-backed CA
- Multi-cloud PKI infrastructure
- Container/Kubernetes-native CA

---

### Implementation Guide

#### Prerequisites

- **Java**: OpenJDK 11 or later
- **Application Server**: WildFly 23+ or JBoss EAP 7.4+
- **Database**: PostgreSQL 12+ or MySQL 8+
- **HSM** (optional): Azure Managed HSM, Luna HSM, or SoftHSM for testing
- **Infrastructure**: 
  - 3 nodes for HA (production)
  - 8 vCPU, 16 GB RAM per node
  - 100 GB disk

#### Installation Steps

**Option A: Container Deployment (Recommended for Production)**

```bash
# 1. Clone repository
git clone https://github.com/Keyfactor/ejbca-ce.git
cd ejbca-ce

# 2. Build container image
docker build -t ejbca-ce:latest .

# 3. Create PostgreSQL database
docker run -d \
  --name ejbca-db \
  -e POSTGRES_DB=ejbca \
  -e POSTGRES_USER=ejbca \
  -e POSTGRES_PASSWORD=<strong_password> \
  -v ejbca-db-data:/var/lib/postgresql/data \
  postgres:14

# 4. Run EJBCA container
docker run -d \
  --name ejbca \
  -p 8080:8080 \
  -p 8443:8443 \
  -e DATABASE_JDBC_URL=jdbc:postgresql://ejbca-db:5432/ejbca \
  -e DATABASE_USER=ejbca \
  -e DATABASE_PASSWORD=<strong_password> \
  -e EJBCA_CA_NAME=ManagementCA \
  -e EJBCA_CA_DN="CN=Management CA,O=Contoso Inc,C=US" \
  -e EJBCA_CA_KEYSPEC=RSA4096 \
  -v ejbca-data:/opt/ejbca/data \
  --link ejbca-db:ejbca-db \
  ejbca-ce:latest

# 5. Wait for startup (2-5 minutes)
docker logs -f ejbca

# 6. Access EJBCA Admin UI
# URL: https://<server>:8443/ejbca/adminweb/
# Initial credentials: superadmin / <see logs>
```

**Option B: Kubernetes Deployment**

```yaml
# ejbca-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ejbca
---
apiVersion: v1
kind: Secret
metadata:
  name: ejbca-db-credentials
  namespace: ejbca
type: Opaque
stringData:
  username: ejbca
  password: <strong_password>
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ejbca-db
  namespace: ejbca
spec:
  serviceName: ejbca-db
  replicas: 1
  selector:
    matchLabels:
      app: ejbca-db
  template:
    metadata:
      labels:
        app: ejbca-db
    spec:
      containers:
      - name: postgres
        image: postgres:14
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: ejbca
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: ejbca-db-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ejbca-db-credentials
              key: password
        volumeMounts:
        - name: db-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: db-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ejbca-db
  namespace: ejbca
spec:
  clusterIP: None
  selector:
    app: ejbca-db
  ports:
  - port: 5432
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ejbca
  namespace: ejbca
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ejbca
  template:
    metadata:
      labels:
        app: ejbca
    spec:
      containers:
      - name: ejbca
        image: keyfactor/ejbca-ce:latest
        ports:
        - containerPort: 8080
        - containerPort: 8443
        env:
        - name: DATABASE_JDBC_URL
          value: jdbc:postgresql://ejbca-db:5432/ejbca
        - name: DATABASE_USER
          valueFrom:
            secretKeyRef:
              name: ejbca-db-credentials
              key: username
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ejbca-db-credentials
              key: password
        - name: EJBCA_CA_NAME
          value: ManagementCA
        - name: EJBCA_CA_DN
          value: "CN=Management CA,O=Contoso Inc,C=US"
        volumeMounts:
        - name: ejbca-data
          mountPath: /opt/ejbca/data
        livenessProbe:
          httpGet:
            path: /ejbca/publicweb/healthcheck/ejbcahealth
            port: 8080
          initialDelaySeconds: 120
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ejbca/publicweb/healthcheck/ejbcahealth
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
      volumes:
      - name: ejbca-data
        persistentVolumeClaim:
          claimName: ejbca-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: ejbca
  namespace: ejbca
spec:
  type: LoadBalancer
  selector:
    app: ejbca
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: https
    port: 8443
    targetPort: 8443
```

Deploy:
```bash
kubectl apply -f ejbca-deployment.yaml
kubectl wait --for=condition=ready pod -l app=ejbca -n ejbca --timeout=300s
kubectl get svc -n ejbca ejbca  # Get LoadBalancer IP
```

#### HSM Integration

**Azure Managed HSM**:

```bash
# 1. Create Managed HSM
az keyvault create \
  --resource-group rg-pki \
  --name mhsm-ejbca \
  --location eastus \
  --sku Premium \
  --enable-purge-protection true \
  --retention-days 90

# 2. Configure EJBCA to use Azure Key Vault HSM
# Edit /opt/ejbca/conf/cesecore.properties:
cryptotoken.p11.lib.255.name=AzureKeyVault
cryptotoken.p11.lib.255.file=/opt/azure-keyvault-pkcs11/libazure-keyvault.so

# 3. Create crypto token in EJBCA pointing to Managed HSM
# CA → Crypto Tokens → Add
# - Name: AzureManagedHSM
# - Type: PKCS#11
# - PKCS#11 Library: AzureKeyVault
# - Slot: <Managed HSM slot ID>
```

**Network HSM (Luna, Utimaco)**:

```bash
# 1. Install HSM client libraries
# (vendor-specific, see HSM documentation)

# 2. Register HSM with EJBCA
# Edit /opt/ejbca/conf/cesecore.properties:
cryptotoken.p11.lib.1.name=LunaHSM
cryptotoken.p11.lib.1.file=/usr/lib/libCryptoki2_64.so

# 3. Create partition and client certificate
# (HSM-specific commands)

# 4. Test connection
/opt/ejbca/bin/ejbca.sh ca showcryptotoken ManagementCA
```

#### Post-Installation Configuration

**1. Create Issuing CA**:

```bash
# Via CLI
/opt/ejbca/bin/ejbca.sh ca init \
  "Contoso Issuing CA" \
  "CN=Contoso Issuing CA,O=Contoso Inc,C=US" \
  soft \
  RSA4096 \
  SHA256WithRSA \
  3650 \
  null \
  "CN=Contoso Root CA,O=Contoso Inc,C=US"

# Or via Admin UI:
# CA Functions → Create CA
# - CA Name: Contoso Issuing CA
# - Subject DN: CN=Contoso Issuing CA,O=Contoso Inc,C=US
# - Key Type: RSA 4096
# - Validity: 10 years
# - Signed by: Root CA or external
```

**2. Configure Certificate Profiles**:

```bash
# Create TLS Server profile
# Certificate Profiles → Add → Clone from SERVER
# Name: TLS-Server-Internal
# Settings:
#   - Validity: 730 days
#   - Key Usage: Digital Signature, Key Encipherment
#   - Extended Key Usage: Server Authentication
#   - SAN: Allow DNS Name, IP Address
#   - CRL Distribution Points: http://crl.contoso.com/Contoso-Issuing-CA.crl
#   - Authority Info Access: http://aia.contoso.com/Contoso-Issuing-CA.crt
```

**3. Configure End Entity Profiles**:

```bash
# End Entity Profiles → Add
# Name: Keyfactor-TLS-Server
# Settings:
#   - Available Certificate Profiles: TLS-Server-Internal
#   - Default Certificate Profile: TLS-Server-Internal
#   - Available CAs: Contoso Issuing CA
#   - Subject DN Attributes: CN (required), O, C
#   - Subject Alternative Name: DNS Name (required), IP Address (optional)
#   - Email: Not required
```

**4. Enable REST API**:

```bash
# 1. Create API administrator
# Administrators → Add Administrator
# - Match with: X.509 Certificate
# - Common Name: Keyfactor-API-Client
# - Role: Super Administrator (or custom REST API role)

# 2. Generate client certificate
openssl req -x509 -newkey rsa:4096 -keyout keyfactor-api.key -out keyfactor-api.crt -days 365 -nodes \
  -subj "/CN=Keyfactor-API-Client/O=Contoso Inc/C=US"

# 3. Import into EJBCA
# RA Web → Add End Entity
# - Username: keyfactor-api
# - CN: Keyfactor-API-Client
# - Certificate Profile: ENDUSER
# - Token: User Generated
# - Status: New

# Upload CSR or certificate

# 4. Test REST API
curl -k --cert keyfactor-api.crt --key keyfactor-api.key \
  https://ejbca.contoso.com:8443/ejbca/ejbca-rest-api/v1/certificate/status
```

**5. Configure CRL/OCSP**:

```bash
# CRL Configuration
# CA → Edit CA → CRL Settings
# - Issue CRL every: 6 hours
# - CRL Validity: 24 hours
# - CRL Distribution Point: http://crl.contoso.com/Contoso-Issuing-CA.crl

# Publish CRL to web server
/opt/ejbca/bin/ejbca.sh ca getcrl "Contoso Issuing CA" latest > /var/www/html/crl/Contoso-Issuing-CA.crl

# Automate via cron
crontab -e
# 0 */6 * * * /opt/ejbca/bin/ejbca.sh ca getcrl "Contoso Issuing CA" latest > /var/www/html/crl/Contoso-Issuing-CA.crl

# OCSP Configuration
# System Configuration → OCSP
# - Enable OCSP: Yes
# - Default OCSP responder: CN=Contoso OCSP Responder,O=Contoso Inc,C=US
# - OCSP signing certificate: Generate or import
# - URL: http://ocsp.contoso.com
```

---

### Operations Guide

#### Daily Operations

**Health Checks**:
```bash
# Check EJBCA status
curl http://ejbca.contoso.com:8080/ejbca/publicweb/healthcheck/ejbcahealth

# Expected output: ALLOK

# Check database connectivity
/opt/ejbca/bin/ejbca.sh ca listcas

# Check CRL freshness
curl -I http://crl.contoso.com/Contoso-Issuing-CA.crl | grep Last-Modified
```

**Monitoring Metrics**:
- Certificate issuance rate (certs/hour)
- CRL generation time (should be <5 min)
- Database connection pool utilization
- JVM heap usage (alert if >80%)
- Disk space (CRL, logs, database)

#### Certificate Operations

**Issue Certificate**:
```bash
# Via REST API
curl -k --cert keyfactor-api.crt --key keyfactor-api.key \
  -X POST https://ejbca.contoso.com:8443/ejbca/ejbca-rest-api/v1/certificate/enrollkeystore \
  -H "Content-Type: application/json" \
  -d '{
    "username": "webapp01",
    "password": "enrollmentPassword",
    "certificate_profile_name": "TLS-Server-Internal",
    "end_entity_profile_name": "Keyfactor-TLS-Server",
    "certificate_authority_name": "Contoso Issuing CA",
    "subject_dn": "CN=webapp01.contoso.com,O=Contoso Inc,C=US",
    "subject_alt_name": "dNSName=webapp01.contoso.com"
  }'
```

**Revoke Certificate**:
```bash
# Via CLI
/opt/ejbca/bin/ejbca.sh ra revokecert \
  <serial_number> \
  <issuer_dn> \
  keyCompromise

# Via REST API
curl -k --cert keyfactor-api.crt --key keyfactor-api.key \
  -X PUT https://ejbca.contoso.com:8443/ejbca/ejbca-rest-api/v1/certificate/<issuer_dn>/<certificate_serial_number>/revoke \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "KEY_COMPROMISE",
    "date": null
  }'
```

**Check Certificate Status**:
```bash
# OCSP check
openssl ocsp -issuer issuing-ca.crt -cert test-cert.crt \
  -url http://ocsp.contoso.com -resp_text

# CRL check
openssl crl -in Contoso-Issuing-CA.crl -text -noout | grep "Serial Number"
```

#### Backup Procedures

**Daily Backup**:
```bash
#!/bin/bash
# /opt/scripts/ejbca-backup.sh

BACKUP_DIR=/backups/ejbca/$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# 1. Database backup
pg_dump -h ejbca-db -U ejbca ejbca | gzip > $BACKUP_DIR/ejbca-db.sql.gz

# 2. Configuration backup
tar -czf $BACKUP_DIR/ejbca-conf.tar.gz /opt/ejbca/conf

# 3. Key store backup (if not using HSM)
tar -czf $BACKUP_DIR/ejbca-keystores.tar.gz /opt/ejbca/p12

# 4. Test restore (automated validation)
# ...

# 5. Upload to S3/Azure Blob
aws s3 cp $BACKUP_DIR s3://backups-ejbca/$(date +%Y%m%d)/ --recursive

# 6. Retention: keep 30 days
find /backups/ejbca -mtime +30 -type d -exec rm -rf {} \;
```

Schedule:
```bash
crontab -e
# Daily backup at 2 AM
0 2 * * * /opt/scripts/ejbca-backup.sh >> /var/log/ejbca-backup.log 2>&1
```

**Disaster Recovery Test** (Quarterly):
```bash
# 1. Restore database
gunzip < ejbca-db.sql.gz | psql -h ejbca-db-dr -U ejbca ejbca

# 2. Restore configuration
tar -xzf ejbca-conf.tar.gz -C /

# 3. Restart EJBCA
systemctl restart wildfly

# 4. Verify
curl http://ejbca-dr.contoso.com:8080/ejbca/publicweb/healthcheck/ejbcahealth

# 5. Test certificate issuance
/opt/ejbca/bin/ejbca.sh ra addendentity ... (test enrollment)
```

---

### Support & Escalation

#### Support Channels

| Level | Channel | Response SLA | Escalation |
|-------|---------|--------------|------------|
| **L1** | Internal PKI team (#pki-support) | 4 business hours | L2 after 24h |
| **L2** | Keyfactor Support Portal | 1 business day | L3 for critical |
| **L3** | Keyfactor TAM (if purchased) | 4 hours (critical), 1 business day (normal) | Engineering |
| **Community** | [EJBCA GitHub Issues](https://github.com/Keyfactor/ejbca-ce/issues) | Best-effort | N/A |

#### Keyfactor Support

**Portal**: https://support.keyfactor.com  
**Email**: support@keyfactor.com  
**Phone**: +1-216-785-2990 (US)

**When to Engage**:
- EJBCA crashes or fails to start
- HSM connectivity issues
- Data corruption
- Security vulnerabilities
- Performance degradation (>5 min to issue cert)
- Upgrade assistance

**Information to Provide**:
- EJBCA version: `cat /opt/ejbca/VERSION`
- Java version: `java -version`
- OS version: `uname -a`
- Error logs: `/opt/wildfly/standalone/log/server.log`
- Database: PostgreSQL/MySQL version
- HSM: Vendor, model, firmware version
- Steps to reproduce issue

---

### Troubleshooting Guide

#### Issue 1: EJBCA fails to start

**Symptoms**:
- Container exits immediately
- Wildfly logs show database connection errors
- Health check returns 503

**Diagnosis**:
```bash
# Check logs
docker logs ejbca
# OR
tail -f /opt/wildfly/standalone/log/server.log

# Common errors:
# - "Could not connect to database" → Database not ready or wrong credentials
# - "Port 8080 already in use" → Port conflict
# - "OutOfMemoryError" → Insufficient heap
```

**Resolution**:
```bash
# Database connection issue
# 1. Verify database is running
docker ps | grep ejbca-db
pg_isready -h ejbca-db -U ejbca

# 2. Test connection manually
psql -h ejbca-db -U ejbca -d ejbca -c "SELECT 1"

# 3. Check credentials in /opt/ejbca/conf/database.properties

# Port conflict
# Check what's using port 8080
lsof -i :8080
# Kill or use different port

# Out of memory
# Increase JVM heap in /opt/wildfly/bin/standalone.conf
JAVA_OPTS="$JAVA_OPTS -Xms2g -Xmx4g"
```

---

#### Issue 2: Certificate issuance fails

**Symptoms**:
- REST API returns 400/500 errors
- "Certificate could not be generated" in logs
- OCSP shows "revoked" for new cert

**Diagnosis**:
```bash
# Check EJBCA logs
grep -i error /opt/wildfly/standalone/log/server.log | tail -20

# Common errors:
# - "End entity does not exist" → End entity not created or already used
# - "Certificate profile not found" → Wrong profile name
# - "Key generation failed" → HSM issue
```

**Resolution**:
```bash
# End entity issue
# 1. Create end entity first
/opt/ejbca/bin/ejbca.sh ra addendentity \
  webapp01 \
  <password> \
  "CN=webapp01.contoso.com,O=Contoso Inc,C=US" \
  "dNSName=webapp01.contoso.com" \
  null \
  TLS-Server-Internal \
  Keyfactor-TLS-Server \
  "Contoso Issuing CA" \
  NEW

# 2. Then request certificate

# Certificate profile issue
# List available profiles
/opt/ejbca/bin/ejbca.sh ca listprofiles

# HSM issue
# Test HSM connectivity
/opt/ejbca/bin/ejbca.sh ca showcryptotoken ManagementCA
```

---

#### Issue 3: CRL not updating

**Symptoms**:
- CRL Last-Modified header is >24 hours old
- Revoked certificates not appearing in CRL
- OCSP still shows "good" for revoked cert

**Diagnosis**:
```bash
# Check CRL generation
/opt/ejbca/bin/ejbca.sh ca getcrl "Contoso Issuing CA" latest > current.crl
openssl crl -in current.crl -text -noout | head -20

# Check CRL generation timer
# CA → Edit CA → CRL Settings
# Verify "Issue CRL every: X hours" is set

# Check for errors in logs
grep -i "CRL generation" /opt/wildfly/standalone/log/server.log
```

**Resolution**:
```bash
# Force CRL generation
/opt/ejbca/bin/ejbca.sh ca createcrl "Contoso Issuing CA"

# Verify generation timestamp
openssl crl -in /var/www/html/crl/Contoso-Issuing-CA.crl -text -noout | grep "This Update"

# If still issues, check:
# 1. Disk space (CRL generation requires temp space)
df -h

# 2. Database lock (if CRL generation is stuck)
psql -h ejbca-db -U ejbca ejbca -c "SELECT * FROM pg_locks WHERE NOT granted"

# 3. HSM connectivity (if CRL signing uses HSM)
# (see HSM troubleshooting)
```

---

#### Issue 4: HSM connectivity lost

**Symptoms**:
- "CKR_TOKEN_NOT_PRESENT" errors
- Certificate issuance fails with "Key generation failed"
- Crypto token shows "Offline" in UI

**Diagnosis**:
```bash
# Check HSM status
/opt/ejbca/bin/ejbca.sh ca showcryptotoken ManagementCA

# Azure Managed HSM
az keyvault show --name mhsm-ejbca --query properties.provisioningState

# Luna HSM
/usr/safenet/lunaclient/bin/vtl verify

# Check EJBCA HSM configuration
cat /opt/ejbca/conf/cesecore.properties | grep cryptotoken
```

**Resolution**:
```bash
# Azure Managed HSM
# 1. Check network connectivity
curl -I https://mhsm-ejbca.managedhsm.azure.net

# 2. Verify managed identity permissions
az role assignment list --assignee <ejbca-managed-identity-id> --resource-group rg-pki

# 3. Regenerate HSM access token
# (restart EJBCA to pick up new token)

# Luna HSM
# 1. Re-register client
/usr/safenet/lunaclient/bin/lunacm

lunacm:> client register -client ejbca-01 -hostname <hsm-ip>

# 2. Verify partition assignment
lunacm:> partition show

# 3. Test crypto operations
/usr/safenet/lunaclient/bin/cmu list

# Restart EJBCA
systemctl restart wildfly
```

---

#### Issue 5: Performance degradation

**Symptoms**:
- Certificate issuance taking >5 minutes
- Web UI slow or unresponsive
- High CPU/memory usage

**Diagnosis**:
```bash
# Check resource usage
top -bn1 | grep java
free -h
df -h

# Check database performance
psql -h ejbca-db -U ejbca ejbca -c "
  SELECT 
    query, 
    calls, 
    mean_exec_time 
  FROM pg_stat_statements 
  ORDER BY mean_exec_time DESC 
  LIMIT 10"

# Check connection pool
# In JBoss/Wildfly CLI:
/subsystem=datasources/data-source=ejbcads:read-resource(include-runtime=true)

# Check for thread deadlocks
jstack <ejbca-pid> | grep -A10 "deadlock"
```

**Resolution**:
```bash
# Increase JVM heap
# Edit /opt/wildfly/bin/standalone.conf
JAVA_OPTS="$JAVA_OPTS -Xms4g -Xmx8g"

# Tune database connection pool
# Edit /opt/wildfly/standalone/configuration/standalone.xml
<datasource jndi-name="java:/EjbcaDS" pool-name="ejbcads">
  <connection-url>jdbc:postgresql://ejbca-db:5432/ejbca</connection-url>
  <driver>postgresql</driver>
  <pool>
    <min-pool-size>10</min-pool-size>
    <max-pool-size>50</max-pool-size>  <!-- Increase if needed -->
    <prefill>true</prefill>
  </pool>
  <timeout>
    <blocking-timeout-millis>5000</blocking-timeout-millis>
    <idle-timeout-minutes>15</idle-timeout-minutes>
  </timeout>
</datasource>

# Optimize database
# PostgreSQL
psql -h ejbca-db -U ejbca ejbca -c "VACUUM ANALYZE"
psql -h ejbca-db -U ejbca ejbca -c "REINDEX DATABASE ejbca"

# Enable query logging to identify slow queries
# postgresql.conf
log_min_duration_statement = 1000  # Log queries >1s

# Restart services
systemctl restart wildfly
```

---

#### Issue 6: Certificate not trusted by clients

**Symptoms**:
- Browsers show "untrusted certificate" error
- OpenSSL verification fails
- Applications reject TLS handshake

**Diagnosis**:
```bash
# Verify certificate chain
openssl s_client -connect webapp01.contoso.com:443 -showcerts

# Check if root CA is in trust store
# Windows
certutil -store root "Contoso Root CA"

# Linux
ls /etc/ssl/certs | grep Contoso

# macOS
security find-certificate -a -c "Contoso Root CA" /System/Library/Keychains/SystemRootCertificates.keychain
```

**Resolution**:
```bash
# 1. Verify certificate chain is complete
# Certificate should include:
#   - Leaf cert (webapp01.contoso.com)
#   - Issuing CA cert (Contoso Issuing CA)
#   - Root CA cert (Contoso Root CA) - optional but recommended

# 2. Check AIA extension
openssl x509 -in webapp01.crt -text -noout | grep -A2 "Authority Information Access"
# Should show: CA Issuers - URI:http://aia.contoso.com/Contoso-Issuing-CA.crt

# 3. Distribute root CA to clients
# Windows (GPO)
# Computer Configuration → Policies → Windows Settings → Security Settings → Public Key Policies → Trusted Root Certification Authorities
# Import Contoso Root CA

# Linux
sudo cp Contoso-Root-CA.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain Contoso-Root-CA.crt

# 4. Ensure certificate includes full chain on server
# Nginx
ssl_certificate /etc/nginx/certs/webapp01-fullchain.crt;  # Leaf + Intermediate + Root

# Apache
SSLCertificateFile /etc/apache2/certs/webapp01.crt
SSLCertificateChainFile /etc/apache2/certs/chain.crt

# IIS (PFX includes full chain automatically)
```

---

### Performance Tuning

#### Recommended Settings for Production

**JVM Tuning** (`/opt/wildfly/bin/standalone.conf`):
```bash
# For 16 GB RAM server
JAVA_OPTS="$JAVA_OPTS -Xms4g -Xmx8g"
JAVA_OPTS="$JAVA_OPTS -XX:MetaspaceSize=256m -XX:MaxMetaspaceSize=512m"
JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC"
JAVA_OPTS="$JAVA_OPTS -XX:MaxGCPauseMillis=200"

# GC logging for troubleshooting
JAVA_OPTS="$JAVA_OPTS -Xlog:gc*:file=/opt/wildfly/standalone/log/gc.log:time,uptime:filecount=5,filesize=10M"
```

**Database Tuning** (PostgreSQL):
```sql
-- postgresql.conf

# Connections
max_connections = 200

# Memory
shared_buffers = 4GB
effective_cache_size = 12GB
maintenance_work_mem = 1GB
work_mem = 16MB

# Query planning
random_page_cost = 1.1  # For SSD
effective_io_concurrency = 200

# Checkpoints
checkpoint_completion_target = 0.9
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB

# Autovacuum (critical for EJBCA)
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 1min
```

**Wildfly Connection Pool**:
```xml
<!-- standalone.xml -->
<datasource jndi-name="java:/EjbcaDS" pool-name="ejbcads" enabled="true">
  <connection-url>jdbc:postgresql://ejbca-db:5432/ejbca</connection-url>
  <driver>postgresql</driver>
  <pool>
    <min-pool-size>20</min-pool-size>
    <max-pool-size>100</max-pool-size>
    <prefill>true</prefill>
  </pool>
  <timeout>
    <blocking-timeout-millis>5000</blocking-timeout-millis>
    <idle-timeout-minutes>30</idle-timeout-minutes>
  </timeout>
  <validation>
    <valid-connection-checker class-name="org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker"/>
    <background-validation>true</background-validation>
    <background-validation-millis>60000</background-validation-millis>
  </validation>
</datasource>
```

**Expected Performance** (after tuning):
- Certificate issuance: <2 seconds
- CRL generation: <5 minutes (for 100,000 revoked certs)
- OCSP response: <100ms
- Concurrent requests: 50-100 requests/sec

---

### Security Hardening

#### Checklist

- [ ] **Change default passwords**
  - SuperAdmin account
  - Database passwords
  - HSM PINs

- [ ] **Enable TLS everywhere**
  - HTTPS only (disable HTTP port 8080 in production)
  - Database connections encrypted (PostgreSQL: `sslmode=require`)
  - HSM connections via TLS

- [ ] **Restrict network access**
  - Admin UI: Internal network only (firewall rules)
  - REST API: Whitelist Keyfactor Command IPs
  - Database: Only EJBCA servers can connect

- [ ] **Enable audit logging**
  ```bash
  # CA → Edit CA → Advanced Settings
  # Use CA defined Audit Devices: Yes
  # Audit log to: Syslog (remote server)
  ```

- [ ] **Implement least privilege**
  - Don't use SuperAdmin for day-to-day operations
  - Create role-specific administrators:
    - CA Administrators (can manage CAs)
    - RA Administrators (can issue/revoke certs)
    - Auditors (read-only access to logs)

- [ ] **Secure private keys**
  - Use HSM for all issuing CAs
  - Never export private keys
  - Rotate key ceremony participants annually

- [ ] **Patch regularly**
  - Subscribe to [EJBCA Security Advisories](https://www.primekey.com/security-advisories/)
  - Test patches in dev before production
  - Patch window: Monthly

- [ ] **Enable rate limiting** (if publicly accessible)
  - Use reverse proxy (Nginx/Apache) with `limit_req`
  - WAF rules to block abuse

---

### Maintenance Schedule

| Frequency | Task | Downtime | Owner |
|-----------|------|----------|-------|
| **Daily** | Check health endpoint | None | Monitoring |
| **Daily** | Verify CRL published | None | Automation |
| **Weekly** | Review logs for errors | None | PKI Ops |
| **Monthly** | Apply security patches | 15-30 min | PKI Admin |
| **Monthly** | Database maintenance (VACUUM) | None | DB Admin |
| **Quarterly** | Review crypto token health | None | PKI Admin |
| **Quarterly** | Test DR restore | N/A (DR environment) | PKI Admin |
| **Annually** | Rotate HSM access | Planned window | PKI Admin + Security |
| **Annually** | Pen test PKI infrastructure | None | Security |

---

### Related Documentation

- [EJBCA Documentation](https://doc.primekey.com/ejbca)
- [EJBCA GitHub](https://github.com/Keyfactor/ejbca-ce)
- [01 - Executive Design Document](./01-Executive-Design-Document.md) § 3.3.1 (CA Layer)
- [02 - RBAC Authorization Framework](./02-RBAC-Authorization-Framework.md)

---

[Continue to next integration...](#2-ejbca-vault-pki-engine)

---

## 2. EJBCA Vault PKI Engine

**Repository**: [https://github.com/Keyfactor/ejbca-vault-pki-engine](https://github.com/Keyfactor/ejbca-vault-pki-engine)  
**Language**: Go  
**Stars**: 13

### Overview

HashiCorp Vault plugin that uses EJBCA as the PKI backend. Allows Vault to issue certificates from EJBCA while Vault manages secrets lifecycle.

### Implementation Phase

**Phase 4**: Automation & Integration (Weeks 14-16)

### Use Cases

- Use Vault as secrets management layer with EJBCA as CA
- Short-lived certificates for microservices (Vault dynamic secrets)
- Integrate with Kubernetes via Vault Agent or CSI driver
- Leverage Vault's lease management for cert rotation

---

### Implementation Guide

#### Prerequisites

- **EJBCA**: 7.4+ running and accessible
- **HashiCorp Vault**: 1.12+ (self-hosted or HCP Vault)
- **Go**: 1.19+ (for building plugin)
- **EJBCA REST API**: Enabled with client cert authentication

#### Installation Steps

**1. Build Plugin**:

```bash
# Clone repository
git clone https://github.com/Keyfactor/ejbca-vault-pki-engine.git
cd ejbca-vault-pki-engine

# Build plugin
make build

# Copy plugin to Vault plugins directory
cp bin/vault-plugin-secrets-ejbca-pki /etc/vault/plugins/

# Calculate SHA256 for plugin registration
sha256sum /etc/vault/plugins/vault-plugin-secrets-ejbca-pki
```

**2. Register Plugin with Vault**:

```bash
# Set plugin directory in Vault config
# /etc/vault/config.hcl
plugin_directory = "/etc/vault/plugins"

# Restart Vault
systemctl restart vault

# Register plugin
vault plugin register -sha256=<sha256_from_above> \
  secret \
  vault-plugin-secrets-ejbca-pki

# Enable plugin at path "pki"
vault secrets enable -path=pki vault-plugin-secrets-ejbca-pki
```

**3. Configure EJBCA Connection**:

```bash
# Store EJBCA API client certificate in Vault
vault kv put secret/ejbca-api \
  cert=@/path/to/ejbca-api.crt \
  key=@/path/to/ejbca-api.key

# Configure EJBCA connection
vault write pki/config/ejbca \
  hostname="https://ejbca.contoso.com:8443" \
  ca_name="Contoso Issuing CA" \
  certificate_profile_name="TLS-Server-Internal" \
  end_entity_profile_name="Keyfactor-TLS-Server" \
  client_cert=@/path/to/ejbca-api.crt \
  client_key=@/path/to/ejbca-api.key \
  ca_cert=@/path/to/ejbca-ca.crt

# Test connection
vault read pki/config/ejbca
```

**4. Create Vault PKI Roles**:

```bash
# Create role for internal TLS servers
vault write pki/roles/tls-server-internal \
  allowed_domains="contoso.com,internal.contoso.com" \
  allow_subdomains=true \
  max_ttl="730h" \
  key_type="any" \
  key_bits=3072 \
  require_cn=true

# Create role for short-lived microservice certs
vault write pki/roles/microservice \
  allowed_domains="svc.cluster.local" \
  allow_subdomains=true \
  max_ttl="24h" \
  key_type="ec" \
  key_bits=256

# Create role for mTLS clients
vault write pki/roles/mtls-client \
  allowed_domains="contoso.com" \
  allow_subdomains=true \
  max_ttl="8760h" \
  key_type="rsa" \
  key_bits=3072 \
  client_flag=true \
  server_flag=false
```

---

### Operations Guide

#### Certificate Issuance

**Request Certificate via Vault API**:

```bash
# Issue certificate
vault write pki/issue/tls-server-internal \
  common_name="webapp01.contoso.com" \
  alt_names="webapp01-api.contoso.com" \
  ttl="730h"

# Response includes:
# - certificate (PEM)
# - private_key (PEM)
# - ca_chain
# - serial_number
# - expiration

# Save to files
vault write -format=json pki/issue/tls-server-internal \
  common_name="webapp01.contoso.com" | \
  jq -r '.data.certificate' > webapp01.crt

vault write -format=json pki/issue/tls-server-internal \
  common_name="webapp01.contoso.com" | \
  jq -r '.data.private_key' > webapp01.key
```

**Application Integration** (Python example):

```python
import hvac
import os

# Initialize Vault client
client = hvac.Client(
    url='https://vault.contoso.com',
    token=os.environ['VAULT_TOKEN']
)

# Request certificate
response = client.write(
    'pki/issue/tls-server-internal',
    common_name='myapp.contoso.com',
    ttl='8760h'
)

# Extract certificate and key
certificate = response['data']['certificate']
private_key = response['data']['private_key']
ca_chain = response['data']['ca_chain']

# Write to files
with open('/etc/ssl/certs/myapp.crt', 'w') as f:
    f.write(certificate)
    
with open('/etc/ssl/private/myapp.key', 'w') as f:
    f.write(private_key)
    os.chmod('/etc/ssl/private/myapp.key', 0o600)

# Reload application
os.system('systemctl reload myapp')
```

#### Kubernetes Integration

**Using Vault Agent Sidecar**:

```yaml
# application-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        vault.hashicorp.com/agent-inject-secret-tls.crt: "pki/issue/tls-server-internal"
        vault.hashicorp.com/agent-inject-template-tls.crt: |
          {{- with secret "pki/issue/tls-server-internal" "common_name=myapp.svc.cluster.local" "ttl=24h" -}}
          {{ .Data.certificate }}
          {{- end }}
        vault.hashicorp.com/agent-inject-secret-tls.key: "pki/issue/tls-server-internal"
        vault.hashicorp.com/agent-inject-template-tls.key: |
          {{- with secret "pki/issue/tls-server-internal" "common_name=myapp.svc.cluster.local" "ttl=24h" -}}
          {{ .Data.private_key }}
          {{- end }}
    spec:
      serviceAccountName: myapp
      containers:
      - name: myapp
        image: myapp:latest
        volumeMounts:
        - name: vault-secrets
          mountPath: /vault/secrets
          readOnly: true
        env:
        - name: TLS_CERT_PATH
          value: /vault/secrets/tls.crt
        - name: TLS_KEY_PATH
          value: /vault/secrets/tls.key
      volumes:
      - name: vault-secrets
        emptyDir:
          medium: Memory
```

**Using Vault CSI Driver**:

```yaml
# secretproviderclass.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-pki-myapp
spec:
  provider: vault
  parameters:
    vaultAddress: "https://vault.contoso.com"
    roleName: "myapp"
    objects: |
      - objectName: "tls-cert"
        secretPath: "pki/issue/tls-server-internal"
        secretKey: "certificate"
        secretArgs:
          common_name: "myapp.svc.cluster.local"
          ttl: "24h"
      - objectName: "tls-key"
        secretPath: "pki/issue/tls-server-internal"
        secretKey: "private_key"
        secretArgs:
          common_name: "myapp.svc.cluster.local"
          ttl: "24h"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      serviceAccountName: myapp
      containers:
      - name: myapp
        image: myapp:latest
        volumeMounts:
        - name: vault-pki
          mountPath: "/mnt/secrets-store"
          readOnly: true
        env:
        - name: TLS_CERT_PATH
          value: /mnt/secrets-store/tls-cert
        - name: TLS_KEY_PATH
          value: /mnt/secrets-store/tls-key
      volumes:
      - name: vault-pki
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "vault-pki-myapp"
```

#### Automatic Renewal

**Vault Lease Management**:

```bash
# When cert is issued, Vault creates a lease
# Check lease
vault lease lookup pki/issue/tls-server-internal/<lease_id>

# Renew lease (refreshes certificate)
vault lease renew pki/issue/tls-server-internal/<lease_id>

# Revoke lease (revokes certificate in EJBCA)
vault lease revoke pki/issue/tls-server-internal/<lease_id>
```

**Automated Renewal Script**:

```python
# auto-renew.py
import hvac
import time
import os

client = hvac.Client(url='https://vault.contoso.com', token=os.environ['VAULT_TOKEN'])

def renew_certificate():
    # Issue new certificate
    response = client.write(
        'pki/issue/tls-server-internal',
        common_name='myapp.contoso.com',
        ttl='730h'
    )
    
    # Update files
    with open('/etc/ssl/certs/myapp.crt', 'w') as f:
        f.write(response['data']['certificate'])
    with open('/etc/ssl/private/myapp.key', 'w') as f:
        f.write(response['data']['private_key'])
        os.chmod('/etc/ssl/private/myapp.key', 0o600)
    
    # Reload application
    os.system('systemctl reload myapp')
    
    return response['data']['expiration']

# Renew 30 days before expiry
while True:
    expiration = renew_certificate()
    # Sleep until 30 days before expiry
    time_until_renewal = expiration - time.time() - (30 * 24 * 3600)
    time.sleep(max(time_until_renewal, 3600))  # Min 1 hour
```

---

### Troubleshooting

#### Issue: Plugin fails to load

**Symptoms**:
```
Error enabling plugin: plugin not found in catalog
```

**Resolution**:
```bash
# 1. Verify plugin file exists
ls -l /etc/vault/plugins/vault-plugin-secrets-ejbca-pki

# 2. Check SHA256 matches
sha256sum /etc/vault/plugins/vault-plugin-secrets-ejbca-pki

# 3. Re-register with correct SHA256
vault plugin register -sha256=<correct_sha256> secret vault-plugin-secrets-ejbca-pki

# 4. Reload plugin
vault plugin reload -plugin vault-plugin-secrets-ejbca-pki
```

---

#### Issue: EJBCA connection fails

**Symptoms**:
```
Error writing data to pki/config/ejbca: failed to connect to EJBCA: x509: certificate signed by unknown authority
```

**Resolution**:
```bash
# 1. Verify EJBCA is accessible
curl -k https://ejbca.contoso.com:8443/ejbca/ejbca-rest-api/v1/ca

# 2. Check client certificate
openssl x509 -in /path/to/ejbca-api.crt -text -noout

# 3. Verify CA certificate
openssl s_client -connect ejbca.contoso.com:8443 -showcerts

# 4. Add EJBCA CA to Vault's trust store
# Update vault config
vault write pki/config/ejbca \
  ... \
  ca_cert=@/path/to/ejbca-root-ca.crt

# OR add to system trust store
sudo cp ejbca-root-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
systemctl restart vault
```

---

#### Issue: Certificate issuance slow

**Symptoms**:
- `vault write pki/issue/...` takes >10 seconds
- EJBCA shows high CPU usage

**Diagnosis**:
```bash
# Check EJBCA performance
# (see EJBCA troubleshooting section)

# Check Vault plugin logs
journalctl -u vault -f | grep pki

# Check network latency
ping ejbca.contoso.com
curl -o /dev/null -s -w '%{time_total}\n' https://ejbca.contoso.com:8443/ejbca/publicweb/healthcheck/ejbcahealth
```

**Resolution**:
```bash
# 1. Tune EJBCA (see EJBCA performance tuning)

# 2. Increase Vault plugin timeout
vault write pki/config/ejbca \
  ... \
  timeout=30s

# 3. Use connection pooling (if multiple Vault instances)
# Configure load balancer in front of EJBCA

# 4. Cache CA certificates in Vault
# Plugin automatically caches, but verify
vault read pki/ca
```

---

### Related Documentation

- [HashiCorp Vault PKI Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/pki)
- [EJBCA REST API](https://doc.primekey.com/ejbca/ejbca-operations/ejbca-ca-concept-guide/protocols/ejbca-rest-interface)
- [01 - Executive Design Document](./01-Executive-Design-Document.md) § 3.3.3 (Secrets Layer)

---

[Continue to remaining integrations...]

---

---

## 3. EJBCA cert-manager Issuer

**Repository**: [https://github.com/Keyfactor/ejbca-cert-manager-issuer](https://github.com/Keyfactor/ejbca-cert-manager-issuer)  
**Language**: Go  
**Stars**: 45 ⭐

### Overview

A Kubernetes cert-manager external issuer for EJBCA. Enables automated certificate issuance for Kubernetes workloads using EJBCA as the CA.

### Implementation Phase

**Phase 3**: Enrollment Rails & Self-Service (Weeks 10-12)

### Use Cases

- Automated TLS for Kubernetes ingress
- Service mesh certificate automation (Istio, Linkerd)
- Application sidecar certificates
- Kubernetes Secret management for TLS

---

### Implementation Guide

#### Prerequisites

- **Kubernetes**: 1.21+
- **cert-manager**: v1.8+ installed
- **EJBCA**: Running instance with REST API enabled
- **Helm**: 3.0+ (for deployment)
- **EJBCA API credentials**: REST API user with enrollment permissions

#### Installation Steps

**Step 1: Install cert-manager (if not already installed)**

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

**Step 2: Install EJBCA Issuer**

```bash
# Clone repository
git clone https://github.com/Keyfactor/ejbca-cert-manager-issuer.git
cd ejbca-cert-manager-issuer

# Install CRDs
kubectl apply -f config/crd/bases/

# Deploy issuer
helm install ejbca-issuer ./charts/ejbca-issuer \
  --namespace ejbca-issuer-system \
  --create-namespace \
  --set image.tag=latest
```

**Step 3: Create EJBCA Secret**

```bash
# Create secret with EJBCA credentials
kubectl create secret generic ejbca-secret \
  --namespace default \
  --from-literal=client-cert='<BASE64_CLIENT_CERT>' \
  --from-literal=client-key='<BASE64_CLIENT_KEY>'
```

**Step 4: Configure Issuer**

```yaml
# ejbca-issuer.yaml
apiVersion: ejbca-issuer.keyfactor.com/v1alpha1
kind: EJBCAIssuer
metadata:
  name: ejbca-issuer-prod
  namespace: default
spec:
  ejbcaSecretName: ejbca-secret
  hostname: https://ejbca.contoso.com
  certificateAuthorityName: "ManagementCA"
  certificateProfileName: "tlsServerProfile"
  endEntityProfileName: "tlsServerEndEntityProfile"
```

```bash
kubectl apply -f ejbca-issuer.yaml
```

**Step 5: Issue Test Certificate**

```yaml
# test-certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-tls-cert
  namespace: default
spec:
  secretName: test-tls-secret
  issuerRef:
    name: ejbca-issuer-prod
    kind: EJBCAIssuer
    group: ejbca-issuer.keyfactor.com
  commonName: test.contoso.com
  dnsNames:
    - test.contoso.com
    - www.test.contoso.com
  duration: 2160h  # 90 days
  renewBefore: 360h  # Renew 15 days before expiry
```

```bash
# Apply certificate request
kubectl apply -f test-certificate.yaml

# Check certificate status
kubectl get certificate test-tls-cert
kubectl describe certificate test-tls-cert

# Verify secret was created
kubectl get secret test-tls-secret -o yaml
```

---

### Operations Guide

#### Daily Operations

**Monitor Certificate Renewals**

```bash
# List all certificates
kubectl get certificates --all-namespaces

# Check renewal status
kubectl get certificaterequests --all-namespaces

# View recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i certificate
```

**Health Checks**

```bash
# Check issuer status
kubectl get ejbcaissuer -o wide

# Check issuer pod logs
kubectl logs -n ejbca-issuer-system deployment/ejbca-issuer-controller-manager

# Verify EJBCA connectivity
kubectl exec -n ejbca-issuer-system deployment/ejbca-issuer-controller-manager -- \
  curl -k https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1/ca/ManagementCA
```

#### Certificate Operations

**Force Certificate Renewal**

```bash
# Delete certificate (will auto-renew)
kubectl delete certificate test-tls-cert

# Or use cmctl
cmctl renew test-tls-cert
```

**Revoke Certificate**

```bash
# Delete certificate resource
kubectl delete certificate test-tls-cert

# Manually revoke in EJBCA UI if needed
```

#### Monitoring Metrics

```bash
# View Prometheus metrics (if enabled)
kubectl port-forward -n ejbca-issuer-system svc/ejbca-issuer-metrics 8080:8080

# Check metrics
curl http://localhost:8080/metrics | grep ejbca
```

**Key Metrics**:
- `certmanager_issuer_sign_duration_seconds` - Certificate signing duration
- `certmanager_issuer_sign_total` - Total signed certificates
- `certmanager_issuer_sign_errors_total` - Signing errors

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 2 business days |
| Keyfactor Community | General questions | Best effort |
| Keyfactor Support | Enterprise customers only | Per contract |

#### When to Escalate

- Certificate issuance failures (>5% failure rate)
- EJBCA connectivity issues
- Memory leaks or crashes
- Security vulnerabilities

#### Logs to Collect

```bash
# Controller logs
kubectl logs -n ejbca-issuer-system deployment/ejbca-issuer-controller-manager --tail=500

# Certificate events
kubectl describe certificate <cert-name>

# CertificateRequest details
kubectl get certificaterequest -o yaml

# Issuer status
kubectl get ejbcaissuer -o yaml
```

---

### Troubleshooting Guide

#### Issue 1: Certificate Request Stuck in "Pending"

**Symptoms**:
```bash
$ kubectl get certificate test-tls-cert
NAME            READY   SECRET            AGE
test-tls-cert   False   test-tls-secret   5m
```

**Diagnosis**:
```bash
# Check certificate status
kubectl describe certificate test-tls-cert

# Check CertificateRequest
kubectl get certificaterequest
kubectl describe certificaterequest <request-name>

# Check issuer logs
kubectl logs -n ejbca-issuer-system deployment/ejbca-issuer-controller-manager | tail -50
```

**Resolution**:

1. **EJBCA Connectivity Issue**:
   ```bash
   # Test connectivity from pod
   kubectl exec -n ejbca-issuer-system deployment/ejbca-issuer-controller-manager -- \
     curl -k https://ejbca.contoso.com/ejbca
   ```
   - Fix: Verify network policies, firewall rules

2. **Invalid Credentials**:
   ```bash
   # Recreate secret with correct credentials
   kubectl delete secret ejbca-secret
   kubectl create secret generic ejbca-secret \
     --from-literal=client-cert='<CORRECT_CERT>' \
     --from-literal=client-key='<CORRECT_KEY>'
   
   # Restart controller
   kubectl rollout restart -n ejbca-issuer-system deployment/ejbca-issuer-controller-manager
   ```

3. **Invalid Profile Configuration**:
   ```yaml
   # Verify profiles exist in EJBCA
   # Update issuer with correct profile names
   kubectl edit ejbcaissuer ejbca-issuer-prod
   ```

---

#### Issue 2: "Failed to Sign Certificate" Error

**Symptoms**:
```
Events:
  Type     Reason       Message
  ----     ------       -------
  Warning  IssuerFailed Failed to sign certificate: REST API error 400
```

**Diagnosis**:
```bash
# Get detailed error
kubectl describe certificaterequest <request-name>

# Check EJBCA logs
# SSH to EJBCA server
tail -f /opt/ejbca/standalone/log/server.log
```

**Common Causes & Resolutions**:

1. **Invalid Subject DN**:
   - EJBCA requires specific DN ordering
   - Fix: Update certificate spec with correct DN format

2. **Profile Restrictions**:
   - End Entity Profile doesn't allow requested SANs
   - Fix: Update EJBCA profile or adjust certificate request

3. **CA Not Available**:
   - CA is offline or key not accessible
   - Fix: Check CA status in EJBCA UI

---

#### Issue 3: High Memory Usage / Pod Crashes

**Symptoms**:
```bash
$ kubectl get pods -n ejbca-issuer-system
NAME                                          READY   STATUS             RESTARTS
ejbca-issuer-controller-manager-xxx           0/1     CrashLoopBackOff   10
```

**Diagnosis**:
```bash
# Check resource usage
kubectl top pod -n ejbca-issuer-system

# View crash logs
kubectl logs -n ejbca-issuer-system deployment/ejbca-issuer-controller-manager --previous

# Check events
kubectl get events -n ejbca-issuer-system --sort-by='.lastTimestamp'
```

**Resolution**:

1. **Increase Resource Limits**:
   ```yaml
   # Update deployment
   kubectl edit deployment -n ejbca-issuer-system ejbca-issuer-controller-manager
   
   # Increase limits
   resources:
     limits:
       memory: "512Mi"
       cpu: "500m"
     requests:
       memory: "256Mi"
       cpu: "200m"
   ```

2. **Memory Leak**:
   - Upgrade to latest version
   - Report issue with memory profile

---

### Performance Tuning

#### Concurrency Settings

```yaml
# Increase worker threads for high-volume environments
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ejbca-issuer-controller-manager
  namespace: ejbca-issuer-system
spec:
  template:
    spec:
      containers:
      - name: manager
        args:
        - --max-concurrent-reconciles=10  # Default is 1
        - --leader-elect
```

#### Connection Pooling

```yaml
# Increase HTTP client pool size
env:
- name: EJBCA_MAX_IDLE_CONNS
  value: "20"
- name: EJBCA_MAX_CONNS_PER_HOST
  value: "10"
- name: EJBCA_TIMEOUT_SECONDS
  value: "30"
```

---

### Security Hardening

#### Use Kubernetes ServiceAccount for Authentication

```yaml
# Instead of client certs in secret, use K8s OIDC
apiVersion: ejbca-issuer.keyfactor.com/v1alpha1
kind: EJBCAIssuer
metadata:
  name: ejbca-issuer-prod
spec:
  hostname: https://ejbca.contoso.com
  authType: kubernetes
  serviceAccountRef:
    name: ejbca-issuer-sa
```

#### Network Policies

```yaml
# Restrict egress to EJBCA only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ejbca-issuer-netpol
  namespace: ejbca-issuer-system
spec:
  podSelector:
    matchLabels:
      app: ejbca-issuer
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: ejbca
    ports:
    - protocol: TCP
      port: 443
```

---

### Related Documentation

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [EJBCA REST API Documentation](#1-ejbca-community-edition)
- [07-Enrollment-Rails-Guide.md](./07-Enrollment-Rails-Guide.md) - cert-manager configuration
- [04-Architecture-Diagrams.md](./04-Architecture-Diagrams.md) - Kubernetes integration

---

## 4. Command cert-manager Issuer

**Repository**: [https://github.com/Keyfactor/command-cert-manager-issuer](https://github.com/Keyfactor/command-cert-manager-issuer)  
**Language**: Go  
**Stars**: 12 ⭐

### Overview

A Kubernetes cert-manager external issuer for Keyfactor Command. Enables automated certificate issuance for Kubernetes workloads using Keyfactor Command as the orchestration layer.

### Implementation Phase

**Phase 3**: Enrollment Rails & Self-Service (Weeks 10-12)

### Use Cases

- Kubernetes TLS automation with Keyfactor Command governance
- Multi-cluster certificate management
- Certificate lifecycle policies enforced at K8s level
- Integration with existing Keyfactor Command deployment

---

### Implementation Guide

#### Prerequisites

- **Kubernetes**: 1.21+
- **cert-manager**: v1.8+ installed
- **Keyfactor Command**: 10.x+ with API access
- **Helm**: 3.0+
- **Command API credentials**: API user with certificate enrollment permissions

#### Installation Steps

**Step 1: Create Command API Secret**

```bash
# Create secret with Command credentials
kubectl create secret generic command-secret \
  --namespace default \
  --from-literal=hostname='https://keyfactor.contoso.com' \
  --from-literal=username='k8s-issuer-api' \
  --from-literal=password='SecurePassword123!' \
  --from-literal=ca-bundle='<BASE64_CA_CERT>'
```

**Step 2: Install Command Issuer**

```bash
# Clone repository
git clone https://github.com/Keyfactor/command-cert-manager-issuer.git
cd command-cert-manager-issuer

# Install CRDs
kubectl apply -f config/crd/bases/

# Deploy issuer
helm install command-issuer ./charts/command-issuer \
  --namespace command-issuer-system \
  --create-namespace \
  --set image.tag=v1.0.0
```

**Step 3: Configure Issuer**

```yaml
# command-issuer.yaml
apiVersion: command-issuer.keyfactor.com/v1alpha1
kind: CommandIssuer
metadata:
  name: command-issuer-prod
  namespace: default
spec:
  commandSecretName: command-secret
  certificateTemplate: "KubernetesServerAuth"
  certificateAuthority: "Contoso-IssuingCA-01"
  metadata:
    - key: "kubernetes-cluster"
      value: "prod-cluster-01"
    - key: "owner-team"
      value: "platform-engineering"
```

```bash
kubectl apply -f command-issuer.yaml
```

**Step 4: Create Certificate Template in Command**

Navigate to Keyfactor Command UI:

1. **Templates** → **Certificate Templates** → **Add**
2. Configure template:
   - Name: `KubernetesServerAuth`
   - Key Algorithm: RSA 2048
   - Key Usage: Digital Signature, Key Encipherment
   - Extended Key Usage: Server Authentication, Client Authentication
   - Subject DN: `CN={{CommonName}}`
   - SAN: DNS allowed
   - Validity: 90 days
3. **Save**

**Step 5: Issue Test Certificate**

```yaml
# test-cert-command.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-command-cert
  namespace: default
  annotations:
    command.keyfactor.com/owner-email: "platform-team@contoso.com"
    command.keyfactor.com/cost-center: "CC-12345"
spec:
  secretName: test-command-secret
  issuerRef:
    name: command-issuer-prod
    kind: CommandIssuer
    group: command-issuer.keyfactor.com
  commonName: test-app.contoso.com
  dnsNames:
    - test-app.contoso.com
    - test-app.internal.contoso.com
  duration: 2160h  # 90 days
  renewBefore: 720h  # Renew 30 days before expiry
```

```bash
kubectl apply -f test-cert-command.yaml

# Verify certificate
kubectl get certificate test-command-cert
kubectl describe certificate test-command-cert

# Check certificate in Keyfactor Command UI
# Navigate to Certificates → Search for "test-app.contoso.com"
```

---

### Operations Guide

#### Daily Operations

**Monitor Certificates in Command**

```bash
# List all K8s-issued certificates
curl -X GET "https://keyfactor.contoso.com/KeyfactorAPI/Certificates/Query" \
  -H "Authorization: Bearer $COMMAND_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "queryString": "Metadata:kubernetes-cluster:prod-cluster-01"
  }'
```

**Sync Certificate Inventory**

```bash
# Force sync from K8s to Command
kubectl annotate certificate test-command-cert \
  command.keyfactor.com/sync="force" --overwrite

# View sync status
kubectl get commandissuer command-issuer-prod -o yaml | grep -A5 status
```

**Health Checks**

```bash
# Check issuer connectivity to Command
kubectl logs -n command-issuer-system deployment/command-issuer-controller-manager | grep -i "connection"

# Test API connectivity
kubectl exec -n command-issuer-system deployment/command-issuer-controller-manager -- \
  curl -k https://keyfactor.contoso.com/KeyfactorAPI/certificates/available-templates
```

#### Certificate Operations

**Revoke Certificate**

```bash
# Annotate certificate for revocation
kubectl annotate certificate test-command-cert \
  command.keyfactor.com/revocation-reason="keyCompromise"

# Delete certificate (will be revoked in Command)
kubectl delete certificate test-command-cert

# Verify revocation in Command UI
```

**Apply Policy Changes**

```bash
# Update issuer with new template
kubectl edit commandissuer command-issuer-prod

# Existing certificates are NOT affected
# New certificates will use updated template
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 2 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| Keyfactor Community | General questions | Best effort |

#### When to Escalate

- Certificate issuance failures (>5%)
- Command API connectivity issues
- Certificate not appearing in Command inventory
- Renewal failures

#### Logs to Collect

```bash
# Controller logs
kubectl logs -n command-issuer-system deployment/command-issuer-controller-manager --tail=1000 > command-issuer.log

# Certificate status
kubectl get certificate -o yaml > certificates.yaml

# Issuer configuration
kubectl get commandissuer -o yaml > command-issuer-config.yaml

# Recent events
kubectl get events --sort-by='.lastTimestamp' --all-namespaces | grep -i certificate > events.log
```

---

### Troubleshooting Guide

#### Issue 1: "Unauthorized" or "403 Forbidden" from Command API

**Symptoms**:
```
Failed to sign certificate: HTTP 403: Forbidden
```

**Diagnosis**:
```bash
# Test API credentials manually
curl -X GET "https://keyfactor.contoso.com/KeyfactorAPI/Certificates" \
  -u "k8s-issuer-api:SecurePassword123!" \
  -H "Content-Type: application/json"
```

**Resolution**:

1. **Verify API User Permissions** in Command UI:
   - Navigate to **Security** → **API Users**
   - Ensure user has **Certificate Enrollment** permission
   - Verify user is in **Certificate Requesters** role

2. **Update Secret with Correct Credentials**:
   ```bash
   kubectl delete secret command-secret -n default
   kubectl create secret generic command-secret \
     --namespace default \
     --from-literal=hostname='https://keyfactor.contoso.com' \
     --from-literal=username='k8s-issuer-api' \
     --from-literal=password='CorrectPassword!'
   
   # Restart controller
   kubectl rollout restart -n command-issuer-system deployment/command-issuer-controller-manager
   ```

---

#### Issue 2: Certificate Issued but Not in Command Inventory

**Symptoms**:
- Certificate exists in Kubernetes secret
- Certificate not visible in Command UI

**Diagnosis**:
```bash
# Check certificate metadata
kubectl get certificate test-command-cert -o yaml | grep -A10 status

# Check Command API directly
curl -X GET "https://keyfactor.contoso.com/KeyfactorAPI/Certificates/Query" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{"queryString": "test-app.contoso.com"}'
```

**Resolution**:

1. **Check Command Inventory Schedule**:
   - Command may take up to 15 minutes to index new certificates
   - Wait and refresh

2. **Force Inventory Sync**:
   ```bash
   # Re-annotate certificate
   kubectl annotate certificate test-command-cert \
     command.keyfactor.com/sync="force" --overwrite
   ```

3. **Verify Certificate Metadata**:
   - Ensure certificate has required metadata fields
   - Check Command logs for import errors

---

#### Issue 3: Template Not Found

**Symptoms**:
```
Failed to sign certificate: Template 'KubernetesServerAuth' not found
```

**Diagnosis**:
```bash
# List available templates
curl -X GET "https://keyfactor.contoso.com/KeyfactorAPI/CertificateAuthority/Templates" \
  -H "Authorization: Bearer $API_TOKEN"
```

**Resolution**:

1. **Create Missing Template** in Command UI (see Step 4 in Installation)

2. **Update Issuer with Correct Template Name**:
   ```bash
   kubectl edit commandissuer command-issuer-prod
   
   # Update spec.certificateTemplate to match existing template
   ```

---

### Performance Tuning

#### API Rate Limiting

```yaml
# Configure rate limiting to avoid Command API throttling
apiVersion: apps/v1
kind: Deployment
metadata:
  name: command-issuer-controller-manager
  namespace: command-issuer-system
spec:
  template:
    spec:
      containers:
      - name: manager
        env:
        - name: COMMAND_API_RATE_LIMIT
          value: "10"  # Requests per second
        - name: COMMAND_API_BURST
          value: "20"  # Burst size
```

#### Connection Pool

```yaml
env:
- name: COMMAND_MAX_IDLE_CONNS
  value: "50"
- name: COMMAND_MAX_CONNS_PER_HOST
  value: "25"
- name: COMMAND_TIMEOUT_SECONDS
  value: "60"
```

---

### Security Hardening

#### Use Keyfactor Command OAuth

```yaml
# Use OAuth instead of basic auth
apiVersion: command-issuer.keyfactor.com/v1alpha1
kind: CommandIssuer
metadata:
  name: command-issuer-prod
spec:
  authType: oauth
  oauthConfigSecretName: command-oauth-secret
  certificateTemplate: "KubernetesServerAuth"
```

```bash
# Create OAuth secret
kubectl create secret generic command-oauth-secret \
  --from-literal=client-id='k8s-issuer-client' \
  --from-literal=client-secret='OAuthClientSecret123!' \
  --from-literal=token-url='https://keyfactor.contoso.com/oauth/token'
```

#### Enforce Metadata Requirements

```yaml
# Require owner and cost center metadata
apiVersion: command-issuer.keyfactor.com/v1alpha1
kind: CommandIssuer
metadata:
  name: command-issuer-prod
spec:
  requiredMetadata:
    - "owner-email"
    - "cost-center"
  metadata:
    - key: "kubernetes-cluster"
      value: "prod-cluster-01"
```

---

### Related Documentation

- [Keyfactor Command API Documentation](https://software.keyfactor.com/Guides/CommandAPI/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [01-Executive-Design-Document.md](./01-Executive-Design-Document.md) - Overall architecture
- [07-Enrollment-Rails-Guide.md](./07-Enrollment-Rails-Guide.md) - cert-manager configuration

---

## 5. Azure Key Vault Orchestrator

**Repository**: [https://github.com/Keyfactor/azurekeyvault-orchestrator](https://github.com/Keyfactor/azurekeyvault-orchestrator)  
**Language**: C#  
**Stars**: 18 ⭐

### Overview

Universal Orchestrator extension for Azure Key Vault. Automates discovery, inventory, and deployment of certificates to Azure Key Vaults.

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Automatic renewal and deployment of certificates to Azure Key Vault
- Discovery of existing certificates across multiple Key Vaults
- Compliance inventory for Azure-hosted applications
- Integration with Azure App Services, Function Apps, API Management

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator installed
- **Azure**:
  - Azure Key Vault(s) created
  - Service Principal with Key Vault access
  - Permissions: Get, List, Import, Delete for certificates
- **.NET Framework**: 4.7.2+ (on orchestrator host)

#### Installation Steps

**Step 1: Register Service Principal in Azure**

```bash
# Create service principal
az ad sp create-for-rbac --name "Keyfactor-Orchestrator-SP" \
  --role "Key Vault Certificates Officer" \
  --scopes /subscriptions/{subscription-id}

# Output will include:
# - appId (Client ID)
# - password (Client Secret)
# - tenant (Tenant ID)
```

**Step 2: Grant Key Vault Permissions**

```bash
# For each Key Vault
az keyvault set-policy \
  --name MyKeyVault \
  --spn <CLIENT_ID> \
  --certificate-permissions get list import delete
```

**Step 3: Install Orchestrator Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/azurekeyvault-orchestrator/releases/latest/download/AzureKeyVault.zip" `
  -OutFile "C:\Temp\AzureKeyVault.zip"

# Extract to orchestrator extensions folder
Expand-Archive -Path "C:\Temp\AzureKeyVault.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\AzureKeyVault"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 4: Configure Store Type in Keyfactor Command**

Navigate to Keyfactor Command UI:

1. **Certificate Locations** → **Certificate Store Types** → **Add**
2. Configure store type:
   - Name: `Azure Key Vault`
   - Short Name: `AKV`
   - Supports Management Add: Yes
   - Supports Discovery: Yes
   - Supports Inventory: Yes
   - Supports Reenrollment: No
   - Use PowerShell: No
3. **Custom Fields**:
   - `AzureCloud`: Azure environment (AzureCloud, AzureUSGovernment, etc.)
   - `VaultName`: Name of the Key Vault
   - `SubscriptionId`: Azure subscription ID
   - `TenantId`: Azure AD tenant ID
   - `ApplicationId`: Service Principal client ID
   - `ClientSecret`: Service Principal secret (password)
4. **Save**

**Step 5: Add Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → **Add**
2. Configure store:
   - Category: `Azure Key Vault`
   - Client Machine: Name/description (e.g., "Production Key Vault")
   - Store Path: `vault-name` (just the vault name, not full URL)
   - Properties:
     - AzureCloud: `AzureCloud`
     - VaultName: `mykeyvault-prod`
     - SubscriptionId: `12345678-1234-1234-1234-123456789012`
     - TenantId: `87654321-4321-4321-4321-210987654321`
     - ApplicationId: `<CLIENT_ID>`
     - ClientSecret: `<CLIENT_SECRET>`
   - Agent: Select orchestrator agent
3. **Save**

**Step 6: Test Inventory**

```bash
# In Keyfactor Command UI:
# Certificate Locations → Certificate Stores → Select store → Inventory

# Should list all certificates in the Key Vault
```

---

### Operations Guide

#### Daily Operations

**Monitor Orchestrator Jobs**

In Keyfactor Command:
1. **Dashboard** → **Orchestrator Jobs**
2. Filter by Store Type: `Azure Key Vault`
3. Review job status:
   - ✅ **Success**: No action needed
   - ⚠️ **Warning**: Review warnings, may need attention
   - ❌ **Error**: Investigate immediately

**Schedule Auto-Inventory**

```sql
-- In Keyfactor Command database
-- Set inventory schedule to daily at 2 AM
UPDATE CertStores
SET InventorySchedule = '0 2 * * *'  -- Cron expression
WHERE CertStoreType = 'AKV'
```

Or via UI:
1. **Certificate Stores** → Select store → **Edit**
2. **Inventory Schedule**: Daily at 2:00 AM
3. **Save**

#### Certificate Operations

**Deploy Certificate to Azure Key Vault**

```bash
# In Keyfactor Command UI:
# Certificates → Select certificate → Management → Add to Store
# Select Azure Key Vault store
# Alias: certificate-name (will be the Key Vault secret/certificate name)
# Click Add
```

**Bulk Deployment**

```powershell
# Using Keyfactor API
$apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$apiToken = "Bearer $env:KEYFACTOR_API_TOKEN"

$certs = @("webapp01-cert", "api01-cert", "function01-cert")
$targetStore = "mykeyvault-prod"

foreach ($certAlias in $certs) {
    $body = @{
        CertificateId = (Get-KeyfactorCertificate -Alias $certAlias).Id
        StoreIds = @($targetStore)
        Alias = $certAlias
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "$apiUrl/Certificates/Management/Add" `
        -Method Post `
        -Headers @{Authorization = $apiToken} `
        -Body $body `
        -ContentType "application/json"
}
```

**Remove Certificate from Key Vault**

```bash
# In Key factor Command UI:
# Certificates → Select certificate → Management → Remove from Store
# Select Azure Key Vault store
# Click Remove
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 3 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| Keyfactor Community | General questions | Best effort |

#### When to Escalate

- Orchestrator job failures (>10% failure rate)
- Azure authentication failures
- Certificate not deploying to Key Vault
- Inventory sync delays (>24 hours)

#### Logs to Collect

**Orchestrator Logs** (on orchestrator server):
```powershell
# Orchestrator service logs
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\orchestrator.log" -Tail 500

# Extension-specific logs
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\AzureKeyVault.log" -Tail 500
```

**Azure Activity Logs**:
```bash
# Get Key Vault activity logs
az monitor activity-log list \
  --resource-group MyResourceGroup \
  --resource-id /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/mykeyvault \
  --start-time 2025-10-22T00:00:00Z \
  --end-time 2025-10-22T23:59:59Z
```

---

### Troubleshooting Guide

#### Issue 1: "Authentication Failed" Error

**Symptoms**:
```
Orchestrator job failed: Authentication failed for Azure Key Vault
Error: AADSTS700016: Application with identifier '<CLIENT_ID>' was not found in the directory
```

**Diagnosis**:
```bash
# Test service principal authentication
az login --service-principal \
  --username <CLIENT_ID> \
  --password <CLIENT_SECRET> \
  --tenant <TENANT_ID>

# Verify Key Vault access
az keyvault certificate list --vault-name mykeyvault-prod
```

**Resolution**:

1. **Verify Service Principal Exists**:
   ```bash
   az ad sp show --id <CLIENT_ID>
   ```

2. **Reset Service Principal Secret**:
   ```bash
   az ad sp credential reset --id <CLIENT_ID>
   # Update Client Secret in Keyfactor store configuration
   ```

3. **Verify Key Vault Permissions**:
   ```bash
   az keyvault show --name mykeyvault-prod --query properties.accessPolicies
   
   # If missing, add policy
   az keyvault set-policy \
     --name mykeyvault-prod \
     --spn <CLIENT_ID> \
     --certificate-permissions get list import delete
   ```

---

#### Issue 2: Certificate Import Fails

**Symptoms**:
```
Management job failed: Failed to import certificate to Azure Key Vault
Error: Certificate format not supported
```

**Diagnosis**:
```bash
# Check certificate format in Keyfactor
# Certificates → Select certificate → Details → Key Algorithm

# Test manual import to Key Vault
az keyvault certificate import \
  --vault-name mykeyvault-prod \
  --name test-cert \
  --file cert.pfx \
  --password ""
```

**Resolution**:

1. **Ensure Certificate Has Private Key**:
   - Azure Key Vault requires PFX format with private key
   - In Keyfactor, ensure certificate has "Include Private Key" option

2. **Check Certificate Policy in Key Vault**:
   ```bash
   # Some Key Vaults have restrictive policies
   az keyvault certificate show --vault-name mykeyvault-prod --name existing-cert --query policy
   ```

3. **Verify Key Vault SKU**:
   - Standard SKU: Software-protected keys
   - Premium SKU: HSM-protected keys
   - Ensure certificate key type matches vault SKU

---

#### Issue 3: Inventory Not Discovering Certificates

**Symptoms**:
- Inventory job completes successfully
- Certificates in Key Vault not showing in Keyfactor

**Diagnosis**:
```bash
# Check Key Vault actually has certificates
az keyvault certificate list --vault-name mykeyvault-prod

# Check orchestrator logs for inventory details
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\AzureKeyVault.log" | Select-String "Inventory"
```

**Resolution**:

1. **Verify Certificate Permissions**:
   ```bash
   # Service principal needs "List" permission
   az keyvault set-policy \
     --name mykeyvault-prod \
     --spn <CLIENT_ID> \
     --certificate-permissions list get
   ```

2. **Check for Deleted/Soft-Deleted Certificates**:
   ```bash
   # Key Vault soft-delete may hide certificates
   az keyvactor certificate list-deleted --vault-name mykeyvault-prod
   
   # Recover if needed
   az keyvault certificate recover --vault-name mykeyvault-prod --name cert-name
   ```

3. **Force Immediate Inventory**:
   - In Keyfactor UI: Store → Actions → Inventory Now
   - Wait 5-10 minutes for processing

---

### Performance Tuning

#### Optimize Inventory for Many Key Vaults

```json
// In orchestrator config.json
{
  "AzureKeyVault": {
    "InventoryBatchSize": 50,  // Process 50 vaults at a time
    "InventoryParallelism": 5,  // 5 concurrent threads
    "InventoryTimeout": 300     // 5 minute timeout per vault
  }
}
```

#### Connection Pooling

```json
{
  "AzureKeyVault": {
    "MaxConnectionsPerVault": 10,
    "ConnectionTimeout": 30,
    "RetryAttempts": 3,
    "RetryDelaySeconds": 5
  }
}
```

---

### Security Hardening

#### Use Managed Identity Instead of Service Principal

```powershell
# On Azure VM running orchestrator
# Enable system-assigned managed identity

# In Keyfactor store config, leave ApplicationId and ClientSecret blank
# Orchestrator will use VM's managed identity automatically
```

#### Restrict Network Access

```bash
# Configure Key Vault firewall
az keyvault network-rule add \
  --name mykeyvault-prod \
  --ip-address <ORCHESTRATOR_PUBLIC_IP>

# Enable private endpoint (recommended)
az network private-endpoint create \
  --name keyvault-pe \
  --resource-group MyResourceGroup \
  --vnet-name MyVNet \
  --subnet orchestrator-subnet \
  --private-connection-resource-id $(az keyvault show --name mykeyvault-prod --query id -o tsv) \
  --group-id vault \
  --connection-name keyvault-connection
```

#### Enable Key Vault Logging

```bash
# Send Key Vault logs to Log Analytics
az monitor diagnostic-settings create \
  --resource $(az keyvault show --name mykeyvault-prod --query id -o tsv) \
  --name keyvault-diagnostics \
  --workspace <LOG_ANALYTICS_WORKSPACE_ID> \
  --logs '[{"category": "AuditEvent", "enabled": true}]'
```

---

### Related Documentation

- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Keyfactor Universal Orchestrator Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [01-Executive-Design-Document.md](./01-Executive-Design-Document.md) - Secrets management architecture
- [14-Integration-Specifications.md](./14-Integration-Specifications.md) - Azure Key Vault integration details

---

## 6. AWS Certificate Manager Orchestrator

**Repository**: [https://github.com/Keyfactor/aws-orchestrator](https://github.com/Keyfactor/aws-orchestrator)  
**Language**: C#  
**Stars**: 9 ⭐

### Overview

Universal Orchestrator extension for AWS Certificate Manager (ACM). Automates discovery, inventory, and lifecycle management of certificates in AWS ACM.

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Automatic renewal and deployment to AWS ACM
- Discovery of existing certificates across multiple AWS accounts/regions
- Compliance inventory for AWS workloads
- Integration with ELB/ALB, CloudFront, API Gateway

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator installed
- **AWS**:
  - AWS Account(s) with ACM enabled
  - IAM user or role with ACM permissions
  - Permissions: `acm:ListCertificates`, `acm:DescribeCertificate`, `acm:ImportCertificate`, `acm:DeleteCertificate`
- **.NET Framework**: 4.7.2+ (on orchestrator host)

#### Installation Steps

**Step 1: Create IAM User/Role**

```bash
# Create IAM policy
cat > keyfactor-acm-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "acm:ImportCertificate",
        "acm:DeleteCertificate",
        "acm:AddTagsToCertificate",
        "acm:ListTagsForCertificate"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name KeyfactorACMOrchestratorPolicy \
  --policy-document file://keyfactor-acm-policy.json

# Create IAM user
aws iam create-user --user-name keyfactor-orchestrator

# Attach policy
aws iam attach-user-policy \
  --user-name keyfactor-orchestrator \
  --policy-arn arn:aws:iam::123456789012:policy/KeyfactorACMOrchestratorPolicy

# Create access key
aws iam create-access-key --user-name keyfactor-orchestrator
# Save Access Key ID and Secret Access Key
```

**Step 2: Install Orchestrator Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/aws-orchestrator/releases/latest/download/AWS-ACM.zip" `
  -OutFile "C:\Temp\AWS-ACM.zip"

# Extract to orchestrator extensions folder
Expand-Archive -Path "C:\Temp\AWS-ACM.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\AWS-ACM"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 3: Configure Store Type in Keyfactor Command**

Navigate to Keyfactor Command UI:

1. **Certificate Locations** → **Certificate Store Types** → **Add**
2. Configure store type:
   - Name: `AWS Certificate Manager`
   - Short Name: `ACM`
   - Supports Management Add: Yes
   - Supports Discovery: Yes
   - Supports Inventory: Yes
   - Supports Reenrollment: No
3. **Custom Fields**:
   - `Region`: AWS region (us-east-1, us-west-2, etc.)
   - `AccessKeyId`: AWS access key ID
   - `SecretAccessKey`: AWS secret access key
   - `AssumeRoleArn`: (Optional) IAM role ARN to assume
4. **Save**

**Step 4: Add Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → **Add**
2. Configure store:
   - Category: `AWS Certificate Manager`
   - Client Machine: Description (e.g., "Production ACM - us-east-1")
   - Store Path: AWS account ID (e.g., `123456789012`)
   - Properties:
     - Region: `us-east-1`
     - AccessKeyId: `AKIAIOSFODNN7EXAMPLE`
     - SecretAccessKey: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`
     - AssumeRoleArn: (optional) `arn:aws:iam::123456789012:role/KeyfactorRole`
   - Agent: Select orchestrator agent
3. **Save**

**Step 5: Test Inventory**

```bash
# In Keyfactor Command UI:
# Certificate Locations → Certificate Stores → Select store → Inventory

# Should list all certificates in ACM for that region
```

---

### Operations Guide

#### Daily Operations

**Monitor Orchestrator Jobs**

In Keyfactor Command:
1. **Dashboard** → **Orchestrator Jobs**
2. Filter by Store Type: `AWS Certificate Manager`
3. Review job status and error rates

**Multi-Region Inventory**

```powershell
# Add stores for each region
$regions = @("us-east-1", "us-west-2", "eu-west-1", "ap-southeast-1")

foreach ($region in $regions) {
    # Create store in Keyfactor for each region
    # Orchestrator will inventory all regions separately
}
```

**Monitor ACM Certificate Expiration**

```bash
# List certificates expiring in 30 days
aws acm list-certificates \
  --region us-east-1 \
  --certificate-statuses ISSUED \
  --query "CertificateSummaryList[?NotAfter<='$(date -d '+30 days' -u +%Y-%m-%dT%H:%M:%SZ)']"
```

#### Certificate Operations

**Deploy Certificate to ACM**

```bash
# In Keyfactor Command UI:
# Certificates → Select certificate → Management → Add to Store
# Select AWS ACM store (specific region)
# Certificate will be imported to ACM
```

**Bulk Deployment via API**

```powershell
# Deploy multiple certificates to ACM
$apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI"
$apiToken = "Bearer $env:KEYFACTOR_API_TOKEN"

$certs = @(
    @{Alias="webapp01"; Region="us-east-1"},
    @{Alias="api01"; Region="us-west-2"}
)

foreach ($cert in $certs) {
    $storeId = Get-ACMStoreIdByRegion -Region $cert.Region
    
    $body = @{
        CertificateId = (Get-KeyfactorCertificate -Alias $cert.Alias).Id
        StoreIds = @($storeId)
        Alias = $cert.Alias
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "$apiUrl/Certificates/Management/Add" `
        -Method Post `
        -Headers @{Authorization = $apiToken} `
        -Body $body `
        -ContentType "application/json"
}
```

**Attach Certificate to Load Balancer**

```bash
# After deploying to ACM, attach to ALB
aws elbv2 modify-listener \
  --listener-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/my-alb/50dc6c495c0c9188/0467ef3c8400ae65 \
  --certificates CertificateArn=arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 3 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| AWS Support | AWS infrastructure issues | Per AWS plan |

#### When to Escalate

- Certificate import failures (>10%)
- AWS authentication errors
- Certificate not appearing in ACM after deployment
- Regional outages affecting multiple stores

#### Logs to Collect

**Orchestrator Logs**:
```powershell
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\AWS-ACM.log" -Tail 500
```

**AWS CloudTrail Logs**:
```bash
# Get ACM API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::ACM::Certificate \
  --start-time 2025-10-22T00:00:00Z \
  --end-time 2025-10-22T23:59:59Z
```

---

### Troubleshooting Guide

#### Issue 1: "Access Denied" Error

**Symptoms**:
```
Orchestrator job failed: Access denied to ACM
Error: User: arn:aws:iam::123456789012:user/keyfactor-orchestrator is not authorized to perform: acm:ListCertificates
```

**Diagnosis**:
```bash
# Test IAM permissions
aws acm list-certificates \
  --region us-east-1 \
  --profile keyfactor-orchestrator

# Check IAM policy
aws iam list-attached-user-policies --user-name keyfactor-orchestrator
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/KeyfactorACMOrchestratorPolicy \
  --version-id v1
```

**Resolution**:

1. **Verify IAM Policy Includes Required Permissions**:
   ```bash
   # Update policy to include missing permissions
   aws iam put-user-policy \
     --user-name keyfactor-orchestrator \
     --policy-name ACMFullAccess \
     --policy-document file://updated-policy.json
   ```

2. **Check for SCP Restrictions** (if using AWS Organizations):
   ```bash
   aws organizations describe-policy \
     --policy-id p-xxxxxxxx
   ```

---

#### Issue 2: Certificate Import Fails with "Validation Error"

**Symptoms**:
```
Management job failed: Certificate validation failed
Error: The certificate chain is incomplete
```

**Diagnosis**:
```bash
# Test certificate manually
openssl x509 -in cert.pem -noout -text

# Verify certificate chain
openssl verify -CAfile ca-bundle.pem cert.pem
```

**Resolution**:

1. **Include Complete Certificate Chain**:
   - ACM requires certificate, intermediate CA certs, and root CA cert
   - In Keyfactor, ensure "Include Chain" is selected during deployment

2. **Check Certificate Format**:
   ```bash
   # ACM requires PEM format
   # Convert if necessary
   openssl pkcs12 -in cert.pfx -out cert.pem -nodes
   ```

3. **Verify Private Key Match**:
   ```bash
   # Certificate and private key must match
   openssl x509 -in cert.pem -noout -modulus | openssl md5
   openssl rsa -in key.pem -noout -modulus | openssl md5
   # MD5 hashes must match
   ```

---

#### Issue 3: Certificate Not Appearing in ACM After Import

**Symptoms**:
- Orchestrator job completes successfully
- Certificate not visible in ACM console

**Diagnosis**:
```bash
# List all certificates in region
aws acm list-certificates --region us-east-1

# Check certificate by ARN (if known)
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
```

**Resolution**:

1. **Verify Correct Region**:
   - Certificate may have been imported to different region
   - Check orchestrator store configuration for region setting

2. **Check for Import Limits**:
   ```bash
   # ACM has quotas per region
   aws service-quotas get-service-quota \
     --service-code acm \
     --quota-code L-FB94F0B0  # Number of ACM certificates
   ```

3. **Wait for ACM Processing**:
   - ACM may take 1-2 minutes to process and display certificate
   - Refresh console or run `list-certificates` again

---

### Performance Tuning

#### Optimize Multi-Region Inventory

```json
// In orchestrator config.json
{
  "AWS-ACM": {
    "InventoryBatchSize": 100,  // Certificates per API call
    "MaxRegionsParallel": 5,     // Concurrent region queries
    "APIRetryAttempts": 3,
    "APIRetryDelay": 2000        // milliseconds
  }
}
```

#### Connection Pooling

```json
{
  "AWS-ACM": {
    "MaxConcurrentConnections": 25,
    "ConnectionTimeout": 30,
    "ReadTimeout": 60
  }
}
```

---

### Security Hardening

#### Use IAM Role Instead of Access Keys

```powershell
# On EC2 instance running orchestrator
# Attach IAM role to instance

# In Keyfactor store config:
# Leave AccessKeyId and SecretAccessKey blank
# Set AssumeRoleArn if cross-account access needed
```

#### Enable CloudTrail Logging

```bash
# Create CloudTrail for ACM API auditing
aws cloudtrail create-trail \
  --name keyfactor-acm-trail \
  --s3-bucket-name my-cloudtrail-bucket \
  --is-multi-region-trail

aws cloudtrail start-logging --name keyfactor-acm-trail

# Add event selector for ACM
aws cloudtrail put-event-selectors \
  --trail-name keyfactor-acm-trail \
  --event-selectors '[{"ReadWriteType":"All","IncludeManagementEvents":true,"DataResources":[{"Type":"AWS::ACM::Certificate","Values":["arn:aws:acm:*:*:certificate/*"]}]}]'
```

#### Use STS Assume Role for Cross-Account

```json
// For multi-account scenarios
{
  "AssumeRoleArn": "arn:aws:iam::987654321098:role/KeyfactorCrossAccountRole",
  "ExternalId": "unique-external-id-12345"
}
```

---

### Related Documentation

- [AWS Certificate Manager Documentation](https://docs.aws.amazon.com/acm/)
- [Keyfactor Universal Orchestrator Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [01-Executive-Design-Document.md](./01-Executive-Design-Document.md) - Cloud integration architecture
- [14-Integration-Specifications.md](./14-Integration-Specifications.md) - AWS integration details

---

## 7. IIS/Windows Certificate Store Orchestrator

**Repository**: [https://github.com/Keyfactor/iis-orchestrator](https://github.com/Keyfactor/iis-orchestrator)  
**Language**: C#  
**Stars**: 23 ⭐

### Overview

Universal Orchestrator extension for IIS and Windows Certificate Stores. Automates certificate binding to IIS sites, application pools, and Windows certificate stores (My, WebHosting, etc.).

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Automatic certificate renewal and binding to IIS websites
- Manage certificates in Windows certificate stores across servers
- Update SSL bindings for multiple IIS sites simultaneously
- Compliance inventory for Windows/IIS infrastructure

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator installed
- **Windows Servers**: Windows Server 2012 R2+ with IIS installed
- **Permissions**: 
  - Local Administrator on target servers
  - Or domain account with IIS administration rights
- **WinRM**: Enabled on target servers for remote management

#### Installation Steps

**Step 1: Enable WinRM on Target Servers**

```powershell
# On each IIS server (run as Administrator)
Enable-PSRemoting -Force

# Configure WinRM for HTTPS (recommended)
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:COMPUTERNAME`";CertificateThumbprint=`"$($cert.Thumbprint)`"}"

# Open firewall
New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow
```

**Step 2: Install Orchestrator Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/iis-orchestrator/releases/latest/download/IIS-WinCert.zip" `
  -OutFile "C:\Temp\IIS-WinCert.zip"

# Extract to orchestrator extensions folder
Expand-Archive -Path "C:\Temp\IIS-WinCert.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\IIS"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 3: Configure Store Types in Keyfactor Command**

Create **two** store types:

**A. Windows Certificate Store (WinCert)**

1. **Certificate Locations** → **Certificate Store Types** → **Add**
2. Configure:
   - Name: `Windows Certificate Store`
   - Short Name: `WinCert`
   - Supports Management Add: Yes
   - Supports Discovery: Yes
   - Supports Inventory: Yes
   - Supports Reenrollment: Yes
3. **Custom Fields**:
   - `StorePath`: Certificate store path (e.g., `My`, `WebHosting`, `Root`)
   - `ProviderType`: Certificate provider (e.g., `CAPI`, `CNG`)
4. **Save**

**B. IIS Binding Store**

1. **Certificate Locations** → **Certificate Store Types** → **Add**
2. Configure:
   - Name: `IIS Binding`
   - Short Name: `IISB`
   - Supports Management Add: Yes
   - Supports Discovery: Yes
   - Supports Inventory: Yes
   - Supports Reenrollment: Yes
3. **Custom Fields**:
   - `SiteName`: IIS site name or * for all sites
   - `Port`: SSL port (default 443)
   - `IPAddress`: IP address or * for all IPs
   - `HostName`: Hostname for SNI binding
   - `SniFlag`: SNI enabled (0=no, 1=yes)
4. **Save**

**Step 4: Add Certificate Store**

**Example: Windows Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → **Add**
2. Configure:
   - Category: `Windows Certificate Store`
   - Client Machine: `webapp01.contoso.com` (FQDN of IIS server)
   - Store Path: `My` (Personal store)
   - Credentials: Domain admin or local admin account
   - Properties:
     - StorePath: `My`
     - ProviderType: `CAPI`
   - Agent: Select orchestrator agent
3. **Save**

**Example: IIS Binding**

1. **Certificate Locations** → **Certificate Stores** → **Add**
2. Configure:
   - Category: `IIS Binding`
   - Client Machine: `webapp01.contoso.com`
   - Store Path: `Default Web Site` (IIS site name)
   - Credentials: Domain admin or local admin account
   - Properties:
     - SiteName: `Default Web Site`
     - Port: `443`
     - IPAddress: `*`
     - HostName: `webapp01.contoso.com`
     - SniFlag: `1`
   - Agent: Select orchestrator agent
3. **Save**

**Step 5: Test Inventory**

```bash
# In Keyfactor Command UI:
# Certificate Locations → Certificate Stores → Select store → Inventory

# Should list all certificates in the Windows store or IIS bindings
```

---

### Operations Guide

#### Daily Operations

**Monitor IIS Certificate Bindings**

```powershell
# Check current IIS bindings on server
Import-Module WebAdministration
Get-ChildItem IIS:\SslBindings
```

**Automated Certificate Replacement**

When a certificate renews in Keyfactor:
1. Orchestrator automatically deploys to Windows certificate store
2. Updates IIS binding to use new certificate
3. Removes old certificate (if configured)
4. IIS automatically picks up new binding (no restart needed)

**Bulk Update Multiple Sites**

```powershell
# Via Keyfactor API - update 10 sites at once
$sites = @("webapp01", "webapp02", "api01", "portal01")
$newCertId = 12345

foreach ($site in $sites) {
    $storeId = Get-KeyfactorStore -ClientMachine "$site.contoso.com" -StoreType "IISB"
    
    Add-KeyfactorCertificateToStore `
        -CertificateId $newCertId `
        -StoreId $storeId `
        -Alias "Default Web Site"
}
```

#### Certificate Operations

**Deploy and Bind Certificate**

```bash
# In Keyfactor Command UI:
# Certificates → Select certificate → Management → Add to Store

# Step 1: Add to Windows store (WinCert)
# Select Windows Certificate Store on webapp01.contoso.com

# Step 2: Add to IIS Binding (IISB)
# Select IIS Binding store on webapp01.contoso.com
# Specify site name, port, hostname
```

**Update SNI Binding**

```powershell
# Enable SNI for specific hostname
# In Keyfactor store properties:
Properties = @{
    SiteName = "Default Web Site"
    Port = "443"
    HostName = "secure.contoso.com"
    SniFlag = "1"  # Enable SNI
}
```

**Remove Old Certificate**

```powershell
# Orchestrator can auto-remove old cert after new one is bound
# Configure in store settings:
# "Remove Certificate After Replacement" = True
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 2 business days |
| Keyfactor Support | Enterprise customers | Per support contract |

#### When to Escalate

- Certificate deployment failures (>5%)
- IIS binding not updating after certificate renewal
- WinRM connectivity issues
- Certificate not being removed from store after replacement

#### Logs to Collect

**Orchestrator Logs**:
```powershell
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\IIS.log" -Tail 500
```

**IIS Logs** (on target server):
```powershell
Get-Content "C:\inetpub\logs\LogFiles\W3SVC1\u_ex$(Get-Date -Format yyMMdd).log" -Tail 100
```

**Windows Event Logs**:
```powershell
Get-EventLog -LogName System -Source "IIS-*" -Newest 50
Get-EventLog -LogName Application -Source "CertificateServicesClient-*" -Newest 50
```

---

### Troubleshooting Guide

#### Issue 1: "Access Denied" When Connecting to Server

**Symptoms**:
```
Orchestrator job failed: Access is denied to webapp01.contoso.com
Error: WinRM authentication failed
```

**Diagnosis**:
```powershell
# Test WinRM connectivity
Test-WSMan -ComputerName webapp01.contoso.com

# Test with credentials
$cred = Get-Credential
Invoke-Command -ComputerName webapp01.contoso.com -Credential $cred -ScriptBlock { hostname }
```

**Resolution**:

1. **Verify Credentials**:
   - Ensure account is local admin on target server
   - Or member of IIS_IUSRS group with appropriate permissions

2. **Check WinRM Configuration**:
   ```powershell
   # On target server
   winrm get winrm/config
   
   # Ensure AllowUnencrypted is false (security)
   # Ensure correct authentication is enabled (Kerberos, NTLM, Certificate)
   ```

3. **Add to TrustedHosts** (if not domain-joined):
   ```powershell
   # On orchestrator server
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "webapp01.contoso.com" -Concatenate
   ```

---

#### Issue 2: IIS Binding Not Updated After Certificate Deployment

**Symptoms**:
- Certificate deployed to Windows store successfully
- IIS site still using old certificate

**Diagnosis**:
```powershell
# Check current IIS binding
Import-Module WebAdministration
Get-WebBinding -Name "Default Web Site" -Protocol "https" | Select-Object *

# Check certificate in store
Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*webapp01*"}

# Check certificate thumbprint in binding
$binding = Get-WebBinding -Name "Default Web Site" -Protocol "https"
$binding.certificateHash
```

**Resolution**:

1. **Manually Update Binding**:
   ```powershell
   # Get new certificate thumbprint
   $newCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -eq "CN=webapp01.contoso.com"} | Sort-Object NotAfter -Descending | Select-Object -First 1
   
   # Update binding
   $binding = Get-WebBinding -Name "Default Web Site" -Protocol "https"
   $binding.AddSslCertificate($newCert.Thumbprint, "My")
   ```

2. **Check Store Configuration**:
   - Verify "Update Bindings" option is enabled in Keyfactor store settings
   - Ensure site name matches exactly (case-sensitive)

3. **Verify IIS Permissions**:
   ```powershell
   # Orchestrator service account needs IIS admin rights
   net localgroup "IIS_IUSRS" orchestrator-service-account /add
   ```

---

#### Issue 3: Certificate Has Private Key But Shows as "No Private Key" in IIS

**Symptoms**:
- Certificate imported to Windows store
- Certificate shows in IIS but grayed out (no private key icon)

**Diagnosis**:
```powershell
# Check certificate private key permissions
$cert = Get-ChildItem Cert:\LocalMachine\My\<THUMBPRINT>
$rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$rsaCert.Key.UniqueName

# Check file permissions on private key
$keyPath = "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$($rsaCert.Key.UniqueName)"
icacls $keyPath
```

**Resolution**:

1. **Grant Private Key Permissions**:
   ```powershell
   # Grant IIS_IUSRS read permission
   $cert = Get-ChildItem Cert:\LocalMachine\My\<THUMBPRINT>
   $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
   $keyPath = "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$($rsaCert.Key.UniqueName)"
   
   icacls $keyPath /grant "IIS_IUSRS:(R)"
   icacls $keyPath /grant "NETWORK SERVICE:(R)"
   ```

2. **Re-import with Private Key**:
   ```powershell
   # Export from Keyfactor with private key
   # Re-import using certutil
   certutil -importpfx -p password cert.pfx
   ```

---

### Performance Tuning

#### Optimize for Large IIS Farms

```json
// In orchestrator config.json
{
  "IIS": {
    "MaxConcurrentServers": 10,  // Process 10 servers simultaneously
    "BindingUpdateTimeout": 60,   // seconds
    "InventoryCacheTimeout": 3600 // 1 hour
  }
}
```

#### Reduce WinRM Latency

```json
{
  "IIS": {
    "WinRMConnectionTimeout": 30,
    "WinRMOperationTimeout": 300,
    "UseHTTPSForWinRM": true,  // HTTPS is more secure but slightly slower
    "WinRMPort": 5986
  }
}
```

---

### Security Hardening

#### Use Certificate-Based Authentication for WinRM

```powershell
# On orchestrator server - create client cert
$cert = New-SelfSignedCertificate -DnsName "orchestrator.contoso.com" -CertStoreLocation Cert:\LocalMachine\My -KeyUsage DigitalSignature,KeyEncipherment

# On IIS servers - map certificate to user account
New-Item -Path WSMan:\localhost\ClientCertificate `
  -Subject "orchestrator@contoso.com" `
  -URI * `
  -Issuer $cert.Thumbprint `
  -Credential (Get-Credential)
```

#### Restrict WinRM Access

```powershell
# On IIS servers - allow only orchestrator server
Set-Item WSMan:\localhost\Service\IPv4Filter -Value "10.0.1.100"  # Orchestrator IP
```

#### Enable Audit Logging

```powershell
# Track certificate operations in Windows Event Log
auditpol /set /subcategory:"Certification Services" /success:enable /failure:enable
```

---

### Related Documentation

- [IIS Documentation](https://docs.microsoft.com/en-us/iis/)
- [Windows Certificate Store Management](https://docs.microsoft.com/en-us/windows-server/identity/ad-cs/)
- [Keyfactor Universal Orchestrator Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [06-Automation-Playbooks.md](./06-Automation-Playbooks.md) - IIS renewal automation scripts

---

## 8. Remote File Orchestrator

**Repository**: [https://github.com/Keyfactor/remote-file-orchestrator](https://github.com/Keyfactor/remote-file-orchestrator)  
**Language**: C#  
**Stars**: 14 ⭐

### Overview

Universal Orchestrator extension for deploying certificates as PEM/PFX/JKS files to remote servers via SSH/SFTP/SCP. Ideal for Linux servers, network devices, and applications that consume certificate files directly.

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Deploy certificates to Linux/Unix servers (Apache, Nginx, HAProxy)
- Update Java keystores (Tomcat, JBoss)
- Deliver certificates to network appliances
- Automated certificate file distribution with restart hooks

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator installed
- **Target Servers**: SSH enabled with key-based or password authentication
- **Permissions**: Write access to certificate directories
- **.NET Framework**: 4.7.2+ (on orchestrator host)

#### Installation Steps

**Step 1: Configure SSH Access on Target Servers**

```bash
# On each target server
# Create certificate directory
sudo mkdir -p /etc/ssl/certs/app
sudo chmod 755 /etc/ssl/certs/app

# Create service account for orchestrator
sudo useradd -m -s /bin/bash keyfactor-orchestrator

# Add to certificate management group
sudo usermod -aG ssl-cert keyfactor-orchestrator

# Grant write permissions
sudo chown -R keyfactor-orchestrator:ssl-cert /etc/ssl/certs/app
sudo chmod 770 /etc/ssl/certs/app

# Configure SSH key-based auth (recommended)
sudo -u keyfactor-orchestrator ssh-keygen -t rsa -b 4096 -f /home/keyfactor-orchestrator/.ssh/id_rsa -N ""
sudo -u keyfactor-orchestrator cat /home/keyfactor-orchestrator/.ssh/id_rsa.pub >> /home/keyfactor-orchestrator/.ssh/authorized_keys
```

**Step 2: Install Orchestrator Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/remote-file-orchestrator/releases/latest/download/RemoteFile.zip" `
  -OutFile "C:\Temp\RemoteFile.zip"

# Extract to orchestrator extensions folder
Expand-Archive -Path "C:\Temp\RemoteFile.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\RemoteFile"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 3: Configure Store Type in Keyfactor Command**

1. **Certificate Locations** → **Certificate Store Types** → **Add**
2. Configure:
   - Name: `Remote File Store`
   - Short Name: `RemoteFile`
   - Supports Management Add: Yes
   - Supports Discovery: Yes
   - Supports Inventory: Yes
   - Supports Reenrollment: No
3. **Custom Fields**:
   - `ServerType`: linux, unix, network-device
   - `FileFormat`: PEM, PFX, JKS, PKCS12
   - `IncludeChain`: true/false
   - `IncludePrivateKey`: true/false
   - `RestartCommand`: Optional command to run after deployment
4. **Save**

**Step 4: Add Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → **Add**
2. Configure:
   - Category: `Remote File Store`
   - Client Machine: `webserver01.contoso.com` (FQDN or IP)
   - Store Path: `/etc/ssl/certs/app` (directory path)
   - Credentials: SSH username/password or private key
   - Properties:
     - ServerType: `linux`
     - FileFormat: `PEM`
     - IncludeChain: `true`
     - IncludePrivateKey: `true`
     - RestartCommand: `sudo systemctl reload nginx`
   - Agent: Select orchestrator agent
3. **Save**

**Step 5: Test Deployment**

```bash
# In Keyfactor Command UI:
# Certificates → Select certificate → Management → Add to Store
# Select Remote File store
# Alias: filename (e.g., webapp01.crt)

# Verify on target server:
ssh keyfactor-orchestrator@webserver01.contoso.com "ls -l /etc/ssl/certs/app/"
```

---

### Operations Guide

#### Daily Operations

**Monitor File Deployments**

```bash
# Check deployment logs
ssh keyfactor-orchestrator@webserver01.contoso.com "tail -f /var/log/keyfactor-deploy.log"

# Verify certificate file permissions
ssh keyfactor-orchestrator@webserver01.contoso.com "ls -l /etc/ssl/certs/app/ | grep webapp01"
```

**Automated Service Restart**

When configured with `RestartCommand`, orchestrator will:
1. Deploy new certificate file(s)
2. Set correct permissions
3. Execute restart command
4. Verify command exit code
5. Report success/failure to Keyfactor Command

**Bulk Deployment Example**

```powershell
# Deploy same certificate to 20 web servers
$servers = 1..20 | ForEach-Object { "webserver$($_.ToString('00')).contoso.com" }
$certId = 12345

foreach ($server in $servers) {
    $storeId = Get-KeyfactorStore -ClientMachine $server -StoreType "RemoteFile"
    
    Add-KeyfactorCertificateToStore `
        -CertificateId $certId `
        -StoreId $storeId `
        -Alias "webapp.crt"
}
```

#### Certificate Operations

**Deploy with Different Formats**

```powershell
# PEM format (Apache/Nginx)
Properties = @{
    FileFormat = "PEM"
    IncludeChain = "true"
    IncludePrivateKey = "true"
    RestartCommand = "sudo systemctl reload nginx"
}

# PFX format (Windows-style on Linux)
Properties = @{
    FileFormat = "PFX"
    IncludeChain = "true"
    IncludePrivateKey = "true"
    RestartCommand = "sudo systemctl restart app"
}

# JKS format (Tomcat/Java)
Properties = @{
    FileFormat = "JKS"
    IncludeChain = "true"
    IncludePrivateKey = "true"
    RestartCommand = "sudo systemctl restart tomcat"
}
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 3 business days |
| Keyfactor Support | Enterprise customers | Per support contract |

#### When to Escalate

- SSH connection failures (>10%)
- File deployment failures
- Restart commands failing
- Permission denied errors

#### Logs to Collect

**Orchestrator Logs**:
```powershell
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\RemoteFile.log" -Tail 500
```

**Target Server Logs**:
```bash
# SSH logs
sudo tail -100 /var/log/auth.log

# Application logs (if restart command executed)
sudo journalctl -u nginx -n 100
```

---

### Troubleshooting Guide

#### Issue 1: "Permission Denied" When Writing File

**Symptoms**:
```
Orchestrator job failed: Permission denied
Error: Cannot write to /etc/ssl/certs/app/webapp01.crt
```

**Diagnosis**:
```bash
# Check directory permissions
ssh keyfactor-orchestrator@webserver01.contoso.com "ls -ld /etc/ssl/certs/app"

# Check user permissions
ssh keyfactor-orchestrator@webserver01.contoso.com "groups"

# Test write access
ssh keyfactor-orchestrator@webserver01.contoso.com "touch /etc/ssl/certs/app/test.txt"
```

**Resolution**:

1. **Grant Directory Permissions**:
   ```bash
   sudo chown keyfactor-orchestrator:ssl-cert /etc/ssl/certs/app
   sudo chmod 770 /etc/ssl/certs/app
   ```

2. **Use sudo for Restricted Paths**:
   - Configure sudoers to allow writes without password
   ```bash
   sudo visudo
   # Add:
   keyfactor-orchestrator ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/ssl/certs/app/*
   ```

---

#### Issue 2: Restart Command Fails

**Symptoms**:
```
Certificate deployed successfully but restart command failed
Error: sudo: no tty present and no askpass program specified
```

**Diagnosis**:
```bash
# Test restart command manually
ssh keyfactor-orchestrator@webserver01.contoso.com "sudo systemctl reload nginx"

# Check sudoers configuration
sudo grep keyfactor-orchestrator /etc/sudoers
```

**Resolution**:

1. **Configure Passwordless sudo**:
   ```bash
   sudo visudo
   # Add:
   keyfactor-orchestrator ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
   keyfactor-orchestrator ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
   ```

2. **Alternative: Use Service-Specific Script**:
   ```bash
   # Create reload script
   sudo tee /usr/local/bin/reload-nginx.sh <<EOF
   #!/bin/bash
   systemctl reload nginx
   EOF
   
   sudo chmod +x /usr/local/bin/reload-nginx.sh
   sudo chown keyfactor-orchestrator /usr/local/bin/reload-nginx.sh
   
   # Update Keyfactor store RestartCommand:
   # /usr/local/bin/reload-nginx.sh
   ```

---

#### Issue 3: SSH Connection Timeout

**Symptoms**:
```
Orchestrator job failed: Connection timeout
Error: Unable to connect to webserver01.contoso.com:22
```

**Diagnosis**:
```powershell
# Test SSH connectivity from orchestrator server
Test-NetConnection -ComputerName webserver01.contoso.com -Port 22

# Test SSH authentication
ssh -v keyfactor-orchestrator@webserver01.contoso.com
```

**Resolution**:

1. **Check Firewall Rules**:
   ```bash
   # On target server
   sudo ufw status
   sudo ufw allow from <ORCHESTRATOR_IP> to any port 22
   ```

2. **Verify SSH Service**:
   ```bash
   sudo systemctl status sshd
   sudo systemctl enable sshd
   sudo systemctl start sshd
   ```

3. **Check SSH Key Authentication**:
   ```bash
   # On orchestrator server, add private key
   # In Keyfactor store credentials, use private key instead of password
   ```

---

### Performance Tuning

#### Concurrent Deployments

```json
// In orchestrator config.json
{
  "RemoteFile": {
    "MaxConcurrentConnections": 20,  // SSH sessions
    "ConnectionTimeout": 30,
    "TransferTimeout": 300,  // File transfer timeout
    "SSHKeepAliveInterval": 60
  }
}
```

#### Optimize for Large Files

```json
{
  "RemoteFile": {
    "CompressionEnabled": true,  // Compress during transfer
    "BufferSize": 32768,  // 32KB buffer
    "RetryAttempts": 3,
    "RetryDelay": 5000
  }
}
```

---

### Security Hardening

#### Use SSH Key Authentication

```bash
# On orchestrator server, generate dedicated key
ssh-keygen -t ed25519 -f keyfactor-orchestrator-key -N ""

# Add public key to all target servers
for server in webserver01 webserver02 webserver03; do
  ssh-copy-id -i keyfactor-orchestrator-key.pub keyfactor-orchestrator@$server.contoso.com
done

# In Keyfactor store credentials, use private key
```

#### Restrict SSH Access

```bash
# On target servers - allow only from orchestrator IP
sudo tee -a /etc/ssh/sshd_config <<EOF
Match User keyfactor-orchestrator
    AllowUsers keyfactor-orchestrator
    PermitRootLogin no
    PasswordAuthentication no
    PubkeyAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
    AllowAgentForwarding no
EOF

sudo systemctl reload sshd
```

#### File Permissions

```bash
# Ensure certificates are readable only by app user
sudo chmod 640 /etc/ssl/certs/app/*.crt
sudo chmod 600 /etc/ssl/certs/app/*.key
sudo chown root:nginx /etc/ssl/certs/app/*
```

---

### Related Documentation

- [SSH Documentation](https://www.openssh.com/manual.html)
- [Keyfactor Universal Orchestrator Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [06-Automation-Playbooks.md](./06-Automation-Playbooks.md) - Deployment automation scripts

---

## 9. F5 Networks REST Orchestrator

**Repository**: [https://github.com/Keyfactor/f5-rest-orchestrator](https://github.com/Keyfactor/f5-rest-orchestrator)  
**Language**: C#  
**Stars**: 8 ⭐

### Overview

Universal Orchestrator extension for F5 BIG-IP load balancers via REST API. Automates certificate and key management on F5 devices including SSL profiles and virtual servers.

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Automatic certificate renewal for F5 load balancers
- Bulk update SSL profiles across multiple virtual servers
- Inventory F5 certificates for compliance
- Synchronized certificate deployment to F5 HA pairs

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator installed
- **F5 BIG-IP**: v12+ with iControl REST API enabled
- **F5 User Account**: Administrator or Certificate Manager role
- **Network Access**: HTTPS access to F5 management interface (typically port 443)

#### Installation Steps

**Step 1: Enable iControl REST API on F5**

```bash
# SSH to F5
ssh admin@f5-lb01.contoso.com

# Verify iControl REST is running
tmsh show sys service restjavad

# If not running, start it
tmsh start sys service restjavad

# Configure API access (if needed)
tmsh modify sys httpd auth-pam-validate-ip off
tmsh save sys config
```

**Step 2: Create F5 API User**

```bash
# Create dedicated user for Keyfactor
tmsh create auth user keyfactor-api password 'SecurePassword123!' partition-access add { all-partitions { role certificate-manager }}

# Verify user
tmsh list auth user keyfactor-api

# Test API access
curl -ku keyfactor-api:SecurePassword123! https://f5-lb01.contoso.com/mgmt/tm/sys/version
```

**Step 3: Install Orchestrator Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/f5-rest-orchestrator/releases/latest/download/F5-REST.zip" `
  -OutFile "C:\Temp\F5-REST.zip"

# Extract to orchestrator extensions folder
Expand-Archive -Path "C:\Temp\F5-REST.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\F5-REST"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 4: Configure Store Type in Keyfactor Command**

1. **Certificate Locations** → **Certificate Store Types** → **Add**
2. Configure:
   - Name: `F5 BIG-IP REST`
   - Short Name: `F5REST`
   - Supports Management Add: Yes
   - Supports Discovery: Yes
   - Supports Inventory: Yes
   - Supports Reenrollment: No
3. **Custom Fields**:
   - `Partition`: F5 partition (default: Common)
   - `UpdateVirtualServers`: Auto-update VS profiles (true/false)
   - `BackupBeforeUpdate`: Create UCS backup (true/false)
4. **Save**

**Step 5: Add Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → **Add**
2. Configure:
   - Category: `F5 BIG-IP REST`
   - Client Machine: `f5-lb01.contoso.com` (F5 management IP/hostname)
   - Store Path: `/Common` (F5 partition)
   - Credentials: API username/password (keyfactor-api)
   - Properties:
     - Partition: `Common`
     - UpdateVirtualServers: `true`
     - BackupBeforeUpdate: `true`
   - Agent: Select orchestrator agent
3. **Save**

**Step 6: Test Inventory**

```bash
# In Keyfactor Command UI:
# Certificate Locations → Certificate Stores → Select F5 store → Inventory

# Should list all certificates in the F5 partition
```

---

### Operations Guide

#### Daily Operations

**Monitor F5 Certificate Status**

```bash
# Via F5 CLI
tmsh list sys file ssl-cert

# Via REST API
curl -ku keyfactor-api:password https://f5-lb01.contoso.com/mgmt/tm/sys/file/ssl-cert
```

**Automated Certificate Replacement**

When certificate renews in Keyfactor:
1. Orchestrator uploads new cert and key to F5
2. Updates SSL client/server profiles
3. Updates virtual server configurations
4. Creates UCS backup (if configured)
5. No service restart required (F5 hot-reload)

**Bulk Update SSL Profiles**

```powershell
# Via Keyfactor API - update all F5 devices
$f5Devices = @("f5-lb01", "f5-lb02", "f5-lb03")
$certId = 12345

foreach ($device in $f5Devices) {
    $storeId = Get-KeyfactorStore -ClientMachine "$device.contoso.com" -StoreType "F5REST"
    
    Add-KeyfactorCertificateToStore `
        -CertificateId $certId `
        -StoreId $storeId `
        -Alias "webapp-cert"
}
```

#### Certificate Operations

**Deploy Certificate with Auto-Profile Update**

```bash
# In Keyfactor Command UI:
# Certificates → Select certificate → Management → Add to Store
# Select F5 store
# Alias: certificate name on F5 (e.g., webapp01-cert)
# Orchestrator will:
# 1. Upload cert and key
# 2. Find SSL profiles using old cert
# 3. Update profiles to use new cert
# 4. Create backup
```

**Manual SSL Profile Update** (if needed):

```bash
# SSH to F5
tmsh modify ltm profile client-ssl webapp-ssl cert webapp01-cert key webapp01-key

# Verify
tmsh list ltm profile client-ssl webapp-ssl
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 3 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| F5 Support | F5 device issues | Per F5 contract |

#### When to Escalate

- API authentication failures
- Certificate upload failures (>5%)
- SSL profile update failures
- HA pair synchronization issues

#### Logs to Collect

**Orchestrator Logs**:
```powershell
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\F5-REST.log" -Tail 500
```

**F5 Logs**:
```bash
# SSH to F5
tail -100 /var/log/ltm
tail -100 /var/log/restjavad.0.log
```

---

### Troubleshooting Guide

#### Issue 1: "Authentication Failed" Error

**Symptoms**:
```
Orchestrator job failed: 401 Unauthorized
Error: Authentication to F5 device failed
```

**Diagnosis**:
```bash
# Test API credentials
curl -ku keyfactor-api:password https://f5-lb01.contoso.com/mgmt/tm/sys/version

# Check user permissions
tmsh list auth user keyfactor-api
```

**Resolution**:

1. **Verify User Credentials**:
   ```bash
   # Reset password if needed
   tmsh modify auth user keyfactor-api password 'NewSecurePassword123!'
   
   # Update credentials in Keyfactor store
   ```

2. **Check User Permissions**:
   ```bash
   # User needs certificate-manager role minimum
   tmsh modify auth user keyfactor-api partition-access modify { all-partitions { role certificate-manager }}
   ```

3. **Verify API Service**:
   ```bash
   tmsh show sys service restjavad
   tmsh restart sys service restjavad
   ```

---

#### Issue 2: Certificate Upload Succeeds But SSL Profile Not Updated

**Symptoms**:
- Certificate uploaded to F5 successfully
- SSL profiles still reference old certificate

**Diagnosis**:
```bash
# Check if cert exists on F5
tmsh list sys file ssl-cert webapp01-cert

# Check SSL profiles
tmsh list ltm profile client-ssl | grep cert

# Check orchestrator logs for profile update attempts
```

**Resolution**:

1. **Verify UpdateVirtualServers Setting**:
   - In Keyfactor store properties, ensure `UpdateVirtualServers = true`

2. **Manually Update Profile**:
   ```bash
   # Find profiles using old cert
   tmsh list ltm profile client-ssl one-line | grep old-cert-name
   
   # Update each profile
   tmsh modify ltm profile client-ssl webapp-ssl cert webapp01-cert key webapp01-key chain webapp01-chain
   ```

3. **Check Partition Access**:
   ```bash
   # User must have access to partition containing profiles
   tmsh list auth user keyfactor-api partition-access
   ```

---

#### Issue 3: HA Sync Failure After Certificate Update

**Symptoms**:
```
Certificate updated on active F5 but not syncing to standby
HA pair out of sync
```

**Diagnosis**:
```bash
# Check sync status
tmsh show cm sync-status

# Check config sync state
tmsh show cm device
```

**Resolution**:

1. **Force Config Sync**:
   ```bash
   # From active F5
   tmsh run cm config-sync to-group f5-ha-group
   
   # Verify sync
   tmsh show cm sync-status
   ```

2. **Check HA Communication**:
   ```bash
   # Verify network connectivity
   ping <standby-f5-ip>
   
   # Check ConfigSync port (TCP 4353)
   tmsh show net connection cs-server
   ```

3. **Enable Auto-Sync** (recommended):
   ```bash
   tmsh modify cm device-group f5-ha-group auto-sync enabled
   ```

---

### Performance Tuning

#### Optimize API Calls

```json
// In orchestrator config.json
{
  "F5-REST": {
    "MaxConcurrentRequests": 10,
    "RequestTimeout": 60,
    "RetryAttempts": 3,
    "RetryDelay": 5000,
    "UseBulkOperations": true
  }
}
```

#### Batch Profile Updates

```json
{
  "F5-REST": {
    "BatchProfileUpdates": true,
    "BatchSize": 50,  // Update 50 profiles per transaction
    "TransactionTimeout": 300
  }
}
```

---

### Security Hardening

#### Use Token-Based Authentication

```bash
# Create auth token (valid for 1200 seconds)
curl -ku keyfactor-api:password -X POST https://f5-lb01.contoso.com/mgmt/shared/authn/login \
  -H "Content-Type: application/json" \
  -d '{"username":"keyfactor-api","password":"password","loginProviderName":"tmos"}'

# Use token in orchestrator instead of password
```

#### Restrict API Access by IP

```bash
# Allow orchestrator IP only
tmsh create security firewall rule-list keyfactor-api-access \
  rules add { allow-orchestrator { action accept source { addresses add { 10.0.1.100/32 } } } }

tmsh modify sys httpd allow add { 10.0.1.100 }
```

#### Enable API Audit Logging

```bash
# Enable detailed logging
tmsh modify sys db config.auditing value enable
tmsh modify sys db systemauth.disablebanner value false

# Log all iControl REST calls
tmsh modify sys daemon-log-settings restjavad level fine
```

---

### Related Documentation

- [F5 iControl REST API Documentation](https://clouddocs.f5.com/api/icontrol-rest/)
- [Keyfactor Universal Orchestrator Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [06-Automation-Playbooks.md](./06-Automation-Playbooks.md) - F5 automation scripts

---

## 10. Palo Alto Firewall Orchestrator

**Repository**: [https://github.com/Keyfactor/paloalto-firewall-orchestrator](https://github.com/Keyfactor/paloalto-firewall-orchestrator)  
**Language**: C#  
**Stars**: 6 ⭐

### Overview

Universal Orchestrator extension for Palo Alto Networks firewalls. Automates certificate management for SSL/TLS decryption, GlobalProtect VPN, and management interface certificates via XML API.

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Automatic certificate renewal for SSL decryption policies
- GlobalProtect VPN gateway certificate management
- Management interface HTTPS certificate updates
- Bulk certificate deployment across firewall clusters

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator installed
- **Palo Alto Firewall**: PAN-OS 8.0+
- **API Access**: XML API enabled with admin credentials
- **Network Access**: HTTPS access to firewall management interface

#### Installation Steps

**Step 1: Enable API Access on Palo Alto Firewall**

```bash
# SSH to firewall
ssh admin@paloalto-fw01.contoso.com

# Enable HTTP/HTTPS services for API
set deviceconfig system service disable-http no
set deviceconfig system service disable-https no

# Commit changes
commit
```

**Step 2: Create API User**

```bash
# Create dedicated API user
set mgt-config users keyfactor-api password
set mgt-config users keyfactor-api permissions role-based superuser yes

# Commit
commit

# Generate API key
curl -k -X GET 'https://paloalto-fw01.contoso.com/api/?type=keygen&user=keyfactor-api&password=SecurePassword123!'
# Save the API key from response
```

**Step 3: Install Orchestrator Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/paloalto-firewall-orchestrator/releases/latest/download/PaloAlto.zip" `
  -OutFile "C:\Temp\PaloAlto.zip"

# Extract to orchestrator extensions folder
Expand-Archive -Path "C:\Temp\PaloAlto.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\PaloAlto"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 4: Configure Store Type in Keyfactor Command**

1. **Certificate Locations** → **Certificate Store Types** → **Add**
2. Configure:
   - Name: `Palo Alto Firewall`
   - Short Name: `PAN`
   - Supports Management Add: Yes
   - Supports Discovery: Yes
   - Supports Inventory: Yes
   - Supports Reenrollment: No
3. **Custom Fields**:
   - `CertificateType`: certificate, trusted-root-ca, scep-ca
   - `CommitChanges`: Auto-commit after update (true/false)
   - `DeviceGroup`: For Panorama-managed firewalls
4. **Save**

**Step 5: Add Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → **Add**
2. Configure:
   - Category: `Palo Alto Firewall`
   - Client Machine: `paloalto-fw01.contoso.com` (firewall FQDN/IP)
   - Store Path: `shared` (certificate store location on firewall)
   - Credentials: API key
   - Properties:
     - CertificateType: `certificate`
     - CommitChanges: `true`
     - DeviceGroup: (leave empty for standalone firewall)
   - Agent: Select orchestrator agent
3. **Save**

**Step 6: Test Inventory**

```bash
# In Keyfactor Command UI:
# Certificate Locations → Certificate Stores → Select PAN store → Inventory

# Should list all certificates on the firewall
```

---

### Operations Guide

#### Daily Operations

**Monitor Firewall Certificates**

```bash
# Via firewall CLI
show config running certificate

# Via API
curl -k -X GET 'https://paloalto-fw01.contoso.com/api/?type=op&cmd=<show><config><running><certificate></certificate></running></config></show>&key=API_KEY'
```

**Automated Certificate Replacement**

When certificate renews in Keyfactor:
1. Orchestrator imports certificate to firewall
2. Updates SSL/TLS decryption profiles
3. Updates GlobalProtect gateway configuration
4. Commits configuration (if enabled)
5. No reboot required

**Bulk Deployment to Firewall Cluster**

```powershell
# Deploy to all firewalls in HA pair
$firewalls = @("paloalto-fw01", "paloalto-fw02")
$certId = 12345

foreach ($fw in $firewalls) {
    $storeId = Get-KeyfactorStore -ClientMachine "$fw.contoso.com" -StoreType "PAN"
    
    Add-KeyfactorCertificateToStore `
        -CertificateId $certId `
        -StoreId $storeId `
        -Alias "ssl-decrypt-cert"
}
```

#### Certificate Operations

**Deploy Certificate for SSL Decryption**

```bash
# In Keyfactor Command UI:
# Certificates → Select certificate → Management → Add to Store
# Select Palo Alto store
# Alias: certificate name on firewall (e.g., ssl-decrypt-2024)

# After deployment, configure SSL decryption policy:
# Policies → Decryption → Add Rule
# Select certificate: ssl-decrypt-2024
```

**Update GlobalProtect Gateway Certificate**

```bash
# After deploying certificate via Keyfactor, update GP gateway:
set network global-protect-gateway gateway-name certificate ssl-decrypt-2024
commit
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 3 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| Palo Alto Support | Firewall issues | Per PAN contract |

#### When to Escalate

- API authentication failures
- Certificate import failures (>5%)
- Commit failures after certificate update
- HA synchronization issues

#### Logs to Collect

**Orchestrator Logs**:
```powershell
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\PaloAlto.log" -Tail 500
```

**Firewall Logs**:
```bash
# SSH to firewall
tail follow yes mp-log system.log

# View recent configuration commits
show config list changes
```

---

### Troubleshooting Guide

#### Issue 1: "API Authentication Failed"

**Symptoms**:
```
Orchestrator job failed: 403 Forbidden
Error: Invalid API key
```

**Diagnosis**:
```bash
# Test API key
curl -k -X GET 'https://paloalto-fw01.contoso.com/api/?type=op&cmd=<show><system><info></info></system></show>&key=YOUR_API_KEY'
```

**Resolution**:

1. **Regenerate API Key**:
   ```bash
   # SSH to firewall
   curl -k 'https://paloalto-fw01.contoso.com/api/?type=keygen&user=keyfactor-api&password=SecurePassword123!'
   
   # Update API key in Keyfactor store credentials
   ```

2. **Verify User Permissions**:
   ```bash
   show mgt-config users keyfactor-api
   
   # User should have superuser role for certificate management
   ```

---

#### Issue 2: Certificate Imported But Not Available in Decryption Policy

**Symptoms**:
- Certificate successfully imported to firewall
- Certificate not appearing in SSL decryption profile dropdown

**Diagnosis**:
```bash
# Check if certificate exists
show config running certificate

# Check certificate format
openssl x509 -in cert.pem -noout -text
```

**Resolution**:

1. **Verify Certificate Has Private Key**:
   - Palo Alto requires certificate + private key for SSL decryption
   - Ensure "Include Private Key" was selected during deployment

2. **Commit Configuration**:
   ```bash
   # If auto-commit is disabled, manually commit
   commit
   
   # Check commit status
   show jobs processed
   ```

3. **Wait for Configuration Sync**:
   - HA firewalls may take 1-2 minutes to sync
   - Check HA sync status: `show high-availability state`

---

#### Issue 3: "Commit Failed" After Certificate Update

**Symptoms**:
```
Certificate imported successfully but commit failed
Error: Commit failed with warnings/errors
```

**Diagnosis**:
```bash
# Check commit status
show jobs processed

# View detailed commit errors
show config diff
```

**Resolution**:

1. **Check for Configuration Conflicts**:
   ```bash
   # View pending changes
   show config diff
   
   # Identify conflicting changes made by other admins
   ```

2. **Force Commit** (if safe):
   ```bash
   commit force
   ```

3. **Disable Auto-Commit in Keyfactor**:
   - Set `CommitChanges = false` in store properties
   - Manually review and commit changes

---

### Performance Tuning

#### Optimize API Calls

```json
// In orchestrator config.json
{
  "PaloAlto": {
    "MaxConcurrentRequests": 5,  // Firewall API has rate limits
    "RequestTimeout": 120,  // Commits can take time
    "RetryAttempts": 3,
    "RetryDelay": 10000,
    "UseAsyncCommit": true
  }
}
```

#### Batch Certificate Operations

```json
{
  "PaloAlto": {
    "BatchImports": true,
    "BatchSize": 10,  // Import 10 certs before committing
    "CommitAfterBatch": true
  }
}
```

---

### Security Hardening

#### Restrict API Access by IP

```bash
# Allow only orchestrator IP
set deviceconfig system permitted-ip 10.0.1.100

# Commit
commit
```

#### Use Certificate-Based API Authentication

```bash
# Create client certificate for API access
# Configure firewall to use certificate authentication
set mgt-config users keyfactor-api client-certificate-only yes

# Import client certificate
set shared certificate keyfactor-api-client
```

#### Enable API Audit Logging

```bash
# Log all API calls
set shared log-settings system match-list api-log filter "All Logs"
set shared log-settings system format "API: %user% - %cmd%"

# Commit
commit
```

---

### Related Documentation

- [Palo Alto XML API Documentation](https://docs.paloaltonetworks.com/pan-os/10-0/pan-os-panorama-api)
- [Keyfactor Universal Orchestrator Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [06-Automation-Playbooks.md](./06-Automation-Playbooks.md) - Firewall automation scripts

---

## 11. Keyfactor Python Client SDK

**Repository**: [https://github.com/Keyfactor/keyfactor-python-client](https://github.com/Keyfactor/keyfactor-python-client)  
**Language**: Python  
**Stars**: 28 ⭐

### Overview

Official Python SDK for Keyfactor Command API. Provides programmatic access to certificate operations, enrollment, inventory management, and orchestration tasks.

### Implementation Phase

**Phase 3**: Enrollment Rails & Self-Service (Weeks 10-12)  
**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Custom certificate enrollment workflows
- Automated certificate inventory reporting
- Integration with ITSM systems (ServiceNow, Jira)
- Custom dashboards and analytics
- Bulk certificate operations via scripts

---

### Implementation Guide

#### Prerequisites

- **Python**: 3.7+
- **Keyfactor Command**: 10.x+ with API enabled
- **API Credentials**: OAuth token or Basic Auth credentials
- **Network Access**: HTTPS access to Keyfactor Command API

#### Installation Steps

**Step 1: Install SDK**

```bash
# Via pip
pip install keyfactor-python-client

# Or from source
git clone https://github.com/Keyfactor/keyfactor-python-client.git
cd keyfactor-python-client
pip install -e .

# Verify installation
python -c "import keyfactor; print(keyfactor.__version__)"
```

**Step 2: Configure API Access in Keyfactor Command**

```bash
# In Keyfactor Command UI:
# 1. Settings → API Settings → Enable API
# 2. Security → API Users → Create User
#    - Username: api-automation
#    - Role: Certificate Requester, Certificate Administrator
# 3. Generate OAuth token or use Basic Auth
```

**Step 3: Create Configuration File**

```python
# config.py
KEYFACTOR_HOST = "https://keyfactor.contoso.com"
KEYFACTOR_USERNAME = "api-automation"
KEYFACTOR_PASSWORD = "SecurePassword123!"
KEYFACTOR_DOMAIN = "contoso"

# Or use OAuth
KEYFACTOR_OAUTH_TOKEN = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Step 4: Basic Usage Example**

```python
#!/usr/bin/env python3
# example.py - Basic Keyfactor SDK usage

from keyfactor import KeyfactorClient
from keyfactor.auth import BasicAuth

# Initialize client
auth = BasicAuth(
    username="api-automation",
    password="SecurePassword123!",
    domain="contoso"
)

client = KeyfactorClient(
    hostname="keyfactor.contoso.com",
    auth=auth,
    verify_ssl=True
)

# List certificates
certs = client.certificates.list(
    query="CN=webapp01.contoso.com"
)

for cert in certs:
    print(f"{cert.thumbprint}: {cert.subject} (Expires: {cert.not_after})")

# Enroll new certificate
request = {
    "template": "WebServerTemplate",
    "subject": "CN=webapp02.contoso.com",
    "sans": ["webapp02.contoso.com", "www.webapp02.contoso.com"],
    "metadata": {
        "owner": "platform-team@contoso.com",
        "cost-center": "CC-12345"
    }
}

new_cert = client.certificates.enroll(request)
print(f"Certificate enrolled: {new_cert.thumbprint}")
```

---

### Operations Guide

#### Common Operations

**Certificate Inventory Report**

```python
#!/usr/bin/env python3
# inventory-report.py

from keyfactor import KeyfactorClient
from keyfactor.auth import BasicAuth
import csv
from datetime import datetime, timedelta

# Initialize client
auth = BasicAuth(username="api-automation", password="password", domain="contoso")
client = KeyfactorClient(hostname="keyfactor.contoso.com", auth=auth)

# Get certificates expiring in 30 days
expiry_date = datetime.now() + timedelta(days=30)
certs = client.certificates.list(
    query=f"ValidTo<={expiry_date.strftime('%Y-%m-%d')}"
)

# Export to CSV
with open('expiring-certs.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Thumbprint', 'Subject', 'Expires', 'Owner', 'Locations'])
    
    for cert in certs:
        locations = ', '.join([loc.name for loc in cert.locations])
        writer.writerow([
            cert.thumbprint,
            cert.subject,
            cert.not_after,
            cert.metadata.get('owner', 'Unknown'),
            locations
        ])

print(f"Report generated: {len(certs)} certificates expiring in 30 days")
```

**Bulk Certificate Enrollment**

```python
#!/usr/bin/env python3
# bulk-enroll.py

from keyfactor import KeyfactorClient
from keyfactor.auth import BasicAuth
import csv

# Initialize client
auth = BasicAuth(username="api-automation", password="password", domain="contoso")
client = KeyfactorClient(hostname="keyfactor.contoso.com", auth=auth)

# Read hostnames from CSV
with open('hostnames.csv', 'r') as f:
    reader = csv.DictReader(f)
    
    for row in reader:
        hostname = row['hostname']
        environment = row['environment']
        owner = row['owner']
        
        print(f"Enrolling certificate for {hostname}...")
        
        try:
            request = {
                "template": f"{environment}ServerTemplate",
                "subject": f"CN={hostname}",
                "sans": [hostname],
                "metadata": {
                    "owner": owner,
                    "environment": environment,
                    "automated": "true"
                }
            }
            
            cert = client.certificates.enroll(request)
            print(f"  ✓ Success: {cert.thumbprint}")
            
        except Exception as e:
            print(f"  ✗ Failed: {e}")
```

**Certificate Renewal Automation**

```python
#!/usr/bin/env python3
# auto-renew.py

from keyfactor import KeyfactorClient
from keyfactor.auth import BasicAuth
from datetime import datetime, timedelta

# Initialize client
auth = BasicAuth(username="api-automation", password="password", domain="contoso")
client = KeyfactorClient(hostname="keyfactor.contoso.com", auth=auth)

# Find certificates expiring in 30 days
renewal_threshold = datetime.now() + timedelta(days=30)
certs_to_renew = client.certificates.list(
    query=f"ValidTo<={renewal_threshold.strftime('%Y-%m-%d')} AND Metadata.automated=true"
)

print(f"Found {len(certs_to_renew)} certificates to renew")

for cert in certs_to_renew:
    print(f"Renewing {cert.subject}...")
    
    try:
        # Request renewal
        new_cert = client.certificates.renew(cert.id)
        
        # Deploy to stores
        for location in cert.locations:
            client.certificates.deploy(
                certificate_id=new_cert.id,
                store_id=location.id,
                alias=location.alias
            )
        
        print(f"  ✓ Renewed and deployed: {new_cert.thumbprint}")
        
    except Exception as e:
        print(f"  ✗ Failed: {e}")
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 2 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| Keyfactor Community | General questions | Best effort |

#### When to Escalate

- SDK bugs or unexpected behavior
- API authentication issues
- Rate limiting problems
- Missing API endpoints in SDK

#### Debugging

```python
# Enable debug logging
import logging
logging.basicConfig(level=logging.DEBUG)

from keyfactor import KeyfactorClient
client = KeyfactorClient(hostname="keyfactor.contoso.com", auth=auth, debug=True)

# View raw API requests/responses
```

---

### Troubleshooting Guide

#### Issue 1: "Authentication Failed" Error

**Symptoms**:
```python
keyfactor.exceptions.AuthenticationError: 401 Unauthorized
```

**Diagnosis**:
```python
# Test credentials manually
import requests
response = requests.get(
    "https://keyfactor.contoso.com/KeyfactorAPI/Certificates",
    auth=("api-automation", "password"),
    headers={"X-Keyfactor-Domain": "contoso"}
)
print(response.status_code, response.text)
```

**Resolution**:

1. **Verify Credentials**:
   ```python
   # Check username, password, and domain
   auth = BasicAuth(
       username="api-automation",
       password="CorrectPassword",
       domain="contoso"  # Case-sensitive!
   )
   ```

2. **Check API User Permissions**:
   - Navigate to Keyfactor Command UI
   - **Security** → **API Users** → Verify user has correct roles

3. **Use OAuth Instead** (recommended):
   ```python
   from keyfactor.auth import OAuthAuth
   
   auth = OAuthAuth(
       token_url="https://keyfactor.contoso.com/oauth/token",
       client_id="api-client",
       client_secret="secret"
   )
   ```

---

#### Issue 2: "Template Not Found" During Enrollment

**Symptoms**:
```python
keyfactor.exceptions.APIError: Template 'WebServerTemplate' not found
```

**Diagnosis**:
```python
# List available templates
templates = client.templates.list()
for template in templates:
    print(f"{template.id}: {template.common_name}")
```

**Resolution**:

1. **Use Correct Template Name**:
   - Template names are case-sensitive
   - Use exact name from Keyfactor Command UI

2. **Check Template Permissions**:
   - API user must have permission to use template
   - Verify in **Certificate Templates** → **Security**

---

#### Issue 3: Rate Limiting / 429 Too Many Requests

**Symptoms**:
```python
keyfactor.exceptions.RateLimitError: 429 Too Many Requests
```

**Diagnosis**:
```python
# Check rate limit headers
response = client._last_response
print(f"Rate Limit: {response.headers.get('X-Rate-Limit-Limit')}")
print(f"Remaining: {response.headers.get('X-Rate-Limit-Remaining')}")
print(f"Reset: {response.headers.get('X-Rate-Limit-Reset')}")
```

**Resolution**:

1. **Implement Exponential Backoff**:
   ```python
   import time
   from keyfactor.exceptions import RateLimitError
   
   def enroll_with_retry(request, max_retries=5):
       for attempt in range(max_retries):
           try:
               return client.certificates.enroll(request)
           except RateLimitError as e:
               if attempt < max_retries - 1:
                   wait_time = 2 ** attempt  # Exponential backoff
                   print(f"Rate limited. Waiting {wait_time}s...")
                   time.sleep(wait_time)
               else:
                   raise
   ```

2. **Reduce Request Rate**:
   ```python
   # Add delays between requests
   for request in bulk_requests:
       cert = client.certificates.enroll(request)
       time.sleep(0.5)  # 500ms delay
   ```

---

### Best Practices

#### Error Handling

```python
from keyfactor.exceptions import (
    AuthenticationError,
    APIError,
    RateLimitError,
    ValidationError
)

try:
    cert = client.certificates.enroll(request)
except AuthenticationError:
    print("Authentication failed - check credentials")
except ValidationError as e:
    print(f"Invalid request: {e.details}")
except RateLimitError:
    print("Rate limited - implement backoff")
except APIError as e:
    print(f"API error: {e.status_code} - {e.message}")
```

#### Connection Pooling

```python
# Reuse client instance across requests
# Don't create new client for each operation

# Good:
client = KeyfactorClient(hostname="keyfactor.contoso.com", auth=auth)
for i in range(100):
    cert = client.certificates.get(cert_ids[i])

# Bad:
for i in range(100):
    client = KeyfactorClient(hostname="keyfactor.contoso.com", auth=auth)
    cert = client.certificates.get(cert_ids[i])
```

#### Pagination

```python
# Handle large result sets with pagination
all_certs = []
page = 1
page_size = 100

while True:
    certs = client.certificates.list(
        page=page,
        page_size=page_size
    )
    
    if not certs:
        break
    
    all_certs.extend(certs)
    page += 1

print(f"Total certificates: {len(all_certs)}")
```

---

### Related Documentation

- [Keyfactor Command API Documentation](https://software.keyfactor.com/Guides/CommandAPI/)
- [Python SDK GitHub Repository](https://github.com/Keyfactor/keyfactor-python-client)
- [06-Automation-Playbooks.md](./06-Automation-Playbooks.md) - Python automation examples

---

## 12. EJBCA Python Client SDK

**Repository**: [https://github.com/Keyfactor/ejbca-python-client-sdk](https://github.com/Keyfactor/ejbca-python-client-sdk)  
**Language**: Python  
**Stars**: 15 ⭐

### Overview

Official Python SDK for EJBCA REST API. Provides programmatic access to EJBCA operations including enrollment, revocation, CRL management, and CA administration.

### Implementation Phase

**Phase 2**: CA & HSM Foundation (Weeks 6-9)  
**Phase 3**: Enrollment Rails & Self-Service (Weeks 10-12)

### Use Cases

- Automated certificate enrollment via EJBCA
- Custom RA (Registration Authority) portal development
- Integration with existing Python applications
- Bulk certificate operations
- CRL and OCSP management automation

---

### Implementation Guide

#### Prerequisites

- **Python**: 3.7+
- **EJBCA**: 7.4+ with REST API enabled
- **API Credentials**: Client certificate or OAuth token
- **Network Access**: HTTPS access to EJBCA REST API

####Installation Steps

**Step 1: Install SDK**

```bash
# Via pip
pip install ejbca-python-client-sdk

# Or from source
git clone https://github.com/Keyfactor/ejbca-python-client-sdk.git
cd ejbca-python-client-sdk
pip install -e .

# Verify installation
python -c "import ejbca_client; print(ejbca_client.__version__)"
```

**Step 2: Configure EJBCA REST API**

```bash
# SSH to EJBCA server
# Verify REST API is enabled
curl -k https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1/ca/status

# If not enabled, enable in ejbca.properties:
# rest.api.enabled=true
# systemctl restart wildfly
```

**Step 3: Generate Client Certificate for API**

```bash
# In EJBCA Admin UI:
# 1. RA Web → Make New Request
# 2. Select End Entity Profile: "RESTAPIAccess"
# 3. Certificate Profile: "RESTAPIClient"
# 4. CN: api-client
# 5. Download certificate and key

# Convert to PEM format
openssl pkcs12 -in api-client.p12 -out api-client.pem -nodes
openssl pkcs12 -in api-client.p12 -out api-client-key.pem -nocerts -nodes
```

**Step 4: Basic Usage Example**

```python
#!/usr/bin/env python3
# example.py - Basic EJBCA SDK usage

from ejbca_client import EJBCAClient
from ejbca_client.auth import CertificateAuth

# Initialize client with certificate authentication
auth = CertificateAuth(
    cert_file="/path/to/api-client.pem",
    key_file="/path/to/api-client-key.pem"
)

client = EJBCAClient(
    base_url="https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1",
    auth=auth,
    verify_ssl=True
)

# Get CA status
ca_status = client.ca.status("ManagementCA")
print(f"CA Status: {ca_status.active}")

# Enroll certificate
request = {
    "certificate_profile_name": "tlsServerProfile",
    "end_entity_profile_name": "tlsServerEndEntityProfile",
    "certificate_authority_name": "ManagementCA",
    "username": "webapp01",
    "password": "enrollmentPassword123",
    "subject_dn": "CN=webapp01.contoso.com",
    "subject_alt_names": ["DNS:webapp01.contoso.com", "DNS:www.webapp01.contoso.com"]
}

cert_response = client.certificate.enroll_pkcs10(request)
print(f"Certificate enrolled: {cert_response.certificate}")
```

---

### Operations Guide

#### Common Operations

**Certificate Enrollment**

```python
#!/usr/bin/env python3
# enroll-certificate.py

from ejbca_client import EJBCAClient
from ejbca_client.auth import CertificateAuth
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend
import datetime

# Initialize client
auth = CertificateAuth(cert_file="api-client.pem", key_file="api-client-key.pem")
client = EJBCAClient(base_url="https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1", auth=auth)

# Generate key pair
private_key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048,
    backend=default_backend()
)

# Create CSR
csr = x509.CertificateSigningRequestBuilder().subject_name(x509.Name([
    x509.NameAttribute(NameOID.COMMON_NAME, "webapp01.contoso.com"),
    x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Contoso Ltd"),
])).add_extension(
    x509.SubjectAlternativeName([
        x509.DNSName("webapp01.contoso.com"),
        x509.DNSName("www.webapp01.contoso.com"),
    ]),
    critical=False,
).sign(private_key, hashes.SHA256(), backend=default_backend())

# Enroll with EJBCA
request = {
    "certificate_request": csr.public_bytes(serialization.Encoding.PEM).decode(),
    "certificate_profile_name": "tlsServerProfile",
    "end_entity_profile_name": "tlsServerEndEntityProfile",
    "certificate_authority_name": "ManagementCA",
    "username": "webapp01",
    "password": "enrollmentPassword123"
}

response = client.certificate.enroll_pkcs10(request)
print(f"Certificate enrolled successfully")

# Save certificate and private key
with open("webapp01.crt", "w") as f:
    f.write(response.certificate)

with open("webapp01.key", "w") as f:
    f.write(private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption()
    ).decode())
```

**Certificate Revocation**

```python
#!/usr/bin/env python3
# revoke-certificate.py

from ejbca_client import EJBCAClient
from ejbca_client.auth import CertificateAuth

# Initialize client
auth = CertificateAuth(cert_file="api-client.pem", key_file="api-client-key.pem")
client = EJBCAClient(base_url="https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1", auth=auth)

# Revoke certificate
cert_serial = "1234567890ABCDEF"
issuer_dn = "CN=ManagementCA,O=Contoso,C=US"

client.certificate.revoke(
    issuer_dn=issuer_dn,
    certificate_serial_number=cert_serial,
    reason="keyCompromise"  # or: cessationOfOperation, superseded, etc.
)

print(f"Certificate {cert_serial} revoked successfully")
```

**CRL Management**

```python
#!/usr/bin/env python3
# download-crl.py

from ejbca_client import EJBCAClient
from ejbca_client.auth import CertificateAuth

# Initialize client
auth = CertificateAuth(cert_file="api-client.pem", key_file="api-client-key.pem")
client = EJBCAClient(base_url="https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1", auth=auth)

# Download latest CRL
crl = client.ca.get_latest_crl("ManagementCA")

# Save to file
with open("ManagementCA.crl", "wb") as f:
    f.write(crl)

print("CRL downloaded successfully")

# Check CRL info
from cryptography import x509
from cryptography.hazmat.backends import default_backend

crl_obj = x509.load_der_x509_crl(crl, default_backend())
print(f"CRL Issuer: {crl_obj.issuer}")
print(f"Last Update: {crl_obj.last_update}")
print(f"Next Update: {crl_obj.next_update}")
print(f"Revoked Certificates: {len(crl_obj)}")
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 2 business days |
| Keyfactor Community | General questions | Best effort |
| EJBCA Support | Enterprise license holders | Per support contract |

#### When to Escalate

- SDK bugs or crashes
- API authentication issues
- Missing REST API endpoints
- EJBCA server errors (500s)

#### Debugging

```python
# Enable debug logging
import logging
logging.basicConfig(level=logging.DEBUG)

from ejbca_client import EJBCAClient
client = EJBCAClient(base_url="...", auth=auth, debug=True)

# View raw HTTP requests/responses
```

---

### Troubleshooting Guide

#### Issue 1: "SSL Certificate Verification Failed"

**Symptoms**:
```python
ssl.SSLError: [SSL: CERTIFICATE_VERIFY_FAILED]
```

**Diagnosis**:
```bash
# Test EJBCA SSL certificate
openssl s_client -connect ejbca.contoso.com:443 -showcerts

# Check certificate chain
curl -v https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1/ca/status
```

**Resolution**:

1. **Add CA Certificate to Trust Store**:
   ```python
   client = EJBCAClient(
       base_url="https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1",
       auth=auth,
       verify_ssl="/path/to/ca-bundle.pem"
   )
   ```

2. **Disable SSL Verification** (development only):
   ```python
   client = EJBCAClient(
       base_url="https://ejbca.contoso.com/ejbca/ejbca-rest-api/v1",
       auth=auth,
       verify_ssl=False  # NOT recommended for production
   )
   ```

---

#### Issue 2: "403 Forbidden - Insufficient Privileges"

**Symptoms**:
```python
ejbca_client.exceptions.APIError: 403 Forbidden
Error: User does not have permission for requested operation
```

**Diagnosis**:
```python
# Check client certificate permissions
# View certificate subject
from cryptography import x509
with open("api-client.pem", "rb") as f:
    cert = x509.load_pem_x509_certificate(f.read())
    print(f"Subject: {cert.subject}")
```

**Resolution**:

1. **Verify Client Certificate Role in EJBCA**:
   - Log into EJBCA Admin UI
   - **System Functions** → **Roles and Access Rules**
   - Ensure client certificate is mapped to role with REST API permissions
   - Required rules: `/ca/<ca-name>/`, `/endentityprofilesrules/<profile>/`, `/certificate_profilesrules/<profile>/`

2. **Re-issue Client Certificate with Correct Profile**:
   ```bash
   # Use End Entity Profile that grants REST API access
   # Certificate Profile should include "REST API Client" template
   ```

---

#### Issue 3: "User Already Exists" During Enrollment

**Symptoms**:
```python
ejbca_client.exceptions.ConflictError: 409 Conflict
Error: End entity 'webapp01' already exists
```

**Diagnosis**:
```python
# Check if end entity exists
try:
    entity = client.end_entity.get("webapp01")
    print(f"End entity status: {entity.status}")
except:
    print("End entity does not exist")
```

**Resolution**:

1. **Clear Old End Entity**:
   ```python
   # Option A: Delete end entity
   client.end_entity.delete("webapp01")
   
   # Option B: Use unique username with timestamp
   import time
   username = f"webapp01-{int(time.time())}"
   ```

2. **Enable "Reuse End Entity"**:
   - In EJBCA Admin UI
   - **End Entity Profiles** → Select profile
   - Check "Allow same end entity to be re-issued"

---

### Best Practices

#### Connection Pooling

```python
# Reuse client instance
client = EJBCAClient(base_url="...", auth=auth)

# Good: Single client for multiple operations
for i in range(100):
    cert = client.certificate.get(serial_numbers[i])

# Bad: Creating new client each time
for i in range(100):
    client = EJBCAClient(base_url="...", auth=auth)
    cert = client.certificate.get(serial_numbers[i])
```

#### Error Handling

```python
from ejbca_client.exceptions import (
    AuthenticationError,
    APIError,
    ConflictError,
    NotFoundError
)

try:
    cert = client.certificate.enroll_pkcs10(request)
except AuthenticationError:
    print("Authentication failed - check client certificate")
except ConflictError:
    print("End entity already exists")
except NotFoundError:
    print("CA or profile not found")
except APIError as e:
    print(f"API error: {e.status_code} - {e.message}")
```

---

### Related Documentation

- [EJBCA REST API Documentation](https://doc.primekey.com/ejbca/ejbca-operations/ejbca-rest-api)
- [EJBCA Community Edition](#1-ejbca-community-edition)
- [06-Automation-Playbooks.md](./06-Automation-Playbooks.md) - EJBCA automation examples

---

## 13. HashiCorp Vault PAM Provider

**Repository**: [https://github.com/Keyfactor/hashicorp-vault-pam-provider](https://github.com/Keyfactor/hashicorp-vault-pam-provider)  
**Language**: Go  
**Stars**: 11 ⭐

### Overview

Privileged Access Management (PAM) provider for HashiCorp Vault. Enables Keyfactor Orchestrators to retrieve credentials from Vault for accessing certificate stores and target systems.

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Securely store orchestrator credentials in Vault
- Dynamic credential rotation for certificate stores
- Centralized secrets management
- Audit trail for credential access

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator
- **HashiCorp Vault**: 1.10+
- **Vault Authentication**: AppRole, Kubernetes, or other method
- **Network Access**: HTTP/HTTPS access to Vault API

#### Installation Steps

**Step 1: Configure HashiCorp Vault**

```bash
# Enable KV secrets engine
vault secrets enable -path=keyfactor kv-v2

# Create policy for Keyfactor access
vault policy write keyfactor-orchestrator - <<EOF
path "keyfactor/data/*" {
  capabilities = ["read"]
}
EOF

# Create AppRole for orchestrator
vault auth enable approle
vault write auth/approle/role/keyfactor-orchestrator \
  secret_id_ttl=0 \
  token_ttl=1h \
  token_max_ttl=4h \
  policies="keyfactor-orchestrator"

# Get Role ID and Secret ID
vault read auth/approle/role/keyfactor-orchestrator/role-id
vault write -f auth/approle/role/keyfactor-orchestrator/secret-id
```

**Step 2: Store Credentials in Vault**

```bash
# Store IIS server credentials
vault kv put keyfactor/iis-servers/webapp01 \
  username="CONTOSO\orchestrator-svc" \
  password="SecurePassword123!"

# Store F5 API credentials
vault kv put keyfactor/f5-devices/f5-lb01 \
  api_key="ABCDEF1234567890"

# Store Azure Key Vault credentials
vault kv put keyfactor/azure/keyvault \
  client_id="12345678-1234-1234-1234-123456789012" \
  client_secret="SecretValue" \
  tenant_id="87654321-4321-4321-4321-210987654321"
```

**Step 3: Install PAM Provider Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/hashicorp-vault-pam-provider/releases/latest/download/HashiCorpVault-PAM.zip" `
  -OutFile "C:\Temp\HashiCorpVault-PAM.zip"

# Extract to orchestrator PAM providers folder
Expand-Archive -Path "C:\Temp\HashiCorpVault-PAM.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\PAM\HashiCorpVault"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 4: Configure PAM Provider in Keyfactor Command**

1. **Settings** → **PAM Providers** → **Add Provider**
2. Configure:
   - Type: `HashiCorp Vault`
   - Vault Address: `https://vault.contoso.com:8200`
   - Auth Method: `approle`
   - Role ID: `<from step 1>`
   - Secret ID: `<from step 1>`
   - Mount Path: `keyfactor`
3. **Test Connection** → **Save**

**Step 5: Use PAM Provider in Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → Edit store
2. **Credentials** → Select "Use PAM Provider"
3. PAM Provider: `HashiCorp Vault`
4. Secret Path: `keyfactor/iis-servers/webapp01`
5. Username Field: `username`
6. Password Field: `password`
7. **Save**

---

### Operations Guide

#### Daily Operations

**Rotate Credentials**

```bash
# Update password in Vault
vault kv put keyfactor/iis-servers/webapp01 \
  username="CONTOSO\orchestrator-svc" \
  password="NewSecurePassword456!"

# Orchestrator will automatically fetch new password on next run
# No need to update Keyfactor Command configuration
```

**Monitor PAM Access**

```bash
# View Vault audit logs
vault audit enable file file_path=/var/log/vault-audit.log

# Query for Keyfactor access
grep "keyfactor" /var/log/vault-audit.log | jq .

# View who accessed specific secret
vault kv metadata get keyfactor/iis-servers/webapp01
```

**Renew AppRole Token**

```bash
# AppRole tokens auto-renew, but can be manually refreshed
vault write -f auth/approle/role/keyfactor-orchestrator/secret-id

# Update Secret ID in Keyfactor PAM Provider settings if needed
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 3 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| HashiCorp Support | Vault issues | Per HashiCorp contract |

#### When to Escalate

- PAM provider authentication failures
- Vault connectivity issues
- Credential retrieval failures
- Token renewal issues

#### Logs to Collect

**Orchestrator Logs**:
```powershell
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\PAM-HashiCorpVault.log" -Tail 500
```

**Vault Audit Logs**:
```bash
tail -100 /var/log/vault-audit.log | jq '.'
```

---

### Troubleshooting Guide

#### Issue 1: "Permission Denied" When Accessing Secret

**Symptoms**:
```
PAM Provider error: 403 Forbidden
Error: Permission denied accessing keyfactor/iis-servers/webapp01
```

**Diagnosis**:
```bash
# Test Vault access with AppRole
vault login -method=approle role_id=<ROLE_ID> secret_id=<SECRET_ID>

# Try to read secret
vault kv get keyfactor/iis-servers/webapp01
```

**Resolution**:

1. **Verify Policy Permissions**:
   ```bash
   # Check policy
   vault policy read keyfactor-orchestrator
   
   # Ensure it includes:
   # path "keyfactor/data/*" {
   #   capabilities = ["read"]
   # }
   ```

2. **Update Policy**:
   ```bash
   vault policy write keyfactor-orchestrator - <<EOF
   path "keyfactor/data/*" {
     capabilities = ["read", "list"]
   }
   path "keyfactor/metadata/*" {
     capabilities = ["read", "list"]
   }
   EOF
   ```

---

#### Issue 2: "Token Expired" Error

**Symptoms**:
```
PAM Provider error: 403 permission denied
Error: Token has expired
```

**Diagnosis**:
```bash
# Check token TTL
vault token lookup

# View AppRole token settings
vault read auth/approle/role/keyfactor-orchestrator
```

**Resolution**:

1. **Increase Token TTL**:
   ```bash
   vault write auth/approle/role/keyfactor-orchestrator \
     token_ttl=24h \
     token_max_ttl=48h \
     token_renewable=true
   ```

2. **Enable Auto-Renewal in PAM Provider**:
   - In Keyfactor PAM Provider settings
   - Enable "Auto-Renew Token"
   - Set renewal threshold to 80% of TTL

---

#### Issue 3: "Secret Not Found"

**Symptoms**:
```
PAM Provider error: 404 Not Found
Error: Secret keyfactor/iis-servers/webapp01 not found
```

**Diagnosis**:
```bash
# List all secrets in path
vault kv list keyfactor/

# Check exact secret path
vault kv get keyfactor/iis-servers/webapp01
```

**Resolution**:

1. **Verify Secret Path**:
   - KV v2 secrets use `/data/` in API path
   - PAM provider should use logical path: `keyfactor/iis-servers/webapp01`
   - Not the API path: `keyfactor/data/iis-servers/webapp01`

2. **Create Missing Secret**:
   ```bash
   vault kv put keyfactor/iis-servers/webapp01 \
     username="user" \
     password="pass"
   ```

---

### Security Hardening

#### Use Kubernetes Auth Instead of AppRole

```bash
# For orchestrators running in Kubernetes
vault auth enable kubernetes

vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

vault write auth/kubernetes/role/keyfactor-orchestrator \
  bound_service_account_names=keyfactor-orchestrator \
  bound_service_account_namespaces=keyfactor \
  policies=keyfactor-orchestrator \
  ttl=1h
```

#### Enable Vault Audit Logging

```bash
# Log all access to secrets
vault audit enable file file_path=/var/log/vault-audit.log

# Or send to syslog
vault audit enable syslog tag="vault" facility="LOCAL7"
```

#### Implement Secret Rotation

```bash
# Automate credential rotation
vault write keyfactor/config \
  max_lease_ttl=2160h \  # 90 days
  default_lease_ttl=720h  # 30 days

# Set up rotation script
cat > rotate-credentials.sh <<EOF
#!/bin/bash
# Generate new password
NEW_PASS=\$(openssl rand -base64 32)

# Update in Vault
vault kv put keyfactor/iis-servers/webapp01 \
  username="CONTOSO\orchestrator-svc" \
  password="\$NEW_PASS"

# Update actual system (Windows)
net user orchestrator-svc "\$NEW_PASS" /domain
EOF

chmod +x rotate-credentials.sh
```

---

### Related Documentation

- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Keyfactor PAM Provider Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [11-Security-Controls.md](./11-Security-Controls.md) - Secrets management architecture

---

## 14. CyberArk PAM Provider

**Repository**: [https://github.com/Keyfactor/cyberark-pam-provider](https://github.com/Keyfactor/cyberark-pam-provider)  
**Language**: C#  
**Stars**: 7 ⭐

### Overview

Privileged Access Management (PAM) provider for CyberArk. Enables Keyfactor Orchestrators to retrieve credentials from CyberArk vaults for accessing certificate stores and target systems.

### Implementation Phase

**Phase 4**: Orchestration & Zero-Touch Operations (Weeks 13-16)

### Use Cases

- Enterprise-grade secrets management for orchestrator credentials
- Integration with existing CyberArk deployments
- Automated credential rotation with CyberArk CPM
- Compliance and audit trail for credential access

---

### Implementation Guide

#### Prerequisites

- **Keyfactor Command**: 10.x+ with Universal Orchestrator
- **CyberArk**: Privileged Access Security (PAS) 11.x+
- **CyberArk Credentials**: Safe permissions and application registration
- **Network Access**: HTTPS access to CyberArk Central Credential Provider (CCP) or REST API

#### Installation Steps

**Step 1: Configure CyberArk Safe**

```powershell
# Create safe for Keyfactor credentials
# In CyberArk PrivateArk Client or PVWA:
# 1. Tools → Administrative Tools → PrivateArk Client
# 2. Right-click Safes → Add Safe
#    - Safe Name: Keyfactor-Orchestrator
#    - Description: Credentials for Keyfactor certificate orchestration
#    - Managing CPM: PasswordManager
# 3. Add safe members:
#    - Keyfactor-Orchestrator-App (application user)
#    - Permissions: List, Retrieve
```

**Step 2: Store Credentials in CyberArk**

```powershell
# Via PVWA UI:
# 1. Open Safe: Keyfactor-Orchestrator
# 2. Add Account:
#    - Address: webapp01.contoso.com
#    - Username: CONTOSO\orchestrator-svc
#    - Platform: Windows Domain Account
#    - Password: SecurePassword123!
#    - Account Name: webapp01-orchestrator-creds

# Or via CLI (using PACLI):
pacli account add safe="Keyfactor-Orchestrator" \
  folder="Root" \
  file="webapp01-orchestrator-creds" \
  name="CONTOSO\orchestrator-svc" \
  address="webapp01.contoso.com" \
  platform="Windows Domain Account" \
  password="SecurePassword123!"
```

**Step 3: Configure Central Credential Provider (CCP)**

```bash
# Install CCP if not already installed
# Configure application in CyberArk:
# 1. PVWA → Applications → Add Application
#    - Application ID: Keyfactor-Orchestrator-App
#    - Description: Keyfactor Universal Orchestrator
#    - Authentication: OS User or Certificate
#    - Allowed Machines: <orchestrator-server-hostname>

# Configure CCP credential file
vim /etc/opt/CARKaim/vault/QueryUser.ini
# Add:
# Query=Safe=Keyfactor-Orchestrator;Folder=Root;Object=webapp01-orchestrator-creds
```

**Step 4: Install PAM Provider Extension**

```powershell
# On Keyfactor Universal Orchestrator server

# Download extension
Invoke-WebRequest -Uri "https://github.com/Keyfactor/cyberark-pam-provider/releases/latest/download/CyberArk-PAM.zip" `
  -OutFile "C:\Temp\CyberArk-PAM.zip"

# Extract to orchestrator PAM providers folder
Expand-Archive -Path "C:\Temp\CyberArk-PAM.zip" `
  -DestinationPath "C:\Program Files\Keyfactor\Keyfactor Orchestrator\extensions\PAM\CyberArk"

# Restart orchestrator service
Restart-Service "Keyfactor Orchestrator"
```

**Step 5: Configure PAM Provider in Keyfactor Command**

1. **Settings** → **PAM Providers** → **Add Provider**
2. Configure:
   - Type: `CyberArk`
   - API Method: `CCP` or `REST API`
   - CCP URL: `https://cyberark-ccp.contoso.com/AIMWebService/api/Accounts`
   - Or REST API URL: `https://cyberark.contoso.com/PasswordVault/API`
   - Application ID: `Keyfactor-Orchestrator-App`
   - Safe: `Keyfactor-Orchestrator`
   - Client Certificate: (if using certificate auth)
3. **Test Connection** → **Save**

**Step 6: Use PAM Provider in Certificate Store**

1. **Certificate Locations** → **Certificate Stores** → Edit store
2. **Credentials** → Select "Use PAM Provider"
3. PAM Provider: `CyberArk`
4. Account ID: `webapp01-orchestrator-creds`
5. Safe: `Keyfactor-Orchestrator`
6. **Save**

---

### Operations Guide

#### Daily Operations

**Rotate Credentials with CPM**

```bash
# CyberArk CPM (Central Password Manager) handles automatic rotation

# View rotation schedule
# In PVWA: Accounts → Select account → Properties
# Rotation Status: Next rotation in X days

# Force immediate rotation
# PVWA → Accounts → Select account → Actions → Change

# Orchestrator will automatically retrieve new password on next run
```

**Monitor PAM Access via CyberArk Audit**

```powershell
# Via PVWA: Reports → Privileged Account Activity
# Filter:
# - Safe: Keyfactor-Orchestrator
# - User: Keyfactor-Orchestrator-App
# - Action: Retrieve Password

# Or via API
$auth = Get-CyberArkAuth
Invoke-RestMethod -Uri "https://cyberark.contoso.com/PasswordVault/API/AuditActions" `
  -Headers @{Authorization="$auth"} `
  -Method GET
```

**Check CCP Availability**

```powershell
# Test CCP endpoint
Invoke-RestMethod -Uri "https://cyberark-ccp.contoso.com/AIMWebService/api/Accounts" `
  -Method GET `
  -Certificate $clientCert

# Expected: 200 OK or authentication challenge
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 3 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| CyberArk Support | CyberArk issues | Per CyberArk contract |

#### When to Escalate

- PAM provider authentication failures
- CCP/REST API connectivity issues
- Credential retrieval failures
- CyberArk vault unavailability

#### Logs to Collect

**Orchestrator Logs**:
```powershell
Get-Content "C:\Program Files\Keyfactor\Keyfactor Orchestrator\Logs\PAM-CyberArk.log" -Tail 500
```

**CyberArk CCP Logs** (on CCP server):
```bash
tail -100 /opt/CARKaim/logs/Aim.log
tail -100 /var/log/httpd/error_log  # If CCP is on Apache
```

**CyberArk Vault Logs** (on Vault server):
```bash
# Via PVWA: Administration → Logs → Vault Log
# Or on Vault server:
tail -100 /opt/PrivateArk/Server/Logs/ITAlog.log
```

---

### Troubleshooting Guide

#### Issue 1: "Application Not Authorized" Error

**Symptoms**:
```
PAM Provider error: 403 Forbidden
Error: Application 'Keyfactor-Orchestrator-App' is not authorized to access safe 'Keyfactor-Orchestrator'
```

**Diagnosis**:
```powershell
# Test CCP access manually
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*orchestrator*"}
Invoke-RestMethod -Uri "https://cyberark-ccp.contoso.com/AIMWebService/api/Accounts?AppID=Keyfactor-Orchestrator-App&Safe=Keyfactor-Orchestrator&Object=webapp01-orchestrator-creds" `
  -Certificate $cert
```

**Resolution**:

1. **Verify Application Registration**:
   - In PVWA: **Applications** → Find **Keyfactor-Orchestrator-App**
   - Ensure **Allowed Machines** includes orchestrator hostname
   - Check **Authentication** method matches (certificate, OS user, etc.)

2. **Grant Safe Access to Application**:
   ```powershell
   # Via PVWA:
   # Safes → Keyfactor-Orchestrator → Members → Add Member
   # User/Group: Keyfactor-Orchestrator-App
   # Permissions: List Accounts, Retrieve Accounts
   ```

3. **Verify Machine IP/Hostname**:
   - CyberArk validates requesting machine
   - Ensure orchestrator server hostname/IP is in allowed machines list

---

#### Issue 2: "Account Not Found" Error

**Symptoms**:
```
PAM Provider error: 404 Not Found
Error: Account 'webapp01-orchestrator-creds' not found in safe 'Keyfactor-Orchestrator'
```

**Diagnosis**:
```powershell
# List accounts in safe via REST API
$auth = Get-CyberArkAuth
Invoke-RestMethod -Uri "https://cyberark.contoso.com/PasswordVault/API/Accounts?search=webapp01" `
  -Headers @{Authorization="$auth"} `
  -Method GET
```

**Resolution**:

1. **Verify Account Name**:
   - Check exact account name in CyberArk (case-sensitive)
   - Account ID format: `<platform>-<address>-<username>` or custom

2. **Check Safe Name**:
   - Ensure safe name matches exactly
   - Verify application has access to specified safe

3. **Create Missing Account**:
   ```powershell
   # Via PVWA: Accounts → Add Account
   # Or via REST API:
   $body = @{
       name = "webapp01-orchestrator-creds"
       address = "webapp01.contoso.com"
       userName = "CONTOSO\orchestrator-svc"
       platformId = "WinDomain"
       safeName = "Keyfactor-Orchestrator"
       secretType = "password"
       secret = "SecurePassword123!"
   } | ConvertTo-Json

   Invoke-RestMethod -Uri "https://cyberark.contoso.com/PasswordVault/API/Accounts" `
       -Headers @{Authorization="$auth"} `
       -Method POST `
       -Body $body `
       -ContentType "application/json"
   ```

---

#### Issue 3: "SSL Certificate Validation Failed"

**Symptoms**:
```
PAM Provider error: SSL/TLS connection failed
Error: The remote certificate is invalid according to the validation procedure
```

**Diagnosis**:
```powershell
# Test SSL connection
Test-NetConnection -ComputerName cyberark-ccp.contoso.com -Port 443

# View certificate
$cert = [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Invoke-WebRequest -Uri "https://cyberark-ccp.contoso.com" -UseBasicParsing
```

**Resolution**:

1. **Add CyberArk CA to Trust Store**:
   ```powershell
   # Import CyberArk CA certificate
   Import-Certificate -FilePath "C:\Temp\cyberark-ca.cer" `
       -CertStoreLocation Cert:\LocalMachine\Root
   ```

2. **Update CyberArk Certificate**:
   - Ensure CyberArk CCP/Vault has valid certificate
   - Certificate must be trusted by orchestrator server

3. **Disable SSL Verification** (development only):
   - In PAM Provider settings
   - Set "Validate SSL Certificate" = false
   - **NOT recommended for production**

---

### Security Hardening

#### Use Certificate-Based Authentication

```powershell
# Generate client certificate for orchestrator
$cert = New-SelfSignedCertificate -DnsName "orchestrator.contoso.com" `
  -CertStoreLocation Cert:\LocalMachine\My `
  -KeyUsage DigitalSignature,KeyEncipherment `
  -KeySpec KeyExchange

# Export public key
Export-Certificate -Cert $cert -FilePath "C:\Temp\orchestrator-public.cer"

# In CyberArk:
# Applications → Keyfactor-Orchestrator-App → Authentication
# Method: Certificate Serial Number
# Add certificate thumbprint or serial number
```

#### Enable CyberArk Dual Control

```bash
# For sensitive certificate stores, require dual control:
# In PVWA: Safes → Keyfactor-Orchestrator → Properties
# Dual Control:
#   - Require dual control for file retrieval
#   - Number of authorized users: 2
#   - Authorized users: Add specific users who can approve
```

#### Implement Least Privilege

```bash
# Restrict PAM provider to specific accounts only
# In CyberArk Application:
# Allowed Safes: Keyfactor-Orchestrator
# Allowed Object Names: webapp01-*, db01-*, api01-*  (wildcard)
# Denied Object Names: *-production-*  (if needed)
```

---

### Related Documentation

- [CyberArk Central Credential Provider Documentation](https://docs.cyberark.com/Product-Doc/OnlineHelp/AAM-CP/Latest/en/Content/CP%20and%20ASCP/CCP-Using-CCP.htm)
- [CyberArk REST API Documentation](https://docs.cyberark.com/Product-Doc/OnlineHelp/PAS/Latest/en/Content/WebServices/Implementing%20Privileged%20Account%20Security%20Web%20Services%20.htm)
- [Keyfactor PAM Provider Documentation](https://software.keyfactor.com/Guides/UniversalOrchestrator/)
- [11-Security-Controls.md](./11-Security-Controls.md) - Secrets management architecture

---

## 15. Terraform Provider for Keyfactor

**Repository**: [https://github.com/Keyfactor/terraform-provider-keyfactor](https://github.com/Keyfactor/terraform-provider-keyfactor)  
**Language**: Go  
**Stars**: 34 ⭐

### Overview

Terraform provider for Keyfactor Command. Enables Infrastructure as Code (IaC) management of certificate templates, policies, stores, and orchestrators using Terraform/OpenTofu.

### Implementation Phase

**Phase 3**: Enrollment Rails & Self-Service (Weeks 10-12)  
**Phase 5**: GitOps & Policy as Code (Weeks 17-20)

### Use Cases

- Manage certificate templates as code
- Automate certificate store provisioning
- Version-controlled policy management
- Consistent multi-environment deployments
- Disaster recovery via IaC

---

### Implementation Guide

#### Prerequisites

- **Terraform**: 1.0+ or OpenTofu 1.5+
- **Keyfactor Command**: 10.x+ with API enabled
- **API Credentials**: OAuth token or Basic Auth
- **Git**: For version control (recommended)

#### Installation Steps

**Step 1: Install Terraform Provider**

```hcl
# versions.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    keyfactor = {
      source  = "Keyfactor/keyfactor"
      version = "~> 2.0"
    }
  }
}

# Configure provider
provider "keyfactor" {
  hostname = "keyfactor.contoso.com"
  username = "api-automation"
  password = var.keyfactor_password
  domain   = "contoso"
  
  # Or use OAuth
  # oauth_client_id     = var.oauth_client_id
  # oauth_client_secret = var.oauth_client_secret
  # oauth_token_url     = "https://keyfactor.contoso.com/oauth/token"
}
```

```bash
# Initialize Terraform
terraform init
```

**Step 2: Define Certificate Template**

```hcl
# templates.tf
resource "keyfactor_certificate_template" "web_server" {
  name        = "WebServerTemplate"
  description = "TLS certificate template for web servers"
  
  template_settings = {
    key_algorithm  = "RSA"
    key_size       = 2048
    validity_period = 397  # days (13 months)
    
    key_usage = [
      "DigitalSignature",
      "KeyEncipherment"
    ]
    
    extended_key_usage = [
      "ServerAuthentication",
      "ClientAuthentication"
    ]
  }
  
  subject_settings = {
    country      = "US"
    organization = "Contoso Ltd"
    
    subject_part_policy = {
      common_name = {
        required = true
        pattern  = "^[a-z0-9.-]+\\.contoso\\.com$"
      }
    }
  }
  
  san_settings = {
    dns_names = {
      allowed = true
      required = true
    }
    ip_addresses = {
      allowed = false
    }
  }
  
  metadata_fields = {
    owner_email = {
      type     = "string"
      required = true
    }
    environment = {
      type     = "string"
      required = true
      allowed_values = ["development", "staging", "production"]
    }
    cost_center = {
      type     = "string"
      required = false
    }
  }
}
```

**Step 3: Define Certificate Store**

```hcl
# stores.tf
resource "keyfactor_certificate_store" "webapp01_iis" {
  store_type = "IISB"  # IIS Binding
  
  client_machine = "webapp01.contoso.com"
  store_path     = "Default Web Site"
  
  properties = {
    SiteName   = "Default Web Site"
    Port       = "443"
    IPAddress  = "*"
    HostName   = "webapp01.contoso.com"
    SniFlag    = "1"
  }
  
  agent_id = data.keyfactor_agent.orchestrator_01.id
  
  credentials = {
    use_pam_provider = true
    pam_provider_id  = data.keyfactor_pam_provider.cyberark.id
    pam_secret_path  = "Keyfactor-Orchestrator/webapp01-orchestrator-creds"
  }
  
  inventory_schedule = "0 2 * * *"  # Daily at 2 AM
}
```

**Step 4: Deploy Configuration**

```bash
# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# View current state
terraform show
```

---

### Operations Guide

#### Common Operations

**Manage Certificate Templates**

```hcl
# templates/production.tf
resource "keyfactor_certificate_template" "api_server_prod" {
  name = "APIServerProductionTemplate"
  
  template_settings = {
    key_algorithm   = "RSA"
    key_size        = 3072  # Higher security for production
    validity_period = 365
    
    key_usage = ["DigitalSignature", "KeyEncipherment"]
    extended_key_usage = ["ServerAuthentication"]
  }
  
  approval_required = true  # Require manual approval for production
  
  allowed_requesters = [
    "CN=Platform Team,OU=Engineering,O=Contoso,C=US",
    "CN=API Team,OU=Engineering,O=Contoso,C=US"
  ]
}

# Apply changes
terraform apply -target=keyfactor_certificate_template.api_server_prod
```

**Bulk Certificate Store Management**

```hcl
# stores/web-servers.tf
locals {
  web_servers = [
    "webapp01",
    "webapp02",
    "webapp03"
  ]
}

resource "keyfactor_certificate_store" "web_servers" {
  for_each = toset(local.web_servers)
  
  store_type     = "IISB"
  client_machine = "${each.value}.contoso.com"
  store_path     = "Default Web Site"
  
  properties = {
    SiteName = "Default Web Site"
    Port     = "443"
    HostName = "${each.value}.contoso.com"
  }
  
  agent_id = data.keyfactor_agent.orchestrator_01.id
}

# Deploy all 3 stores
terraform apply
```

**Disaster Recovery**

```bash
# Export current configuration
terraform show -json > keyfactor-backup.json

# In disaster scenario, rebuild from code:
git clone https://github.com/contoso/keyfactor-terraform.git
cd keyfactor-terraform
terraform init
terraform apply -auto-approve

# All templates, policies, and stores recreated from code
```

---

### Support & Escalation

#### Support Channels

| Channel | Purpose | Response SLA |
|---------|---------|--------------|
| GitHub Issues | Bug reports, feature requests | 2 business days |
| Keyfactor Support | Enterprise customers | Per support contract |
| HashiCorp Community | Terraform questions | Community support |

#### When to Escalate

- Provider bugs or crashes
- API authentication issues
- Resource drift detection failures
- State file corruption

#### Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

terraform apply

# View detailed logs
cat terraform-debug.log | grep keyfactor
```

---

### Troubleshooting Guide

#### Issue 1: "Resource Already Exists" Error

**Symptoms**:
```
Error: resource already exists
Template 'WebServerTemplate' already exists in Keyfactor
```

**Diagnosis**:
```bash
# Check existing resources in Keyfactor
terraform import keyfactor_certificate_template.web_server "WebServerTemplate"

# Or query Keyfactor API
curl -u api-automation:password \
  "https://keyfactor.contoso.com/KeyfactorAPI/CertificateAuthority/Templates"
```

**Resolution**:

1. **Import Existing Resource**:
   ```bash
   terraform import keyfactor_certificate_template.web_server "WebServerTemplate"
   
   # Terraform will add to state file
   # Future applies will update, not create
   ```

2. **Use Different Name**:
   ```hcl
   resource "keyfactor_certificate_template" "web_server_v2" {
     name = "WebServerTemplate-v2"
     # ... rest of config
   }
   ```

---

#### Issue 2: State Drift Detected

**Symptoms**:
```
Terraform detected manual changes to resources
Template 'WebServerTemplate' has been modified outside of Terraform
```

**Diagnosis**:
```bash
# Detect drift
terraform plan -refresh-only

# View differences
terraform show
```

**Resolution**:

1. **Refresh State to Match Reality**:
   ```bash
   terraform apply -refresh-only
   ```

2. **Revert Manual Changes**:
   ```bash
   # Apply Terraform config to override manual changes
   terraform apply
   ```

3. **Prevent Future Drift**:
   - Use CI/CD to enforce Terraform-only changes
   - Implement pre-commit hooks
   - Enable Terraform Cloud drift detection

---

#### Issue 3: API Rate Limiting

**Symptoms**:
```
Error: API rate limit exceeded
Too many requests to Keyfactor API
```

**Diagnosis**:
```bash
# Check rate limit headers in debug log
export TF_LOG=DEBUG
terraform apply
grep "X-Rate-Limit" terraform-debug.log
```

**Resolution**:

1. **Reduce Parallelism**:
   ```bash
   terraform apply -parallelism=1  # Serial execution
   ```

2. **Add Delays Between Resources**:
   ```hcl
   resource "time_sleep" "wait_after_template" {
     depends_on = [keyfactor_certificate_template.web_server]
     create_duration = "5s"
   }
   
   resource "keyfactor_certificate_store" "webapp01" {
     depends_on = [time_sleep.wait_after_template]
     # ... config
   }
   ```

---

### Best Practices

#### Use Workspaces for Environments

```bash
# Create workspaces
terraform workspace new development
terraform workspace new staging
terraform workspace new production

# Deploy to specific environment
terraform workspace select production
terraform apply -var-file="production.tfvars"
```

#### Store State Remotely

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatecontoso"
    container_name       = "keyfactor-tfstate"
    key                  = "production.terraform.tfstate"
  }
}
```

#### Use Modules for Reusability

```hcl
# modules/certificate-template/main.tf
variable "name" {}
variable "validity_days" {}
variable "environment" {}

resource "keyfactor_certificate_template" "this" {
  name = var.name
  
  template_settings = {
    validity_period = var.validity_days
  }
  
  metadata_fields = {
    environment = {
      type     = "string"
      required = true
      default  = var.environment
    }
  }
}

# Use module
module "web_server_template" {
  source = "./modules/certificate-template"
  
  name          = "WebServerTemplate"
  validity_days = 397
  environment   = "production"
}
```

---

### Related Documentation

- [Terraform Provider Documentation](https://registry.terraform.io/providers/Keyfactor/keyfactor/latest/docs)
- [Keyfactor Command API Documentation](https://software.keyfactor.com/Guides/CommandAPI/)
- [03-Policy-Catalog.md](./03-Policy-Catalog.md) - Certificate templates and policies
- [17-Architecture-Decision-Records.md](./17-Architecture-Decision-Records.md) - IaC decisions

---

## Summary

This guide has provided comprehensive implementation, operations, support, and troubleshooting documentation for all 15 Keyfactor integrations:

### Core Components (1-4)
1. ✅ EJBCA Community Edition
2. ✅ EJBCA Vault PKI Engine
3. ✅ EJBCA cert-manager Issuer
4. ✅ Command cert-manager Issuer

### Universal Orchestrators (5-10)
5. ✅ Azure Key Vault Orchestrator
6. ✅ AWS Certificate Manager Orchestrator
7. ✅ IIS/Windows Certificate Store Orchestrator
8. ✅ Remote File Orchestrator
9. ✅ F5 Networks REST Orchestrator
10. ✅ Palo Alto Firewall Orchestrator

### SDKs & Automation (11-12)
11. ✅ Keyfactor Python Client SDK
12. ✅ EJBCA Python Client SDK

### PAM Providers (13-14)
13. ✅ HashiCorp Vault PAM Provider
14. ✅ CyberArk PAM Provider

### Infrastructure as Code (15)
15. ✅ Terraform Provider for Keyfactor

---

**All integrations are production-ready and include**:
- Complete installation procedures
- Daily operational guidance
- Support escalation paths
- Comprehensive troubleshooting
- Performance tuning recommendations
- Security hardening guidelines

For questions or support, contact:

**Author**: Adrian Johnson  
**Email**: adrian207@gmail.com  
**Version**: 1.0  
**Date**: October 22, 2025

---

**End of Keyfactor Integrations Guide**

