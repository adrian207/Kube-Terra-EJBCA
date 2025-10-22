# Installation Guide - Asset Validation Scripts

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025

---

## Quick Start

### 1. Choose Your Language

| If you have... | Use... | Why? |
|----------------|--------|------|
| Windows servers + Azure | **PowerShell** | Native integration |
| Linux servers | **Python** or **Bash** | Cross-platform or lightweight |
| Containers/Kubernetes | **Go** | Single binary, no dependencies |
| High volume (>10k/day) | **Go** | Best performance |
| Mixed environment | **Python** | Works everywhere |

**Recommendation**: Start with **Python** (easiest to maintain), migrate to **Go** if performance becomes an issue.

---

## Python Installation

### Prerequisites
- Python 3.7 or higher
- pip package manager

### Install

```bash
# 1. Install Python (if not already installed)
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y python3 python3-pip

# RHEL/CentOS
sudo yum install -y python3 python3-pip

# macOS (with Homebrew)
brew install python3

# Windows: Download from https://www.python.org/downloads/

# 2. Install dependencies
pip3 install psycopg2-binary requests azure-identity azure-mgmt-resourcegraph

# 3. Copy script
sudo mkdir -p /opt/keyfactor/scripts
sudo cp validate-device.py /opt/keyfactor/scripts/
sudo chmod +x /opt/keyfactor/scripts/validate-device.py

# 4. Test
/opt/keyfactor/scripts/validate-device.py webapp01.contoso.com
```

### Docker Installation

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir psycopg2-binary requests azure-identity azure-mgmt-resourcegraph

# Copy script
COPY validate-device.py /app/

# Set entrypoint
ENTRYPOINT ["python3", "/app/validate-device.py"]
```

```bash
# Build
docker build -t keyfactor-validator:python .

# Run
docker run --rm keyfactor-validator:python webapp01.contoso.com
```

---

## PowerShell Installation

### Prerequisites
- PowerShell 7.0 or higher (cross-platform)
- Or Windows PowerShell 5.1 (Windows only)

### Install

```powershell
# 1. Install PowerShell 7 (if not already installed)
# Windows: winget install --id Microsoft.PowerShell --source winget
# macOS: brew install --cask powershell
# Linux: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux

# 2. Install required modules
Install-Module -Name Az.ResourceGraph -Scope CurrentUser -Force
Install-Module -Name Npgsql -Scope CurrentUser -Force  # Optional: for PostgreSQL

# 3. Copy script
New-Item -Path "C:\Keyfactor\scripts" -ItemType Directory -Force
Copy-Item validate-device.ps1 -Destination "C:\Keyfactor\scripts\"

# 4. Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 5. Test
C:\Keyfactor\scripts\validate-device.ps1 -Hostname webapp01.contoso.com -Verbose
```

### Linux/macOS Installation

```bash
# 1. Install PowerShell (see above)

# 2. Install modules
pwsh -Command "Install-Module -Name Az.ResourceGraph -Scope CurrentUser -Force"

# 3. Copy script
sudo mkdir -p /opt/keyfactor/scripts
sudo cp validate-device.ps1 /opt/keyfactor/scripts/
sudo chmod +x /opt/keyfactor/scripts/validate-device.ps1

# 4. Test
pwsh /opt/keyfactor/scripts/validate-device.ps1 -Hostname webapp01.contoso.com
```

---

## Go Installation

### Prerequisites
- Go 1.19 or higher (for building)
- No prerequisites for running the compiled binary

### Build from Source

```bash
# 1. Install Go (if not already installed)
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y golang-go

# RHEL/CentOS
sudo yum install -y golang

# macOS (with Homebrew)
brew install go

# Windows: Download from https://go.dev/dl/

# 2. Create project
mkdir validate-device && cd validate-device
go mod init validate-device

# 3. Install dependencies
go get github.com/lib/pq  # PostgreSQL driver (optional)

# 4. Build
go build -o validate-device -ldflags="-s -w" validate-device.go

# 5. Install
sudo cp validate-device /opt/keyfactor/scripts/
sudo chmod +x /opt/keyfactor/scripts/validate-device

