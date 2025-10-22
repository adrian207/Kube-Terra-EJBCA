# PowerShell Asset Validation Script
# File: /opt/keyfactor/scripts/validate-device.ps1
# Author: Adrian Johnson <adrian207@gmail.com>

<#
.SYNOPSIS
    Validates device exists in asset inventory for certificate authorization.

.DESCRIPTION
    Multi-source device validation for Keyfactor certificate issuance.
    Tries sources in order: ServiceNow CMDB, Database, Azure, AWS, K8s, CSV.

.PARAMETER Hostname
    The hostname to validate (e.g., webapp01.contoso.com)

.PARAMETER RequesterEmail
    Optional: Email of the person requesting the certificate

.EXAMPLE
    .\validate-device.ps1 -Hostname webapp01.contoso.com
    Output: AUTHORIZED|team-web-apps|production|12345

.EXAMPLE
    .\validate-device.ps1 -Hostname nonexistent.contoso.com
    Output: DENIED|Device not found in asset inventory
    Exit Code: 1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Hostname,
    
    [Parameter(Mandatory=$false)]
    [string]$RequesterEmail
)

# Configuration
$CSV_PATH = "C:\Keyfactor\asset-inventory\asset-inventory.csv"
$CACHE_PATH = "$env:TEMP\asset-inventory-cache.xml"
$CACHE_TIMEOUT_SECONDS = 3600  # 1 hour

#region Helper Functions

function Write-AuthorizedOutput {
    param(
        [string]$OwnerTeam,
        [string]$Environment,
        [string]$CostCenter
    )
    Write-Output "AUTHORIZED|$OwnerTeam|$Environment|$CostCenter"
    exit 0
}

function Write-DeniedOutput {
    param([string]$Reason)
    Write-Output "DENIED|$Reason"
    exit 1
}

function Test-CacheFresh {
    if (Test-Path $CACHE_PATH) {
        $cacheAge = (Get-Date) - (Get-Item $CACHE_PATH).LastWriteTime
        return $cacheAge.TotalSeconds -lt $CACHE_TIMEOUT_SECONDS
    }
    return $false
}

#endregion

#region CSV Validation

function Get-AssetFromCSV {
    param([string]$Hostname)
    
    try {
        # Try to load from cache
        if (Test-CacheFresh) {
            $inventory = Import-Clixml -Path $CACHE_PATH
        }
        else {
            # Load from CSV
            if (-not (Test-Path $CSV_PATH)) {
                Write-Verbose "CSV file not found: $CSV_PATH"
                return $null
            }
            
            $inventory = Import-Csv -Path $CSV_PATH | 
                         Where-Object { $_.status -eq 'active' } |
                         Group-Object -Property hostname -AsHashTable
            
            # Cache for next time
            $inventory | Export-Clixml -Path $CACHE_PATH -Force
        }
        
        # Lookup hostname
        if ($inventory.ContainsKey($Hostname)) {
            $asset = $inventory[$Hostname]
            return @{
                Exists = $true
                OwnerEmail = $asset.owner_email
                OwnerTeam = $asset.owner_team
                Environment = $asset.environment
                CostCenter = $asset.cost_center
                Status = $asset.status
            }
        }
        
        return $null
    }
    catch {
        Write-Verbose "CSV validation error: $_"
        return $null
    }
}

#endregion

#region Database Validation

