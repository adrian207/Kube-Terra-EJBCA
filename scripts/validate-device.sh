#!/bin/bash
# Bash Asset Validation Script
# File: /opt/keyfactor/scripts/validate-device.sh
# Author: Adrian Johnson <adrian207@gmail.com>
#
# Usage:
#   ./validate-device.sh webapp01.contoso.com
#   Output: AUTHORIZED|team-web-apps|production|12345
#
#   ./validate-device.sh nonexistent.contoso.com
#   Output: DENIED|Device not found
#   Exit Code: 1

set -euo pipefail

# Configuration
CSV_PATH="${ASSET_CSV_PATH:-/opt/keyfactor/asset-inventory/asset-inventory.csv}"
CACHE_PATH="${ASSET_CACHE_PATH:-/tmp/asset-inventory-cache.txt}"
CACHE_TIMEOUT_SECS=3600  # 1 hour

# Functions

authorized() {
    local owner_team="$1"
    local environment="$2"
    local cost_center="$3"
    echo "AUTHORIZED|$owner_team|$environment|$cost_center"
    exit 0
}

denied() {
    local reason="$1"
    echo "DENIED|$reason"
    exit 1
}

is_cache_fresh() {
    if [[ ! -f "$CACHE_PATH" ]]; then
        return 1
    fi
    
    local cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_PATH" 2>/dev/null || stat -f %m "$CACHE_PATH" 2>/dev/null)))
    [[ $cache_age -lt $CACHE_TIMEOUT_SECS ]]
}

# CSV Validation
validate_from_csv() {
    local hostname="$1"
    
    if [[ ! -f "$CSV_PATH" ]]; then
        return 1
    fi
    
    # Try cache first
    if is_cache_fresh && [[ -f "$CACHE_PATH" ]]; then
        local cached=$(grep "^$hostname," "$CACHE_PATH" 2>/dev/null || true)
        if [[ -n "$cached" ]]; then
            IFS=',' read -r _ owner_email owner_team environment cost_center _ _ status _ <<< "$cached"
            if [[ "$status" == "active" ]]; then
                authorized "$owner_team" "$environment" "$cost_center"
            fi
        fi
    fi
    
    # Load from CSV
    grep ",active" "$CSV_PATH" > "$CACHE_PATH" 2>/dev/null || true
    
    # Search for hostname
    local line=$(grep "^$hostname," "$CACHE_PATH" 2>/dev/null || true)
    
    if [[ -n "$line" ]]; then
        IFS=',' read -r _ owner_email owner_team environment cost_center _ _ status _ <<< "$line"
        if [[ "$status" == "active" ]]; then
            authorized "$owner_team" "$environment" "$cost_center"
        fi
    fi
    
    return 1
}

# Database Validation (using psql)
validate_from_database() {
    local hostname="$1"
    
    # Check if PostgreSQL tools are available
    if ! command -v psql &> /dev/null; then
        return 1
    fi
    
    local db_host="${ASSET_DB_HOST:-asset-db.contoso.com}"
    local db_name="asset_inventory"
    local db_user="${ASSET_DB_USER:-keyfactor_reader}"
    local db_password="${ASSET_DB_PASSWORD:-}"
    
    if [[ -z "$db_password" ]]; then
        return 1
    fi
    
    # Query database
    local result=$(PGPASSWORD="$db_password" psql -h "$db_host" -U "$db_user" -d "$db_name" -t -A -c \
        "SELECT owner_team, environment, cost_center FROM get_asset('$hostname')" 2>/dev/null || true)
    
    if [[ -n "$result" ]]; then
        IFS='|' read -r owner_team environment cost_center <<< "$result"
        authorized "$owner_team" "$environment" "$cost_center"
    fi
    
    return 1
}