# 6. Test
/opt/keyfactor/scripts/validate-device webapp01.contoso.com
```

### Cross-Platform Build

```bash
# Build for Linux (from any OS)
GOOS=linux GOARCH=amd64 go build -o validate-device-linux -ldflags="-s -w" validate-device.go

# Build for Windows (from any OS)
GOOS=windows GOARCH=amd64 go build -o validate-device.exe -ldflags="-s -w" validate-device.go

# Build for macOS (from any OS)
GOOS=darwin GOARCH=amd64 go build -o validate-device-macos -ldflags="-s -w" validate-device.go
```

### Docker Installation (Recommended)

```dockerfile
FROM golang:1.19-alpine AS builder

WORKDIR /build

# Copy source
COPY validate-device.go go.mod go.sum ./

# Build static binary
RUN go build -o validate-device -ldflags="-s -w" validate-device.go

# Final image
FROM alpine:latest

RUN apk add --no-cache ca-certificates

COPY --from=builder /build/validate-device /usr/local/bin/

ENTRYPOINT ["validate-device"]
```

```bash
# Build
docker build -t keyfactor-validator:go .

# Run
docker run --rm keyfactor-validator:go webapp01.contoso.com

# Image size: ~15 MB (vs ~150 MB for Python)
```

---

## Bash Installation

### Prerequisites
- Bash 4.0 or higher
- Standard Unix tools: `curl`, `jq`, `grep`, `awk`
- Optional: `psql` (PostgreSQL client), `az` (Azure CLI), `kubectl`

### Install

```bash
# 1. Install dependencies
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y curl jq postgresql-client

# RHEL/CentOS
sudo yum install -y curl jq postgresql

# macOS (with Homebrew)
brew install curl jq libpq

# 2. Copy script
sudo mkdir -p /opt/keyfactor/scripts
sudo cp validate-device.sh /opt/keyfactor/scripts/
sudo chmod +x /opt/keyfactor/scripts/validate-device.sh

# 3. Test
/opt/keyfactor/scripts/validate-device.sh webapp01.contoso.com
```

---

## Configuration

All scripts use the same environment variables:

### Required for CSV (default)
```bash
export ASSET_CSV_PATH="/opt/keyfactor/asset-inventory/asset-inventory.csv"
```

### Optional for Database
```bash
export ASSET_DB_HOST="asset-db.contoso.com"
export ASSET_DB_USER="keyfactor_reader"
export ASSET_DB_PASSWORD="SecurePassword123!"
```

### Optional for ServiceNow
```bash
export SNOW_INSTANCE="contoso.service-now.com"
export SNOW_USER="keyfactor-api"
export SNOW_PASSWORD="ServiceNowAPIKey123!"
```

### Optional for Azure
```bash
export AZURE_SUBSCRIPTION_ID="12345678-1234-1234-1234-123456789012"
```

### Create Environment File

```bash
# Create /opt/keyfactor/scripts/.env
cat <<EOF | sudo tee /opt/keyfactor/scripts/.env
ASSET_CSV_PATH=/opt/keyfactor/asset-inventory/asset-inventory.csv
ASSET_CACHE_PATH=/tmp/asset-inventory-cache
ASSET_DB_HOST=asset-db.contoso.com
ASSET_DB_USER=keyfactor_reader
ASSET_DB_PASSWORD=SecurePassword123!
SNOW_INSTANCE=contoso.service-now.com
SNOW_USER=keyfactor-api
SNOW_PASSWORD=ServiceNowAPIKey123!
AZURE_SUBSCRIPTION_ID=12345678-1234-1234-1234-123456789012
EOF

# Secure the file
sudo chmod 600 /opt/keyfactor/scripts/.env
```

---

## Testing

### Test Script (All Languages)

```bash
#!/bin/bash
# File: test-all-validators.sh

# Test valid hostname
echo "Testing valid hostname..."
for script in \
    "python3 /opt/keyfactor/scripts/validate-device.py" \
    "pwsh /opt/keyfactor/scripts/validate-device.ps1 -Hostname" \
    "/opt/keyfactor/scripts/validate-device" \
    "/opt/keyfactor/scripts/validate-device.sh"
do
    echo "  Script: $script"
    result=$($script webapp01.contoso.com)
    if [[ $? -eq 0 ]] && [[ "$result" == AUTHORIZED* ]]; then
        echo "    ✅ PASS: $result"
    else
        echo "    ❌ FAIL: $result"
    fi
