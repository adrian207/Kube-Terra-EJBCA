#!/usr/bin/env python3
"""
ServiceNow Integration for Certificate Management
Creates incidents and change requests based on certificate events.
"""

import requests
import logging
import os
import json
from datetime import datetime

# Configuration
SERVICENOW_INSTANCE = os.environ.get('SERVICENOW_INSTANCE')  # e.g., 'yourinstance.service-now.com'
SERVICENOW_USER = os.environ.get('SERVICENOW_USER')
SERVICENOW_PASSWORD = os.environ.get('SERVICENOW_PASSWORD')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ServiceNowClient:
    def __init__(self, instance, username, password):
        self.instance = instance
        self.base_url = f"https://{instance}/api/now"
        self.auth = (username, password)
        self.headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def create_incident(self, short_description, description, urgency='3', impact='3', category='Security'):
        """Create an incident in ServiceNow."""
        url = f"{self.base_url}/table/incident"
        
        payload = {
            'short_description': short_description,
            'description': description,
            'urgency': urgency,
            'impact': impact,
            'category': category,
            'subcategory': 'Certificate Management',
            'assignment_group': 'PKI Team',
            'caller_id': SERVICENOW_USER
        }
        
        try:
            response = requests.post(
                url,
                auth=self.auth,
                headers=self.headers,
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            
            incident = response.json()['result']
            logger.info(f"Incident created: {incident['number']}")
            return incident
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to create incident: {e}")
            return None
    
    def create_change_request(self, short_description, description, risk='moderate', priority='3'):
        """Create a change request in ServiceNow."""
        url = f"{self.base_url}/table/change_request"
        
        payload = {
            'short_description': short_description,
            'description': description,
            'risk': risk,
            'priority': priority,
            'category': 'Security',
            'type': 'Standard',
            'assignment_group': 'PKI Team',
            'requested_by': SERVICENOW_USER
        }
        
        try:
            response = requests.post(
                url,
                auth=self.auth,
                headers=self.headers,
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            
            change = response.json()['result']
            logger.info(f"Change request created: {change['number']}")
            return change
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to create change request: {e}")
            return None
    
    def update_cmdb(self, ci_name, certificate_data):
        """Update CMDB CI with certificate information."""
        url = f"{self.base_url}/table/cmdb_ci_server"
        
        # Search for CI
        params = {'sysparm_query': f'name={ci_name}'}
        
        try:
            response = requests.get(
                url,
                auth=self.auth,
                headers=self.headers,
                params=params,
                timeout=30
            )
            response.raise_for_status()
            
            cis = response.json()['result']
            
            if not cis:
                logger.warning(f"CI not found: {ci_name}")
                return None
            
            ci_sys_id = cis[0]['sys_id']
            
            # Update CI with certificate info
            update_url = f"{url}/{ci_sys_id}"
            update_payload = {
                'u_certificate_thumbprint': certificate_data.get('thumbprint'),
                'u_certificate_expiry': certificate_data.get('expiry'),
                'u_certificate_issuer': certificate_data.get('issuer')
            }
            
            response = requests.patch(
                update_url,
                auth=self.auth,
                headers=self.headers,
                json=update_payload,
                timeout=30
            )
            response.raise_for_status()
            
            logger.info(f"CMDB CI updated: {ci_name}")
            return response.json()['result']
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Failed to update CMDB: {e}")
            return None

def handle_certificate_expiring(cert_data, client):
    """Handle certificate expiring event."""
    subject = cert_data.get('subject')
    days_until_expiry = cert_data.get('daysUntilExpiry')
    
    short_desc = f"Certificate Expiring Soon: {subject}"
    description = f"""
Certificate Details:
- Subject: {subject}
- Days Until Expiry: {days_until_expiry}
- Thumbprint: {cert_data.get('thumbprint')}
- Issuer: {cert_data.get('issuer')}

Action Required:
Please review and renew this certificate before expiry.
    """
    
    # Create incident with high urgency if < 7 days
    urgency = '2' if days_until_expiry < 7 else '3'
    impact = '2' if days_until_expiry < 7 else '3'
    
    client.create_incident(short_desc, description, urgency=urgency, impact=impact)

def handle_certificate_renewal(cert_data, client):
    """Handle certificate renewal event."""
    subject = cert_data.get('subject')
    
    short_desc = f"Certificate Renewal Change Request: {subject}"
    description = f"""
Certificate Renewal Details:
- Subject: {subject}
- Old Thumbprint: {cert_data.get('oldThumbprint')}
- New Thumbprint: {cert_data.get('newThumbprint')}
- New Expiry: {cert_data.get('newExpiry')}

Deployment Plan:
1. Update certificate in all stores
2. Reload services
3. Verify HTTPS endpoints
4. Update CMDB
    """
    
    client.create_change_request(short_desc, description, risk='low', priority='3')
    
    # Update CMDB
    hostname = cert_data.get('hostname')
    if hostname:
        client.update_cmdb(hostname, {
            'thumbprint': cert_data.get('newThumbprint'),
            'expiry': cert_data.get('newExpiry'),
            'issuer': cert_data.get('issuer')
        })

def main():
    """Main function."""
    if not all([SERVICENOW_INSTANCE, SERVICENOW_USER, SERVICENOW_PASSWORD]):
        logger.error("ServiceNow credentials not configured")
        return 1
    
    client = ServiceNowClient(SERVICENOW_INSTANCE, SERVICENOW_USER, SERVICENOW_PASSWORD)
    
    # Example usage
    cert_data = {
        'subject': 'CN=webapp01.contoso.com',
        'thumbprint': 'ABCD1234...',
        'issuer': 'CN=Contoso CA',
        'daysUntilExpiry': 5
    }
    
    handle_certificate_expiring(cert_data, client)
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())

