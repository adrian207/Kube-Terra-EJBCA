#!/bin/bash
#
# Reload NGINX after certificate deployment
# Usage: reload-nginx.sh <cert-path> <key-path> <nginx-config>
#

set -e

# Configuration
CERT_PATH="$1"
KEY_PATH="$2"
NGINX_CONFIG="${3:-/etc/nginx/nginx.conf}"
LOG_FILE="/var/log/keyfactor-nginx-reload.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Validate inputs
if [ -z "$CERT_PATH" ] || [ -z "$KEY_PATH" ]; then
    log "ERROR: Certificate path and key path are required"
    echo "Usage: $0 <cert-path> <key-path> [nginx-config]"
    exit 1
fi

log "Starting NGINX certificate update"
log "Certificate: $CERT_PATH"
log "Key: $KEY_PATH"
log "Config: $NGINX_CONFIG"

# Verify certificate and key exist
if [ ! -f "$CERT_PATH" ]; then
    log "ERROR: Certificate file not found: $CERT_PATH"
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    log "ERROR: Key file not found: $KEY_PATH"
    exit 1
fi

# Verify certificate and key match
log "Verifying certificate and key match..."
CERT_MODULUS=$(openssl x509 -noout -modulus -in "$CERT_PATH" | openssl md5)
KEY_MODULUS=$(openssl rsa -noout -modulus -in "$KEY_PATH" | openssl md5)

if [ "$CERT_MODULUS" != "$KEY_MODULUS" ]; then
    log "ERROR: Certificate and key do not match"
    log "  Certificate modulus: $CERT_MODULUS"
    log "  Key modulus: $KEY_MODULUS"
    exit 1
fi

log "Certificate and key match successfully"

# Backup existing configuration
BACKUP_DIR="/etc/nginx/backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/nginx-$(date +%Y%m%d-%H%M%S).tar.gz"

log "Creating backup: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C /etc/nginx .

# Test NGINX configuration
log "Testing NGINX configuration..."
nginx -t -c "$NGINX_CONFIG"

if [ $? -ne 0 ]; then
    log "ERROR: NGINX configuration test failed"
    exit 1
fi

log "NGINX configuration test passed"

# Reload NGINX
log "Reloading NGINX..."
systemctl reload nginx

if [ $? -ne 0 ]; then
    log "ERROR: NGINX reload failed"
    log "Attempting to restore from backup..."
    
    # Restore backup
    tar -xzf "$BACKUP_FILE" -C /etc/nginx
    systemctl reload nginx
    
    log "Configuration restored from backup"
    exit 1
fi

log "NGINX reloaded successfully"

# Verify NGINX is running
sleep 2
if systemctl is-active --quiet nginx; then
    log "NGINX is running"
else
    log "ERROR: NGINX is not running after reload"
    exit 1
fi

# Test HTTPS endpoint
log "Testing HTTPS endpoint..."
HTTPS_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost)

if [ "$HTTPS_TEST" == "200" ] || [ "$HTTPS_TEST" == "301" ] || [ "$HTTPS_TEST" == "302" ]; then
    log "HTTPS endpoint test successful (Status: $HTTPS_TEST)"
else
    log "WARNING: HTTPS endpoint test returned status: $HTTPS_TEST"
fi

# Verify certificate expiry
CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
log "New certificate expires: $CERT_EXPIRY"

log "NGINX certificate update completed successfully"
exit 0

