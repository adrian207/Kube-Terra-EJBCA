#!/usr/bin/env python3
"""
Certificate Inventory Report Generator
Generates detailed reports of all certificates managed by Keyfactor.
"""

import requests
import pandas as pd
from datetime import datetime, timedelta
import os
import sys
import logging

# Configuration
KEYFACTOR_HOST = os.environ.get('KEYFACTOR_HOST')
KEYFACTOR_USERNAME = os.environ.get('KEYFACTOR_USERNAME')
KEYFACTOR_PASSWORD = os.environ.get('KEYFACTOR_PASSWORD')
KEYFACTOR_DOMAIN = os.environ.get('KEYFACTOR_DOMAIN', 'CONTOSO')

REPORT_OUTPUT_DIR = '/var/reports/keyfactor'

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class KeyfactorReporter:
    def __init__(self, hostname, username, password, domain):
        self.base_url = f"{hostname}/KeyfactorAPI"
        self.session = requests.Session()
        self.session.auth = (f"{domain}\\{username}", password)
        self.session.headers.update({'Content-Type': 'application/json'})
    
    def get_all_certificates(self):
        """Retrieve all certificates."""
        certs = []
        page = 1
        page_size = 1000
        
        while True:
            params = {
                'pq.pageReturned': page,
                'pq.returnLimit': page_size
            }
            
            response = self.session.get(f"{self.base_url}/Certificates", params=params)
            response.raise_for_status()
            
            batch = response.json()
            if not batch:
                break
            
            certs.extend(batch)
            page += 1
            
            logger.info(f"Retrieved {len(certs)} certificates...")
        
        return certs
    
    def generate_inventory_report(self):
        """Generate inventory report."""
        logger.info("Generating inventory report...")
        
        certificates = self.get_all_certificates()
        logger.info(f"Total certificates: {len(certificates)}")
        
        # Convert to DataFrame
        df = pd.DataFrame(certificates)
        
        # Extract key fields
        df['Subject'] = df['IssuedDN']
        df['Expiry'] = pd.to_datetime(df['NotAfter'])
        df['DaysUntilExpiry'] = (df['Expiry'] - datetime.now()).dt.days
        
        # Categorize by expiry
        df['Status'] = pd.cut(
            df['DaysUntilExpiry'],
            bins=[-float('inf'), 0, 7, 30, 90, float('inf')],
            labels=['Expired', 'Critical (< 7 days)', 'Warning (< 30 days)', 'Attention (< 90 days)', 'OK']
        )
        
        # Generate summary
        summary = df['Status'].value_counts().to_dict()
        
        # Save detailed report
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        output_file = f"{REPORT_OUTPUT_DIR}/inventory-{timestamp}.xlsx"
        
        with pd.ExcelWriter(output_file, engine='openpyxl') as writer:
            # Summary sheet
            summary_df = pd.DataFrame.from_dict(summary, orient='index', columns=['Count'])
            summary_df.to_excel(writer, sheet_name='Summary')
            
            # All certificates
            df[['Subject', 'Thumbprint', 'Expiry', 'DaysUntilExpiry', 'Status']].to_excel(
                writer, sheet_name='All Certificates', index=False
            )
            
            # Expiring soon
            expiring = df[df['DaysUntilExpiry'] <= 30].sort_values('DaysUntilExpiry')
            expiring[['Subject', 'Expiry', 'DaysUntilExpiry']].to_excel(
                writer, sheet_name='Expiring Soon', index=False
            )
            
            # By issuer
            issuer_summary = df.groupby('IssuerDN').size().reset_index(name='Count')
            issuer_summary.to_excel(writer, sheet_name='By Issuer', index=False)
        
        logger.info(f"Report saved: {output_file}")
        logger.info(f"Summary: {summary}")
        
        return output_file

def main():
    if not all([KEYFACTOR_HOST, KEYFACTOR_USERNAME, KEYFACTOR_PASSWORD]):
        logger.error("Missing Keyfactor credentials")
        return 1
    
    # Create output directory
    os.makedirs(REPORT_OUTPUT_DIR, exist_ok=True)
    
    reporter = KeyfactorReporter(
        hostname=KEYFACTOR_HOST,
        username=KEYFACTOR_USERNAME,
        password=KEYFACTOR_PASSWORD,
        domain=KEYFACTOR_DOMAIN
    )
    
    report_file = reporter.generate_inventory_report()
    print(f"Report generated: {report_file}")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())