function Get-AssetFromDatabase {
    param([string]$Hostname)
    
    try {
        $dbServer = $env:ASSET_DB_HOST ?? "asset-db.contoso.com"
        $dbName = "asset_inventory"
        $dbUser = "keyfactor_reader"
        $dbPassword = $env:ASSET_DB_PASSWORD
        
        if (-not $dbPassword) {
            Write-Verbose "Database password not set in ASSET_DB_PASSWORD"
            return $null
        }
        
        # PostgreSQL connection (requires Npgsql module or ODBC)
        $connectionString = "Host=$dbServer;Database=$dbName;Username=$dbUser;Password=$dbPassword;Timeout=5"
        
        # Using .NET PostgreSQL provider
        [System.Reflection.Assembly]::LoadWithPartialName("Npgsql") | Out-Null
        $conn = New-Object Npgsql.NpgsqlConnection($connectionString)
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT * FROM get_asset(@hostname)"
        $cmd.Parameters.AddWithValue("hostname", $Hostname) | Out-Null
        
        $reader = $cmd.ExecuteReader()
        
        if ($reader.Read()) {
            $result = @{
                Exists = $true
                OwnerEmail = $reader["owner_email"]
                OwnerTeam = $reader["owner_team"]
                Environment = $reader["environment"]
                CostCenter = $reader["cost_center"]
                Status = $reader["status"]
            }
            $reader.Close()
            $conn.Close()
            return $result
        }
        
        $reader.Close()
        $conn.Close()
        return $null
    }
    catch {
        Write-Verbose "Database validation error: $_"
        return $null
    }
}

#endregion

#region Azure Validation

function Get-AssetFromAzure {
    param([string]$Hostname)
    
    try {
        # Check if Az.ResourceGraph module is available
        if (-not (Get-Module -ListAvailable -Name Az.ResourceGraph)) {
            Write-Verbose "Az.ResourceGraph module not installed"
            return $null
        }
        
        Import-Module Az.ResourceGraph -ErrorAction SilentlyContinue
        
        $query = @"
Resources
| where type == 'microsoft.compute/virtualmachines'
| where name == '$Hostname' or properties.osProfile.computerName == '$Hostname'
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
"@
        
        $result = Search-AzGraph -Query $query -First 1
        
        if ($result) {
            return @{
                Exists = $true
                OwnerEmail = $result.owner_email ?? "unknown@contoso.com"
                OwnerTeam = $result.owner_team ?? "unknown"
                Environment = $result.environment ?? "unknown"
                CostCenter = $result.cost_center ?? ""
                Status = $result.status
            }
        }
        
        return $null
    }
    catch {
        Write-Verbose "Azure validation error: $_"
        return $null
    }
}

#endregion

#region ServiceNow Validation

function Get-AssetFromServiceNow {
    param([string]$Hostname)
    
    try {
        $snowInstance = "contoso.service-now.com"
        $snowUser = $env:SNOW_USER ?? "keyfactor-api"
        $snowPassword = $env:SNOW_PASSWORD
        
        if (-not $snowPassword) {
            Write-Verbose "ServiceNow password not set"
            return $null
        }
        
        $uri = "https://$snowInstance/api/now/table/cmdb_ci_server"
        $query = "name=$Hostname^operational_status=1"
        $fields = "name,owned_by,support_group,environment,cost_center,operational_status"
        
        $headers = @{
            'Accept' = 'application/json'
        }
        
        $credential = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${snowUser}:${snowPassword}"))
        $headers['Authorization'] = "Basic $credential"
        
        $response = Invoke-RestMethod -Uri "$uri`?sysparm_query=$query&sysparm_fields=$fields" `
                                       -Method Get `
                                       -Headers $headers `
                                       -TimeoutSec 10 `
                                       -ErrorAction Stop
        
        if ($response.result) {
            $ci = $response.result[0]
            
            # Get owner details
            $ownerUri = "https://$snowInstance/api/now/table/sys_user/$($ci.owned_by.value)"
            $ownerResponse = Invoke-RestMethod -Uri $ownerUri -Method Get -Headers $headers
            
            return @{
                Exists = $true
                OwnerEmail = $ownerResponse.result.email
                OwnerTeam = $ci.support_group.display_value ?? "unknown"
                Environment = $ci.environment ?? "unknown"
                CostCenter = $ci.cost_center ?? ""
                Status = "active"
            }
        }
        
        return $null
    }
    catch {
        Write-Verbose "ServiceNow validation error: $_"
        return $null
    }
}

#endregion

#region Kubernetes Validation