# Azure Validation (using az CLI)
validate_from_azure() {
    local hostname="$1"
    
    # Check if az CLI is available
    if ! command -v az &> /dev/null; then
        return 1
    fi
    
    # Only try Azure for internal domains
    if [[ ! "$hostname" =~ contoso\.com$ ]] && [[ ! "$hostname" =~ internal$ ]]; then
        return 1
    fi
    
    # Query Azure Resource Graph
    local query="Resources | where type == 'microsoft.compute/virtualmachines' | where name == '$hostname' | project owner_team = tags.Team, environment = tags.Environment, cost_center = tags.CostCenter, status = properties.extended.instanceView.powerState.displayStatus | limit 1"
    
    local result=$(az graph query -q "$query" --query 'data[0]' -o json 2>/dev/null || true)
    
    if [[ -n "$result" ]] && [[ "$result" != "null" ]]; then
        local owner_team=$(echo "$result" | jq -r '.owner_team // "unknown"')
        local environment=$(echo "$result" | jq -r '.environment // "unknown"')
        local cost_center=$(echo "$result" | jq -r '.cost_center // ""')
        local status=$(echo "$result" | jq -r '.status // ""')
        
        if [[ "$status" == "VM running" ]]; then
            authorized "$owner_team" "$environment" "$cost_center"
        fi
    fi
    
    return 1
}

# Kubernetes Validation (using kubectl)
validate_from_kubernetes() {
    local hostname="$1"
    
    # Only for .svc.cluster.local hostnames
    if [[ ! "$hostname" =~ \.svc\.cluster\.local$ ]]; then
        return 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        return 1
    fi
    
    # Extract namespace from hostname (format: service.namespace.svc.cluster.local)
    IFS='.' read -r service namespace svc cluster local <<< "$hostname"
    
    if [[ "$svc" != "svc" ]]; then
        return 1
    fi
    
    # Get namespace info
    local ns_json=$(kubectl get namespace "$namespace" -o json 2>/dev/null || true)
    
    if [[ -z "$ns_json" ]]; then
        return 1
    fi
    
    local phase=$(echo "$ns_json" | jq -r '.status.phase // ""')
    
    if [[ "$phase" != "Active" ]]; then
        return 1
    fi
    
    # Extract labels
    local owner_team=$(echo "$ns_json" | jq -r '.metadata.labels.team // "unknown"')
    local environment=$(echo "$ns_json" | jq -r '.metadata.labels.environment // "unknown"')
    local cost_center=$(echo "$ns_json" | jq -r '.metadata.labels."cost-center" // ""')
    
    authorized "$owner_team" "$environment" "$cost_center"
    
    return 0
}

# ServiceNow Validation (using curl)
validate_from_servicenow() {
    local hostname="$1"
    
    local snow_instance="${SNOW_INSTANCE:-contoso.service-now.com}"
    local snow_user="${SNOW_USER:-keyfactor-api}"
    local snow_password="${SNOW_PASSWORD:-}"
    
    if [[ -z "$snow_password" ]]; then
        return 1
    fi
    
    # Query ServiceNow
    local url="https://$snow_instance/api/now/table/cmdb_ci_server?sysparm_query=name=$hostname^operational_status=1&sysparm_fields=support_group,environment,cost_center"
    
    local response=$(curl -s --max-time 10 -u "$snow_user:$snow_password" \
        -H "Accept: application/json" \
        "$url" 2>/dev/null || true)
    
    if [[ -n "$response" ]]; then
        local count=$(echo "$response" | jq -r '.result | length')
        
        if [[ "$count" -gt 0 ]]; then
            local owner_team=$(echo "$response" | jq -r '.result[0].support_group.display_value // "unknown"')
            local environment=$(echo "$response" | jq -r '.result[0].environment // "unknown"')
            local cost_center=$(echo "$response" | jq -r '.result[0].cost_center // ""')
            
            authorized "$owner_team" "$environment" "$cost_center"
        fi
    fi
    
    return 1
}

# Main Logic

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <hostname> [requester_email]" >&2
        exit 2
    fi
    
    local hostname="$1"
    local requester="${2:-}"
    
    # Try sources in order
    
    # 1. ServiceNow CMDB
    validate_from_servicenow "$hostname" || true
    
    # 2. Database
    validate_from_database "$hostname" || true
    
    # 3. Azure
    validate_from_azure "$hostname" || true
    
    # 4. Kubernetes
    validate_from_kubernetes "$hostname" || true
    
    # 5. CSV (fallback)
    validate_from_csv "$hostname" || true
    
    # All sources failed
    denied "Device '$hostname' not found in any inventory source"
}

main "$@"

