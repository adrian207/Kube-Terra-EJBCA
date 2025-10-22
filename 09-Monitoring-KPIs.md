# Keyfactor Monitoring & KPIs
## Metrics, Dashboards, and Success Criteria

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use  
**Target Audience**: Operations teams, management, compliance

---

## Document Purpose

This document defines all key performance indicators (KPIs), service level objectives (SLOs), monitoring metrics, and dashboard configurations for the Keyfactor certificate lifecycle management platform.

---

## Table of Contents

1. [KPI Framework](#1-kpi-framework)
2. [Service Level Objectives](#2-service-level-objectives)
3. [Operational Metrics](#3-operational-metrics)
4. [Dashboard Specifications](#4-dashboard-specifications)
5. [Alerting Configuration](#5-alerting-configuration)
6. [Reporting Requirements](#6-reporting-requirements)
7. [Compliance Metrics](#7-compliance-metrics)
8. [Performance Baselines](#8-performance-baselines)

---

## 1. KPI Framework

### 1.1 Strategic KPIs (Executive Dashboard)

**Purpose**: High-level metrics for leadership and stakeholders  
**Update Frequency**: Monthly  
**Distribution**: Executive leadership, board presentations

| KPI | Target | Measurement | Business Impact |
|-----|--------|-------------|----------------|
| **Certificate Lifecycle Automation Rate** | ≥ 85% | (Automated Operations / Total Operations) × 100 | Reduced manual effort, lower costs |
| **Mean Time to Issue Certificate** | ≤ 15 minutes | Average time from request to issuance | Developer productivity |
| **Certificate Expiry Prevention Rate** | ≥ 99.5% | (Non-Expired Certs / Total Certs) × 100 | Service availability |
| **PKI Platform Availability** | ≥ 99.9% | Uptime / Total Time × 100 | Business continuity |
| **Security Incident Rate** | 0 | Compromised certificates / month | Security posture |
| **Cost Per Certificate** | ≤ $15 | Total PKI Costs / Active Certificates | Financial efficiency |
| **Compliance Score** | 100% | Compliant Controls / Total Controls × 100 | Audit readiness |

**Visualization**: Executive Summary Dashboard

```
╔══════════════════════════════════════════════════════════════╗
║           PKI PLATFORM - EXECUTIVE DASHBOARD                  ║
║                    Month: October 2025                        ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Automation Rate:  [██████████████████░░] 87% ✅             ║
║  Target: ≥85%                                                 ║
║                                                               ║
║  Avg Issue Time:   12 minutes ✅                             ║
║  Target: ≤15 minutes                                          ║
║                                                               ║
║  Expiry Prevention: [███████████████████████] 99.8% ✅       ║
║  Target: ≥99.5%                                               ║
║                                                               ║
║  Platform Uptime:  [███████████████████████] 99.95% ✅       ║
║  Target: ≥99.9%                                               ║
║                                                               ║
║  Security Incidents: 0 ✅                                     ║
║  Target: 0                                                    ║
║                                                               ║
║  Cost Per Cert:    $12.50 ✅                                 ║
║  Target: ≤$15                                                 ║
║                                                               ║
║  Compliance:       [████████████████████████] 100% ✅         ║
║  Target: 100%                                                 ║
║                                                               ║
╠══════════════════════════════════════════════════════════════╣
║  Overall Status: ✅ ALL TARGETS MET                          ║
╚══════════════════════════════════════════════════════════════╝
```

---

### 1.2 Operational KPIs (Daily Monitoring)

**Purpose**: Day-to-day platform performance  
**Update Frequency**: Real-time / Hourly  
**Distribution**: Operations team, on-call engineers

| KPI | Target | Alert Threshold | Measurement Method |
|-----|--------|----------------|-------------------|
| Certificate Issuance Success Rate | ≥ 98% | < 95% | (Successful / Total Requests) × 100 |
| Certificate Renewal Success Rate | ≥ 99% | < 97% | (Successful Renewals / Total Due) × 100 |
| Orchestrator Uptime | ≥ 99% | < 98% | Connected Time / Total Time × 100 |
| CA Response Time | ≤ 2 seconds | > 5 seconds | Average API response time |
| Database Query Performance | ≤ 100ms avg | > 500ms | Query execution time |
| API Availability | ≥ 99.5% | < 99% | Successful API Calls / Total Calls × 100 |
| Webhook Delivery Success | ≥ 95% | < 90% | Successful Deliveries / Total Events × 100 |
| Certificate Store Sync Success | ≥ 98% | < 95% | Successful Syncs / Total Stores × 100 |

---

### 1.3 Business KPIs (Monthly Reporting)

**Purpose**: Demonstrate business value and ROI  
**Update Frequency**: Monthly  
**Distribution**: Finance, management, stakeholders

| KPI | Calculation | Target | Business Value |
|-----|------------|--------|----------------|
| **Time Saved (Hours/Month)** | (Manual Ops Avoided × Time Per Op) / 60 | ≥ 500 hours | Labor cost savings |
| **Incident Reduction Rate** | (Old Incidents - New Incidents) / Old Incidents × 100 | ≥ 80% | Operational efficiency |
| **Self-Service Adoption** | Self-Service Requests / Total Requests × 100 | ≥ 70% | Reduced support burden |
| **Audit Readiness Score** | Audit-Ready Certs / Total Certs × 100 | 100% | Compliance confidence |
| **Certificate Reuse Rate** | Renewed Certs / Expired Certs × 100 | ≥ 95% | Efficient operations |

---

## 2. Service Level Objectives (SLOs)

### 2.1 Availability SLOs

**Platform Availability**: 99.9% monthly uptime

```
Calculation: (Total Minutes - Downtime Minutes) / Total Minutes × 100

Monthly Allowance: 43.2 minutes downtime per month
Weekly Allowance: 10.1 minutes downtime per week
Daily Allowance: 1.4 minutes downtime per day
```

**Planned Maintenance**: Not counted against SLO if:
- Scheduled during approved maintenance window
- Notified 48 hours in advance
- Completed within window

**Measurement**:
```sql
-- Query for monthly availability
DECLARE @StartDate DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);
DECLARE @EndDate DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) + 1, 0);
DECLARE @TotalMinutes INT = DATEDIFF(MINUTE, @StartDate, @EndDate);
DECLARE @DowntimeMinutes INT = (
    SELECT SUM(DATEDIFF(MINUTE, StartTime, EndTime))
    FROM Outages
    WHERE StartTime >= @StartDate AND EndTime < @EndDate
        AND PlannedMaintenance = 0
);

SELECT 
    @TotalMinutes AS TotalMinutes,
    @DowntimeMinutes AS DowntimeMinutes,
    CAST((@TotalMinutes - @DowntimeMinutes) * 100.0 / @TotalMinutes AS DECIMAL(5,2)) AS UptimePercentage,
    CASE 
        WHEN CAST((@TotalMinutes - @DowntimeMinutes) * 100.0 / @TotalMinutes AS DECIMAL(5,2)) >= 99.9 
        THEN 'MET' 
        ELSE 'MISSED' 
    END AS SLO_Status;
```

---

### 2.2 Performance SLOs

#### Certificate Issuance Time

**SLO**: 95% of certificate requests complete within 15 minutes

```
Measurement Window: Rolling 7 days
Success Criteria: P95 latency ≤ 15 minutes

Breakdown by Priority:
- P1 (Production): ≤ 10 minutes (99%)
- P2 (Non-Production): ≤ 15 minutes (95%)
- P3 (Test/Dev): ≤ 30 minutes (90%)
```

**Monitoring Query**:
```sql
WITH RecentRequests AS (
    SELECT 
        RequestID,
        RequestTime,
        CompletionTime,
        DATEDIFF(MINUTE, RequestTime, CompletionTime) AS DurationMinutes,
        Priority
    FROM CertificateRequests
    WHERE CompletionTime >= DATEADD(DAY, -7, GETDATE())
        AND Status = 'Completed'
)
SELECT 
    Priority,
    COUNT(*) AS TotalRequests,
    AVG(DurationMinutes) AS AvgDurationMinutes,
    MAX(DurationMinutes) AS MaxDurationMinutes,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY DurationMinutes) OVER (PARTITION BY Priority) AS P50,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY DurationMinutes) OVER (PARTITION BY Priority) AS P95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY DurationMinutes) OVER (PARTITION BY Priority) AS P99
FROM RecentRequests
GROUP BY Priority;
```

---

#### API Response Time

**SLO**: 99% of API requests complete within 2 seconds

```
Endpoint-Specific SLOs:

/Certificates (GET):     < 500ms (P95)
/Certificates (POST):    < 2s (P95)
/Certificates/{id}:      < 200ms (P95)
/Certificates/Search:    < 1s (P95)
/Orchestrators:          < 500ms (P95)
/CertificateStores:      < 1s (P95)
```

**Dashboard Visualization**:
```
API Performance (Last Hour)

GET /Certificates
[██████████████████░░] P50: 180ms | P95: 450ms | P99: 890ms ✅

POST /Certificates  
[███████████████░░░░░] P50: 850ms | P95: 1.8s | P99: 3.2s ✅

GET /Certificates/{id}
[████████████████████] P50: 45ms | P95: 120ms | P99: 280ms ✅

POST /Certificates/Search
[██████████████████░░] P50: 420ms | P95: 980ms | P99: 1.5s ✅
```

---

### 2.3 Reliability SLOs

#### Certificate Renewal Success Rate

**SLO**: 99% of eligible certificates renew automatically

```
Exclusions (Not counted):
- Certificates pending manual approval
- Certificates explicitly marked "manual renewal"
- Certificates belonging to decommissioned services

Success Criteria:
- Certificate renewed before expiration
- New certificate deployed to all stores
- Old certificate marked for revocation
- Service continuity maintained
```

**Failure Categories**:
| Failure Type | Current Rate | Target | Action |
|-------------|-------------|--------|--------|
| CA Unavailable | 0.2% | < 0.5% | Auto-retry, fail to backup CA |
| Policy Violation | 0.1% | < 0.2% | Alert owner, manual intervention |
| Deployment Failed | 0.4% | < 0.5% | Retry 3x, escalate if failed |
| Approval Timeout | 0.3% | < 0.5% | Escalate to owner after 48h |

---

#### Orchestrator Reliability

**SLO**: 98% of orchestrators maintain connection 99% of the time

```
Measurement:
- Track heartbeat status every 5 minutes
- Flag orchestrator as "disconnected" if no heartbeat for 15 minutes
- Calculate uptime per orchestrator per month

Acceptable Disconnections:
- Planned maintenance (notified in advance)
- Server reboots (< 10 minutes)
- Network maintenance (< 30 minutes)
```

---

## 3. Operational Metrics

### 3.1 Certificate Inventory Metrics

**Collected**: Real-time via Keyfactor API  
**Stored**: Time-series database (InfluxDB/Prometheus)  
**Retention**: 2 years

| Metric | Description | Collection Frequency |
|--------|-------------|---------------------|
| `cert.total.count` | Total certificates in inventory | 5 minutes |
| `cert.active.count` | Active certificates (not expired/revoked) | 5 minutes |
| `cert.expired.count` | Expired certificates | 5 minutes |
| `cert.expiring.count{days="7"}` | Expiring within 7 days | 5 minutes |
| `cert.expiring.count{days="30"}` | Expiring within 30 days | 5 minutes |
| `cert.expiring.count{days="90"}` | Expiring within 90 days | 5 minutes |
| `cert.revoked.count` | Revoked certificates | 5 minutes |
| `cert.by_template.count` | Certificates by template | 15 minutes |
| `cert.by_issuer.count` | Certificates by issuing CA | 15 minutes |
| `cert.by_owner.count` | Certificates by owner | 30 minutes |

**Prometheus Metrics Export**:
```python
# Example Prometheus exporter
from prometheus_client import Gauge, CollectorRegistry
import requests

registry = CollectorRegistry()

cert_total = Gauge('keyfactor_certificates_total', 'Total certificates', registry=registry)
cert_active = Gauge('keyfactor_certificates_active', 'Active certificates', registry=registry)
cert_expiring = Gauge('keyfactor_certificates_expiring', 'Expiring certificates', ['days'], registry=registry)

def collect_metrics():
    api_url = "https://keyfactor.contoso.com/KeyfactorAPI/Certificates/Metrics"
    response = requests.get(api_url, auth=auth)
    data = response.json()
    
    cert_total.set(data['total'])
    cert_active.set(data['active'])
    cert_expiring.labels(days='7').set(data['expiring_7d'])
    cert_expiring.labels(days='30').set(data['expiring_30d'])
    cert_expiring.labels(days='90').set(data['expiring_90d'])
```

---

### 3.2 Issuance Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|----------------|
| `cert.issuance.total` | Total certificates issued | - |
| `cert.issuance.rate` | Certificates per hour | > 200/hr (capacity alert) |
| `cert.issuance.success_rate` | Successful issuances | < 95% |
| `cert.issuance.duration_seconds` | Time to issue | P95 > 900s (15min) |
| `cert.issuance.by_template` | Issuances per template | - |
| `cert.issuance.by_ca` | Issuances per CA | Imbalance > 30% |
| `cert.requests.pending.count` | Pending approval | > 100 |
| `cert.requests.failed.count` | Failed requests (24h) | > 20 |

**Grafana Query Examples**:
```promql
# Certificate issuance rate (per hour)
rate(keyfactor_certificates_issued_total[1h]) * 3600

# Success rate (last 24 hours)
(
  sum(rate(keyfactor_certificate_issuance_success_total[24h])) /
  sum(rate(keyfactor_certificate_issuance_attempts_total[24h]))
) * 100

# P95 issuance duration
histogram_quantile(0.95, rate(keyfactor_certificate_issuance_duration_seconds_bucket[5m]))
```

---

### 3.3 Renewal Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|----------------|
| `cert.renewal.eligible.count` | Certificates due for renewal | - |
| `cert.renewal.success.count` | Successfully renewed | - |
| `cert.renewal.failed.count` | Failed renewals | > 10/day |
| `cert.renewal.success_rate` | Renewal success rate | < 97% |
| `cert.renewal.auto_rate` | Automated renewal rate | < 85% |
| `cert.renewal.pending.count` | Renewals pending approval | > 50 |
| `cert.renewal.duration_seconds` | Time to renew and deploy | P95 > 1800s (30min) |

---

### 3.4 Platform Health Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|----------------|
| `keyfactor.api.requests.total` | Total API requests | - |
| `keyfactor.api.requests.rate` | Requests per second | > 100 (capacity) |
| `keyfactor.api.response_time_seconds` | API response time | P95 > 2s |
| `keyfactor.api.errors.count` | API errors (5xx) | > 10/hour |
| `keyfactor.db.connections.active` | Active DB connections | > 80% of pool |
| `keyfactor.db.query_time_seconds` | Database query time | P95 > 0.5s |
| `keyfactor.orchestrator.connected.count` | Connected orchestrators | < 95% of total |
| `keyfactor.orchestrator.jobs.pending` | Pending orchestrator jobs | > 1000 |
| `keyfactor.ca.response_time_seconds` | CA response time | > 5s |
| `keyfactor.ca.availability` | CA availability (%) | < 99% |

---

### 3.5 Security Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|----------------|
| `cert.weak_key.count` | Certificates with RSA < 2048 bits | > 0 (immediate action) |
| `cert.revoked.rate` | Revocations per day | > 20 (investigate) |
| `cert.emergency_revoked.count` | Emergency revocations | > 0 (security review) |
| `auth.failed_logins.count` | Failed login attempts | > 50/hour |
| `auth.suspicious_activity.count` | Suspicious authentication patterns | > 0 |
| `hsm.operations.failed.count` | Failed HSM operations | > 5/hour |
| `audit.log.gaps.count` | Audit log gaps detected | > 0 (critical) |

---

## 4. Dashboard Specifications

### 4.1 Executive Dashboard

**URL**: `https://grafana.contoso.com/d/keyfactor-executive`  
**Audience**: CIO, CISO, VP Infrastructure  
**Update Frequency**: Daily  
**Data Retention**: 1 year

**Layout**:
```
┌─────────────────────────────────────────────────────────────┐
│  KEYFACTOR PKI PLATFORM - EXECUTIVE DASHBOARD               │
│  Last Updated: 2025-10-22 09:00 EST                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Total Certs│  │   Uptime    │  │  Cost/Cert  │         │
│  │             │  │             │  │             │         │
│  │   45,234    │  │   99.95%    │  │   $12.50    │         │
│  │    ✅       │  │    ✅       │  │    ✅       │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Certificate Issuance Trend (30 Days)                │   │
│  │                                                      │   │
│  │  300┤                                      ●         │   │
│  │  250┤                              ●     ●           │   │
│  │  200┤                    ●   ●   ●                   │   │
│  │  150┤          ●   ●   ●                             │   │
│  │  100┤    ●   ●                                       │   │
│  │   50┤  ●                                             │   │
│  │    0└──────────────────────────────────────────────│   │
│  │      Oct 1        Oct 10       Oct 20      Oct 30   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────┐   │
│  │  Expiring Soon │  │ Auto-Renewal   │  │  Incidents │   │
│  │   (30 days)    │  │      Rate      │  │ (This Month│   │
│  │                │  │                │  │            │   │
│  │      287       │  │      87%       │  │      0     │   │
│  │      ⚠️        │  │      ✅        │  │      ✅    │   │
│  └────────────────┘  └────────────────┘  └────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Panels**:
1. **KPI Summary Cards** (Top Row)
   - Total Active Certificates (gauge)
   - Platform Uptime (gauge with sparkline)
   - Cost Per Certificate (stat)

2. **Certificate Issuance Trend** (Main Panel)
   - Time series graph (30 days)
   - Daily issuance count
   - 7-day moving average overlay

3. **Health Indicators** (Bottom Row)
   - Certificates expiring within 30 days
   - Auto-renewal success rate
   - Security incidents this month

---

### 4.2 Operations Dashboard

**URL**: `https://grafana.contoso.com/d/keyfactor-operations`  
**Audience**: Operations team, on-call engineers  
**Update Frequency**: Real-time (30-second refresh)  
**Data Retention**: 90 days

**Layout**:
```
┌──────────────────────────────────────────────────────────────┐
│  KEYFACTOR PKI PLATFORM - OPERATIONS DASHBOARD               │
│  Live View - Auto-refresh: 30s                               │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │ API Latency │ │  CA Status  │ │Orchestrators│            │
│  │             │ │             │ │             │            │
│  │   180ms     │ │  4/4 Online │ │  44/45      │            │
│  │    ✅       │ │     ✅      │ │     ⚠️      │            │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Certificate Issuance Rate (Last Hour)                  │  │
│  │                                                         │  │
│  │ 60┤                           ●                        │  │
│  │ 50┤                     ●           ●                  │  │
│  │ 40┤               ●           ●           ●            │  │
│  │ 30┤         ●           ●                              │  │
│  │ 20┤   ●           ●                                    │  │
│  │ 10┤                                                    │  │
│  │  0└─────────────────────────────────────────────────  │  │
│  │    :00    :15    :30    :45    :00    :15    :30      │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────┐  ┌──────────────────────────────┐    │
│  │ Pending Approvals │  │  Recent Errors (24h)         │    │
│  │                   │  │                               │    │
│  │        23         │  │  CA Timeout: 3                │    │
│  │   [View Queue]    │  │  Policy Violation: 2          │    │
│  │                   │  │  Network Error: 1             │    │
│  └───────────────────┘  └──────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Orchestrator Status Map                               │   │
│  │                                                        │   │
│  │  ✅ webapp-orch-01  ✅ webapp-orch-02  ⚠️ webapp-orch-05│   │
│  │  ✅ db-orch-01      ✅ db-orch-02      ✅ api-orch-01   │   │
│  │  ✅ azure-orch-01   ✅ azure-orch-02   ✅ k8s-orch-01   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

**Panels**:
1. **Health Metrics** (Top)
   - API Response Time (gauge, P95)
   - CA Availability (status indicator)
   - Orchestrator Connectivity (fraction)

2. **Issuance Activity** (Time Series)
   - Certificates issued per minute
   - Success vs. failure rates
   - Anomaly detection overlay

3. **Action Queues** (Tables)
   - Pending approval requests
   - Failed operations with links to details

4. **Infrastructure Status** (Status Map)
   - All orchestrators with health indicators
   - Click for details and logs

---

### 4.3 Certificate Health Dashboard

**URL**: `https://grafana.contoso.com/d/keyfactor-certificates`  
**Audience**: PKI operators, certificate owners  
**Update Frequency**: Every 5 minutes  
**Data Retention**: 1 year

**Key Panels**:

**Panel 1: Certificate Expiry Timeline**
```
Heatmap showing certificate expirations over next 365 days

        Week 1  Week 2  Week 3  Week 4  ...
Mon     ░░░░    ░░░░    ▓▓▓▓    ░░░░    ...
Tue     ░░░░    ▓▓▓▓    ████    ░░░░    ...
Wed     ░░░░    ░░░░    ░░░░    ▓▓▓▓    ...
...

Legend: ░ = 0-10 certs  ▓ = 11-50 certs  █ = 51+ certs
```

**Panel 2: Certificate Distribution**
```
Pie Chart: Certificates by Template
- WebServer: 45%
- ClientAuth: 25%
- CodeSigning: 15%
- Email: 10%
- Other: 5%

Bar Chart: Top 10 Certificate Owners
```

**Panel 3: Risk Indicators**
```
Table: High-Risk Certificates

| Certificate | Risk | Days to Expiry | Action Required |
|------------|------|----------------|-----------------|
| prod-api.contoso.com | ⚠️ HIGH | 3 | RENEW NOW |
| www.contoso.com | ⚠️ HIGH | 5 | Renew soon |
| mail.contoso.com | 🟡 MEDIUM | 12 | Schedule renewal |
```

---

### 4.4 Security Dashboard

**URL**: `https://grafana.contoso.com/d/keyfactor-security`  
**Audience**: Security team, CISO, auditors  
**Update Frequency**: Real-time  
**Data Retention**: 7 years (compliance)

**Key Panels**:

**Panel 1: Security Events (24h)**
```
Timeline of Security-Relevant Events

23:45  ❌ Failed login attempt: user@contoso.com (IP: 203.0.113.45)
22:30  ✅ Certificate revoked: webapp05.contoso.com (Reason: Key Compromise)
21:15  ⚠️  3+ failed login attempts from IP: 198.51.100.23
20:00  ℹ️  HSM backup completed successfully
```

**Panel 2: Compliance Status**
```
Compliance Checks

SOC 2 Requirements:        [████████████████████] 100% ✅
PCI-DSS Requirements:      [████████████████████] 100% ✅
ISO 27001 Controls:        [████████████████████] 100% ✅
Internal Policy:           [█████████████████░░░]  95% ⚠️

5 items require attention - [View Details]
```

**Panel 3: Certificate Weaknesses**
```
Security Issues

Weak Key Algorithms (RSA < 2048):    0 ✅
Expiring Wildcard Certificates:      3 ⚠️
Certificates Without Owner:          12 ⚠️
Long Validity Period (> 398 days):   0 ✅
Self-Signed Certificates in Prod:    0 ✅
```

---

## 5. Alerting Configuration

### 5.1 Critical Alerts (PagerDuty)

**Delivery**: Phone call + SMS + Push notification  
**Escalation**: After 5 minutes if not acknowledged  
**Acknowledgement Required**: Yes

| Alert Name | Condition | Threshold | Actions |
|-----------|-----------|-----------|---------|
| **CA Offline** | CA not responding | Any CA down > 5 min | Page on-call, escalate to PKI lead |
| **HSM Unavailable** | HSM connection failed | Both HSMs down | Page on-call + CISO, emergency procedure |
| **Certificate Expired (Prod)** | Production cert expired | Any | Page on-call, auto-issue emergency cert |
| **Database Offline** | Cannot connect to DB | Connection failed | Page on-call + DBA team |
| **Platform Down** | Keyfactor unreachable | > 5 min | Page on-call, initiate failover |
| **Mass Revocation** | Multiple revocations | > 10 certs in 1 hour | Page security team, investigate |

**Alert Configuration** (Prometheus):
```yaml
groups:
- name: keyfactor_critical
  interval: 30s
  rules:
  - alert: CAOffline
    expr: keyfactor_ca_up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Certificate Authority {{ $labels.ca_name }} is offline"
      description: "CA has been unreachable for 5 minutes"
      runbook_url: "https://wiki.contoso.com/pki/runbooks/ca-offline"
  
  - alert: ProductionCertificateExpired
    expr: |
      keyfactor_certificate_expired{environment="production"} > 0
    labels:
      severity: critical
    annotations:
      summary: "Production certificate expired"
      description: "{{ $value }} production certificates have expired"
      runbook_url: "https://wiki.contoso.com/pki/runbooks/cert-expired"
```

---

### 5.2 Warning Alerts (Slack)

**Delivery**: Slack channel `#pki-ops`  
**Escalation**: None (monitoring only)  
**Acknowledgement Required**: No

| Alert Name | Condition | Threshold | Actions |
|-----------|-----------|-----------|---------|
| **High Expiry Count** | Many certs expiring soon | > 100 in 7 days | Review renewal queue |
| **Low Renewal Rate** | Auto-renewal failing | < 90% success | Investigate failures |
| **Orchestrator Disconnected** | Orchestrator offline | 1-4 orchestrators, > 15 min | Check network, restart if needed |
| **High API Latency** | Slow API responses | P95 > 2s for 10 min | Review performance, scale if needed |
| **Approval Queue Backup** | Too many pending | > 100 pending | Notify approvers |
| **Failed Deployments** | Deployment failures | > 20/day | Review orchestrator logs |

---

### 5.3 Info Alerts (Email Digest)

**Delivery**: Daily email digest at 8:00 AM  
**Audience**: Operations team, management  
**Format**: HTML summary

**Content**:
```
Daily PKI Platform Summary - [Date]

✅ System Health: All systems operational

📊 Yesterday's Activity:
- Certificates Issued: 234
- Certificates Renewed: 89
- Certificates Revoked: 3
- Average Issue Time: 12 minutes

⚠️  Items Requiring Attention:
- 45 certificates expiring within 7 days
- 3 orchestrators pending software update
- 12 pending approval requests (> 48 hours old)

📈 Trends (vs. 7-day average):
- Issuance Volume: +5% ↑
- Renewal Success Rate: 98% (▬)
- API Response Time: -10% ↓ (improved)

🔗 Quick Links:
- Operations Dashboard: https://grafana.contoso.com/d/keyfactor-operations
- View Pending Approvals: https://keyfactor.contoso.com/approvals
- On-Call Schedule: https://pagerduty.com/schedules/pki
```

---

## 6. Reporting Requirements

### 6.1 Daily Operations Report

**Schedule**: Every business day at 9:00 AM  
**Distribution**: Operations team  
**Format**: Email + Dashboard

**Sections**:
1. **24-Hour Summary**
   - Total certificates issued/renewed/revoked
   - Success rates
   - Any incidents or alerts

2. **Current State**
   - Total active certificates
   - Certificates expiring within 7/30/90 days
   - Pending approvals

3. **System Health**
   - Platform availability (last 24h)
   - Orchestrator status
   - CA performance

4. **Action Items**
   - Items requiring immediate attention
   - Upcoming maintenance
   - Recommendations

---

### 6.2 Weekly Management Report

**Schedule**: Every Monday at 10:00 AM  
**Distribution**: PKI lead, IT management  
**Format**: PowerPoint presentation + PDF

**Sections**:
1. **Executive Summary**
   - Key metrics vs. targets
   - Notable events
   - Action items from previous week

2. **Operational Metrics**
   - Certificate lifecycle statistics
   - Performance trends
   - System health

3. **Risk and Compliance**
   - Expiring certificates (next 30 days)
   - Policy violations
   - Security incidents

4. **Upcoming Activities**
   - Scheduled maintenance
   - Projects and initiatives
   - Resource requirements

---

### 6.3 Monthly Business Report

**Schedule**: First Monday of each month  
**Distribution**: Executive leadership, finance  
**Format**: Executive briefing document

**Sections**:
1. **Strategic KPIs**
   - All 7 strategic KPIs with trends
   - Comparison to targets
   - Year-over-year comparison

2. **Business Value**
   - Time saved (hours)
   - Cost savings realized
   - Incident reduction
   - Productivity improvements

3. **Compliance Status**
   - Audit readiness score
   - Control effectiveness
   - Outstanding items

4. **Capacity Planning**
   - Current capacity utilization
   - Growth projections
   - Resource recommendations

5. **Initiatives and Roadmap**
   - Completed projects
   - In-progress work
   - Planned improvements

---

### 6.4 Quarterly Board Report

**Schedule**: Quarterly board meetings  
**Distribution**: Board of directors, C-suite  
**Format**: Executive presentation (10 slides)

**Content**:
1. **Platform Overview** (1 slide)
   - Role in business operations
   - Current scale

2. **Performance Summary** (2 slides)
   - All strategic KPIs
   - Trends and insights

3. **Security Posture** (2 slides)
   - Incidents and response
   - Compliance status
   - Risk management

4. **Business Value** (2 slides)
   - ROI metrics
   - Cost optimization
   - Productivity gains

5. **Strategic Initiatives** (2 slides)
   - Completed projects
   - Ongoing work
   - Future roadmap

6. **Recommendations** (1 slide)
   - Investment needs
   - Resource requirements
   - Strategic decisions needed

---

## 7. Compliance Metrics

### 7.1 SOC 2 Control Metrics

| Control | Metric | Target | Collection Method |
|---------|--------|--------|------------------|
| **CC6.1** - Logical Access | Failed login attempts | < 1% | Auth logs |
| **CC6.6** - Encryption | Certificates with weak crypto | 0 | Certificate scan |
| **CC7.2** - Monitoring | Alert response time | < 15 min | PagerDuty metrics |
| **CC7.3** - Incident Response | Mean time to resolve | < 4 hours | Incident tickets |
| **CC8.1** - Change Management | Changes without approval | 0 | Change logs |
| **CC9.2** - Vendor Management | Vendor SLA compliance | 100% | Vendor reports |

**Monthly Compliance Report**:
```sql
-- SOC 2 Control Effectiveness Query
SELECT 
    'CC6.1 - Logical Access' AS Control,
    CAST(SUM(CASE WHEN AuthResult = 'Failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS FailureRate,
    CASE WHEN CAST(SUM(CASE WHEN AuthResult = 'Failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) < 1.0 
        THEN 'PASS' ELSE 'FAIL' END AS Status
FROM AuthenticationLogs
WHERE LogDate >= DATEADD(MONTH, -1, GETDATE())

UNION ALL

SELECT 
    'CC6.6 - Encryption',
    COUNT(*) AS WeakCertificates,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM Certificates
WHERE KeySize < 2048 AND Status = 'Active';
```

---

### 7.2 PCI-DSS Metrics

| Requirement | Metric | Target | Evidence |
|------------|--------|--------|----------|
| **3.4** - Encryption in Transit | TLS 1.2+ usage | 100% | Protocol logs |
| **6.2** - Patch Management | Systems with current patches | 100% | Patch status |
| **8.2** - Authentication | MFA enabled accounts | 100% | User audit |
| **10.2** - Audit Logging | Logs with timestamps | 100% | Log review |
| **10.6** - Log Review | Daily log reviews completed | 100% | Review records |

---

### 7.3 ISO 27001 Metrics

| Control | Metric | Target | Measurement |
|---------|--------|--------|-------------|
| **A.9.2.3** - Access Review | Quarterly access reviews | 100% | Review logs |
| **A.10.1.1** - Crypto Policy | Compliant certificates | 100% | Crypto scan |
| **A.12.4.1** - Event Logging | Events captured | 100% | Log coverage |
| **A.16.1.2** - Incident Reporting | Incidents reported within 24h | 100% | Incident timestamps |
| **A.18.1.5** - Compliance Review | Controls tested | 100% | Test results |

---

## 8. Performance Baselines

### 8.1 System Performance Baselines

Established during performance testing (Q3 2025)

| Component | Metric | Baseline | Acceptable Range | Alert Threshold |
|-----------|--------|----------|------------------|----------------|
| **Keyfactor App** | CPU Utilization | 35% | 20-50% | > 70% |
| **Keyfactor App** | Memory Usage | 8 GB | 6-12 GB | > 14 GB |
| **Database** | CPU Utilization | 25% | 15-40% | > 60% |
| **Database** | Memory Usage | 16 GB | 12-20 GB | > 22 GB |
| **Database** | Query Time (avg) | 45ms | 30-100ms | > 200ms |
| **Database** | Connections | 35 | 20-60 | > 80 |
| **API** | Response Time (P50) | 120ms | 80-200ms | > 500ms |
| **API** | Response Time (P95) | 350ms | 200-800ms | > 2000ms |
| **API** | Requests/sec | 15 | 5-40 | > 80 |

---

### 8.2 Business Process Baselines

| Process | Metric | Baseline | Target | Current |
|---------|--------|----------|--------|---------|
| Certificate Issuance | Avg time | 8 minutes | < 15 min | 12 min ✅ |
| Certificate Renewal | Avg time | 15 minutes | < 30 min | 18 min ✅ |
| Approval Workflow | Avg time | 4 hours | < 8 hours | 3.5 hours ✅ |
| Orchestrator Discovery | Avg time | 10 minutes | < 20 min | 12 min ✅ |
| Emergency Issuance | Avg time | 25 minutes | < 1 hour | 30 min ✅ |

---

### 8.3 Capacity Baselines

**Established**: October 2025  
**Review Frequency**: Quarterly

| Resource | Current Capacity | Current Usage | Utilization | Projected Growth | Next Review |
|----------|-----------------|---------------|-------------|------------------|-------------|
| **Database Storage** | 100 GB | 45 GB | 45% | 15% per quarter | Jan 2026 |
| **Application Servers** | 4 servers | 3 active | 75% | 10% per quarter | Jan 2026 |
| **Orchestrators** | 50 licenses | 45 deployed | 90% | 20% per quarter | Dec 2025 ⚠️ |
| **API Rate Limit** | 100 req/s | 15 req/s | 15% | 25% per quarter | Jan 2026 |
| **CA Capacity** | 1000 certs/day | 250/day | 25% | 15% per quarter | Jan 2026 |

**Capacity Actions**:
- ⚠️ **Orchestrator licenses**: Procure 10 additional licenses by December 2025
- Monitor API usage monthly; may need rate limit increase by Q2 2026

---

## Appendix A: Metric Definitions

### A.1 Calculated Metrics

**Automation Rate**:
```
(Certificates Issued via Automation / Total Certificates Issued) × 100

Where "Automation" includes:
- ACME protocol
- EST protocol
- GPO auto-enrollment
- Kubernetes cert-manager
- API with automation flag
```

**Cost Per Certificate**:
```
(Total PKI Platform Costs / Active Certificate Count)

Costs include:
- Keyfactor licensing
- CA infrastructure (hardware, software)
- HSM costs (amortized)
- Staff time (FTEs allocated to PKI)
- Infrastructure (compute, storage, network)
```

**Mean Time to Issue** (MTTI):
```
Average time from certificate request submission to issuance

Calculation:
SUM(Issuance Time for all certificates in period) / COUNT(certificates)

Excludes:
- Requests pending approval
- Requests with errors requiring intervention
```

---

## Appendix B: Data Collection Scripts

### B.1 Prometheus Exporter Example

```python
#!/usr/bin/env python3
"""
Keyfactor Prometheus Exporter
Collects metrics from Keyfactor API and exposes in Prometheus format
"""

from prometheus_client import start_http_server, Gauge, Counter, Histogram
import requests
import time
import os

# Configuration
KEYFACTOR_HOST = os.environ['KEYFACTOR_HOST']
KEYFACTOR_USERNAME = os.environ['KEYFACTOR_USERNAME']
KEYFACTOR_PASSWORD = os.environ['KEYFACTOR_PASSWORD']
EXPORT_PORT = int(os.environ.get('EXPORT_PORT', 9100))

# Metrics
cert_total = Gauge('keyfactor_certificates_total', 'Total certificates')
cert_active = Gauge('keyfactor_certificates_active', 'Active certificates')
cert_expiring = Gauge('keyfactor_certificates_expiring', 'Expiring certificates', ['days'])
cert_issued = Counter('keyfactor_certificates_issued_total', 'Certificates issued')
api_duration = Histogram('keyfactor_api_duration_seconds', 'API call duration')
orchestrator_connected = Gauge('keyfactor_orchestrators_connected', 'Connected orchestrators')

class KeyfactorCollector:
    def __init__(self, host, username, password):
        self.base_url = f"{host}/KeyfactorAPI"
        self.auth = (username, password)
    
    def collect_metrics(self):
        try:
            # Collect certificate metrics
            with api_duration.time():
                response = requests.get(
                    f"{self.base_url}/Certificates/Summary",
                    auth=self.auth,
                    timeout=30
                )
            
            data = response.json()
            cert_total.set(data['total'])
            cert_active.set(data['active'])
            cert_expiring.labels(days='7').set(data['expiring_7d'])
            cert_expiring.labels(days='30').set(data['expiring_30d'])
            cert_expiring.labels(days='90').set(data['expiring_90d'])
            
            # Collect orchestrator metrics
            response = requests.get(
                f"{self.base_url}/Orchestrators",
                auth=self.auth,
                timeout=30
            )
            orchestrators = response.json()
            connected_count = sum(1 for o in orchestrators if o['status'] == 'Connected')
            orchestrator_connected.set(connected_count)
            
        except Exception as e:
            print(f"Error collecting metrics: {e}")

def main():
    collector = KeyfactorCollector(KEYFACTOR_HOST, KEYFACTOR_USERNAME, KEYFACTOR_PASSWORD)
    
    # Start HTTP server for Prometheus
    start_http_server(EXPORT_PORT)
    print(f"Keyfactor exporter started on port {EXPORT_PORT}")
    
    # Collect metrics every 60 seconds
    while True:
        collector.collect_metrics()
        time.sleep(60)

if __name__ == '__main__':
    main()
```

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

**End of Monitoring & KPIs Document**