function Get-AssetFromKubernetes {
    param([string]$Hostname)
    
    # Only for .svc.cluster.local hostnames
    if ($Hostname -notlike "*.svc.cluster.local") {
        return $null
    }
    
    try {
        $parts = $Hostname -split '\.'
        if ($parts.Count -lt 4 -or $parts[2] -ne 'svc') {
            return $null
        }
        
        $namespace = $parts[1]
        
        # Use kubectl to get namespace
        $nsJson = kubectl get namespace $namespace -o json 2>$null | ConvertFrom-Json
        
        if (-not $nsJson) {
            return $null
        }
        
        if ($nsJson.status.phase -ne 'Active') {
            return $null
        }
        
        $labels = $nsJson.metadata.labels ?? @{}
        $annotations = $nsJson.metadata.annotations ?? @{}
        
        return @{
            Exists = $true
            OwnerEmail = $annotations.'owner-email' ?? $labels.owner ?? "unknown@contoso.com"
            OwnerTeam = $labels.team ?? "unknown"
            Environment = $labels.environment ?? "unknown"
            CostCenter = $labels.'cost-center' ?? ""
            Status = "active"
        }
    }
    catch {
        Write-Verbose "Kubernetes validation error: $_"
        return $null
    }
}

#endregion

#region Main Logic

function Invoke-MultiSourceValidation {
    param(
        [string]$Hostname,
        [string]$RequesterEmail
    )
    
    Write-Verbose "Validating hostname: $Hostname"
    
    # Try sources in order of preference
    
    # 1. ServiceNow CMDB (if configured)
    Write-Verbose "Trying ServiceNow CMDB..."
    $result = Get-AssetFromServiceNow -Hostname $Hostname
    if ($result -and $result.Exists) {
        Write-Verbose "Found in ServiceNow CMDB"
        Write-AuthorizedOutput -OwnerTeam $result.OwnerTeam `
                               -Environment $result.Environment `
                               -CostCenter $result.CostCenter
    }
    
    # 2. Database (if configured)
    Write-Verbose "Trying database..."
    $result = Get-AssetFromDatabase -Hostname $Hostname
    if ($result -and $result.Exists) {
        Write-Verbose "Found in database"
        Write-AuthorizedOutput -OwnerTeam $result.OwnerTeam `
                               -Environment $result.Environment `
                               -CostCenter $result.CostCenter
    }
    
    # 3. Azure Resource Graph
    if ($Hostname -like "*.contoso.com" -or $Hostname -like "*.internal*") {
        Write-Verbose "Trying Azure..."
        $result = Get-AssetFromAzure -Hostname $Hostname
        if ($result -and $result.Exists -and $result.Status -eq 'active') {
            Write-Verbose "Found in Azure"
            Write-AuthorizedOutput -OwnerTeam $result.OwnerTeam `
                                   -Environment $result.Environment `
                                   -CostCenter $result.CostCenter
        }
    }
    
    # 4. Kubernetes
    if ($Hostname -like "*.svc.cluster.local") {
        Write-Verbose "Trying Kubernetes..."
        $result = Get-AssetFromKubernetes -Hostname $Hostname
        if ($result -and $result.Exists) {
            Write-Verbose "Found in Kubernetes"
            Write-AuthorizedOutput -OwnerTeam $result.OwnerTeam `
                                   -Environment $result.Environment `
                                   -CostCenter $result.CostCenter
        }
    }
    
    # 5. CSV (fallback)
    Write-Verbose "Trying CSV..."
    $result = Get-AssetFromCSV -Hostname $Hostname
    if ($result -and $result.Exists) {
        Write-Verbose "Found in CSV"
        Write-AuthorizedOutput -OwnerTeam $result.OwnerTeam `
                               -Environment $result.Environment `
                               -CostCenter $result.CostCenter
    }
    
    # All sources failed
    Write-DeniedOutput -Reason "Device '$Hostname' not found in any inventory source"
}

# Execute
Invoke-MultiSourceValidation -Hostname $Hostname -RequesterEmail $RequesterEmail

#endregion

