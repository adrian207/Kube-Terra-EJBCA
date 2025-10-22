# Keyfactor Incident Response Procedures
## Troubleshooting and Emergency Response Guide

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use - Restricted  
**Target Audience**: On-call engineers, security team, operations

---

## Document Purpose

This document provides comprehensive incident response procedures, troubleshooting guides, and emergency protocols for the Keyfactor certificate lifecycle management platform. It covers common issues, root cause analysis, and step-by-step resolution procedures.

---

## Table of Contents

1. [Incident Classification](#1-incident-classification)
2. [Incident Response Framework](#2-incident-response-framework)
3. [Common Issues and Resolution](#3-common-issues-and-resolution)
4. [Emergency Procedures](#4-emergency-procedures)
5. [Root Cause Analysis](#5-root-cause-analysis)
6. [Post-Incident Review](#6-post-incident-review)
7. [Troubleshooting Decision Trees](#7-troubleshooting-decision-trees)
8. [Known Issues and Workarounds](#8-known-issues-and-workarounds)

---

## 1. Incident Classification

### 1.1 Severity Definitions

| Severity | Impact | Response Time | Escalation | Examples |
|----------|--------|--------------|------------|----------|
| **P1 - Critical** | Production down, complete service outage | 15 minutes | Immediate (phone) | CA offline, HSM failure, all certs expired |
| **P2 - High** | Major feature unavailable, significant impact | 1 hour | Email + Slack | Certificate issuance failing, orchestrator cluster down |
| **P3 - Medium** | Minor feature degraded, workaround available | 4 hours | Slack | Slow performance, single orchestrator down |
| **P4 - Low** | Minimal impact, cosmetic issues | 1 business day | Ticket queue | UI glitches, documentation errors |

### 1.2 Classification Decision Tree

```
┌─────────────────────────────────────────┐
│ Is production service affected?         │
└────────────┬────────────────────────────┘
             │
      ┌──────┴──────┐
      │ YES         │ NO → P4 (Low)
      v             
┌─────────────────┐
│ Is there a      │
│ workaround?     │
└────┬────────────┘
     │
  ┌──┴──┐
  │YES │NO
  v     v
 P2    P1
(High) (Critical)
```

---

## 2. Incident Response Framework

### 2.1 Response Workflow

**Phase 1: Detection** (0-5 minutes)
```
Alert received → Acknowledge → Initial assessment → Classify severity
```

**Phase 2: Containment** (5-30 minutes)
```
Stop spread → Protect critical systems → Implement workaround if available
```

**Phase 3: Investigation** (30min-4 hours)
```
Gather logs → Identify root cause → Develop resolution plan
```

**Phase 4: Resolution** (Variable)
```
Implement fix → Test → Verify → Monitor
```

**Phase 5: Recovery** (Variable)
```
Restore services → Verify functionality → Update monitoring
```

**Phase 6: Post-Incident** (1-7 days)
```
Document incident → Root cause analysis → Preventive actions → Update runbooks
```

---

### 2.2 Communication Templates

#### P1 - Critical Incident Announcement

**Slack Channel**: `#pki-incidents`  
**Email**: All stakeholders

```
🚨 P1 INCIDENT - KEYFACTOR CERTIFICATE PLATFORM

Incident ID: INC-2025-1022-001
Severity: P1 - Critical
Start Time: 2025-10-22 14:30 EST
Status: INVESTIGATING

Impact:
- Certificate issuance unavailable
- Renewals blocked
- Production services affected: [List affected services]

Current Actions:
- On-call team investigating
- Failover to backup CA initiated
- ETA for resolution: TBD (next update in 30 minutes)

Incident Lead: [Name]
War Room: [Teams/Zoom link]
Status Page: https://status.contoso.com/pki

Updates will be provided every 30 minutes until resolved.
```

#### Incident Resolution Announcement

```
✅ INCIDENT RESOLVED - INC-2025-1022-001

Incident: Certificate issuance unavailable
Severity: P1 - Critical
Duration: 2 hours 15 minutes
Resolution Time: 2025-10-22 16:45 EST

Resolution:
- Primary CA connection restored
- All pending certificate requests processed
- Services verified operational

Root Cause: [Brief description]
Preventive Actions: [Planned improvements]

Post-Incident Review: Scheduled for 2025-10-24 10:00 EST

Thank you for your patience.
```

---

### 2.3 Incident Roles and Responsibilities

| Role | Responsibilities | On-Call | Training Required |
|------|-----------------|---------|-------------------|
| **Incident Commander** | Overall response coordination, communication | Yes | Incident Management 101 |
| **Technical Lead** | Root cause analysis, resolution implementation | Yes | Platform expert |
| **Communications Lead** | Stakeholder updates, status page | No | Communication protocols |
| **Subject Matter Expert** | Specialized knowledge (HSM, CA, etc.) | On-demand | Component expertise |
| **Scribe** | Documentation, timeline tracking | No | None |

---

## 3. Common Issues and Resolution

### 3.1 Certificate Issuance Failures

#### Issue: "Certificate request fails immediately"

**Symptoms**:
- Request status changes to "Failed" within seconds
- Error message in request details
- No certificate generated

**Common Causes and Solutions**:

| Error Message | Root Cause | Solution | Estimated Time |
|--------------|------------|----------|----------------|
| "CA unavailable" | CA offline or network issue | 1. Check CA status<br>2. Verify network connectivity<br>3. Restart CA if needed | 15 minutes |
| "Policy violation" | CSR doesn't meet template requirements | 1. Review template policy<br>2. Regenerate CSR with correct params<br>3. Resubmit | 10 minutes |
| "Duplicate certificate" | Active cert exists for same SAN | 1. Revoke old certificate<br>2. Wait 5 minutes<br>3. Retry request | 10 minutes |
| "Invalid CSR" | Malformed CSR or wrong format | 1. Validate CSR with openssl<br>2. Regenerate CSR<br>3. Ensure PEM/DER format | 15 minutes |
| "SAN not authorized" | User doesn't own requested hostname | 1. Verify asset inventory<br>2. Update ownership<br>3. Retry | 30 minutes |

**Detailed Troubleshooting** (CA Unavailable):

1. **Verify CA Status**
   ```powershell
   # Windows CA
   Get-Service -Name certsvc
   certutil -ping
   
   # Check CA cert validity
   certutil -CAInfo
   ```

2. **Check Network Connectivity**
   ```powershell
   Test-NetConnection -ComputerName ca-server.contoso.com -Port 135
   Test-NetConnection -ComputerName ca-server.contoso.com -Port 445
   ```

3. **Review CA Event Logs**
   ```powershell
   Get-WinEvent -LogName "Application" -Source "Microsoft-Windows-CertificationAuthority" -MaxEvents 50
   ```

4. **Restart CA Service** (if needed)
   ```powershell
   Restart-Service -Name certsvc
   Start-Sleep -Seconds 30
   certutil -ping
   ```

5. **Verify in Keyfactor**
   ```
   Navigation: Certificate Authorities → [Select CA] → Test Connection
   Expected: "Connection successful"
   ```

---

#### Issue: "Certificate request stuck in 'Pending' status"

**Symptoms**:
- Request submitted hours/days ago
- Still shows "Pending" status
- No progress or updates

**Troubleshooting Steps**:

1. **Check Approval Status**
   ```
   Navigation: Certificates → Requests → [Find request] → View Details
   Look for: "Pending Approval" or "Awaiting Action"
   ```

2. **Review Approval Workflow**
   ```sql
   -- Check approval status in database
   SELECT 
       RequestID,
       RequestTime,
       CurrentApprover,
       ApprovalStatus,
       DATEDIFF(HOUR, RequestTime, GETDATE()) AS HoursPending
   FROM CertificateApprovals
   WHERE RequestID = 'REQ-12345'
   ORDER BY ApprovalStepOrder;
   ```

3. **Common Resolutions**:
   - **Approver on vacation**: Reassign to backup approver
   - **Email not delivered**: Resend approval request
   - **Approval expired**: Resubmit with updated justification
   - **Workflow stuck**: Reset workflow state (requires admin)

4. **Force Approval** (Emergency Only - with authorization):
   ```powershell
   # Via Keyfactor PowerShell module
   Approve-KeyfactorCertificateRequest -RequestID "REQ-12345" -ApproverComments "Emergency approval - authorized by CISO"
   ```

---

### 3.2 Certificate Renewal Failures

#### Issue: "Automated renewal not triggering"

**Symptoms**:
- Certificates approaching expiry
- No renewal attempts logged
- Auto-renewal script not running

**Troubleshooting Decision Tree**:

```
Certificate not renewing automatically?
│
├─ Is auto-renewal enabled for this cert?
│  └─ NO → Enable in certificate metadata
│  └─ YES → Continue
│
├─ Is certificate template marked for auto-renewal?
│  └─ NO → Update template settings
│  └─ YES → Continue
│
├─ Check renewal threshold (days before expiry)
│  ├─ Cert expires in > 30 days → Wait (not yet due)
│  └─ Cert expires in < 30 days → Continue
│
├─ Check renewal script status
│  ├─ Script not running → Start scheduled task
│  ├─ Script errors → Review logs
│  └─ Script running → Continue
│
└─ Check renewal job logs
   ├─ No logs → Script not executing
   └─ Errors in logs → Review specific error
```

**Common Auto-Renewal Issues**:

1. **Renewal Script Not Running**
   ```powershell
   # Check scheduled task
   Get-ScheduledTask -TaskName "Keyfactor-AutoRenew" | Get-ScheduledTaskInfo
   
   # Review task history
   Get-ScheduledTask -TaskName "Keyfactor-AutoRenew" | Get-ScheduledTaskInfo | Select-Object LastRunTime, LastTaskResult
   
   # Run manually to test
   Start-ScheduledTask -TaskName "Keyfactor-AutoRenew"
   ```

2. **Certificate Not Eligible**
   ```sql
   -- Check certificate eligibility
   SELECT 
       CertificateID,
       SubjectName,
       ExpiryDate,
       DATEDIFF(DAY, GETDATE(), ExpiryDate) AS DaysToExpiry,
       Metadata_AutoRenew,
       Template_AllowsAutoRenew
   FROM Certificates
   WHERE CertificateID = 'CERT-123'
   ```

3. **CSR Generation Failure**
   - Check if private key is exportable
   - Verify key storage provider is available
   - Review orchestrator logs for key generation errors

---

#### Issue: "Renewal succeeds but deployment fails"

**Symptoms**:
- New certificate issued successfully
- Certificate shows in Keyfactor inventory
- Old certificate still in use on server
- Orchestrator deployment job failed

**Troubleshooting Steps**:

1. **Check Orchestrator Status**
   ```
   Navigation: Orchestrators → [Find orchestrator for target server]
   
   Status should be: "Connected"
   Last Heartbeat: < 5 minutes ago
   ```

2. **Review Deployment Job**
   ```
   Navigation: Jobs → Filter by Certificate ID
   Look for: Job status, error messages, execution time
   ```

3. **Common Deployment Failures**:

| Error | Cause | Solution |
|-------|-------|----------|
| "Access Denied" | Invalid credentials | Update certificate store credentials |
| "Path not found" | Store path incorrect | Verify and update store path |
| "Permission denied" | Insufficient rights | Grant orchestrator service account rights |
| "Service unavailable" | Target server offline | Verify server is online, retry |
| "Store full" | Too many certificates | Clean up old certificates |
| "Binding in use" | Certificate still bound | Stop service, deploy, restart service |

4. **Manual Deployment** (Temporary Workaround):
   ```powershell
   # Download certificate from Keyfactor
   $certThumbprint = "ABC123DEF456..."
   Export-KeyfactorCertificate -Thumbprint $certThumbprint -OutputPath "C:\Temp\cert.pfx" -Password "temp123"
   
   # Deploy to server
   $cert = Import-PfxCertificate -FilePath "C:\Temp\cert.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString "temp123" -AsPlainText -Force)
   
   # Update IIS binding (example)
   Get-WebBinding -Name "Default Web Site" -Protocol https | ForEach-Object {
       $_.AddSslCertificate($cert.Thumbprint, "My")
   }
   
   # Verify
   Get-WebBinding -Name "Default Web Site" -Protocol https | Select-Object certificateHash
   ```

---

### 3.3 Orchestrator Issues

#### Issue: "Orchestrator showing as disconnected"

**Symptoms**:
- Orchestrator status: "Disconnected" in Keyfactor portal
- No recent heartbeat
- Jobs not executing

**Priority Assessment**:
- **P1**: > 10 orchestrators disconnected
- **P2**: 5-10 orchestrators disconnected
- **P3**: 1-4 orchestrators disconnected

**Troubleshooting Steps**:

1. **Check Orchestrator Service**
   ```powershell
   # On orchestrator server
   Get-Service "Keyfactor Orchestrator"
   
   # Service stopped?
   Start-Service "Keyfactor Orchestrator"
   Start-Sleep -Seconds 30
   Get-Service "Keyfactor Orchestrator"
   ```

2. **Check Network Connectivity**
   ```powershell
   Test-NetConnection -ComputerName keyfactor.contoso.com -Port 443
   Test-NetConnection -ComputerName keyfactor.contoso.com -Port 5672  # RabbitMQ (if used)
   ```

3. **Review Orchestrator Logs**
   ```powershell
   # Windows
   Get-Content "C:\Program Files\Keyfactor\Orchestrator\Logs\orchestrator.log" -Tail 50
   
   # Linux
   tail -n 50 /var/log/keyfactor-orchestrator/orchestrator.log
   ```

4. **Common Issues**:

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| Expired auth certificate | "Authentication failed" | Renew orchestrator certificate |
| Network firewall | Timeout errors | Verify firewall rules (ports 443, 5672) |
| DNS resolution | "Cannot resolve hostname" | Verify DNS, update hosts file if needed |
| Memory exhaustion | High memory usage, crashes | Restart service, investigate memory leak |
| Certificate store full | "No space available" | Increase store size or clean up |

5. **Force Re-registration** (if connectivity restored but still disconnected):
   ```powershell
   # On orchestrator server
   Stop-Service "Keyfactor Orchestrator"
   Remove-Item "C:\ProgramData\Keyfactor\Orchestrator\registration.dat"
   Start-Service "Keyfactor Orchestrator"
   
   # Monitor logs for re-registration
   Get-Content "C:\Program Files\Keyfactor\Orchestrator\Logs\orchestrator.log" -Wait -Tail 20
   ```

---

### 3.4 Performance Issues

#### Issue: "Keyfactor portal slow/unresponsive"

**Symptoms**:
- Pages take > 10 seconds to load
- API calls timing out
- Users unable to complete tasks

**Immediate Actions**:

1. **Check System Resources**
   ```powershell
   # CPU and Memory
   Get-Counter '\Processor(_Total)\% Processor Time'
   Get-Counter '\Memory\Available MBytes'
   
   # Application pool status
   Get-IISAppPool | Select-Object Name, State, @{n="CPU";e={$_.cpu}}, @{n="Memory";e={$_.memory}}
   ```

2. **Check Database Performance**
   ```sql
   -- Active sessions
   SELECT COUNT(*) AS ActiveSessions
   FROM sys.dm_exec_sessions
   WHERE is_user_process = 1 AND status = 'running';
   
   -- Long-running queries
   SELECT 
       session_id,
       start_time,
       DATEDIFF(SECOND, start_time, GETDATE()) AS duration_seconds,
       command,
       wait_type,
       blocking_session_id
   FROM sys.dm_exec_requests
   WHERE database_id = DB_ID('Keyfactor')
       AND DATEDIFF(SECOND, start_time, GETDATE()) > 30
   ORDER BY duration_seconds DESC;
   
   -- Blocking chains
   EXEC sp_who2 'active';
   ```

3. **Review Application Logs**
   ```powershell
   # Look for errors or warnings
   Get-EventLog -LogName Application -Source "Keyfactor*" -EntryType Error,Warning -Newest 20
   ```

**Common Performance Issues**:

| Cause | Symptoms | Resolution | ETA |
|-------|----------|------------|-----|
| **High database load** | Slow queries, timeouts | Run index rebuild, kill blocking queries | 30 min |
| **Memory pressure** | High memory usage, paging | Restart IIS application pool | 5 min |
| **Too many connections** | Connection pool exhausted | Increase pool size, restart app pool | 10 min |
| **Large result sets** | Specific queries very slow | Add pagination, optimize query | Varies |
| **Cache invalidation** | Sudden slowdown after deploy | Clear application cache, restart | 5 min |

**Performance Optimization Quick Wins**:

1. **Restart IIS Application Pool**
   ```powershell
   Restart-WebAppPool -Name "KeyfactorAppPool"
   Start-Sleep -Seconds 30
   # Test portal
   Invoke-WebRequest -Uri "https://keyfactor.contoso.com" -UseBasicParsing
   ```

2. **Clear Application Cache**
   ```powershell
   # Clear ASP.NET temporary files
   Remove-Item "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files\*" -Recurse -Force
   ```

3. **Rebuild Fragmented Indexes** (during maintenance window)
   ```sql
   USE Keyfactor;
   ALTER INDEX ALL ON Certificates REBUILD WITH (ONLINE = ON);
   ALTER INDEX ALL ON CertificateStores REBUILD WITH (ONLINE = ON);
   ```

---

### 3.5 HSM Issues

#### Issue: "HSM unavailable or degraded"

**Severity**: P1 (Critical) - Immediate escalation required

**Symptoms**:
- Certificate signing operations fail
- Error: "HSM not responding"
- CA operations timeout

**Immediate Actions**:

1. **DO NOT RESTART HSM** without proper authorization
2. **Notify HSM vendor support immediately**
3. **Escalate to CISO and PKI Lead**
4. **Document all observations**

**Assessment Steps**:

1. **Check HSM Status** (read-only operations only)
   ```bash
   # Via HSM client tools
   /opt/safenet/lunaclient/bin/vtl verify
   /opt/safenet/lunaclient/bin/lunacm
   > slot list
   > partition show -partition <partition_name>
   ```

2. **Review HSM Logs**
   ```bash
   tail -n 100 /var/log/safenet/lunaclient.log
   grep -i error /var/log/safenet/lunaclient.log | tail -n 50
   ```

3. **Check Network Connectivity to HSM**
   ```bash
   ping -c 5 hsm1.contoso.com
   nc -zv hsm1.contoso.com 1792  # HSM port
   ```

**DO NOT ATTEMPT**:
- ❌ Restarting HSM without vendor support
- ❌ Modifying HSM configuration
- ❌ Key material operations
- ❌ Firmware updates

**Escalation Contacts**:
- **HSM Vendor Support**: +1-800-XXX-XXXX (24/7)
- **CISO**: [Phone] (P1 incidents only)
- **HSM Administrator**: [Name] [Phone]

---

## 4. Emergency Procedures

### 4.1 Emergency Certificate Issuance

**Scenario**: Production service needs certificate immediately, normal process too slow

**Authorization Required**: CISO or VP Infrastructure

**Procedure**:

1. **Get Authorization**
   - Document business justification
   - Get approval via email/Slack
   - Create emergency ticket: `EMG-CERT-[DATE]-[SEQUENCE]`

2. **Use Break-Glass Account**
   ```powershell
   # Retrieve break-glass credentials from secure vault
   $secret = Get-AzKeyVaultSecret -VaultName "vault-pki-prod" -Name "breakglass-pki-admin"
   $credential = New-Object PSCredential("breakglass-admin", $secret.SecretValue)
   ```

3. **Generate CSR** (if not provided)
   ```powershell
   # Quick CSR generation
   $subject = "CN=emergency.contoso.com"
   $san = @("emergency.contoso.com")
   
   # Create and submit CSR
   certreq -new -f emergency-request.inf emergency.csr
   ```

4. **Submit to CA Directly** (bypass normal workflow)
   ```powershell
   # Windows CA
   certreq -submit -attrib "CertificateTemplate:WebServerEmergency" emergency.csr emergency.cer
   ```

5. **Deploy Certificate**
   - Deploy manually to target system
   - Update monitoring to track emergency certificate
   - Schedule proper replacement within 7 days

6. **Post-Emergency Actions**
   - Document all actions in incident ticket
   - Schedule proper certificate issuance
   - Rotate break-glass credentials
   - Conduct post-incident review

---

### 4.2 Mass Certificate Revocation

**Scenario**: Key compromise affecting multiple certificates, or CA compromise

**Severity**: P1 (Critical)  
**Authorization**: CISO required

**Procedure**:

1. **Activate Incident Response Team**
   - Security team
   - PKI administrators
   - Communications lead
   - Legal (if customer-facing)

2. **Assess Scope**
   ```sql
   -- Identify affected certificates
   SELECT 
       CertificateID,
       SubjectName,
       IssuedDate,
       ExpiryDate,
       CurrentLocation
   FROM Certificates
   WHERE IssuerCA = 'AFFECTED-CA'
       AND Status = 'Active'
   ORDER BY CriticalityScore DESC;
   ```

3. **Prioritize Revocation**
   - **Immediate**: Customer-facing production certificates
   - **High**: Internal production certificates
   - **Medium**: Non-production certificates
   - **Low**: Test/development certificates

4. **Execute Revocation** (automated script)
   ```powershell
   # Mass revocation script
   $affectedCerts = Import-Csv "affected-certificates.csv"
   
   foreach ($cert in $affectedCerts) {
       try {
           Revoke-KeyfactorCertificate `
               -CertificateID $cert.ID `
               -Reason "KeyCompromise" `
               -Comment "INCIDENT-2025-1022 - CA Compromise"
           
           Write-Log "Revoked: $($cert.SubjectName)"
       }
       catch {
           Write-Log "FAILED to revoke: $($cert.SubjectName) - $_" -Level ERROR
       }
   }
   ```

5. **Force CRL Publication**
   ```powershell
   # Publish CRL immediately
   certutil -CRL
   
   # Verify CRL update
   certutil -URL http://pki.contoso.com/crl/contoso-ca.crl
   ```

6. **Communication Plan**
   - **Internal**: Immediate notification to all IT teams
   - **External** (if applicable): Customer notification within 24 hours
   - **Media**: Prepared statement (if public disclosure required)

7. **Replacement Plan**
   - Fast-track certificate reissuance
   - Deploy replacement certificates
   - Verify service continuity

---

### 4.3 Complete Platform Failure

**Scenario**: Keyfactor platform completely unavailable, all CAs unreachable

**Severity**: P1 (Critical)  
**Immediate Actions**: Within 15 minutes

**Step 1: Assess and Contain** (0-15 minutes)

1. **Verify Outage Scope**
   - Test from multiple locations
   - Check status page: https://status.contoso.com/pki
   - Verify not a local network issue

2. **Notify Stakeholders**
   ```
   🚨 P1 INCIDENT - PKI PLATFORM DOWN
   
   All certificate operations unavailable.
   Investigating cause. Updates every 15 minutes.
   
   DO NOT submit new certificate requests until resolved.
   ```

3. **Check Dependencies**
   - Database availability
   - HSM connectivity
   - Network infrastructure
   - DNS resolution

**Step 2: Emergency Procedures** (15-30 minutes)

1. **Activate DR Site** (if configured)
   ```powershell
   # Failover to DR environment
   # 1. Update DNS to point to DR Keyfactor instance
   # 2. Verify DR database replication is current
   # 3. Test DR Keyfactor portal
   # 4. Verify DR CA connectivity
   ```

2. **Bypass Keyfactor** (temporary, if DR not available)
   ```powershell
   # Issue certificates directly from CA (EMERGENCY ONLY)
   certreq -submit -config "CA-SERVER\CA-NAME" request.csr certificate.cer
   
   # Document all certificates issued this way
   # These must be imported to Keyfactor when restored
   ```

**Step 3: Root Cause and Resolution** (30 minutes - 4 hours)

1. **Common Failure Modes**:

| Cause | Detection | Resolution |
|-------|-----------|------------|
| **Database failure** | Connection timeouts | Restore database from backup, failover to replica |
| **Application crash** | IIS not responding | Restart IIS, review crash dumps |
| **Network partition** | Network unreachable | Engage network team, reroute traffic |
| **HSM failure** | Signing operations fail | Contact HSM vendor, failover to backup HSM |
| **Ransomware/Cyberattack** | File encryption, suspicious activity | Isolate systems, engage security IR team |

2. **Recovery Checklist**:
   ```
   □ Root cause identified
   □ Fix implemented
   □ Services restarted
   □ Basic functionality tested
   □ Certificate issuance tested (1 test cert)
   □ Orchestrator connectivity verified
   □ CA connectivity verified
   □ HSM operations verified
   □ Monitoring restored
   □ Backlog processing initiated
   ```

**Step 4: Service Restoration** (Variable)

1. **Gradual Restoration**
   - Start with test certificate issuance
   - Process backlog of pending requests
   - Resume automated operations
   - Monitor for anomalies

2. **Verification**
   ```powershell
   # End-to-end test
   # 1. Submit test certificate request
   # 2. Verify issuance
   # 3. Deploy to test server
   # 4. Verify HTTPS connection
   ```

3. **Declare Restoration**
   ```
   ✅ INCIDENT RESOLVED - PKI Platform Restored
   
   All services operational as of [TIME].
   
   Backlog Status: [X] requests pending, processing at [Y] per hour
   ETA for backlog completion: [TIME]
   
   Post-incident review scheduled for [DATE/TIME]
   ```

---

### 4.4 Key Compromise Response

**Scenario**: Private key compromised or suspected compromised

**Severity**: P1 (Critical) - Security incident

**Immediate Actions** (0-30 minutes):

1. **Confirm Compromise**
   - Evidence of key theft
   - Unauthorized certificate usage
   - Suspect activity logs
   - Security team confirmation

2. **Containment**
   ```powershell
   # Immediate revocation
   Revoke-KeyfactorCertificate `
       -CertificateID "CERT-12345" `
       -Reason KeyCompromise `
       -EffectiveDate (Get-Date) `
       -Comment "SECURITY-INCIDENT-[ID]"
   
   # Force immediate CRL publication
   certutil -CRL
   ```

3. **Remove from All Systems**
   ```powershell
   # Emergency removal script
   $compromisedThumbprint = "ABC123DEF456..."
   
   # Remove from all servers (via orchestrators)
   Get-KeyfactorCertificateStore | Where-Object {$_.ContainsCertificate($compromisedThumbprint)} | ForEach-Object {
       Remove-CertificateFromStore -StoreID $_.ID -Thumbprint $compromisedThumbprint -Force
   }
   ```

4. **Issue Replacement**
   - Generate new key pair (NEVER reuse compromised key)
   - Fast-track new certificate issuance
   - Deploy replacement immediately

**Investigation** (30 minutes - ongoing):

1. **Forensics**
   - Preserve evidence
   - Review access logs
   - Identify compromise vector
   - Assess blast radius

2. **Determine Scope**
   ```sql
   -- Check for related certificates with same key
   -- Check for certificates issued using compromised credentials
   -- Review all certificates issued in timeframe
   SELECT 
       CertificateID,
       SubjectName,
       IssuedDate,
       RequestedBy
   FROM Certificates
   WHERE IssuedDate BETWEEN '[COMPROMISE_START]' AND '[COMPROMISE_END]'
       OR RequestedBy = '[COMPROMISED_USER]'
   ORDER BY IssuedDate DESC;
   ```

3. **Incident Response**
   - Engage security IR team
   - Notify legal/compliance (if required)
   - Prepare breach notifications (if customer data affected)

**Post-Incident** (1-7 days):

1. **Security Hardening**
   - Review and update key storage policies
   - Enhance monitoring and alerting
   - Update access controls
   - Conduct security training

2. **Compliance Reporting**
   - Document incident timeline
   - Report to regulators (if required)
   - Update compliance artifacts

---

## 5. Root Cause Analysis

### 5.1 RCA Template

**Incident ID**: INC-YYYY-MMDD-XXX  
**Date**: YYYY-MM-DD  
**Severity**: P1 / P2 / P3 / P4  
**Duration**: [Start] to [End] = [Duration]

#### Summary
[One paragraph description of the incident]

#### Impact
- **Services Affected**: [List]
- **Users Affected**: [Number/percentage]
- **Business Impact**: [Revenue loss, SLA breach, etc.]
- **Duration**: [Total downtime]

#### Timeline

| Time (EST) | Event | Action Taken |
|-----------|-------|--------------|
| 14:30 | Alert fired: CA unreachable | On-call engineer paged |
| 14:35 | Incident confirmed | Classified as P1 |
| 14:40 | Investigation started | Reviewed CA server status |
| 14:55 | Root cause identified | Certificate expired on CA |
| 15:05 | Fix implemented | Renewed CA certificate |
| 15:20 | Services restored | Verified functionality |
| 15:45 | Incident closed | Monitoring resumed |

#### Root Cause
[Detailed explanation of what caused the incident]

**Contributing Factors**:
1. [Factor 1]
2. [Factor 2]
3. [Factor 3]

#### Resolution
[What was done to resolve the incident]

#### Prevention Measures

| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| Implement auto-renewal for CA certs | PKI Admin | 2025-11-15 | Planned |
| Add monitoring for CA cert expiry | Ops Team | 2025-11-01 | In Progress |
| Update runbook with CA cert renewal | Tech Writer | 2025-10-30 | Complete |

#### Lessons Learned
- [Lesson 1]
- [Lesson 2]
- [Lesson 3]

---

### 5.2 5 Whys Analysis

**Problem Statement**: [Describe the issue]

**Why #1**: Why did the incident occur?  
**Answer**: [First level cause]

**Why #2**: Why did [answer from Why #1] happen?  
**Answer**: [Second level cause]

**Why #3**: Why did [answer from Why #2] happen?  
**Answer**: [Third level cause]

**Why #4**: Why did [answer from Why #3] happen?  
**Answer**: [Fourth level cause]

**Why #5**: Why did [answer from Why #4] happen?  
**Answer**: [Root cause - often a process or policy issue]

**Example**:

**Problem**: Certificate issuance failed for 2 hours

1. **Why did certificate issuance fail?**  
   Because the CA was offline.

2. **Why was the CA offline?**  
   Because the CA service stopped.

3. **Why did the CA service stop?**  
   Because the server ran out of disk space.

4. **Why did the server run out of disk space?**  
   Because logs were not being rotated.

5. **Why were logs not being rotated?**  
   Because the log rotation script was not scheduled.

**Root Cause**: Lack of automated log management  
**Preventive Action**: Implement automated log rotation and disk space monitoring

---

## 6. Post-Incident Review

### 6.1 PIR Meeting Agenda

**Schedule**: Within 5 business days of incident resolution  
**Duration**: 60 minutes  
**Attendees**: Incident team, stakeholders, management

**Agenda**:

1. **Incident Overview** (5 minutes)
   - What happened
   - Impact summary
   - Timeline

2. **Root Cause Analysis** (15 minutes)
   - Technical root cause
   - Contributing factors
   - 5 Whys analysis

3. **Response Effectiveness** (15 minutes)
   - What went well
   - What didn't go well
   - Communication effectiveness

4. **Prevention Measures** (20 minutes)
   - Proposed improvements
   - Ownership assignment
   - Timeline for completion

5. **Lessons Learned** (5 minutes)
   - Key takeaways
   - Actionable insights

**Output**: Action item list with owners and due dates

---

### 6.2 PIR Report Template

```markdown
# Post-Incident Review: [Incident Title]

**Incident ID**: INC-YYYY-MMDD-XXX  
**Date of Incident**: YYYY-MM-DD  
**PIR Date**: YYYY-MM-DD  
**Facilitator**: [Name]  
**Attendees**: [Names]

## Executive Summary

[2-3 paragraphs summarizing incident, impact, root cause, and key actions]

## Incident Details

**Severity**: P1/P2/P3/P4  
**Detection**: [How was it detected]  
**Duration**: [Start time] to [End time] = [Duration]  
**Services Affected**: [List]  
**Customer Impact**: [Description]

## What Happened

[Detailed narrative of the incident]

## Root Cause Analysis

[RCA findings - see Section 5.1]

## Response Timeline

| Time | Event | Action | Outcome |
|------|-------|--------|---------|
| ... | ... | ... | ... |

## What Went Well

1. [Positive aspect 1]
2. [Positive aspect 2]
3. [Positive aspect 3]

## What Didn't Go Well

1. [Challenge 1]
2. [Challenge 2]
3. [Challenge 3]

## Action Items

| Action | Owner | Due Date | Priority | Status |
|--------|-------|----------|----------|--------|
| ... | ... | ... | High/Med/Low | ... |

## Lessons Learned

1. [Lesson 1]
2. [Lesson 2]
3. [Lesson 3]

## Appendices

- Incident timeline (detailed)
- Relevant logs and screenshots
- Communication transcripts
```

---

## 7. Troubleshooting Decision Trees

### 7.1 Certificate Request Failure

```
Certificate request failed?
│
├─ Error: "CA unavailable"
│  │
│  ├─ Is CA service running?
│  │  ├─ NO → Start CA service
│  │  └─ YES → Continue
│  │
│  ├─ Can you ping CA server?
│  │  ├─ NO → Check network/firewall
│  │  └─ YES → Continue
│  │
│  ├─ Is CA certificate valid?
│  │  ├─ NO → Renew CA certificate
│  │  └─ YES → Restart Keyfactor service
│  
├─ Error: "Policy violation"
│  │
│  ├─ Check CSR parameters
│  │  ├─ Key size < 2048 → Regenerate with 2048+ bit key
│  │  ├─ Validity > template max → Adjust validity period
│  │  └─ SAN restrictions → Use approved SANs only
│  
├─ Error: "Duplicate certificate"
│  │
│  ├─ Find existing certificate
│  │  └─ Is it still needed?
│  │     ├─ YES → Wait for expiry or contact owner
│  │     └─ NO → Revoke and retry
│  
└─ Error: "SAN not authorized"
   │
   ├─ Check asset inventory
   │  ├─ Hostname not found → Register in inventory
   │  ├─ Wrong owner → Update ownership
   │  └─ Permissions issue → Grant user access
```

---

### 7.2 Service Degradation

```
Service is slow?
│
├─ What is slow?
│  │
│  ├─ Web Portal
│  │  │
│  │  ├─ Check IIS App Pool
│  │  │  ├─ CPU > 80% → Restart app pool
│  │  │  ├─ Memory > 90% → Restart app pool
│  │  │  └─ Requests queued → Scale out
│  │  │
│  │  └─ Check Database
│  │     ├─ Query time > 2s → Rebuild indexes
│  │     ├─ Blocking chains → Kill blockers
│  │     └─ High CPU → Identify slow queries
│  │
│  ├─ API Calls
│  │  │
│  │  ├─ Which endpoint?
│  │  │  ├─ /Certificates (GET) → Check database index
│  │  │  ├─ /Certificates (POST) → Check CA response time
│  │  │  └─ /Search → Add pagination
│  │  │
│  │  └─ Check network latency
│  │
│  └─ Certificate Operations
│     │
│     ├─ Issuance slow → Check CA response time
│     ├─ Renewal slow → Check orchestrator queue
│     └─ Deployment slow → Check orchestrator connectivity
```

---

## 8. Known Issues and Workarounds

### 8.1 Current Known Issues

**Last Updated**: October 22, 2025

| Issue ID | Description | Severity | Workaround | ETA for Fix |
|----------|-------------|----------|------------|-------------|
| KF-2025-001 | Orchestrator memory leak after 7 days uptime | P3 | Restart orchestrator weekly | Q1 2026 |
| KF-2025-002 | Large certificate stores (>10,000) slow to inventory | P3 | Schedule inventory during off-hours | Q4 2025 |
| KF-2025-003 | Webhook delivery may retry up to 5 times | P4 | Ensure idempotent webhook handlers | No fix planned |
| KF-2025-004 | UI session timeout not configurable | P4 | Users must re-login after 30 min | Q1 2026 |

### 8.2 Vendor-Reported Issues

**Keyfactor Platform**:
- Version 10.x has known issues with EJBCA 8.x compatibility
- Workaround: Use EJBCA 7.x until patch available
- ETA: Version 10.2 (December 2025)

**Windows Server 2022**:
- Certification Authority role has intermittent performance issues
- Workaround: Apply latest cumulative update
- Reference: KB5012345

---

## Appendix A: Incident Response Checklist

```markdown
## P1 Incident Response Checklist

Incident ID: _________________
Date/Time: _________________
On-Call: _________________

### Detection (0-5 min)
□ Alert acknowledged
□ Incident ticket created
□ Initial assessment complete
□ Severity classified

### Communication (5-10 min)
□ Stakeholders notified (Slack #pki-incidents)
□ Status page updated
□ Management informed (if P1)
□ War room established (if needed)

### Investigation (10-30 min)
□ Logs reviewed
□ System status checked
□ Root cause hypothesis formed
□ SMEs engaged (if needed)

### Containment (30-60 min)
□ Issue contained (no further spread)
□ Workaround implemented (if available)
□ Critical systems protected
□ Rollback plan prepared

### Resolution (Variable)
□ Fix implemented
□ Testing completed
□ Monitoring shows normal
□ Backlog processing started

### Communication (Ongoing)
□ Regular updates provided (every 30 min for P1)
□ Status page updated
□ Resolution communicated
□ PIR scheduled

### Post-Incident (1-7 days)
□ RCA completed
□ PIR conducted
□ Action items assigned
□ Runbooks updated
□ Preventive measures implemented
```

---

## Appendix B: Contact Information

### Primary Contacts

| Role | Name | Phone | Email | Availability |
|------|------|-------|-------|-------------|
| **On-Call Engineer** | [Auto-routed] | PagerDuty | - | 24/7 |
| **PKI Lead** | [Name] | [Phone] | [Email] | Business hours |
| **Backup On-Call** | [Name] | [Phone] | [Email] | 24/7 |
| **CISO** | [Name] | [Phone] | [Email] | P1 escalation only |
| **VP Infrastructure** | [Name] | [Phone] | [Email] | P1 escalation only |

### Vendor Support

| Vendor | Product | Support Phone | Support Email | SLA |
|--------|---------|--------------|---------------|-----|
| **Keyfactor** | Platform | +1-800-XXX-XXXX | support@keyfactor.com | 24/7, 1hr response |
| **Thales** | HSM | +1-800-YYY-YYYY | support@thales.com | 24/7, 30min response |
| **Microsoft** | Premier Support | +1-800-ZZZ-ZZZZ | premier@microsoft.com | 24/7, 1hr response |

---

## Document Maintenance

**Review Schedule**: Quarterly or after major incidents  
**Owner**: PKI Operations Team  
**Last Reviewed**: October 22, 2025  
**Next Review**: January 22, 2026 or after next P1 incident

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial version |

---

**CLASSIFICATION**: INTERNAL USE - RESTRICTED  
**Contains sensitive operational procedures and contact information**

**For incident support, contact**: PagerDuty or adrian207@gmail.com

**End of Incident Response Procedures Document**

