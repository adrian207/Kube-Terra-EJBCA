#!/usr/bin/env python3
"""
Keyfactor Webhook Receiver
Receives webhook events from Keyfactor Command and routes to appropriate handlers.
"""

from flask import Flask, request, jsonify
import hmac
import hashlib
import json
import logging
from datetime import datetime
import os
import requests

app = Flask(__name__)

# Configuration
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'your-secret-key')
LOG_FILE = '/var/log/keyfactor-webhooks.log'

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def verify_signature(payload, signature):
    """Verify webhook signature to ensure authenticity."""
    expected_signature = hmac.new(
        WEBHOOK_SECRET.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected_signature)

def send_to_servicenow(event_data):
    """Create incident in ServiceNow for certificate events."""
    snow_url = os.environ.get('SERVICENOW_URL')
    snow_user = os.environ.get('SERVICENOW_USER')
    snow_password = os.environ.get('SERVICENOW_PASSWORD')
    
    if not all([snow_url, snow_user, snow_password]):
        logger.warning("ServiceNow credentials not configured")
        return
    
    incident_data = {
        'short_description': f"Certificate Event: {event_data['eventType']}",
        'description': json.dumps(event_data, indent=2),
        'category': 'Security',
        'subcategory': 'Certificate Management',
        'urgency': '3',
        'impact': '3'
    }
    
    try:
        response = requests.post(
            f"{snow_url}/api/now/table/incident",
            auth=(snow_user, snow_password),
            headers={'Content-Type': 'application/json'},
            json=incident_data,
            timeout=10
        )
        response.raise_for_status()
        logger.info(f"ServiceNow incident created: {response.json()['result']['number']}")
    except Exception as e:
        logger.error(f"Failed to create ServiceNow incident: {e}")

def send_to_slack(event_data):
    """Send notification to Slack."""
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    
    if not slack_webhook_url:
        logger.warning("Slack webhook URL not configured")
        return
    
    event_type = event_data.get('eventType', 'Unknown')
    cert_subject = event_data.get('certificate', {}).get('subject', 'Unknown')
    
    # Color coding based on event type
    color_map = {
        'CertificateExpiring': 'warning',
        'CertificateExpired': 'danger',
        'CertificateRenewed': 'good',
        'CertificateRevoked': 'danger',
        'CertificateIssued': 'good'
    }
    
    slack_message = {
        'attachments': [{
            'color': color_map.get(event_type, 'good'),
            'title': f"Certificate Event: {event_type}",
            'fields': [
                {'title': 'Subject', 'value': cert_subject, 'short': True},
                {'title': 'Event', 'value': event_type, 'short': True},
                {'title': 'Time', 'value': datetime.utcnow().isoformat(), 'short': True}
            ],
            'footer': 'Keyfactor Certificate Management'
        }]
    }
    
    try:
        response = requests.post(
            slack_webhook_url,
            json=slack_message,
            timeout=10
        )
        response.raise_for_status()
        logger.info("Slack notification sent")
    except Exception as e:
        logger.error(f"Failed to send Slack notification: {e}")

def handle_certificate_expiring(event_data):
    """Handle certificate expiring event."""
    cert = event_data.get('certificate', {})
    days_until_expiry = event_data.get('daysUntilExpiry', 0)
    
    logger.info(f"Certificate expiring in {days_until_expiry} days: {cert.get('subject')}")
    
    # Send notifications
    send_to_slack(event_data)
    
    # If < 7 days, create incident
    if days_until_expiry < 7:
        send_to_servicenow(event_data)

def handle_certificate_expired(event_data):
    """Handle certificate expired event."""
    cert = event_data.get('certificate', {})
    
    logger.error(f"Certificate EXPIRED: {cert.get('subject')}")
    
    # Critical notification
    send_to_slack(event_data)
    send_to_servicenow(event_data)

def handle_certificate_renewed(event_data):
    """Handle certificate renewed event."""
    cert = event_data.get('certificate', {})
    
    logger.info(f"Certificate renewed: {cert.get('subject')}")
    send_to_slack(event_data)

def handle_certificate_revoked(event_data):
    """Handle certificate revoked event."""
    cert = event_data.get('certificate', {})
    reason = event_data.get('revocationReason', 'Unknown')
    
    logger.warning(f"Certificate revoked: {cert.get('subject')} - Reason: {reason}")
    
    send_to_slack(event_data)
    send_to_servicenow(event_data)

def handle_certificate_issued(event_data):
    """Handle certificate issued event."""
    cert = event_data.get('certificate', {})
    
    logger.info(f"Certificate issued: {cert.get('subject')}")

# Event handler mapping
EVENT_HANDLERS = {
    'CertificateExpiring': handle_certificate_expiring,
    'CertificateExpired': handle_certificate_expired,
    'CertificateRenewed': handle_certificate_renewed,
    'CertificateRevoked': handle_certificate_revoked,
    'CertificateIssued': handle_certificate_issued
}

@app.route('/webhook', methods=['POST'])
def webhook():
    """Main webhook endpoint."""
    try:
        # Get signature from header
        signature = request.headers.get('X-Keyfactor-Signature')
        if not signature:
            logger.warning("Missing signature header")
            return jsonify({'error': 'Missing signature'}), 401
        
        # Get payload
        payload = request.get_data(as_text=True)
        
        # Verify signature
        if not verify_signature(payload, signature):
            logger.warning("Invalid signature")
            return jsonify({'error': 'Invalid signature'}), 401
        
        # Parse event data
        event_data = json.loads(payload)
        event_type = event_data.get('eventType')
        
        logger.info(f"Received webhook: {event_type}")
        
        # Route to appropriate handler
        handler = EVENT_HANDLERS.get(event_type)
        if handler:
            handler(event_data)
        else:
            logger.warning(f"No handler for event type: {event_type}")
        
        return jsonify({'status': 'success'}), 200
    
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON: {e}")
        return jsonify({'error': 'Invalid JSON'}), 400
    
    except Exception as e:
        logger.error(f"Webhook processing error: {e}", exc_info=True)
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}), 200

if __name__ == '__main__':
    # Run on port 5000, bind to all interfaces
    app.run(host='0.0.0.0', port=5000, debug=False)

