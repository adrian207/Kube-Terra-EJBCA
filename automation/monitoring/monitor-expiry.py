#!/usr/bin/env python3
"""
Certificate Expiry Monitor
High-performance monitoring for certificate expiry across all stores.
"""

import requests
import logging
import os
import sys
import time
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
KEYFACTOR_HOST = os.environ.get('KEYFACTOR_HOST')
KEYFACTOR_USERNAME = os.environ.get('KEYFACTOR_USERNAME')
KEYFACTOR_PASSWORD = os.environ.get('KEYFACTOR_PASSWORD')
KEYFACTOR_DOMAIN = os.environ.get('KEYFACTOR_DOMAIN', 'CONTOSO')

WARNING_DAYS = int(os.environ.get('WARNING_DAYS', 30))
CRITICAL_DAYS = int(os.environ.get('CRITICAL_DAYS', 7))
CHECK_INTERVAL = int(os.environ.get('CHECK_INTERVAL', 60))  # minutes

ALERT_WEBHOOK_URL = os.environ.get('ALERT_WEBHOOK_URL')

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CertificateMonitor:
    def __init__(self, hostname, username, password, domain):
        self.base_url = f"{hostname}/KeyfactorAPI"
        self.session = requests.Session()
        self.session.auth = (f"{domain}\\{username}", password)
        self.session.headers.update({'Content-Type': 'application/json'})
        self.session.timeout = 30
    
    def get_certificates(self):
        """Retrieve all certificates."""
        try:
            response = self.session.get(f"{self.base_url}/Certificates")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to retrieve certificates: {e}")
            return []
    
    def check_expiry(self, cert):
        """Check certificate expiry and return status."""
        try:
            expiry = datetime.fromisoformat(cert['NotAfter'].replace('Z', '+00:00'))
            days_until_expiry = (expiry - datetime.now()).days
            
            subject = cert.get('IssuedDN', 'Unknown')
            
            if days_until_expiry < 0:
                logger.error(f"🔴 EXPIRED: {subject} (Expired {-days_until_expiry} days ago)")
                return 'EXPIRED', days_until_expiry
            elif days_until_expiry <= CRITICAL_DAYS:
                logger.error(f"🔴 CRITICAL: {subject} (Expires in {days_until_expiry} days)")
                return 'CRITICAL', days_until_expiry
            elif days_until_expiry <= WARNING_DAYS:
                logger.warning(f"🟡 WARNING: {subject} (Expires in {days_until_expiry} days)")
                return 'WARNING', days_until_expiry
            
            return 'OK', days_until_expiry
        except Exception as e:
            logger.error(f"Error checking expiry for certificate: {e}")
            return 'ERROR', None
    
    def send_alert(self, cert, severity, days_until_expiry):
        """Send alert to monitoring system."""
        if not ALERT_WEBHOOK_URL:
            return
        
        payload = {
            'severity': severity,
            'subject': cert.get('IssuedDN'),
            'thumbprint': cert.get('Thumbprint'),
            'daysUntilExpiry': days_until_expiry,
            'expiryDate': cert.get('NotAfter'),
            'timestamp': datetime.now().isoformat()
        }
        
        try:
            response = requests.post(
                ALERT_WEBHOOK_URL,
                json=payload,
                timeout=10
            )
            response.raise_for_status()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to send alert: {e}")
    
    def monitor_loop(self):
        """Continuous monitoring loop."""
        while True:
            logger.info("Starting certificate expiry check...")
            
            certificates = self.get_certificates()
            logger.info(f"Retrieved {len(certificates)} certificates")
            
            if not certificates:
                logger.warning("No certificates retrieved, sleeping...")
                time.sleep(CHECK_INTERVAL * 60)
                continue
            
            # Counters
            counters = {
                'EXPIRED': 0,
                'CRITICAL': 0,
                'WARNING': 0,
                'OK': 0,
                'ERROR': 0
            }
            
            # Check certificates concurrently
            with ThreadPoolExecutor(max_workers=10) as executor:
                future_to_cert = {
                    executor.submit(self.check_expiry, cert): cert
                    for cert in certificates
                }
                
                for future in as_completed(future_to_cert):
                    cert = future_to_cert[future]
                    try:
                        status, days = future.result()
                        counters[status] += 1
                        
                        # Send alert for expired or critical
                        if status in ['EXPIRED', 'CRITICAL', 'WARNING']:
                            self.send_alert(cert, status, days)
                    except Exception as e:
                        logger.error(f"Error processing certificate: {e}")
                        counters['ERROR'] += 1
            
            # Summary
            logger.info("=" * 60)
            logger.info("Expiry Check Summary:")
            logger.info(f"  Total: {len(certificates)}")
            logger.info(f"  OK: {counters['OK']}")
            logger.info(f"  Warning: {counters['WARNING']}")
            logger.info(f"  Critical: {counters['CRITICAL']}")
            logger.info(f"  Expired: {counters['EXPIRED']}")
            logger.info(f"  Errors: {counters['ERROR']}")
            logger.info("=" * 60)
            
            # Sleep until next check
            logger.info(f"Sleeping for {CHECK_INTERVAL} minutes...")
            time.sleep(CHECK_INTERVAL * 60)


def main():
    if not all([KEYFACTOR_HOST, KEYFACTOR_USERNAME, KEYFACTOR_PASSWORD]):
        logger.error("Missing Keyfactor credentials")
        return 1
    
    logger.info("Starting Certificate Expiry Monitor...")
    logger.info(f"Warning threshold: {WARNING_DAYS} days")
    logger.info(f"Critical threshold: {CRITICAL_DAYS} days")
    logger.info(f"Check interval: {CHECK_INTERVAL} minutes")
    
    monitor = CertificateMonitor(
        hostname=KEYFACTOR_HOST,
        username=KEYFACTOR_USERNAME,
        password=KEYFACTOR_PASSWORD,
        domain=KEYFACTOR_DOMAIN
    )
    
    try:
        monitor.monitor_loop()
    except KeyboardInterrupt:
        logger.info("Monitor stopped by user")
        return 0
    except Exception as e:
        logger.error(f"Monitor failed: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())