done

# Test invalid hostname
echo ""
echo "Testing invalid hostname..."
for script in \
    "python3 /opt/keyfactor/scripts/validate-device.py" \
    "pwsh /opt/keyfactor/scripts/validate-device.ps1 -Hostname" \
    "/opt/keyfactor/scripts/validate-device" \
    "/opt/keyfactor/scripts/validate-device.sh"
do
    echo "  Script: $script"
    result=$($script nonexistent.contoso.com 2>/dev/null)
    if [[ $? -eq 1 ]] && [[ "$result" == DENIED* ]]; then
        echo "    ✅ PASS: $result"
    else
        echo "    ❌ FAIL: $result"
    fi
done
```

### Performance Test

```bash
#!/bin/bash
# File: benchmark-validators.sh

echo "Benchmarking validators (100 queries)..."

# Test Python
time for i in {1..100}; do 
    python3 /opt/keyfactor/scripts/validate-device.py webapp01.contoso.com > /dev/null
done

# Test PowerShell
time for i in {1..100}; do 
    pwsh /opt/keyfactor/scripts/validate-device.ps1 -Hostname webapp01.contoso.com > /dev/null
done

# Test Go
time for i in {1..100}; do 
    /opt/keyfactor/scripts/validate-device webapp01.contoso.com > /dev/null
done

# Test Bash
time for i in {1..100}; do 
    /opt/keyfactor/scripts/validate-device.sh webapp01.contoso.com > /dev/null
done
```

---

## Integration with Keyfactor

### Webhook Configuration

```yaml
# Keyfactor Command webhook configuration
webhook:
  validation_endpoint: "http://localhost:5000/validate"
  validation_script: "/opt/keyfactor/scripts/validate-device.py"
  timeout: 5s
  retry_count: 3
```

### Event Handler

```python
# File: /opt/keyfactor/webhook-handler.py
import subprocess

def validate_certificate_request(hostname, requester_email):
    """Call validation script and parse result"""
    result = subprocess.run(
        ['/opt/keyfactor/scripts/validate-device.py', hostname, requester_email],
        capture_output=True,
        text=True,
        timeout=5
    )
    
    if result.returncode == 0:
        # Parse output: AUTHORIZED|team|env|cost_center
        parts = result.stdout.strip().split('|')
        return {
            'authorized': True,
            'owner_team': parts[1],
            'environment': parts[2],
            'cost_center': parts[3]
        }
    else:
        # Parse output: DENIED|reason
        return {
            'authorized': False,
            'reason': result.stdout.strip().split('|')[1]
        }
```

---

## Troubleshooting

### Python Issues

**Problem**: `ModuleNotFoundError: No module named 'psycopg2'`

**Solution**:
```bash
pip3 install psycopg2-binary
```

**Problem**: `ImportError: cannot import name 'DefaultAzureCredential'`

**Solution**:
```bash
pip3 install azure-identity azure-mgmt-resourcegraph
```

---

### PowerShell Issues

**Problem**: `Az.ResourceGraph module not found`

**Solution**:
```powershell
Install-Module -Name Az.ResourceGraph -Scope CurrentUser -Force
Import-Module Az.ResourceGraph
```

**Problem**: `Execution policy error`

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### Go Issues

**Problem**: `undefined: sql.Open`

**Solution**:
```bash
go get github.com/lib/pq
go build
```

**Problem**: Binary too large

**Solution**:
```bash
# Build with stripping and compression
go build -ldflags="-s -w" -o validate-device validate-device.go

# Optional: compress with UPX
upx --best --lzma validate-device
```

---

### Bash Issues

**Problem**: `jq: command not found`

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

**Problem**: `psql: command not found`

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client

# RHEL/CentOS
sudo yum install postgresql
```

---

## Support

**Documentation**: [scripts/README.md](./README.md)  
**Main Guide**: [ASSET-INVENTORY-INTEGRATION-GUIDE.md](../ASSET-INVENTORY-INTEGRATION-GUIDE.md)  
**Author**: Adrian Johnson <adrian207@gmail.com>  

---

**Version**: 1.0  
**Last Updated**: October 22, 2025

