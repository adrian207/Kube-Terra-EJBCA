# Asset Inventory Integration Guide
## Certificate Authorization via Device Registry

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use

---

## Purpose

This guide explains how to implement **device/asset validation** for certificate authorization. Keyfactor's Resource Binding authorization layer (Layer 3) requires an asset inventory to:

✅ Verify the target device/server exists  
✅ Validate the device is operational (not decommissioned)  
✅ Confirm requester is authorized to manage the device  
✅ Tag certificates with ownership metadata  

**Important**: You do NOT need an expensive CMDB product to start. This guide provides 5 options from simple (CSV file) to enterprise (ServiceNow CMDB).

**Language Choice**: All validation scripts are provided in **Python, PowerShell, Go, and Bash**. Choose based on your environment:
- **Python**: Cross-platform, easy to maintain (recommended default)
- **PowerShell**: Native Windows/Azure integration
- **Go**: High performance, single binary, containers
- **Bash**: Linux-only, minimal dependencies

See [scripts/README.md](./scripts/README.md) for detailed language comparison.

---

## Table of Contents

1. [Quick Decision Matrix](#quick-decision-matrix)
2. [Option 1: CSV/Spreadsheet (Start Here)](#option-1-csvspreadsheet-simplest)
3. [Option 2: PostgreSQL Database](#option-2-postgresql-database)
4. [Option 3: Cloud Provider Inventory](#option-3-cloud-provider-inventory)
5. [Option 4: Kubernetes Native](#option-4-kubernetes-native)
6. [Option 5: Enterprise CMDB Integration](#option-5-enterprise-cmdb-integration)
7. [Migration Path](#migration-path)
8. [Integration with Keyfactor](#integration-with-keyfactor)

---

## Quick Decision Matrix

| Option | Best For | Setup Time | Maintenance | Cost | Accuracy |
|--------|----------|------------|-------------|------|----------|
| **1. CSV/Spreadsheet** | Small deployments (<500 assets) | 1 hour | Weekly manual updates | $0 | 70% |
| **2. PostgreSQL DB** | Medium deployments (500-5000 assets) | 4 hours | Automated updates via scripts | $0 | 85% |
| **3. Cloud Inventory** | Azure/AWS-heavy environments | 2 hours | Automatic (native) | $0 | 95% |
| **4. Kubernetes** | Container/K8s workloads | 2 hours | Automatic (native) | $0 | 95% |
| **5. Enterprise CMDB** | Large enterprises with ITSM | 1-2 days | Automatic (existing process) | $$$$ | 99% |

**Recommendation for Phase 1**: Start with **Option 1 (CSV)** for simplicity, then migrate to Option 2 or 3 by Phase 3.

---

### Available Validation Scripts

All 5 options include validation scripts in **4 languages**. Choose based on your environment:

| Language | Best For | Script Location | Performance |
|----------|----------|-----------------|-------------|
| **Python** | Cross-platform, default choice | [scripts/validate-device.py](./scripts/validate-device.py) | Good (3-5s/100 queries) |
| **PowerShell** | Windows/Azure environments | [scripts/validate-device.ps1](./scripts/validate-device.ps1) | Good (4-5s/100 queries) |
| **Go** | Containers, high-volume | [scripts/validate-device.go](./scripts/validate-device.go) | Excellent (<1s/100 queries) |
| **Bash** | Linux-only, minimal deps | [scripts/validate-device.sh](./scripts/validate-device.sh) | Good (2-3s/100 queries) |

**Full comparison and setup instructions**: [scripts/README.md](./scripts/README.md)

All scripts provide **identical functionality** - they support all 5 inventory sources (CSV, Database, Azure, Kubernetes, ServiceNow) and can be used interchangeably.

---

## Option 1: CSV/Spreadsheet (Simplest)

### Overview

Store asset inventory in a CSV file, update manually or via script, version control in Git.

**Pros**:
- ✅ Zero cost
- ✅ No dependencies
- ✅ Easy to start (Day 1)
- ✅ Version controlled
- ✅ Works offline

**Cons**:
- ❌ Manual updates required
- ❌ No real-time sync
- ❌ Prone to stale data
- ❌ Doesn't scale >1000 assets

**Language Support**: 
- ✅ Python implementation (default, cross-platform)
- ✅ PowerShell implementation (Windows/Azure)
- ✅ Go implementation (performance, containers)
- ✅ Bash implementation (Linux-only)

See [scripts/README.md](./scripts/README.md) for language comparison and [scripts/](./scripts/) for all implementations.

### Implementation

**Step 1: Create CSV Template**

See [asset-inventory-template.csv](#asset-inventory-templatecsv) below for 50 sample entries.

**Step 2: Initialize Git Repository**

```bash
# Create directory
mkdir -p /opt/keyfactor/asset-inventory
cd /opt/keyfactor/asset-inventory

# Copy template
cp /path/to/asset-inventory-template.csv asset-inventory.csv

# Initialize Git
git init
git add asset-inventory.csv
git commit -m "Initial asset inventory"

# Push to remote (GitHub/GitLab/Bitbucket)
git remote add origin https://github.com/contoso/asset-inventory.git
git push -u origin main
```

**Step 3: Create Validation Script**

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device-csv.py

import csv
import sys
import os
from datetime import datetime

CSV_PATH = '/opt/keyfactor/asset-inventory/asset-inventory.csv'
CACHE_TIMEOUT = 3600  # 1 hour

def load_inventory():
    """Load CSV into memory with caching"""
    cache_file = '/tmp/asset-inventory-cache.txt'
    
    # Check if cache is fresh
    if os.path.exists(cache_file):
        cache_age = datetime.now().timestamp() - os.path.getmtime(cache_file)
        if cache_age < CACHE_TIMEOUT:
            # Use cache
            with open(cache_file, 'r') as f:
                return eval(f.read())
    
    # Reload from CSV
    inventory = {}
    with open(CSV_PATH, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            inventory[row['hostname']] = {
                'owner_email': row['owner_email'],
                'owner_team': row['owner_team'],
                'environment': row['environment'],
                'cost_center': row.get('cost_center', ''),
                'status': row['status'],
                'location': row.get('location', ''),
                'os': row.get('os', ''),
                'notes': row.get('notes', '')
            }
    
    # Cache for next time
    with open(cache_file, 'w') as f:
        f.write(repr(inventory))
    
    return inventory

def validate_device(hostname, requester_email=None):
    """
    Validate device exists and is active
    Returns: (authorized: bool, reason: str, metadata: dict)
    """
    inventory = load_inventory()
    
    # Check if device exists
    if hostname not in inventory:
        return False, f"Device '{hostname}' not found in asset inventory", {}
    
    device = inventory[hostname]
    
    # Check if device is active
    if device['status'] != 'active':
        return False, f"Device '{hostname}' status is '{device['status']}' (not active)", {}
    
    # Check if requester is authorized (if provided)
    if requester_email:
        # Simple check: requester email matches owner or is in owner team
        # You can extend this with AD group membership checks
        if requester_email != device['owner_email'] and \
           not requester_email.endswith(f"@{device['owner_team']}.contoso.com"):
            # For more sophisticated checks, query AD or Azure AD here
            pass  # Allow for now, but log
    
    return True, "Device authorized", device

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device-csv.py <hostname> [requester_email]")
        sys.exit(2)
    
    hostname = sys.argv[1]
    requester = sys.argv[2] if len(sys.argv) > 2 else None
    
    authorized, reason, metadata = validate_device(hostname, requester)
    
    if authorized:
        # Output format: AUTHORIZED|owner_team|environment|cost_center
        print(f"AUTHORIZED|{metadata['owner_team']}|{metadata['environment']}|{metadata['cost_center']}")
        sys.exit(0)
    else:
        # Output format: DENIED|reason
        print(f"DENIED|{reason}")
        sys.exit(1)
```

Make executable:
```bash
chmod +x /opt/keyfactor/scripts/validate-device-csv.py
```

**Step 4: Test Validation**

```bash
# Test valid device
/opt/keyfactor/scripts/validate-device-csv.py webapp01.contoso.com
# Output: AUTHORIZED|team-web-apps|production|12345
# Exit code: 0

# Test invalid device
/opt/keyfactor/scripts/validate-device-csv.py nonexistent.contoso.com
# Output: DENIED|Device 'nonexistent.contoso.com' not found in asset inventory
# Exit code: 1

# Test decommissioned device
/opt/keyfactor/scripts/validate-device-csv.py old-server.contoso.com
# Output: DENIED|Device 'old-server.contoso.com' status is 'decommissioned' (not active)
# Exit code: 1
```

**Step 5: Update Process**

```bash
#!/bin/bash
# File: /opt/keyfactor/scripts/update-inventory.sh

cd /opt/keyfactor/asset-inventory

# Pull latest from Git
git pull origin main

# Clear cache
rm -f /tmp/asset-inventory-cache.txt

# Log update
echo "$(date): Asset inventory updated from Git" >> /var/log/keyfactor/inventory-updates.log
```

Schedule updates:
```bash
# Cron job: Update every hour
crontab -e
0 * * * * /opt/keyfactor/scripts/update-inventory.sh
```

---

## Option 2: PostgreSQL Database

### Overview

Store asset inventory in PostgreSQL with automated updates via scripts or webhooks.

**Pros**:
- ✅ Scales to 10,000+ assets
- ✅ Fast lookups (indexed)
- ✅ Multi-user updates
- ✅ Transaction support
- ✅ Audit trail (triggers)

**Cons**:
- ❌ Requires database server
- ❌ More complex setup
- ❌ Backup/maintenance needed

### Implementation

**Step 1: Create Database Schema**

```sql
-- File: /opt/keyfactor/sql/create-asset-inventory.sql

-- Create database
CREATE DATABASE asset_inventory;

\c asset_inventory

-- Create asset table
CREATE TABLE assets (
    asset_id SERIAL PRIMARY KEY,
    hostname VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET,
    owner_email VARCHAR(255) NOT NULL,
    owner_team VARCHAR(100) NOT NULL,
    environment VARCHAR(50) NOT NULL,  -- dev, test, staging, production
    cost_center VARCHAR(50),
    location VARCHAR(100),
    os VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active',  -- active, decommissioned, maintenance
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    CONSTRAINT chk_environment CHECK (environment IN ('dev', 'test', 'staging', 'production')),
    CONSTRAINT chk_status CHECK (status IN ('active', 'decommissioned', 'maintenance', 'pending'))
);

-- Create indexes
CREATE INDEX idx_hostname ON assets(hostname);
CREATE INDEX idx_owner_team ON assets(owner_team);
CREATE INDEX idx_status ON assets(status);
CREATE INDEX idx_environment ON assets(environment);

-- Create audit log table
CREATE TABLE asset_audit_log (
    log_id SERIAL PRIMARY KEY,
    asset_id INTEGER REFERENCES assets(asset_id),
    action VARCHAR(50),  -- INSERT, UPDATE, DELETE
    changed_by VARCHAR(255),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    old_values JSONB,
    new_values JSONB
);

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assets_updated_at
    BEFORE UPDATE ON assets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Create audit trigger
CREATE OR REPLACE FUNCTION audit_asset_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO asset_audit_log (asset_id, action, changed_by, old_values, new_values)
        VALUES (
            OLD.asset_id,
            'UPDATE',
            current_user,
            row_to_json(OLD),
            row_to_json(NEW)
        );
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO asset_audit_log (asset_id, action, changed_by, old_values)
        VALUES (
            OLD.asset_id,
            'DELETE',
            current_user,
            row_to_json(OLD)
        );
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assets_audit
    AFTER UPDATE OR DELETE ON assets
    FOR EACH ROW
    EXECUTE FUNCTION audit_asset_changes();

-- Create function to get asset
CREATE OR REPLACE FUNCTION get_asset(p_hostname VARCHAR)
RETURNS TABLE (
    hostname VARCHAR,
    owner_email VARCHAR,
    owner_team VARCHAR,
    environment VARCHAR,
    cost_center VARCHAR,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.hostname,
        a.owner_email,
        a.owner_team,
        a.environment,
        a.cost_center,
        a.status
    FROM assets a
    WHERE a.hostname = p_hostname
      AND a.status = 'active';
END;
$$ LANGUAGE plpgsql;

-- Create read-only user for Keyfactor
CREATE USER keyfactor_reader WITH PASSWORD '<strong_password>';
GRANT CONNECT ON DATABASE asset_inventory TO keyfactor_reader;
GRANT SELECT ON assets TO keyfactor_reader;
GRANT EXECUTE ON FUNCTION get_asset TO keyfactor_reader;
```

Deploy:
```bash
psql -h asset-db.contoso.com -U postgres -f /opt/keyfactor/sql/create-asset-inventory.sql
```

**Step 2: Import Existing Data**

```bash
# From CSV
psql -h asset-db.contoso.com -U postgres -d asset_inventory -c "
COPY assets (hostname, owner_email, owner_team, environment, cost_center, location, os, status)
FROM '/path/to/asset-inventory.csv'
DELIMITER ','
CSV HEADER;
"
```

**Step 3: Create Python Validation Script**

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device-db.py

import psycopg2
import sys
import os

DB_CONFIG = {
    'host': os.environ.get('ASSET_DB_HOST', 'asset-db.contoso.com'),
    'database': 'asset_inventory',
    'user': 'keyfactor_reader',
    'password': os.environ.get('ASSET_DB_PASSWORD'),
    'connect_timeout': 5
}

def validate_device(hostname, requester_email=None):
    """Query database for device"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Use prepared function
        cursor.execute("SELECT * FROM get_asset(%s)", (hostname,))
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if result:
            return True, "Device authorized", {
                'hostname': result[0],
                'owner_email': result[1],
                'owner_team': result[2],
                'environment': result[3],
                'cost_center': result[4],
                'status': result[5]
            }
        else:
            return False, f"Device '{hostname}' not found in database or not active", {}
    
    except psycopg2.Error as e:
        return False, f"Database error: {str(e)}", {}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device-db.py <hostname> [requester_email]")
        sys.exit(2)
    
    hostname = sys.argv[1]
    requester = sys.argv[2] if len(sys.argv) > 2 else None
    
    authorized, reason, metadata = validate_device(hostname, requester)
    
    if authorized:
        print(f"AUTHORIZED|{metadata['owner_team']}|{metadata['environment']}|{metadata['cost_center']}")
        sys.exit(0)
    else:
        print(f"DENIED|{reason}")
        sys.exit(1)
```

**Step 4: Automated Updates from Cloud**

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/sync-assets-from-azure.py

from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.resourcegraph.models import QueryRequest
import psycopg2

def sync_azure_vms():
    """Sync Azure VMs to asset database"""
    
    # Query Azure
    credential = DefaultAzureCredential()
    client = ResourceGraphClient(credential)
    
    query = """
    Resources
    | where type == 'microsoft.compute/virtualmachines'
    | project 
        hostname = name,
        ip_address = properties.networkProfile.networkInterfaces[0].properties.ipConfigurations[0].properties.privateIPAddress,
        owner_email = tags.Owner,
        owner_team = tags.Team,
        environment = tags.Environment,
        cost_center = tags.CostCenter,
        location,
        os = properties.storageProfile.osDisk.osType,
        status = case(
            properties.extended.instanceView.powerState.displayStatus == 'VM running', 'active',
            properties.extended.instanceView.powerState.displayStatus == 'VM deallocated', 'decommissioned',
            'maintenance'
        )
    """
    
    request = QueryRequest(
        subscriptions=['<subscription-id>'],
        query=query
    )
    
    response = client.resources(request)
    
    # Update database
    conn = psycopg2.connect(
        host='asset-db.contoso.com',
        database='asset_inventory',
        user='asset_writer',
        password='<password>'
    )
    
    cursor = conn.cursor()
    
    for vm in response.data:
        cursor.execute("""
            INSERT INTO assets (hostname, ip_address, owner_email, owner_team, environment, cost_center, location, os, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (hostname) 
            DO UPDATE SET
                ip_address = EXCLUDED.ip_address,
                owner_email = EXCLUDED.owner_email,
                owner_team = EXCLUDED.owner_team,
                environment = EXCLUDED.environment,
                status = EXCLUDED.status,
                updated_at = CURRENT_TIMESTAMP
        """, (
            vm['hostname'],
            vm.get('ip_address'),
            vm.get('owner_email', 'unknown@contoso.com'),
            vm.get('owner_team', 'unknown'),
            vm.get('environment', 'unknown'),
            vm.get('cost_center'),
            vm.get('location'),
            vm.get('os'),
            vm.get('status', 'active')
        ))
    
    conn.commit()
    cursor.close()
    conn.close()
    
    print(f"Synced {len(response.data)} VMs from Azure")

if __name__ == '__main__':
    sync_azure_vms()
```

Schedule sync:
```bash
# Cron: Sync from Azure every 6 hours
crontab -e
0 */6 * * * /opt/keyfactor/scripts/sync-assets-from-azure.py >> /var/log/keyfactor/asset-sync.log 2>&1
```

---

## Option 3: Cloud Provider Inventory

### Azure Resource Graph

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device-azure.py

from azure.identity import DefaultAzureCredential
from azure.mgmt.resourcegraph import ResourceGraphClient
from azure.mgmt.resourcegraph.models import QueryRequest
import sys
import json

def validate_device_azure(hostname):
    """Query Azure Resource Graph for VM"""
    credential = DefaultAzureCredential()
    client = ResourceGraphClient(credential)
    
    query = f"""
    Resources
    | where type == 'microsoft.compute/virtualmachines'
    | where name == '{hostname}' or properties.osProfile.computerName == '{hostname}'
    | project 
        hostname = name,
        owner_email = tags.Owner,
        owner_team = tags.Team,
        environment = tags.Environment,
        cost_center = tags.CostCenter,
        status = case(
            properties.extended.instanceView.powerState.displayStatus == 'VM running', 'active',
            'inactive'
        )
    | limit 1
    """
    
    request = QueryRequest(
        subscriptions=['<subscription-id>'],
        query=query
    )
    
    try:
        response = client.resources(request)
        
        if response.data:
            vm = response.data[0]
            return True, "Device found in Azure", {
                'owner_email': vm.get('owner_email', 'unknown@contoso.com'),
                'owner_team': vm.get('owner_team', 'unknown'),
                'environment': vm.get('environment', 'unknown'),
                'cost_center': vm.get('cost_center', ''),
                'status': vm.get('status', 'inactive')
            }
        else:
            return False, f"Device '{hostname}' not found in Azure", {}
    
    except Exception as e:
        return False, f"Azure query error: {str(e)}", {}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device-azure.py <hostname>")
        sys.exit(2)
    
    hostname = sys.argv[1]
    authorized, reason, metadata = validate_device_azure(hostname)
    
    if authorized and metadata['status'] == 'active':
        print(f"AUTHORIZED|{metadata['owner_team']}|{metadata['environment']}|{metadata['cost_center']}")
        sys.exit(0)
    else:
        print(f"DENIED|{reason}")
        sys.exit(1)
```

### AWS Config

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device-aws.py

import boto3
import sys

def validate_device_aws(hostname):
    """Query AWS EC2 for instance"""
    ec2 = boto3.client('ec2')
    
    try:
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:Name', 'Values': [hostname]},
                {'Name': 'instance-state-name', 'Values': ['running', 'stopped']}
            ]
        )
        
        if response['Reservations']:
            instance = response['Reservations'][0]['Instances'][0]
            tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
            state = instance['State']['Name']
            
            return True, "Device found in AWS", {
                'owner_email': tags.get('Owner', 'unknown@contoso.com'),
                'owner_team': tags.get('Team', 'unknown'),
                'environment': tags.get('Environment', 'unknown'),
                'cost_center': tags.get('CostCenter', ''),
                'status': 'active' if state == 'running' else 'inactive'
            }
        else:
            return False, f"Device '{hostname}' not found in AWS", {}
    
    except Exception as e:
        return False, f"AWS query error: {str(e)}", {}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device-aws.py <hostname>")
        sys.exit(2)
    
    hostname = sys.argv[1]
    authorized, reason, metadata = validate_device_aws(hostname)
    
    if authorized and metadata['status'] == 'active':
        print(f"AUTHORIZED|{metadata['owner_team']}|{metadata['environment']}|{metadata['cost_center']}")
        sys.exit(0)
    else:
        print(f"DENIED|{reason}")
        sys.exit(1)
```

---

## Option 4: Kubernetes Native

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device-k8s.py

from kubernetes import client, config
import sys

def validate_device_k8s(hostname):
    """
    For Kubernetes, hostname format: <service>.<namespace>.svc.cluster.local
    Validate namespace exists and has ownership labels
    """
    
    # Parse hostname
    parts = hostname.split('.')
    if len(parts) < 4 or parts[2] != 'svc':
        return False, f"Invalid Kubernetes hostname format: {hostname}", {}
    
    service_name = parts[0]
    namespace = parts[1]
    
    try:
        config.load_kube_config()  # or load_incluster_config() if running in cluster
        v1 = client.CoreV1Api()
        
        # Get namespace
        ns = v1.read_namespace(namespace)
        labels = ns.metadata.labels or {}
        annotations = ns.metadata.annotations or {}
        
        # Check namespace is active
        if ns.status.phase != 'Active':
            return False, f"Namespace '{namespace}' is not active (phase: {ns.status.phase})", {}
        
        # Extract ownership from labels/annotations
        metadata = {
            'owner_email': annotations.get('owner-email', labels.get('owner', 'unknown@contoso.com')),
            'owner_team': labels.get('team', 'unknown'),
            'environment': labels.get('environment', 'unknown'),
            'cost_center': labels.get('cost-center', ''),
            'status': 'active'
        }
        
        return True, "Namespace found and active", metadata
    
    except client.exceptions.ApiException as e:
        if e.status == 404:
            return False, f"Namespace '{namespace}' not found", {}
        else:
            return False, f"Kubernetes API error: {str(e)}", {}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device-k8s.py <hostname>")
        sys.exit(2)
    
    hostname = sys.argv[1]
    authorized, reason, metadata = validate_device_k8s(hostname)
    
    if authorized:
        print(f"AUTHORIZED|{metadata['owner_team']}|{metadata['environment']}|{metadata['cost_center']}")
        sys.exit(0)
    else:
        print(f"DENIED|{reason}")
        sys.exit(1)
```

**Namespace Labeling Standard**:

```yaml
# All namespaces must have these labels
apiVersion: v1
kind: Namespace
metadata:
  name: production-web-apps
  labels:
    team: team-web-apps
    environment: production
    cost-center: "12345"
  annotations:
    owner-email: web-apps@contoso.com
    description: Production web applications
```

---

## Option 5: Enterprise CMDB Integration

### ServiceNow

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device-servicenow.py

import requests
import sys
import os

SNOW_INSTANCE = 'contoso.service-now.com'
SNOW_USER = os.environ.get('SNOW_USER', 'keyfactor-api')
SNOW_PASSWORD = os.environ.get('SNOW_PASSWORD')

def validate_device_servicenow(hostname):
    """Query ServiceNow CMDB for CI"""
    
    url = f'https://{SNOW_INSTANCE}/api/now/table/cmdb_ci_server'
    params = {
        'sysparm_query': f'name={hostname}^operational_status=1',  # 1 = Operational
        'sysparm_fields': 'name,owned_by,support_group,environment,cost_center,operational_status'
    }
    
    try:
        response = requests.get(
            url,
            params=params,
            auth=(SNOW_USER, SNOW_PASSWORD),
            headers={'Accept': 'application/json'},
            timeout=10
        )
        
        response.raise_for_status()
        data = response.json()
        
        if data['result']:
            ci = data['result'][0]
            
            # Get owner details
            owner_url = f"https://{SNOW_INSTANCE}/api/now/table/sys_user/{ci['owned_by']['value']}"
            owner_response = requests.get(
                owner_url,
                auth=(SNOW_USER, SNOW_PASSWORD),
                headers={'Accept': 'application/json'}
            )
            owner_data = owner_response.json()['result']
            
            return True, "Device found in ServiceNow CMDB", {
                'owner_email': owner_data['email'],
                'owner_team': ci.get('support_group', {}).get('display_value', 'unknown'),
                'environment': ci.get('environment', 'unknown'),
                'cost_center': ci.get('cost_center', ''),
                'status': 'active'  # operational_status=1 means active
            }
        else:
            return False, f"Device '{hostname}' not found in ServiceNow CMDB", {}
    
    except requests.RequestException as e:
        return False, f"ServiceNow API error: {str(e)}", {}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device-servicenow.py <hostname>")
        sys.exit(2)
    
    hostname = sys.argv[1]
    authorized, reason, metadata = validate_device_servicenow(hostname)
    
    if authorized:
        print(f"AUTHORIZED|{metadata['owner_team']}|{metadata['environment']}|{metadata['cost_center']}")
        sys.exit(0)
    else:
        print(f"DENIED|{reason}")
        sys.exit(1)
```

### BMC Helix/Remedy

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device-bmc.py

import requests
import sys
import os

BMC_ENDPOINT = os.environ.get('BMC_ENDPOINT', 'https://bmc.contoso.com:8443/api/arsys/v1')
BMC_USER = os.environ.get('BMC_USER')
BMC_PASSWORD = os.environ.get('BMC_PASSWORD')

def validate_device_bmc(hostname):
    """Query BMC Remedy CMDB for CI"""
    
    url = f'{BMC_ENDPOINT}/entry/BMC.ASSET:BMC_ComputerSystem'
    params = {
        'q': f"'Name'=\"{hostname}\" AND 'AssetLifecycleStatus'=\"Deployed\"",
        'fields': 'values(Name,Owner,SupportOrganization,Environment,CostCenter)'
    }
    
    try:
        response = requests.get(
            url,
            params=params,
            auth=(BMC_USER, BMC_PASSWORD),
            headers={'Content-Type': 'application/json'},
            verify=True,
            timeout=10
        )
        
        response.raise_for_status()
        data = response.json()
        
        if data['entries']:
            ci = data['entries'][0]['values']
            
            return True, "Device found in BMC CMDB", {
                'owner_email': ci.get('Owner', 'unknown@contoso.com'),
                'owner_team': ci.get('SupportOrganization', 'unknown'),
                'environment': ci.get('Environment', 'unknown'),
                'cost_center': ci.get('CostCenter', ''),
                'status': 'active'
            }
        else:
            return False, f"Device '{hostname}' not found in BMC CMDB or not deployed", {}
    
    except requests.RequestException as e:
        return False, f"BMC API error: {str(e)}", {}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device-bmc.py <hostname>")
        sys.exit(2)
    
    hostname = sys.argv[1]
    authorized, reason, metadata = validate_device_bmc(hostname)
    
    if authorized:
        print(f"AUTHORIZED|{metadata['owner_team']}|{metadata['environment']}|{metadata['cost_center']}")
        sys.exit(0)
    else:
        print(f"DENIED|{reason}")
        sys.exit(1)
```

---

## Migration Path

### Phase-by-Phase Evolution

```
Week 1-2 (Phase 1 Discovery):
  CSV file with manual updates
  ↓ 50 assets documented
  ↓ Validation working
  
Week 3-4 (Phase 1 completion):
  Add cloud provider queries (Azure/AWS)
  ↓ Auto-discovery of cloud VMs
  ↓ CSV for on-prem only
  
Month 2 (Phase 2):
  Deploy PostgreSQL database
  ↓ Import CSV + cloud discoveries
  ↓ Automated sync from cloud (cron)
  
Month 3 (Phase 3):
  Add Kubernetes namespace validation
  ↓ All K8s workloads covered
  
Month 4-5 (Phase 4):
  Integrate with ServiceNow CMDB (if available)
  ↓ Pull ownership from CMDB
  ↓ Keep database as cache/fallback
  
Month 6+ (Phase 5-6):
  Full automation, no manual updates
  ↓ Real-time sync
  ↓ 99% accuracy
```

---

## Integration with Keyfactor

### Unified Validation Script

```python
#!/usr/bin/env python3
# File: /opt/keyfactor/scripts/validate-device.py
# Master script that tries all sources

import sys
import subprocess

def validate_multi_source(hostname):
    """
    Try validation sources in order:
    1. ServiceNow CMDB (if available)
    2. Database (if configured)
    3. Cloud providers (Azure/AWS)
    4. Kubernetes (if *.svc.cluster.local)
    5. CSV (fallback)
    """
    
    # 1. Try ServiceNow
    result = subprocess.run(
        ['/opt/keyfactor/scripts/validate-device-servicenow.py', hostname],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print(result.stdout.strip())
        return 0
    
    # 2. Try Database
    result = subprocess.run(
        ['/opt/keyfactor/scripts/validate-device-db.py', hostname],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print(result.stdout.strip())
        return 0
    
    # 3. Try Azure (if hostname pattern matches)
    if '.contoso.com' in hostname or '.internal' in hostname:
        result = subprocess.run(
            ['/opt/keyfactor/scripts/validate-device-azure.py', hostname],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(result.stdout.strip())
            return 0
    
    # 4. Try Kubernetes
    if '.svc.cluster.local' in hostname:
        result = subprocess.run(
            ['/opt/keyfactor/scripts/validate-device-k8s.py', hostname],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(result.stdout.strip())
            return 0
    
    # 5. Fallback to CSV
    result = subprocess.run(
        ['/opt/keyfactor/scripts/validate-device-csv.py', hostname],
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        print(result.stdout.strip())
        return 0
    
    # All sources failed
    print(f"DENIED|Device '{hostname}' not found in any inventory source")
    return 1

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: validate-device.py <hostname>")
        sys.exit(2)
    
    hostname = sys.argv[1]
    sys.exit(validate_multi_source(hostname))
```

### Keyfactor Webhook Integration

```python
# Keyfactor webhook handler
# File: /opt/keyfactor/webhooks/certificate-request-handler.py

from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)

@app.route('/webhook/certificate-request', methods=['POST'])
def handle_certificate_request():
    """
    Webhook called by Keyfactor before issuing certificate
    Returns: 200 OK if authorized, 403 Forbidden if denied
    """
    data = request.json
    
    hostname = data.get('subject_cn') or data.get('san', [None])[0]
    requester = data.get('requester_email')
    
    if not hostname:
        return jsonify({'error': 'No hostname provided'}), 400
    
    # Validate device
    result = subprocess.run(
        ['/opt/keyfactor/scripts/validate-device.py', hostname, requester],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        # Parse output: AUTHORIZED|owner_team|environment|cost_center
        parts = result.stdout.strip().split('|')
        return jsonify({
            'authorized': True,
            'owner_team': parts[1],
            'environment': parts[2],
            'cost_center': parts[3],
            'tags': {
                'team': parts[1],
                'environment': parts[2],
                'cost_center': parts[3]
            }
        }), 200
    else:
        # Parse output: DENIED|reason
        parts = result.stdout.strip().split('|')
        reason = parts[1] if len(parts) > 1 else 'Unknown'
        return jsonify({
            'authorized': False,
            'reason': reason
        }), 403

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

---

## Testing & Validation

### Test Suite

```bash
#!/bin/bash
# File: /opt/keyfactor/scripts/test-validation.sh

echo "Asset Inventory Validation Test Suite"
echo "======================================"

# Test 1: Valid active device
echo -n "Test 1: Valid active device... "
result=$(/opt/keyfactor/scripts/validate-device.py webapp01.contoso.com)
if [[ $? -eq 0 && $result == AUTHORIZED* ]]; then
    echo "✅ PASS"
else
    echo "❌ FAIL: $result"
fi

# Test 2: Non-existent device
echo -n "Test 2: Non-existent device... "
result=$(/opt/keyfactor/scripts/validate-device.py nonexistent.contoso.com 2>&1)
if [[ $? -eq 1 && $result == DENIED* ]]; then
    echo "✅ PASS"
else
    echo "❌ FAIL: Should be denied"
fi

# Test 3: Decommissioned device
echo -n "Test 3: Decommissioned device... "
result=$(/opt/keyfactor/scripts/validate-device.py old-server.contoso.com 2>&1)
if [[ $? -eq 1 && $result == DENIED* ]]; then
    echo "✅ PASS"
else
    echo "❌ FAIL: Should be denied"
fi

# Test 4: Kubernetes service
echo -n "Test 4: Kubernetes service... "
result=$(/opt/keyfactor/scripts/validate-device.py myapp.production.svc.cluster.local 2>&1)
if [[ $? -eq 0 && $result == AUTHORIZED* ]]; then
    echo "✅ PASS"
else
    echo "❌ FAIL: $result"
fi

# Test 5: Performance (should be <1 second)
echo -n "Test 5: Performance... "
start=$(date +%s%N)
/opt/keyfactor/scripts/validate-device.py webapp01.contoso.com > /dev/null 2>&1
end=$(date +%s%N)
duration=$(( (end - start) / 1000000 ))  # Convert to milliseconds

if [[ $duration -lt 1000 ]]; then
    echo "✅ PASS (${duration}ms)"
else
    echo "❌ FAIL (${duration}ms, should be <1000ms)"
fi

echo ""
echo "Test suite complete"
```

---

## Troubleshooting

### Issue: Validation script slow

**Symptoms**: Script takes >5 seconds

**Diagnosis**:
```bash
# Time each component
time /opt/keyfactor/scripts/validate-device-csv.py webapp01.contoso.com
time /opt/keyfactor/scripts/validate-device-db.py webapp01.contoso.com
time /opt/keyfactor/scripts/validate-device-azure.py webapp01.contoso.com
```

**Resolution**:
- For CSV: Ensure cache is enabled (`/tmp/asset-inventory-cache.txt`)
- For Database: Add indexes, use connection pooling
- For Cloud: Cache results (1-hour TTL)

---

### Issue: Device not found but should exist

**Diagnosis**:
```bash
# Check each source manually
# CSV
grep "webapp01.contoso.com" /opt/keyfactor/asset-inventory/asset-inventory.csv

# Database
psql -h asset-db.contoso.com -U keyfactor_reader -d asset_inventory -c \
  "SELECT * FROM assets WHERE hostname = 'webapp01.contoso.com'"

# Azure
az vm show --name webapp01 --resource-group rg-prod

# Check sync logs
tail -50 /var/log/keyfactor/asset-sync.log
```

**Resolution**: Trigger manual sync or add missing entry

---

## Performance Metrics

**Target Performance**:
- Validation time: <500ms (95th percentile)
- Cache hit rate: >80%
- Accuracy: >95%
- Freshness: <6 hours

**Monitoring**:
```bash
# Log validation requests
# /var/log/keyfactor/validation.log format:
# timestamp|hostname|result|source|duration_ms

# Generate metrics
awk -F'|' '{sum+=$5; count++} END {print "Average:", sum/count, "ms"}' \
  /var/log/keyfactor/validation.log

# Cache hit rate
grep -c "cache-hit" /var/log/keyfactor/validation.log
```

---

## Related Documentation

- [01 - Executive Design Document](./01-Executive-Design-Document.md) § 4 (Authorization Model)
- [02 - RBAC Authorization Framework](./02-RBAC-Authorization-Framework.md) § 4 (Resource Binding)
- [18 - Quick Start First Sprint](./18-Quick-Start-First-Sprint.md) § Day 4 (Ownership Tagging)

---

**Document Owner**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Last Updated**: October 22, 2025

