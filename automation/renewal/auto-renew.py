#!/usr/bin/env python3
"""
Certificate Auto-Renewal Script
Queries Keyfactor for expiring certificates and automatically renews them.
"""

import requests
import logging
from datetime import datetime, timedelta
import os
import sys
import time
import json

# Configuration
KEYFACTOR_HOST = os.environ.get('KEYFACTOR_HOST', 'https://keyfactor.contoso.com')
KEYFACTOR_USERNAME = os.environ.get('KEYFACTOR_USERNAME')
KEYFACTOR_PASSWORD = os.environ.get('KEYFACTOR_PASSWORD')
KEYFACTOR_DOMAIN = os.environ.get('KEYFACTOR_DOMAIN', 'CONTOSO')

RENEWAL_THRESHOLD_DAYS = int(os.environ.get('RENEWAL_THRESHOLD_DAYS', '30'))
DRY_RUN = os.environ.get('DRY_RUN', 'false').lower() == 'true'

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/keyfactor-renewal.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class KeyfactorClient:
    def __init__(self, hostname, username, password, domain):
        self.hostname = hostname
        self.base_url = f"{hostname}/KeyfactorAPI"
        self.session = requests.Session()
        self.session.auth = (f"{domain}\\{username}", password)
        self.session.headers.update({
            'Content-Type': 'application/json',
            'X-Keyfactor-Requested-With': 'APIClient'
        })
    
    def get_expiring_certificates(self, days):
        """Get certificates expiring within specified days."""
        expiry_date = (datetime.now() + timedelta(days=days)).strftime('%Y-%m-%d')
        
        params = {
            'pq.queryString': f'NotAfter<={expiry_date} AND Metadata.automated=true',
            'pq.pageReturned': 1,
            'pq.returnLimit': 1000
        }
        
        try:
            response = self.session.get(
                f"{self.base_url}/Certificates",
                params=params,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get expiring certificates: {e}")
            return []
    
    def renew_certificate(self, cert_id):
        """Renew a certificate."""
        payload = {
            'CertificateId': cert_id,
            'UseExistingCSR': False
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/Certificates/{cert_id}/Renew",
                json=payload,
                timeout=60
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to renew certificate {cert_id}: {e}")
            return None
    
    def get_certificate_locations(self, cert_id):
        """Get all locations where certificate is deployed."""
        try:
            response = self.session.get(
                f"{self.base_url}/Certificates/{cert_id}/Locations",
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to get certificate locations: {e}")
            return []
    
    def deploy_certificate(self, cert_id, store_id, alias):
        """Deploy certificate to a store."""
        payload = {
            'CertificateId': cert_id,
            'StoreId': store_id,
            'Alias': alias,
            'Overwrite': True
        }
        
        try:
            response = self.session.post(
                f"{self.base_url}/Certificates/{cert_id}/Deploy",
                json=payload,
                timeout=60
            )
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to deploy certificate to store {store_id}: {e}")
            return False

def renew_and_deploy(client, cert):
    """Renew certificate and deploy to all existing locations."""
    cert_id = cert['Id']
    subject = cert['IssuedDN']
    expiry = cert['NotAfter']
    
    logger.info(f"Processing certificate: {subject} (Expires: {expiry})")
    
    if DRY_RUN:
        logger.info(f"[DRY RUN] Would renew certificate {cert_id}")
        return True
    
    # Get existing locations before renewal
    locations = client.get_certificate_locations(cert_id)
    logger.info(f"Certificate deployed to {len(locations)} locations")
    
    # Renew certificate
    logger.info(f"Renewing certificate {cert_id}...")
    renewed_cert = client.renew_certificate(cert_id)
    
    if not renewed_cert:
        logger.error(f"Failed to renew certificate {cert_id}")
        return False
    
    new_cert_id = renewed_cert.get('CertificateId')
    logger.info(f"Certificate renewed successfully. New ID: {new_cert_id}")
    
    # Deploy to all previous locations
    success_count = 0
    for location in locations:
        store_id = location['StoreId']
        alias = location['Alias']
        
        logger.info(f"Deploying to store {store_id} with alias {alias}...")
        if client.deploy_certificate(new_cert_id, store_id, alias):
            success_count += 1
            logger.info(f"Successfully deployed to store {store_id}")
        else:
            logger.error(f"Failed to deploy to store {store_id}")
        
        # Rate limiting
        time.sleep(1)
    
    logger.info(f"Deployment complete: {success_count}/{len(locations)} successful")
    return success_count == len(locations)

def main():
    """Main renewal logic."""
    if not all([KEYFACTOR_USERNAME, KEYFACTOR_PASSWORD]):
        logger.error("Missing Keyfactor credentials")
        sys.exit(1)
    
    logger.info(f"Starting certificate renewal process (Threshold: {RENEWAL_THRESHOLD_DAYS} days)")
    if DRY_RUN:
        logger.info("Running in DRY RUN mode - no changes will be made")
    
    # Initialize client
    client = KeyfactorClient(
        hostname=KEYFACTOR_HOST,
        username=KEYFACTOR_USERNAME,
        password=KEYFACTOR_PASSWORD,
        domain=KEYFACTOR_DOMAIN
    )
    
    # Get expiring certificates
    certificates = client.get_expiring_certificates(RENEWAL_THRESHOLD_DAYS)
    logger.info(f"Found {len(certificates)} certificates expiring in {RENEWAL_THRESHOLD_DAYS} days")
    
    if not certificates:
        logger.info("No certificates require renewal")
        return 0
    
    # Renew each certificate
    success_count = 0
    failed_count = 0
    
    for cert in certificates:
        try:
            if renew_and_deploy(client, cert):
                success_count += 1
            else:
                failed_count += 1
        except Exception as e:
            logger.error(f"Unexpected error processing certificate: {e}", exc_info=True)
            failed_count += 1
        
        # Rate limiting between certificates
        time.sleep(2)
    
    # Summary
    logger.info("=" * 60)
    logger.info(f"Renewal Summary:")
    logger.info(f"  Total certificates: {len(certificates)}")
    logger.info(f"  Successful: {success_count}")
    logger.info(f"  Failed: {failed_count}")
    logger.info("=" * 60)
    
    return 0 if failed_count == 0 else 1

if __name__ == '__main__':
    sys.exit(main())

