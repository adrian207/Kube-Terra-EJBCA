#!/usr/bin/env python3
"""
Python Asset Validation Script
File: /opt/keyfactor/scripts/validate-device.py
Author: Adrian Johnson <adrian207@gmail.com>

Usage:
    python3 validate-device.py webapp01.contoso.com
    Output: AUTHORIZED|team-web-apps|production|12345
    
    python3 validate-device.py nonexistent.contoso.com
    Output: DENIED|Device not found
    Exit Code: 1
"""

import csv
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Tuple

# Configuration
CSV_PATH = os.getenv('ASSET_CSV_PATH', '/opt/keyfactor/asset-inventory/asset-inventory.csv')
CACHE_PATH = os.getenv('ASSET_CACHE_PATH', '/tmp/asset-inventory-cache.json')
CACHE_TIMEOUT_SECS = 3600  # 1 hour

# Database config
DB_HOST = os.getenv('ASSET_DB_HOST', 'asset-db.contoso.com')
DB_NAME = 'asset_inventory'
DB_USER = os.getenv('ASSET_DB_USER', 'keyfactor_reader')
DB_PASSWORD = os.getenv('ASSET_DB_PASSWORD')

# ServiceNow config
SNOW_INSTANCE = os.getenv('SNOW_INSTANCE', 'contoso.service-now.com')
SNOW_USER = os.getenv('SNOW_USER', 'keyfactor-api')
SNOW_PASSWORD = os.getenv('SNOW_PASSWORD')

# Azure config
AZURE_SUBSCRIPTION = os.getenv('AZURE_SUBSCRIPTION_ID')


class AssetInfo:
    """Device/asset metadata"""
    def __init__(self, owner_email: str, owner_team: str, environment: str, 
                 cost_center: str = '', status: str = 'active'):
        self.exists = True
        self.owner_email = owner_email
        self.owner_team = owner_team
        self.environment = environment
        self.cost_center = cost_center
        self.status = status


def authorized(owner_team: str, environment: str, cost_center: str):
    """Print authorized output and exit"""
    print(f"AUTHORIZED|{owner_team}|{environment}|{cost_center}")
    sys.exit(0)


def denied(reason: str):
    """Print denied output and exit"""
    print(f"DENIED|{reason}")
    sys.exit(1)


def is_cache_fresh(cache_path: str, timeout_secs: int) -> bool:
    """Check if cache file is fresh"""
    if not os.path.exists(cache_path):
        return False
    
    cache_age = time.time() - os.path.getmtime(cache_path)
    return cache_age < timeout_secs


