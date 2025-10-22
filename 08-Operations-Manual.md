# Keyfactor Operations Manual
## Day-to-Day Operational Procedures and Monitoring

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use  
**Target Audience**: Operations teams, on-call engineers, PKI administrators

---

## Document Purpose

This operations manual provides comprehensive procedures for day-to-day management and monitoring of the Keyfactor certificate lifecycle management platform. It covers routine operations, monitoring, troubleshooting, and emergency procedures.

---

## Table of Contents

1. [Daily Operations](#1-daily-operations)
2. [Monitoring and Dashboards](#2-monitoring-and-dashboards)
3. [Certificate Lifecycle Operations](#3-certificate-lifecycle-operations)
4. [System Maintenance](#4-system-maintenance)
5. [Backup and Recovery](#5-backup-and-recovery)
6. [User Support](#6-user-support)
7. [Break-Glass Procedures](#7-break-glass-procedures)
8. [Change Management](#8-change-management)
9. [Capacity Planning](#9-capacity-planning)
10. [On-Call Responsibilities](#10-on-call-responsibilities)

---

## 1. Daily Operations

### 1.1 Morning Health Check (15 minutes)

**Frequency**: Every business day at 9:00 AM  
**Responsible**: On-call engineer or designated operator

**Checklist**:

```markdown
Morning Health Check - [Date: ________]

□ Keyfactor Application
  □ Web portal accessible (https://keyfactor.contoso.com)
  □ Login successful with test account
  □ Dashboard loads within 3 seconds
  □ No error messages on main page

□ Certificate Authorities
  □ AD CS: All CAs online and issuing
  □ EJBCA: Cluster health check passed
  □ HSM: Status "operational" in both data centers

□ Orchestrators
  □ All orchestrators showing "Connected" status
  □ No orchestrators in "Error" or "Disconnected" state
  □ Last heartbeat < 5 minutes ago for all

□ Overnight Operations
  □ Review automated renewal log (target: 0 failures)
  □ Check certificate issuance volume (normal range)
  □ Review error logs for any critical issues

□ Expiring Certificates
  □ Certificates expiring within 7 days: ____ (threshold < 50)
  □ Certificates expiring within 24 hours: ____ (threshold: 0)
  □ Expired certificates: ____ (threshold: 0)

□ System Resources
  □ Keyfactor server CPU: < 70%
  □ Keyfactor server memory: < 80%
  □ Database size: Note current size ______GB
  □ Disk space: > 20% free on all volumes

□ Monitoring Alerts
  □ Review all alerts from past 24 hours
  □ Verify all critical alerts have been addressed
  □ Check for recurring warnings

Action Items:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

Checked by: _________________ Time: _______ Status: OK / Issues
```

**Escalation**: If 3 or more items fail, escalate to PKI lead immediately.

---

### 1.2 Certificate Queue Management

**Frequency**: Every 2 hours during business hours  
**Tool**: Keyfactor web portal → **Certificates** → **Pending Requests**

**Procedure**:

1. **Check Pending Approvals**
   ```
   Navigation: Certificates → Pending Requests → Filter: "Awaiting Approval"
   ```
   - Review each pending request
   - Verify requestor identity and justification
   - Check SAN against asset inventory
   - Approve or reject within 2 hours of submission

2. **Monitor Failed Requests**
   ```
   Navigation: Certificates → Requests → Filter: "Failed"
   ```
   - Review failure reason
   - Common causes:
     - CA unavailable
     - Policy violation
     - Invalid CSR
     - Duplicate SAN
   - Contact requestor if clarification needed
   - Retry or reject with detailed reason

3. **Track Renewal Queue**
   ```
   Navigation: Reports → Certificate Lifecycle → Pending Renewals
   ```
   - Expected: < 100 certificates in renewal queue
   - Alert if queue grows by > 50 certificates in 24 hours
   - Investigate if renewal success rate < 95%

**Automation Check**:
- Auto-renewal should handle 80%+ of renewals
- Manual intervention required only for:
  - High-value certificates
  - Certificates with approval requirements
  - Failed automated renewals

---

### 1.3 Orchestrator Health Monitoring

**Frequency**: Every 4 hours  
**Tool**: Keyfactor → **Orchestrators** → **Agent Health**

**Monitoring Criteria**:

| Status | Threshold | Action |
|--------|-----------|--------|
| Connected | > 95% | Normal operations |
| Disconnected | Any | Investigate immediately |
| Error | Any | Review logs, restart if needed |
| Heartbeat | < 5 min | Normal |
| Heartbeat | > 15 min | Warning - check network connectivity |

**Common Issues and Resolutions**:

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| Network connectivity | Intermittent disconnects | Check firewall rules, DNS resolution |
| Certificate expired | Orchestrator offline | Renew orchestrator authentication cert |
| Service stopped | Status "Stopped" | Restart Keyfactor Orchestrator service |
| High CPU | CPU > 90% | Check for excessive discovery jobs |
| Memory leak | Memory increasing over time | Restart orchestrator service, log bug |

**Restart Procedure** (Windows Orchestrator):
```powershell
# On orchestrator server
Stop-Service "Keyfactor Orchestrator"
Start-Sleep -Seconds 10
Start-Service "Keyfactor Orchestrator"

# Verify startup
Get-Service "Keyfactor Orchestrator"
Get-EventLog -LogName Application -Source "Keyfactor*" -Newest 10
```

**Restart Procedure** (Linux Orchestrator):
```bash
sudo systemctl stop keyfactor-orchestrator
sudo systemctl start keyfactor-orchestrator
sudo systemctl status keyfactor-orchestrator
sudo journalctl -u keyfactor-orchestrator -n 20
```

---

### 1.4 Database Health Check

**Frequency**: Daily at 10:00 AM  
**Tool**: SQL Server Management Studio or Azure Portal

**Checks**:

1. **Database Size Monitoring**
   ```sql
   -- Check Keyfactor database size
   SELECT 
       DB_NAME() AS DatabaseName,
       SUM(size * 8 / 1024) AS SizeMB,
       SUM(size * 8 / 1024 / 1024) AS SizeGB
   FROM sys.master_files
   WHERE database_id = DB_ID('Keyfactor')
   GROUP BY database_id;
   ```

2. **Index Fragmentation**
   ```sql
   -- Check for fragmented indexes
   SELECT 
       OBJECT_NAME(ips.object_id) AS TableName,
       i.name AS IndexName,
       ips.avg_fragmentation_in_percent
   FROM sys.dm_db_index_physical_stats(DB_ID('Keyfactor'), NULL, NULL, NULL, 'SAMPLED') ips
   INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
   WHERE ips.avg_fragmentation_in_percent > 30
   ORDER BY ips.avg_fragmentation_in_percent DESC;
   ```
   - **Action**: If fragmentation > 30%, schedule index rebuild during maintenance window

3. **Long-Running Queries**
   ```sql
   -- Identify queries running > 30 seconds
   SELECT 
       session_id,
       start_time,
       status,
       command,
       DATEDIFF(SECOND, start_time, GETDATE()) AS duration_seconds,
       database_name = DB_NAME(database_id),
       blocking_session_id,
       wait_type,
       wait_time,
       cpu_time,
       logical_reads
   FROM sys.dm_exec_requests
   WHERE database_id = DB_ID('Keyfactor')
       AND session_id <> @@SPID
       AND DATEDIFF(SECOND, start_time, GETDATE()) > 30
   ORDER BY duration_seconds DESC;
   ```

4. **Backup Verification**
   ```sql
   -- Check last successful backup
   SELECT 
       database_name,
       backup_start_date,
       backup_finish_date,
       type,
       DATEDIFF(HOUR, backup_finish_date, GETDATE()) AS hours_since_backup
   FROM msdb.dbo.backupset
   WHERE database_name = 'Keyfactor'
   ORDER BY backup_finish_date DESC;
   ```
   - **Alert**: If last backup > 24 hours ago

**Database Performance Baselines**:
- Query response time (avg): < 100ms
- Transaction log size: < 10GB
- Index rebuild frequency: Weekly
- Statistics update: Daily (automated)

---

## 2. Monitoring and Dashboards

### 2.1 Primary Dashboard (Real-Time Monitoring)

**URL**: `https://keyfactor.contoso.com/Dashboard`

**Key Metrics** (Update interval: 1 minute):

#### Certificate Inventory
```
┌─────────────────────────────────────────────────┐
│ Total Certificates: 45,234                       │
│ Active: 44,892 | Expired: 12 | Revoked: 330     │
│                                                  │
│ Expiring Soon:                                   │
│   ⚠ Next 7 days: 45 certificates                │
│   ⚠ Next 30 days: 287 certificates              │
│   ⚠ Next 90 days: 1,234 certificates            │
└─────────────────────────────────────────────────┘
```

#### Certificate Issuance (Last 24 Hours)
```
┌─────────────────────────────────────────────────┐
│ Issued: 234                                      │
│ Renewed: 89                                      │
│ Revoked: 3                                       │
│ Failed: 7 (Success Rate: 97.9%)                 │
└─────────────────────────────────────────────────┘
```

#### Orchestrator Status
```
┌─────────────────────────────────────────────────┐
│ Total: 45                                        │
│ ✓ Connected: 44                                  │
│ ✗ Disconnected: 1 (webapp-orch-05)              │
│ ⚠ Warning: 0                                     │
└─────────────────────────────────────────────────┘
```

#### Certificate Authority Health
```
┌─────────────────────────────────────────────────┐
│ AD CS - DC1: ✓ Online | Issued Today: 156       │
│ AD CS - DC2: ✓ Online | Issued Today: 78        │
│ EJBCA - Node 1: ✓ Online | Issued Today: 45     │
│ EJBCA - Node 2: ✓ Online | Issued Today: 48     │
└─────────────────────────────────────────────────┘
```

---

### 2.2 Alerting Thresholds

**Critical Alerts** (Page immediately):

| Metric | Threshold | Alert Channel |
|--------|-----------|---------------|
| CA offline | Any CA unavailable > 5 min | PagerDuty + Slack |
| HSM unavailable | Both HSMs offline | PagerDuty + Phone |
| Certificate expired | Any high-priority cert expired | PagerDuty + Email |
| Orchestrator down | > 5 orchestrators disconnected | PagerDuty |
| Database unavailable | Keyfactor DB connection failed | PagerDuty + Phone |
| Disk space | < 10% free | PagerDuty |

**Warning Alerts** (Notify via Slack):

| Metric | Threshold | Alert Channel |
|--------|-----------|---------------|
| Expiring soon | > 100 certs expiring in 7 days | Slack #pki-ops |
| Failed renewals | Renewal success rate < 90% | Slack #pki-ops |
| High CPU | Keyfactor server CPU > 80% for 15 min | Slack #pki-ops |
| Queue backup | > 200 certs in pending approval | Slack #pki-ops |
| Slow response | API response time > 2 seconds | Slack #pki-ops |

---

### 2.3 Grafana Dashboards

**Dashboard URL**: `https://grafana.contoso.com/d/keyfactor`

#### Dashboard 1: Certificate Health Overview
```
Panels:
- Total certificate count (gauge)
- Certificates by status (pie chart)
- Certificate issuance rate (time series, last 30 days)
- Top 10 SANs by certificate count (bar chart)
- Certificate expiry timeline (heatmap)
```

#### Dashboard 2: Operational Metrics
```
Panels:
- API response times (time series)
- Keyfactor server CPU/Memory (time series)
- Database connection pool (gauge)
- Orchestrator connectivity (status map)
- Error rate by category (pie chart)
```

#### Dashboard 3: Certificate Authority Performance
```
Panels:
- Certificates issued per CA (bar chart)
- CA response time (time series)
- CA availability (uptime percentage)
- HSM operations per second (time series)
```

**Refresh Interval**: 30 seconds for operational dashboards

---

## 3. Certificate Lifecycle Operations

### 3.1 Manual Certificate Issuance

**Use Case**: Emergency certificate issuance or troubleshooting

**Procedure**:

1. **Verify Authorization**
   - Confirm requestor identity
   - Verify ownership of domain/hostname
   - Check asset inventory for device registration

2. **Generate CSR** (if needed)
   
   **Windows**:
   ```powershell
   # Create certificate request
   $subject = "CN=webapp01.contoso.com"
   $san = @("webapp01.contoso.com", "www.contoso.com")
   
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
   OID=1.3.6.1.5.5.7.3.1 ; Server Authentication
   
   [Extensions]
   2.5.29.17 = "{text}"
   _continue_ = "dns=$($san[0])&"
   _continue_ = "dns=$($san[1])&"
   "@
   
   $inf | Out-File -FilePath "C:\Temp\request.inf" -Encoding ASCII
   certreq -new "C:\Temp\request.inf" "C:\Temp\request.csr"
   ```
   
   **Linux**:
   ```bash
   # Generate CSR with OpenSSL
   openssl req -new -newkey rsa:2048 -nodes \
       -keyout server.key \
       -out server.csr \
       -subj "/C=US/ST=State/L=City/O=Contoso/CN=webapp01.contoso.com" \
       -addext "subjectAltName = DNS:webapp01.contoso.com,DNS:www.contoso.com"
   ```

3. **Submit to Keyfactor**
   ```
   Navigation: Certificates → Enroll → Paste CSR
   
   Fields to Complete:
   - Certificate Template: [Select appropriate template]
   - Subject Alternative Names: [Verify/add SANs]
   - Metadata:
     * Owner: [Service owner email]
     * Application: [Application name]
     * Environment: [dev/staging/prod]
     * Cost Center: [Budget code]
   ```

4. **Download Certificate**
   - Format: PFX (if private key needed) or PEM/DER
   - Password protect PFX files
   - Deliver via secure channel (never email)

5. **Update Inventory**
   - Record certificate ID in asset inventory
   - Update CMDB with certificate details
   - Set expiry reminder (60 days before expiration)

---

### 3.2 Certificate Renewal

**Standard Renewal** (Automated):
- Triggered: 30 days before expiration
- Process: Automatic CSR generation and rekey
- Deployment: Orchestrators auto-deploy to configured stores
- Notification: Email to certificate owner upon completion

**Manual Renewal** (When automation fails):

1. **Identify Certificate**
   ```
   Navigation: Certificates → Search → [Enter thumbprint or SAN]
   ```

2. **Initiate Renewal**
   ```
   Actions: Renew → Choose Method:
   - Reuse existing key (faster, less secure)
   - Generate new key pair (recommended)
   ```

3. **Verify Renewal**
   - New certificate issued with same SAN
   - Validity period: 1 year from renewal date
   - Old certificate marked for revocation after grace period (7 days)

4. **Deploy Renewed Certificate**
   - If orchestrator deployment failed, deploy manually:
   ```powershell
   # Example: Deploy to IIS
   $pfxPath = "C:\Temp\renewed-cert.pfx"
   $pfxPassword = ConvertTo-SecureString "password" -AsPlainText -Force
   Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation Cert:\LocalMachine\My -Password $pfxPassword
   
   # Update IIS binding
   $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*webapp01*"} | Sort-Object NotAfter -Descending | Select-Object -First 1
   Get-WebBinding -Name "Default Web Site" -Protocol https | ForEach-Object {
       $_.AddSslCertificate($cert.Thumbprint, "My")
   }
   ```

---

### 3.3 Certificate Revocation

**Emergency Revocation** (Key Compromise):

1. **Initiate Revocation**
   ```
   Navigation: Certificates → [Find certificate] → Actions → Revoke
   
   Reason Codes:
   - Key Compromise (Code: 1) - IMMEDIATE CRL PUBLICATION
   - Cessation of Operation (Code: 5) - Standard process
   - Superseded (Code: 4) - After successful renewal
   ```

2. **Verify CRL Update**
   ```bash
   # Download and check CRL
   curl -o crl.crl http://pki.contoso.com/crl/contoso-ca.crl
   openssl crl -in crl.crl -inform DER -text -noout | grep -A 5 "Serial Number: <cert_serial>"
   ```
   - Expected: Certificate appears in CRL within 5 minutes
   - CRL publication: Every 4 hours (delta CRL: every hour)

3. **Remove from Stores**
   - Orchestrators will auto-remove revoked certificates
   - Verify removal after 15 minutes
   - Manual removal if orchestrator fails:
   ```powershell
   # Windows
   Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -eq "ABC123..."} | Remove-Item
   ```

4. **Incident Documentation**
   - Create ServiceNow incident
   - Document reason for revocation
   - Notify certificate owner
   - Update asset inventory

---

## 4. System Maintenance

### 4.1 Weekly Maintenance Tasks

**Schedule**: Sunday 2:00 AM - 4:00 AM EST  
**Downtime**: 15 minutes expected

**Task List**:

1. **Database Maintenance** (30 minutes)
   ```sql
   -- Run on Keyfactor database
   USE Keyfactor;
   GO
   
   -- Update statistics
   EXEC sp_updatestats;
   
   -- Rebuild fragmented indexes
   DECLARE @TableName NVARCHAR(255);
   DECLARE @IndexName NVARCHAR(255);
   DECLARE @SQL NVARCHAR(MAX);
   
   DECLARE IndexCursor CURSOR FOR
   SELECT 
       OBJECT_NAME(ips.object_id) AS TableName,
       i.name AS IndexName
   FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
   INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
   WHERE ips.avg_fragmentation_in_percent > 30;
   
   OPEN IndexCursor;
   FETCH NEXT FROM IndexCursor INTO @TableName, @IndexName;
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
       SET @SQL = 'ALTER INDEX ' + @IndexName + ' ON ' + @TableName + ' REBUILD;';
       EXEC sp_executesql @SQL;
       FETCH NEXT FROM IndexCursor INTO @TableName, @IndexName;
   END;
   
   CLOSE IndexCursor;
   DEALLOCATE IndexCursor;
   ```

2. **Certificate Store Inventory** (45 minutes)
   - Trigger full inventory scan on all orchestrators
   - Expected: Complete within 1 hour
   - Review: Identify any unexpected certificates

3. **Log Rotation** (5 minutes)
   ```powershell
   # Rotate Keyfactor application logs
   $logPath = "C:\Program Files\Keyfactor\Logs"
   $archivePath = "C:\LogArchive\Keyfactor"
   $retentionDays = 90
   
   # Move logs older than 7 days to archive
   Get-ChildItem $logPath -Filter "*.log" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-7)} | ForEach-Object {
       Move-Item $_.FullName -Destination $archivePath
   }
   
   # Delete archived logs older than retention period
   Get-ChildItem $archivePath -Filter "*.log" | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$retentionDays)} | Remove-Item -Force
   ```

4. **Backup Verification** (10 minutes)
   - Verify last backup succeeded
   - Test restore to secondary environment (monthly)
   - Verify backup file integrity

---

### 4.2 Monthly Maintenance Tasks

**Schedule**: First Sunday of month, 2:00 AM - 6:00 AM EST

**Task List**:

1. **Certificate Ownership Audit** (2 hours)
   ```sql
   -- Find certificates without valid owners
   SELECT 
       CertificateID,
       SubjectName,
       ExpiryDate,
       Metadata_Owner,
       Metadata_Application
   FROM Certificates
   WHERE Metadata_Owner IS NULL 
       OR Metadata_Owner NOT IN (SELECT Email FROM ActiveDirectoryUsers)
   ORDER BY ExpiryDate;
   ```
   - Action: Contact service teams to update ownership

2. **Security Patch Review** (30 minutes)
   - Review Keyfactor security bulletins
   - Schedule patching for non-critical updates
   - Emergency patching for critical vulnerabilities

3. **Capacity Planning Review** (30 minutes)
   - Review growth trends
   - Forecast capacity needs for next quarter
   - Adjust thresholds if needed

4. **Orchestrator Health Report** (30 minutes)
   - Generate orchestrator performance report
   - Identify underperforming orchestrators
   - Schedule upgrades for outdated versions

---

### 4.3 Quarterly Maintenance Tasks

**Schedule**: First Sunday of quarter, 12:00 AM - 8:00 AM EST  
**Downtime**: Up to 4 hours

**Major Tasks**:

1. **Keyfactor Platform Upgrade**
   - Pre-upgrade backup
   - Database schema update
   - Application server upgrade
   - Orchestrator upgrades
   - Post-upgrade validation

2. **DR Failover Test**
   - Test failover to DR environment
   - Verify all services operational
   - Test failback procedure
   - Document lessons learned

3. **Performance Baseline Update**
   - Capture new performance baselines
   - Update monitoring thresholds
   - Identify optimization opportunities

---

## 5. Backup and Recovery

### 5.1 Backup Schedule

| Component | Frequency | Retention | Backup Method |
|-----------|-----------|-----------|---------------|
| Keyfactor Database | Daily (2:00 AM) | 30 days | SQL Server backup |
| Keyfactor Config | Daily (2:30 AM) | 90 days | File system backup |
| Certificate Store Inventory | Daily (3:00 AM) | 14 days | JSON export |
| HSM Keys | Never* | N/A | HSM backup procedures |
| Application Logs | Daily (4:00 AM) | 90 days | Log archival |

\* HSM keys backed up during initial configuration only, using HSM vendor procedures

**Backup Script** (Automated):
```powershell
# File: C:\Scripts\Backup-Keyfactor.ps1
# Schedule: Daily 2:00 AM via Task Scheduler

param(
    [string]$BackupPath = "\\backup-server\Keyfactor",
    [int]$RetentionDays = 30
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "C:\Logs\Backup-$timestamp.log"

function Write-Log {
    param([string]$Message)
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $entry
    Write-Host $entry
}

Write-Log "Starting Keyfactor backup"

# 1. Database backup
try {
    $dbBackupFile = "$BackupPath\Database\Keyfactor-$timestamp.bak"
    $sqlCmd = @"
    BACKUP DATABASE [Keyfactor] 
    TO DISK = '$dbBackupFile' 
    WITH COMPRESSION, CHECKSUM, STATS = 10;
    "@
    
    Invoke-Sqlcmd -Query $sqlCmd -ServerInstance "sql-server.contoso.com" -QueryTimeout 0
    Write-Log "Database backup completed: $dbBackupFile"
}
catch {
    Write-Log "ERROR: Database backup failed - $_"
    exit 1
}

# 2. Configuration backup
try {
    $configPath = "C:\Program Files\Keyfactor\Config"
    $configBackup = "$BackupPath\Config\Config-$timestamp.zip"
    Compress-Archive -Path $configPath -DestinationPath $configBackup -Force
    Write-Log "Configuration backup completed: $configBackup"
}
catch {
    Write-Log "ERROR: Configuration backup failed - $_"
}

# 3. Inventory export
try {
    $inventoryFile = "$BackupPath\Inventory\Inventory-$timestamp.json"
    # Export certificate inventory via API
    $apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI/Certificates/Export"
    $credential = Get-Credential # Use service account
    $inventory = Invoke-RestMethod -Uri $apiUrl -Method GET -Credential $credential
    $inventory | ConvertTo-Json -Depth 10 | Out-File $inventoryFile
    Write-Log "Inventory export completed: $inventoryFile"
}
catch {
    Write-Log "ERROR: Inventory export failed - $_"
}

# 4. Cleanup old backups
Write-Log "Cleaning up backups older than $RetentionDays days"
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem $BackupPath -Recurse -File | Where-Object {$_.CreationTime -lt $cutoffDate} | ForEach-Object {
    Write-Log "Deleting: $($_.FullName)"
    Remove-Item $_.FullName -Force
}

Write-Log "Backup completed successfully"
exit 0
```

---

### 5.2 Recovery Procedures

#### Scenario 1: Keyfactor Application Server Failure

**Recovery Time Objective (RTO)**: 2 hours  
**Recovery Point Objective (RPO)**: 24 hours

**Procedure**:

1. **Provision New Server** (30 minutes)
   - Deploy from template or provision new VM
   - Install Windows Server 2022
   - Configure networking (same IP if possible)

2. **Install Keyfactor Application** (30 minutes)
   ```powershell
   # Run Keyfactor installer
   Start-Process -FilePath "KeyfactorInstaller.msi" -ArgumentList "/quiet" -Wait
   
   # Restore configuration
   $latestConfig = Get-ChildItem "\\backup-server\Keyfactor\Config" | Sort-Object CreationTime -Descending | Select-Object -First 1
   Expand-Archive -Path $latestConfig.FullName -DestinationPath "C:\Program Files\Keyfactor\Config" -Force
   ```

3. **Restore Database Connection** (15 minutes)
   - Update connection string in `web.config`
   - Test database connectivity
   - Restart IIS

4. **Verify Functionality** (15 minutes)
   - Test login
   - Verify orchestrator connections
   - Test certificate issuance
   - Review error logs

5. **Resume Operations** (30 minutes)
   - Update DNS if needed
   - Notify teams of recovery
   - Monitor for 2 hours

---

#### Scenario 2: Database Corruption

**RTO**: 4 hours  
**RPO**: 24 hours (last backup)

**Procedure**:

1. **Assess Damage** (15 minutes)
   ```sql
   -- Check database integrity
   USE Keyfactor;
   DBCC CHECKDB (Keyfactor) WITH NO_INFOMSGS, ALL_ERRORMSGS;
   ```

2. **Decision Point**:
   - **Minor corruption**: Attempt repair
   - **Major corruption**: Restore from backup

3. **Restore from Backup** (2 hours)
   ```sql
   -- Take database offline
   ALTER DATABASE Keyfactor SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
   
   -- Restore latest backup
   RESTORE DATABASE Keyfactor 
   FROM DISK = '\\backup-server\Keyfactor\Database\Keyfactor-20251022-020000.bak'
   WITH REPLACE, RECOVERY;
   
   -- Bring back online
   ALTER DATABASE Keyfactor SET MULTI_USER;
   ```

4. **Verify Data Integrity** (30 minutes)
   - Run consistency checks
   - Verify certificate counts match expected
   - Check recent transactions

5. **Catchup Operations** (1 hour)
   - Review certificates issued since backup
   - Re-issue any certificates from the gap period
   - Notify affected users

---

## 6. User Support

### 6.1 Common User Issues

#### Issue: "I can't log in to the Keyfactor portal"

**Troubleshooting Steps**:

1. **Verify Account Status**
   - Check Active Directory: Account enabled?
   - Check Keyfactor role assignments
   - Verify MFA setup (if enabled)

2. **Test Authentication**
   ```powershell
   # Test AD authentication
   $credential = Get-Credential
   $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain')
   $context.ValidateCredentials($credential.UserName, $credential.GetNetworkCredential().Password)
   ```

3. **Common Solutions**:
   - Reset password in Active Directory
   - Clear browser cache and cookies
   - Try different browser
   - Add user to appropriate AD security group

---

#### Issue: "My certificate request was rejected"

**Troubleshooting Steps**:

1. **Review Rejection Reason**
   ```
   Navigation: Certificates → Requests → Find request → View Details
   ```

2. **Common Rejection Reasons**:

| Rejection Reason | Solution |
|-----------------|----------|
| "SAN not authorized for user" | User doesn't own the hostname - verify in asset inventory |
| "Invalid CSR format" | Regenerate CSR with correct parameters |
| "Template not allowed" | User role doesn't permit this template - request access |
| "Duplicate certificate exists" | Active cert for same SAN - revoke old or wait for expiry |
| "Policy violation" | CSR doesn't meet template requirements (key size, validity) |

3. **Resubmit Process**:
   - Address rejection reason
   - Submit new request
   - Escalate to PKI team if unclear

---

#### Issue: "Certificate not deploying to my server"

**Troubleshooting Steps**:

1. **Verify Orchestrator Connection**
   ```
   Navigation: Orchestrators → Find orchestrator for server → Check status
   ```
   - Status should be "Connected"
   - Last heartbeat < 5 minutes

2. **Check Certificate Store Configuration**
   ```
   Navigation: Certificate Stores → Find store → Verify:
   - Path is correct
   - Credentials are valid
   - Orchestrator is assigned
   ```

3. **Review Deployment Job**
   ```
   Navigation: Jobs → Filter by certificate ID
   ```
   - Check job status and error messages
   - Common errors:
     - Permission denied: Update store credentials
     - Path not found: Verify store path
     - Store full: Clean up old certificates

4. **Manual Deployment**:
   - If automated deployment fails repeatedly, deploy manually
   - Document issue for root cause analysis

---

### 6.2 Support Ticket SLAs

| Priority | Response Time | Resolution Time | Examples |
|----------|--------------|----------------|----------|
| P1 - Critical | 15 minutes | 4 hours | CA offline, production cert expired |
| P2 - High | 1 hour | 1 business day | Cert not deploying, urgent renewal |
| P3 - Medium | 4 hours | 3 business days | Certificate request help, access issues |
| P4 - Low | 1 business day | 5 business days | General questions, documentation |

---

## 7. Break-Glass Procedures

### 7.1 Emergency CA Access

**Scenario**: Primary CA offline, emergency certificate issuance required

**Prerequisites**:
- Break-glass account credentials (stored in secure vault)
- Approval from CISO or delegate
- Incident ticket created

**Procedure**:

1. **Retrieve Break-Glass Credentials**
   ```powershell
   # From Azure Key Vault
   $secret = Get-AzKeyVaultSecret -VaultName "vault-pki-prod" -Name "breakglass-ca-admin"
   $credential = New-Object PSCredential("breakglass-admin", $secret.SecretValue)
   ```

2. **Access Backup CA**
   - Connect to secondary CA (if available)
   - Or: Issue from EJBCA instead of AD CS

3. **Issue Emergency Certificate**
   - Use Keyfactor portal with elevated account
   - Or: Direct CA issuance:
   ```powershell
   # Windows CA
   certreq -submit -attrib "CertificateTemplate:WebServerEmergency" request.csr emergency.cer
   ```

4. **Deploy Certificate**
   - Manual deployment to affected system
   - Update monitoring to track emergency cert

5. **Post-Incident**
   - Document all actions taken
   - Schedule proper certificate reissuance
   - Rotate break-glass credentials
   - Conduct post-mortem

---

### 7.2 Emergency Revocation (Key Compromise)

**Trigger**: Confirmed or suspected private key compromise

**Immediate Actions** (Within 15 minutes):

1. **Revoke Certificate**
   ```powershell
   # Via Keyfactor API
   $apiUrl = "https://keyfactor.contoso.com/KeyfactorAPI/Certificates/$certId/Revoke"
   $body = @{
       RevocationReason = 1  # Key Compromise
       EffectiveDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
       Comment = "EMERGENCY: Key compromise suspected"
   } | ConvertTo-Json
   
   Invoke-RestMethod -Uri $apiUrl -Method POST -Body $body -Credential $credential -ContentType "application/json"
   ```

2. **Force CRL Publication**
   - Update CRL immediately (don't wait for next scheduled update)
   - Verify CRL contains revoked certificate

3. **Remove from All Stores**
   ```powershell
   # Force immediate removal
   Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -eq $compromisedThumbprint} | Remove-Item -Force
   ```

4. **Notify Stakeholders**
   - Email to security team
   - Slack alert in #security-incidents
   - Page on-call security engineer if after hours

5. **Issue Replacement Certificate**
   - Generate new key pair (NEVER reuse compromised key)
   - Fast-track issuance process
   - Deploy ASAP

**Follow-Up Actions** (Within 24 hours):
- Investigate how compromise occurred
- Review access logs
- Check for other potentially compromised certificates
- Update incident response procedures if needed

---

## 8. Change Management

### 8.1 Change Request Process

All changes to the Keyfactor platform require a change request except:
- Certificate issuance/renewal (standard operations)
- Non-privileged user access changes
- Log review and monitoring

**Change Categories**:

| Type | Examples | Approval Required | Notice Period |
|------|----------|-------------------|---------------|
| **Standard** | Certificate template updates, new orchestrator | PKI Lead | 3 business days |
| **Major** | Platform upgrade, new CA integration | Change Board + CISO | 2 weeks |
| **Emergency** | Security patch, break-glass access | CISO or VP Infrastructure | Immediate |

**Standard Change Template**:
```
Change Request: [Title]
Requestor: [Name]
Date: [YYYY-MM-DD]
Type: Standard / Major / Emergency

Description:
[Detailed description of change]

Business Justification:
[Why this change is needed]

Technical Details:
[What will be changed]

Risk Assessment:
Impact: Low / Medium / High
Probability: Low / Medium / High
Mitigation: [How risks will be managed]

Testing Plan:
[How change will be tested before production]

Rollback Plan:
[How to undo change if issues occur]

Maintenance Window:
Date: [YYYY-MM-DD]
Time: [HH:MM - HH:MM] [Timezone]
Expected Duration: [X] hours
Downtime Required: Yes / No

Approvals:
PKI Lead: ________________ Date: ________
Change Board: ________________ Date: ________ (if Major)
CISO: ________________ Date: ________ (if Emergency)
```

---

### 8.2 Standard Maintenance Windows

| Window | Schedule | Max Duration | Acceptable Changes |
|--------|----------|-------------|-------------------|
| Weekly | Sunday 2:00-4:00 AM EST | 2 hours | Database maintenance, log rotation, minor updates |
| Monthly | First Sunday 2:00-6:00 AM EST | 4 hours | Security patches, orchestrator updates |
| Quarterly | First Sunday 12:00-8:00 AM EST | 8 hours | Platform upgrades, major configuration changes |

**Emergency Changes** (Outside Maintenance Windows):
- Security vulnerabilities (CVSS ≥ 8.0)
- Service affecting outages
- Regulatory compliance requirements
- Must have CISO approval

---

## 9. Capacity Planning

### 9.1 Growth Monitoring

**Monthly Metrics to Track**:

```sql
-- Certificate growth rate
WITH MonthlyStats AS (
    SELECT 
        YEAR(IssuedDate) AS Year,
        MONTH(IssuedDate) AS Month,
        COUNT(*) AS CertificatesIssued
    FROM Certificates
    WHERE IssuedDate >= DATEADD(MONTH, -12, GETDATE())
    GROUP BY YEAR(IssuedDate), MONTH(IssuedDate)
)
SELECT 
    Year,
    Month,
    CertificatesIssued,
    CertificatesIssued - LAG(CertificatesIssued) OVER (ORDER BY Year, Month) AS GrowthFromPreviousMonth,
    CAST(
        (CertificatesIssued - LAG(CertificatesIssued) OVER (ORDER BY Year, Month)) * 100.0 
        / NULLIF(LAG(CertificatesIssued) OVER (ORDER BY Year, Month), 0)
    AS DECIMAL(5,2)) AS GrowthPercentage
FROM MonthlyStats
ORDER BY Year DESC, Month DESC;
```

**Capacity Indicators**:

| Metric | Current Capacity | Warning Threshold | Action Required |
|--------|-----------------|-------------------|-----------------|
| Total Certificates | 100,000 | 80,000 (80%) | Plan database expansion |
| Certificates/Day | 1,000 | 800 (80%) | Add CA capacity |
| Orchestrators | 100 | 80 (80%) | Deploy additional orchestrators |
| Database Size | 100 GB | 80 GB (80%) | Expand storage |
| API Requests/Second | 100 | 80 (80%) | Scale application servers |

---

### 9.2 Capacity Planning Projections

**Quarterly Forecast**:
```
Current State (Q4 2025):
- Total Certificates: 45,234
- Monthly Issuance: 2,500
- Active Orchestrators: 45

Growth Rate (Last 6 Months): 15% per quarter

Projected State (Q2 2026):
- Total Certificates: ~70,000
- Monthly Issuance: ~3,750
- Orchestrators Needed: ~60

Recommended Actions:
1. Add 2 application servers by Q1 2026
2. Deploy 15 additional orchestrators by Q1 2026
3. Expand database storage by 50GB by Q2 2026
4. Review and optimize database queries
```

---

## 10. On-Call Responsibilities

### 10.1 On-Call Rotation

**Schedule**: 24/7 coverage, 1-week rotations  
**Team Size**: 4 engineers (primary + backup)  
**Handoff**: Friday 5:00 PM EST

**On-Call Checklist** (Start of Shift):
```markdown
□ Review open incidents from previous shift
□ Check current system health
□ Verify access to all required systems:
  □ Keyfactor web portal
  □ VPN access
  □ PagerDuty account active
  □ Azure portal access
  □ SQL Server access
  □ HSM admin access (if applicable)
□ Review upcoming maintenance windows
□ Test break-glass procedures access
□ Verify contact information current
```

---

### 10.2 Escalation Matrix

| Issue Severity | Initial Response | Escalation Path | Max Time Before Escalation |
|----------------|-----------------|----------------|---------------------------|
| **P1 - Critical** | On-call engineer | → PKI Lead → CISO → VP Infrastructure | 30 minutes |
| **P2 - High** | On-call engineer | → PKI Lead | 2 hours |
| **P3 - Medium** | On-call engineer | → PKI Lead (next business day) | 4 hours |
| **P4 - Low** | Ticket queue | → Team review | Next business day |

**Contact Information**:
```
On-Call Engineer: PagerDuty auto-routes
PKI Lead: [Name] - [Phone] - [Email]
Backup: [Name] - [Phone] - [Email]
CISO: [Name] - [Phone] (emergencies only)
VP Infrastructure: [Name] - [Phone] (emergencies only)
Keyfactor Support: +1-800-XXX-XXXX (24/7)
HSM Vendor Support: +1-800-YYY-YYYY (24/7)
```

---

### 10.3 After-Hours Procedures

**Decision Tree**: Should I wake someone up?

```
┌─────────────────────────────────┐
│ Is production impacted?         │
└────────────┬────────────────────┘
             │
      ┌──────┴──────┐
      │ YES         │ NO
      │             │
      v             v
┌─────────────┐   Wait until
│ Can you fix │   business hours
│ it yourself?│
└──────┬──────┘
       │
 ┌─────┴─────┐
 │YES       │NO
 │          │
 v          v
Fix it    Escalate
Document  immediately
```

**Acceptable After-Hours Actions** (No escalation needed):
- Certificate issuance (if automated)
- Restart orchestrator service
- Clear disk space
- Reset user password
- Acknowledge and monitor non-critical alerts

**Require Escalation**:
- CA offline
- HSM unavailable
- Database corruption
- Widespread certificate expiry
- Security incident
- Any P1 alert

---

## Appendix A: Command Reference

### A.1 PowerShell Commands

```powershell
# Check orchestrator status
Get-Service "Keyfactor Orchestrator"

# Restart orchestrator
Restart-Service "Keyfactor Orchestrator"

# View recent errors
Get-EventLog -LogName Application -Source "Keyfactor*" -EntryType Error -Newest 20

# Export certificate inventory
$certs = Invoke-RestMethod -Uri "https://keyfactor.contoso.com/KeyfactorAPI/Certificates" -Credential $cred
$certs | Export-Csv -Path "cert-inventory.csv" -NoTypeInformation

# Find expiring certificates
$expiringCerts = $certs | Where-Object { 
    [datetime]$_.NotAfter -lt (Get-Date).AddDays(30) 
} | Select-Object Subject, NotAfter, Owner
```

### A.2 SQL Queries

```sql
-- Certificate count by template
SELECT 
    TemplateName,
    COUNT(*) AS Count,
    AVG(DATEDIFF(DAY, GETDATE(), ExpiryDate)) AS AvgDaysToExpiry
FROM Certificates
WHERE Status = 'Active'
GROUP BY TemplateName
ORDER BY Count DESC;

-- Top certificate owners
SELECT TOP 10
    Owner,
    COUNT(*) AS CertificateCount
FROM Certificates
WHERE Status = 'Active'
GROUP BY Owner
ORDER BY CertificateCount DESC;

-- Failed requests in last 24 hours
SELECT 
    RequestID,
    RequestTime,
    RequestorUser,
    FailureReason
FROM CertificateRequests
WHERE Status = 'Failed'
    AND RequestTime >= DATEADD(HOUR, -24, GETDATE())
ORDER BY RequestTime DESC;
```

---

## Appendix B: Quick Reference Cards

### B.1 Health Check Card
```
DAILY HEALTH CHECK QUICK REFERENCE

□ Portal accessible
□ All CAs online
□ All orchestrators connected
□ No expired certificates
□ Backup completed (last 24h)
□ < 50 certificates expiring in 7 days
□ Renewal success rate > 95%
□ No critical alerts

If ANY fail: Investigate immediately
If 3+ fail: Escalate to PKI Lead
```

### B.2 Emergency Contacts
```
EMERGENCY CONTACTS

PagerDuty: https://contoso.pagerduty.com
On-Call: Auto-routed via PagerDuty

Keyfactor Support: +1-800-XXX-XXXX
HSM Support: +1-800-YYY-YYYY
Microsoft Support: +1-800-XXX-XXXX

PKI Lead: [Name] [Phone]
CISO: [Name] [Phone] (P1 only)
```

---

## Appendix C: Runbook Index

Quick links to related runbooks:

- [05-Implementation-Runbooks.md](./05-Implementation-Runbooks.md) - Implementation procedures
- [06-Automation-Playbooks.md](./06-Automation-Playbooks.md) - Automation scripts
- [10-Incident-Response-Procedures.md](./10-Incident-Response-Procedures.md) - Detailed troubleshooting

---

## Document Maintenance

**Review Schedule**: Quarterly  
**Owner**: PKI Operations Team  
**Last Reviewed**: October 22, 2025  
**Next Review**: January 22, 2026

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial version |

---

**For questions or updates to this document, contact**: adrian207@gmail.com

**End of Operations Manual**