# CSV Validation
def validate_from_csv(hostname: str) -> Optional[AssetInfo]:
    """Validate device from CSV file"""
    try:
        # Try cache first
        if is_cache_fresh(CACHE_PATH, CACHE_TIMEOUT_SECS):
            with open(CACHE_PATH, 'r') as f:
                cache = json.load(f)
                if hostname in cache:
                    data = cache[hostname]
                    if data['status'] == 'active':
                        return AssetInfo(**data)
        
        # Load CSV
        if not os.path.exists(CSV_PATH):
            return None
        
        inventory = {}
        with open(CSV_PATH, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row.get('status') == 'active':
                    inventory[row['hostname']] = {
                        'owner_email': row.get('owner_email', 'unknown@contoso.com'),
                        'owner_team': row.get('owner_team', 'unknown'),
                        'environment': row.get('environment', 'unknown'),
                        'cost_center': row.get('cost_center', ''),
                        'status': row.get('status', 'active')
                    }
        
        # Save cache
        with open(CACHE_PATH, 'w') as f:
            json.dump(inventory, f, indent=2)
        
        # Lookup hostname
        if hostname in inventory:
            return AssetInfo(**inventory[hostname])
        
        return None
    
    except Exception as e:
        print(f"CSV validation error: {e}", file=sys.stderr)
        return None


# Database Validation
def validate_from_database(hostname: str) -> Optional[AssetInfo]:
    """Validate device from PostgreSQL database"""
    if not DB_PASSWORD:
        return None
    
    try:
        import psycopg2
        
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=5
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM get_asset(%s)", (hostname,))
        row = cursor.fetchone()
        
        if row:
            # Assuming function returns: hostname, owner_email, owner_team, environment, cost_center, status
            return AssetInfo(
                owner_email=row[1],
                owner_team=row[2],
                environment=row[3],
                cost_center=row[4],
                status=row[5]
            )
        
        cursor.close()
        conn.close()
        return None
    
    except ImportError:
        print("psycopg2 not installed, skipping database validation", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Database validation error: {e}", file=sys.stderr)
        return None


# Azure Validation
def validate_from_azure(hostname: str) -> Optional[AssetInfo]:
    """Validate device from Azure Resource Graph"""
    if not hostname.endswith('.contoso.com') and 'internal' not in hostname:
        return None
    
    try:
        from azure.identity import DefaultAzureCredential
        from azure.mgmt.resourcegraph import ResourceGraphClient
        
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
        
        result = client.resources(query={'query': query})
        
        if result.data:
            data = result.data[0]
            if data['status'] == 'active':
                return AssetInfo(
                    owner_email=data.get('owner_email', 'unknown@contoso.com'),
                    owner_team=data.get('owner_team', 'unknown'),
                    environment=data.get('environment', 'unknown'),
                    cost_center=data.get('cost_center', ''),
                    status=data['status']
                )
        
        return None
    
    except ImportError:
        print("Azure SDK not installed, skipping Azure validation", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Azure validation error: {e}", file=sys.stderr)
        return None


# Kubernetes Validation
def validate_from_kubernetes(hostname: str) -> Optional[AssetInfo]:
    """Validate device from Kubernetes namespace"""
    if not hostname.endswith('.svc.cluster.local'):
        return None
    
    try:
        import subprocess
        
        # Extract namespace from hostname (format: service.namespace.svc.cluster.local)
        parts = hostname.split('.')
        if len(parts) < 4 or parts[2] != 'svc':
            return None
        
        namespace = parts[1]
        
        # Get namespace info using kubectl
        result = subprocess.run(
            ['kubectl', 'get', 'namespace', namespace, '-o', 'json'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return None
        
        ns_data = json.loads(result.stdout)
        
        if ns_data['status']['phase'] != 'Active':
            return None
        
        labels = ns_data.get('metadata', {}).get('labels', {})
        annotations = ns_data.get('metadata', {}).get('annotations', {})
        
        owner_email = annotations.get('owner-email') or labels.get('owner', 'unknown@contoso.com')
        
        return AssetInfo(
            owner_email=owner_email,
            owner_team=labels.get('team', 'unknown'),
            environment=labels.get('environment', 'unknown'),
            cost_center=labels.get('cost-center', ''),
            status='active'
        )
    
    except FileNotFoundError:
        print("kubectl not found, skipping Kubernetes validation", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Kubernetes validation error: {e}", file=sys.stderr)
        return None


# ServiceNow Validation
def validate_from_servicenow(hostname: str) -> Optional[AssetInfo]:
    """Validate device from ServiceNow CMDB"""
    if not SNOW_PASSWORD:
        return None
    
    try:
        import requests
        
        url = f"https://{SNOW_INSTANCE}/api/now/table/cmdb_ci_server"
        params = {
            'sysparm_query': f'name={hostname}^operational_status=1',
            'sysparm_fields': 'name,owned_by,support_group,environment,cost_center'
        }
        
        response = requests.get(
            url,
            auth=(SNOW_USER, SNOW_PASSWORD),
            headers={'Accept': 'application/json'},
            timeout=10
        )
        
        if response.status_code != 200:
            return None
        
        data = response.json()
        
        if not data.get('result'):
            return None
        
        ci = data['result'][0]
        
        # Get owner email
        owner_id = ci.get('owned_by', {}).get('value')
        if owner_id:
            owner_url = f"https://{SNOW_INSTANCE}/api/now/table/sys_user/{owner_id}"
            owner_response = requests.get(
                owner_url,
                auth=(SNOW_USER, SNOW_PASSWORD),
                headers={'Accept': 'application/json'},
                timeout=10
            )
            owner_email = owner_response.json().get('result', {}).get('email', 'unknown@contoso.com')
        else:
            owner_email = 'unknown@contoso.com'
        
        return AssetInfo(
            owner_email=owner_email,
            owner_team=ci.get('support_group', {}).get('display_value', 'unknown'),
            environment=ci.get('environment', 'unknown'),
            cost_center=ci.get('cost_center', ''),
            status='active'
        )
    
    except ImportError:
        print("requests library not installed, skipping ServiceNow validation", file=sys.stderr)
        return None
    except Exception as e:
        print(f"ServiceNow validation error: {e}", file=sys.stderr)
        return None


# Main validation logic
def validate_hostname(hostname: str, requester_email: Optional[str] = None) -> Optional[AssetInfo]:
    """
    Validate hostname against multiple sources in order of preference
    """
    # 1. ServiceNow CMDB (if configured)
    asset = validate_from_servicenow(hostname)
    if asset and asset.status == 'active':
        return asset
    
    # 2. Database (if configured)
    asset = validate_from_database(hostname)
    if asset and asset.status == 'active':
        return asset
    
    # 3. Azure (if applicable)
    if hostname.endswith('.contoso.com') or 'internal' in hostname:
        asset = validate_from_azure(hostname)
        if asset and asset.status == 'active':
            return asset
    
    # 4. Kubernetes (if applicable)
    if hostname.endswith('.svc.cluster.local'):
        asset = validate_from_kubernetes(hostname)
        if asset and asset.status == 'active':
            return asset
    
    # 5. CSV (fallback)
    asset = validate_from_csv(hostname)
    if asset and asset.status == 'active':
        return asset
    
    return None


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <hostname> [requester_email]", file=sys.stderr)
        sys.exit(2)
    
    hostname = sys.argv[1]
    requester = sys.argv[2] if len(sys.argv) > 2 else None
    
    asset = validate_hostname(hostname, requester)
    
    if asset and asset.exists and asset.status == 'active':
        authorized(asset.owner_team, asset.environment, asset.cost_center)
    else:
        denied(f"Device '{hostname}' not found in any inventory source")


if __name__ == '__main__':
    main()

