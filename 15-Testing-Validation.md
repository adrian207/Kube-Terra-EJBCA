# Keyfactor Testing & Validation
## Test Plans and Acceptance Criteria

**Author**: Adrian Johnson <adrian207@gmail.com>  
**Version**: 1.0  
**Date**: October 22, 2025  
**Classification**: Internal Use  
**Target Audience**: QA engineers, implementation team, project managers

---

## Document Purpose

This document provides comprehensive testing and validation procedures for the Keyfactor PKI platform implementation. It includes test plans, acceptance criteria, unit tests, integration tests, performance tests, and user acceptance testing procedures.

---

## Table of Contents

1. [Testing Strategy](#1-testing-strategy)
2. [Unit Testing](#2-unit-testing)
3. [Integration Testing](#3-integration-testing)
4. [System Testing](#4-system-testing)
5. [Performance Testing](#5-performance-testing)
6. [Security Testing](#6-security-testing)
7. [User Acceptance Testing](#7-user-acceptance-testing)
8. [Test Automation](#8-test-automation)
9. [Acceptance Criteria](#9-acceptance-criteria)
10. [Test Environments](#10-test-environments)

---

## 1. Testing Strategy

### 1.1 Test Pyramid

```
        ┌──────────────┐
        │   Manual     │  10% - Exploratory, usability
        │   Testing    │
        ├──────────────┤
        │     UAT      │  15% - User acceptance, scenarios
        ├──────────────┤
        │  Integration │  35% - API, service integration
        │   Testing    │
        ├──────────────┤
        │     Unit     │  40% - Component, function testing
        │   Testing    │
        └──────────────┘
```

### 1.2 Testing Phases

| Phase | Duration | Focus | Exit Criteria |
|-------|----------|-------|---------------|
| **Unit Testing** | Continuous | Individual components | 80% code coverage |
| **Integration Testing** | 2 weeks | Component integration | All critical paths tested |
| **System Testing** | 2 weeks | End-to-end scenarios | All test cases passed |
| **Performance Testing** | 1 week | Load, stress, scalability | Meets SLAs |
| **Security Testing** | 1 week | Vulnerabilities, compliance | No critical findings |
| **UAT** | 2 weeks | Business scenarios | User sign-off |

### 1.3 Test Levels

**L0 - Smoke Tests**: Basic functionality, deployment validation  
**L1 - Unit Tests**: Individual functions, classes  
**L2 - Integration Tests**: API integration, database, external services  
**L3 - System Tests**: End-to-end workflows  
**L4 - Acceptance Tests**: Business scenarios

---

## 2. Unit Testing

### 2.1 Unit Test Coverage

**Target Coverage**: 80% for critical components

| Component | Coverage Target | Priority |
|-----------|----------------|----------|
| Authorization logic | 90% | Critical |
| Certificate validation | 90% | Critical |
| API controllers | 80% | High |
| Orchestrator jobs | 80% | High |
| Utility functions | 70% | Medium |
| UI components | 60% | Medium |

### 2.2 Sample Unit Tests

#### Test 1: RBAC Authorization

**Test Case**: User authorization for certificate request

```python
import pytest
from keyfactor.authorization import AuthorizationEngine
from keyfactor.models import User, CertificateRequest

class TestRBACAuthorization:
    def setup_method(self):
        self.auth_engine = AuthorizationEngine()
        self.user = User(
            email="test@contoso.com",
            roles=["CertificateManager"],
            allowed_templates=["WebServer"],
            owned_domains=["*.contoso.com"]
        )
    
    def test_authorized_request_valid_template(self):
        """User should be authorized for allowed template"""
        request = CertificateRequest(
            template="WebServer",
            subject="CN=webapp01.contoso.com",
            sans=["webapp01.contoso.com"]
        )
        
        result = self.auth_engine.authorize(self.user, request)
        
        assert result.authorized == True
        assert result.reason == "Authorized"
    
    def test_unauthorized_request_invalid_template(self):
        """User should NOT be authorized for disallowed template"""
        request = CertificateRequest(
            template="CodeSigning",  # Not in allowed_templates
            subject="CN=app.exe",
            sans=[]
        )
        
        result = self.auth_engine.authorize(self.user, request)
        
        assert result.authorized == False
        assert "template" in result.reason.lower()
    
    def test_unauthorized_request_invalid_domain(self):
        """User should NOT be authorized for unowned domain"""
        request = CertificateRequest(
            template="WebServer",
            subject="CN=external.example.com",
            sans=["external.example.com"]  # Not in owned_domains
        )
        
        result = self.auth_engine.authorize(self.user, request)
        
        assert result.authorized == False
        assert "domain" in result.reason.lower()
    
    def test_edge_case_wildcard_domain(self):
        """Wildcard domain ownership should match subdomains"""
        request = CertificateRequest(
            template="WebServer",
            subject="CN=sub.contoso.com",
            sans=["sub.contoso.com"]
        )
        
        result = self.auth_engine.authorize(self.user, request)
        
        assert result.authorized == True
```

#### Test 2: Certificate Validation

```csharp
using Xunit;
using Keyfactor.Validation;
using System.Security.Cryptography.X509Certificates;

public class CertificateValidatorTests
{
    private readonly CertificateValidator _validator;
    
    public CertificateValidatorTests()
    {
        _validator = new CertificateValidator();
    }
    
    [Fact]
    public void ValidateCertificate_ValidRSA2048_ShouldPass()
    {
        // Arrange
        var cert = LoadTestCertificate("valid-rsa-2048.cer");
        
        // Act
        var result = _validator.Validate(cert);
        
        // Assert
        Assert.True(result.IsValid);
        Assert.Empty(result.Errors);
    }
    
    [Fact]
    public void ValidateCertificate_WeakKeyRSA1024_ShouldFail()
    {
        // Arrange
        var cert = LoadTestCertificate("weak-rsa-1024.cer");
        
        // Act
        var result = _validator.Validate(cert);
        
        // Assert
        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.Contains("key size"));
    }
    
    [Fact]
    public void ValidateCertificate_ExpiredCertificate_ShouldFail()
    {
        // Arrange
        var cert = LoadTestCertificate("expired.cer");
        
        // Act
        var result = _validator.Validate(cert);
        
        // Assert
        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, e => e.Contains("expired"));
    }
    
    [Theory]
    [InlineData("SHA-256", true)]
    [InlineData("SHA-384", true)]
    [InlineData("SHA-512", true)]
    [InlineData("SHA-1", false)]  // Weak hash
    public void ValidateCertificate_HashAlgorithm_ShouldValidateCorrectly(
        string hashAlgorithm, bool expectedValid)
    {
        // Arrange
        var cert = CreateTestCertificate(hashAlgorithm);
        
        // Act
        var result = _validator.Validate(cert);
        
        // Assert
        Assert.Equal(expectedValid, result.IsValid);
    }
}
```

#### Test 3: API Controller

```javascript
// Jest test for Keyfactor API
const request = require('supertest');
const app = require('../app');
const { generateToken } = require('../auth');

describe('Certificate API', () => {
  let authToken;
  
  beforeAll(() => {
    authToken = generateToken({ 
      email: 'test@contoso.com', 
      roles: ['CertificateManager'] 
    });
  });
  
  describe('POST /api/certificates', () => {
    it('should create certificate with valid request', async () => {
      const response = await request(app)
        .post('/api/certificates')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          template: 'WebServer',
          subject: 'CN=test.contoso.com',
          sans: ['test.contoso.com'],
          keySize: 2048
        });
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('certificateId');
      expect(response.body).toHaveProperty('thumbprint');
    });
    
    it('should reject unauthorized user', async () => {
      const response = await request(app)
        .post('/api/certificates')
        .send({
          template: 'WebServer',
          subject: 'CN=test.contoso.com'
        });
      
      expect(response.status).toBe(401);
    });
    
    it('should reject invalid template', async () => {
      const response = await request(app)
        .post('/api/certificates')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          template: 'InvalidTemplate',
          subject: 'CN=test.contoso.com'
        });
      
      expect(response.status).toBe(400);
      expect(response.body.error).toContain('template');
    });
  });
  
  describe('GET /api/certificates/:id', () => {
    it('should return certificate details', async () => {
      const response = await request(app)
        .get('/api/certificates/12345')
        .set('Authorization', `Bearer ${authToken}`);
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('subject');
      expect(response.body).toHaveProperty('notAfter');
    });
    
    it('should return 404 for non-existent certificate', async () => {
      const response = await request(app)
        .get('/api/certificates/99999')
        .set('Authorization', `Bearer ${authToken}`);
      
      expect(response.status).toBe(404);
    });
  });
});
```

### 2.3 Unit Test Execution

```bash
# Python (pytest)
pytest tests/unit/ --cov=keyfactor --cov-report=html --cov-report=term

# .NET (xUnit)
dotnet test Keyfactor.Tests.Unit --collect:"XPlat Code Coverage"

# JavaScript (Jest)
npm test -- --coverage --coverageDirectory=coverage
```

---

## 3. Integration Testing

### 3.1 Integration Test Scenarios

| Test ID | Scenario | Components | Expected Result |
|---------|----------|------------|----------------|
| **IT-001** | Certificate enrollment via API | Keyfactor API → CA | Certificate issued |
| **IT-002** | Orchestrator inventory sync | Orchestrator → Azure Key Vault | Certs discovered |
| **IT-003** | ACME protocol enrollment | ACME client → Keyfactor → CA | Auto-enrollment |
| **IT-004** | Certificate renewal automation | Renewal job → API → CA | Renewed cert deployed |
| **IT-005** | Webhook notification | Cert event → Webhook → ServiceNow | Incident created |

### 3.2 Sample Integration Tests

#### Test IT-001: End-to-End Certificate Enrollment

```python
import requests
import pytest
from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import default_backend

class TestCertificateEnrollment:
    @pytest.fixture
    def keyfactor_client(self):
        return {
            'base_url': 'https://keyfactor-test.contoso.com/KeyfactorAPI',
            'username': 'test@contoso.com',
            'password': 'test-password'
        }
    
    def test_complete_enrollment_flow(self, keyfactor_client):
        """Test complete certificate enrollment workflow"""
        
        # Step 1: Authenticate
        auth_response = requests.post(
            f"{keyfactor_client['base_url']}/Auth/Login",
            json={
                'username': keyfactor_client['username'],
                'password': keyfactor_client['password']
            }
        )
        assert auth_response.status_code == 200
        token = auth_response.json()['access_token']
        headers = {'Authorization': f'Bearer {token}'}
        
        # Step 2: Generate CSR
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
            backend=default_backend()
        )
        
        csr = x509.CertificateSigningRequestBuilder().subject_name(
            x509.Name([
                x509.NameAttribute(NameOID.COMMON_NAME, "test.contoso.com"),
            ])
        ).add_extension(
            x509.SubjectAlternativeName([
                x509.DNSName("test.contoso.com"),
            ]),
            critical=False,
        ).sign(private_key, hashes.SHA256(), default_backend())
        
        csr_pem = csr.public_bytes(encoding=serialization.Encoding.PEM)
        
        # Step 3: Submit enrollment request
        enroll_response = requests.post(
            f"{keyfactor_client['base_url']}/Certificates/Enroll",
            headers=headers,
            json={
                'CSR': csr_pem.decode('utf-8'),
                'Template': 'WebServer-Test',
                'CertificateAuthority': 'Test-CA',
                'Metadata': {
                    'Environment': 'Test',
                    'Owner': 'test@contoso.com'
                }
            }
        )
        
        assert enroll_response.status_code == 201
        cert_data = enroll_response.json()
        
        # Step 4: Verify certificate was issued
        assert 'CertificateId' in cert_data
        assert 'Thumbprint' in cert_data
        assert 'Certificates' in cert_data
        
        cert_id = cert_data['CertificateId']
        
        # Step 5: Retrieve certificate details
        get_response = requests.get(
            f"{keyfactor_client['base_url']}/Certificates/{cert_id}",
            headers=headers
        )
        
        assert get_response.status_code == 200
        cert_details = get_response.json()
        
        # Step 6: Validate certificate properties
        assert cert_details['Subject'] == 'CN=test.contoso.com'
        assert 'test.contoso.com' in cert_details['SANs']
        assert cert_details['Status'] == 'Active'
        
        # Cleanup: Revoke test certificate
        revoke_response = requests.delete(
            f"{keyfactor_client['base_url']}/Certificates/{cert_id}/Revoke",
            headers=headers,
            json={'RevocationReason': 5, 'Comment': 'Test cleanup'}
        )
        assert revoke_response.status_code == 200
```

#### Test IT-002: Orchestrator Integration

```powershell
Describe "Orchestrator Azure Key Vault Integration" {
    BeforeAll {
        # Setup: Create test certificate in Keyfactor
        $testCert = New-TestCertificate -Subject "CN=orch-test.contoso.com"
    }
    
    It "Should discover certificates in Azure Key Vault" {
        # Trigger inventory job
        $jobId = Start-OrchestratorJob -Type "Inventory" -Store "test-azure-kv"
        
        # Wait for completion (max 5 minutes)
        $job = Wait-OrchestratorJob -JobId $jobId -TimeoutSeconds 300
        
        # Verify job completed successfully
        $job.Status | Should -Be "Completed"
        $job.ErrorCount | Should -Be 0
        
        # Verify certificates were discovered
        $certs = Get-DiscoveredCertificates -JobId $jobId
        $certs.Count | Should -BeGreaterThan 0
    }
    
    It "Should deploy certificate to Azure Key Vault" {
        # Trigger management (deployment) job
        $jobId = Start-OrchestratorJob `
            -Type "Management" `
            -Operation "Add" `
            -Store "test-azure-kv" `
            -CertificateId $testCert.Id
        
        # Wait for completion
        $job = Wait-OrchestratorJob -JobId $jobId -TimeoutSeconds 300
        
        # Verify deployment succeeded
        $job.Status | Should -Be "Completed"
        $job.ErrorCount | Should -Be 0
        
        # Verify certificate exists in Azure Key Vault
        $akvCert = Get-AzKeyVaultCertificate `
            -VaultName "test-vault" `
            -Name "orch-test-contoso-com"
        
        $akvCert | Should -Not -BeNullOrEmpty
        $akvCert.Thumbprint | Should -Be $testCert.Thumbprint
    }
    
    AfterAll {
        # Cleanup
        Remove-TestCertificate -CertificateId $testCert.Id
    }
}
```

### 3.3 Integration Test Execution

```bash
# Run all integration tests
pytest tests/integration/ --tb=short

# Run specific integration suite
pytest tests/integration/test_api_integration.py -v

# Run with test report
pytest tests/integration/ --html=report.html --self-contained-html
```

---

## 4. System Testing

### 4.1 End-to-End Test Scenarios

**Scenario ST-001: Complete Certificate Lifecycle**

```gherkin
Feature: Certificate Lifecycle Management
  As a certificate manager
  I want to manage the complete certificate lifecycle
  So that I can ensure secure TLS communication

  Scenario: Request, deploy, renew, and revoke certificate
    Given I am logged in as a certificate manager
    And I have access to the "WebServer" template
    
    When I request a new certificate for "webapp01.contoso.com"
    Then the certificate should be issued within 5 minutes
    And the certificate should be deployed to the configured stores
    And the certificate status should be "Active"
    
    When the certificate is 30 days from expiration
    Then an automatic renewal should be triggered
    And the renewed certificate should be deployed
    And the old certificate should be marked for revocation
    
    When I manually revoke the certificate
    Then the certificate status should change to "Revoked"
    And the certificate should appear in the CRL within 1 hour
    And the certificate should be removed from all stores
```

### 4.2 System Test Cases

| Test ID | Scenario | Steps | Expected Result | Priority |
|---------|----------|-------|----------------|----------|
| **ST-001** | Certificate request workflow | 1. Login<br>2. Submit CSR<br>3. Approve (if needed)<br>4. Verify issuance | Certificate issued and available | P1 |
| **ST-002** | ACME auto-enrollment | 1. Configure ACME client<br>2. Request cert<br>3. Complete challenge<br>4. Receive cert | Certificate auto-issued via ACME | P1 |
| **ST-003** | Auto-renewal workflow | 1. Certificate near expiry<br>2. Renewal job triggers<br>3. New cert issued<br>4. Deployment | Certificate renewed automatically | P1 |
| **ST-004** | Emergency revocation | 1. Report key compromise<br>2. Emergency revoke<br>3. CRL update<br>4. Store removal | Cert revoked within 15 minutes | P1 |
| **ST-005** | Bulk certificate import | 1. Prepare CSV with 100 certs<br>2. Bulk import<br>3. Validation<br>4. Deployment | All certificates imported correctly | P2 |

### 4.3 System Test Execution

**Test Execution Plan**:
1. Deploy test environment (identical to production)
2. Load test data (users, templates, stores)
3. Execute test cases in priority order
4. Log all failures and deviations
5. Generate test report

**Test Report Template**:
```markdown
# System Test Report

**Test Cycle**: ST-2025-Q4
**Environment**: Test
**Test Period**: 2025-10-15 to 2025-10-29
**Tester**: QA Team

## Summary
- Total Test Cases: 50
- Passed: 48 (96%)
- Failed: 2 (4%)
- Blocked: 0

## Failed Test Cases

| Test ID | Scenario | Failure Reason | Severity | Status |
|---------|----------|----------------|----------|--------|
| ST-012 | Cert renewal with manual approval | Approval notification not sent | Medium | Bug filed: BUG-123 |
| ST-033 | F5 BIG-IP deployment | Connection timeout to F5 | Low | Environment issue, retested successfully |

## Recommendations
1. Fix approval notification bug (BUG-123) before production
2. Increase F5 API timeout from 30s to 60s
3. All P1 test cases passed - ready for UAT
```

---

## 5. Performance Testing

### 5.1 Performance Test Scenarios

| Test ID | Scenario | Load | Duration | Success Criteria |
|---------|----------|------|----------|------------------|
| **PT-001** | Baseline load | 10 req/min | 1 hour | < 2s avg response time |
| **PT-002** | Normal load | 50 req/min | 4 hours | < 3s avg response time |
| **PT-003** | Peak load | 200 req/min | 1 hour | < 5s P95 response time |
| **PT-004** | Stress test | 500 req/min | 30 min | No errors, graceful degradation |
| **PT-005** | Soak test | 50 req/min | 24 hours | No memory leaks, stable performance |

### 5.2 Performance Test Scripts

**JMeter Test Plan** (Certificate Enrollment):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan testname="Keyfactor Certificate Enrollment Load Test">
      <stringProp name="TestPlan.comments">Certificate enrollment performance test</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup testname="Certificate Requests">
        <intProp name="ThreadGroup.num_threads">50</intProp>
        <intProp name="ThreadGroup.ramp_time">60</intProp>
        <longProp name="ThreadGroup.duration">3600</longProp>
        <stringProp name="ThreadGroup.delay">0</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy testname="POST /Certificates/Enroll">
          <stringProp name="HTTPSampler.domain">keyfactor-test.contoso.com</stringProp>
          <stringProp name="HTTPSampler.port">443</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.path">/KeyfactorAPI/Certificates/Enroll</stringProp>
          <stringProp name="HTTPSampler.method">POST</stringProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
        </HTTPSamplerProxy>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
```

**Locust Test** (Python):
```python
from locust import HttpUser, task, between
import random

class CertificateUser(HttpUser):
    wait_time = between(5, 15)
    
    def on_start(self):
        """Login and get token"""
        response = self.client.post("/KeyfactorAPI/Auth/Login", json={
            "username": "loadtest@contoso.com",
            "password": "test-password"
        })
        self.token = response.json()["access_token"]
        self.headers = {"Authorization": f"Bearer {self.token}"}
    
    @task(3)
    def search_certificates(self):
        """Search for certificates (common operation)"""
        self.client.get(
            "/KeyfactorAPI/Certificates",
            params={"pq.returnLimit": 50},
            headers=self.headers
        )
    
    @task(1)
    def enroll_certificate(self):
        """Enroll new certificate (less frequent)"""
        csr = self.generate_csr()  # Mock CSR generation
        self.client.post(
            "/KeyfactorAPI/Certificates/Enroll",
            json={
                "CSR": csr,
                "Template": "WebServer-Test",
                "CertificateAuthority": "Test-CA"
            },
            headers=self.headers
        )
    
    @task(2)
    def get_certificate_details(self):
        """Get certificate by ID"""
        cert_id = random.randint(1, 10000)
        self.client.get(
            f"/KeyfactorAPI/Certificates/{cert_id}",
            headers=self.headers
        )
```

### 5.3 Performance Test Execution

```bash
# Run Locust test
locust -f tests/performance/locustfile.py --host=https://keyfactor-test.contoso.com --users 100 --spawn-rate 10 --run-time 1h

# Run JMeter test
jmeter -n -t tests/performance/certificate-load-test.jmx -l results/test-results.jtl -e -o results/html-report

# Analyze results
python scripts/analyze-performance.py results/test-results.jtl
```

### 5.4 Performance Acceptance Criteria

| Metric | Target | Acceptable | Unacceptable |
|--------|--------|------------|--------------|
| API Response Time (P50) | < 500ms | < 1s | > 2s |
| API Response Time (P95) | < 2s | < 3s | > 5s |
| API Response Time (P99) | < 5s | < 10s | > 15s |
| Throughput (cert/hour) | > 500 | > 200 | < 100 |
| Error Rate | < 0.1% | < 1% | > 2% |
| Database Query Time (avg) | < 50ms | < 100ms | > 500ms |
| Orchestrator Job Time | < 5 min | < 10 min | > 30 min |

---

## 6. Security Testing

### 6.1 Security Test Scenarios

| Test ID | Category | Test | Expected Result |
|---------|----------|------|----------------|
| **SEC-001** | Authentication | Brute force attempt | Account locked after 5 failures |
| **SEC-002** | Authorization | Access without token | 401 Unauthorized |
| **SEC-003** | Authorization | Access with invalid role | 403 Forbidden |
| **SEC-004** | Input Validation | SQL injection attempt | Request rejected, logged |
| **SEC-005** | Input Validation | XSS payload | Sanitized, no execution |
| **SEC-006** | Encryption | TLS version check | Only TLS 1.2/1.3 accepted |
| **SEC-007** | Encryption | Weak cipher suite | Rejected, strong ciphers only |
| **SEC-008** | Session Management | Session timeout | Session expires after 30 min |
| **SEC-009** | API Security | Rate limiting | 429 after 100 requests/min |
| **SEC-010** | Data Protection | Sensitive data in logs | No passwords/keys in logs |

### 6.2 Vulnerability Scanning

**Tools**:
- OWASP ZAP for web application scanning
- Nessus for infrastructure scanning
- Qualys SSL Labs for TLS configuration
- SonarQube for code quality and security

**Scan Schedule**:
```bash
# Weekly automated security scan
./scripts/security-scan.sh

# Scan includes:
# 1. OWASP ZAP baseline scan
zap-baseline.py -t https://keyfactor-test.contoso.com -r zap-report.html

# 2. Nessus vulnerability scan (via API)
python scripts/run-nessus-scan.py --target keyfactor-test.contoso.com

# 3. SSL/TLS configuration test
python scripts/test-tls-config.py --host keyfactor-test.contoso.com

# 4. Code security scan
sonar-scanner -Dsonar.projectKey=keyfactor-pki -Dsonar.sources=src
```

### 6.3 Penetration Testing

**Scope**: Annual penetration test by external firm

**Test Areas**:
1. Authentication and session management
2. Authorization and access control
3. API security
4. Certificate issuance and validation
5. HSM integration security
6. Network segmentation
7. Data protection

**Remediation SLA**:
- Critical: 7 days
- High: 30 days
- Medium: 90 days
- Low: Next release

---

## 7. User Acceptance Testing (UAT)

### 7.1 UAT Scenarios

**UAT-001: Self-Service Certificate Request**

```markdown
**Scenario**: Service owner requests certificate via self-service portal

**Test Steps**:
1. Login to Keyfactor portal as service owner
2. Navigate to "Request Certificate"
3. Select "WebServer" template
4. Enter hostname: webapp01.contoso.com
5. Add SAN: www.contoso.com
6. Add metadata (owner, application name)
7. Submit request

**Expected Results**:
- Request submitted successfully
- Request ID provided
- Email confirmation received
- Certificate issued within 15 minutes
- Download link available in portal
- Certificate valid for 1 year
- Both SANs present in certificate

**Actual Results**: [To be filled by tester]

**Status**: ☐ Pass  ☐ Fail  ☐ Blocked

**Comments**: _________________________________
```

**UAT-002: Certificate Renewal**

**UAT-003: Certificate Revocation**

**UAT-004: Kubernetes Auto-Enrollment**

**UAT-005: Certificate Search and Reporting**

### 7.2 UAT Execution Plan

**Week 1**: Training and environment setup  
**Week 2**: Test execution (scenarios UAT-001 to UAT-010)  
**Week 3**: Issue resolution and retesting  
**Week 4**: Final sign-off

**UAT Sign-Off Criteria**:
- All P1 scenarios passed
- No critical defects
- User documentation reviewed and approved
- Training completed
- Go-live checklist completed

**UAT Sign-Off Form**:
```markdown
# User Acceptance Testing Sign-Off

**Project**: Keyfactor PKI Implementation
**UAT Period**: 2025-11-01 to 2025-11-30
**Environment**: Pre-Production

## Test Summary

| Scenario | Result | Comments |
|----------|--------|----------|
| UAT-001: Self-Service Request | Pass | |
| UAT-002: Certificate Renewal | Pass | |
| UAT-003: Certificate Revocation | Pass | Minor UI improvement suggested |
| ... | | |

## Defects Summary

| Severity | Open | Closed | Total |
|----------|------|--------|-------|
| Critical | 0 | 2 | 2 |
| High | 1 | 5 | 6 |
| Medium | 3 | 8 | 11 |
| Low | 5 | 10 | 15 |

## Outstanding Issues

1. [HIGH] Issue #127: F5 deployment occasionally times out
   - Workaround: Retry deployment
   - Target fix: Before go-live

## Recommendation

☑ Approve for production deployment
☐ Conditional approval (issues must be fixed)
☐ Do not approve

**Business Owner**: _________________ Date: _______
**IT Manager**: _________________ Date: _______
**CISO**: _________________ Date: _______
```

---

## 8. Test Automation

### 8.1 CI/CD Pipeline Integration

```yaml
# Azure DevOps Pipeline
name: Keyfactor-CI-CD

trigger:
  branches:
    include:
      - main
      - develop

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        steps:
          - task: DotNetCoreCLI@2
            displayName: 'Build Solution'
            inputs:
              command: 'build'
              projects: '**/*.csproj'
          
          - task: DotNetCoreCLI@2
            displayName: 'Run Unit Tests'
            inputs:
              command: 'test'
              projects: '**/*Tests.Unit.csproj'
              arguments: '--collect:"XPlat Code Coverage"'
          
          - task: PublishCodeCoverageResults@1
            displayName: 'Publish Code Coverage'
            inputs:
              codeCoverageTool: 'Cobertura'
              summaryFileLocation: '$(Agent.TempDirectory)/**/coverage.cobertura.xml'

  - stage: IntegrationTest
    dependsOn: Build
    jobs:
      - job: IntegrationTests
        steps:
          - task: Docker@2
            displayName: 'Start Test Dependencies'
            inputs:
              command: 'run'
              arguments: 'docker-compose -f docker-compose.test.yml up -d'
          
          - task: DotNetCoreCLI@2
            displayName: 'Run Integration Tests'
            inputs:
              command: 'test'
              projects: '**/*Tests.Integration.csproj'
          
          - task: Docker@2
            displayName: 'Stop Test Dependencies'
            inputs:
              command: 'run'
              arguments: 'docker-compose -f docker-compose.test.yml down'

  - stage: SecurityScan
    dependsOn: IntegrationTest
    jobs:
      - job: SecurityScanning
        steps:
          - task: OwaspZap@1
            displayName: 'OWASP ZAP Scan'
            inputs:
              scanType: 'baseline'
              targetUrl: '$(TestEnvironmentUrl)'
          
          - task: SonarQubePrepare@5
            displayName: 'Prepare SonarQube'
          
          - task: SonarQubeAnalyze@5
            displayName: 'Run SonarQube Analysis'

  - stage: Deploy
    dependsOn: SecurityScan
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployToTest
        environment: 'Test'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureRmWebAppDeployment@4
                  displayName: 'Deploy to Test Environment'
```

### 8.2 Automated Test Execution

**Daily Regression Suite**:
```bash
#!/bin/bash
# Daily automated test execution

echo "Starting daily regression tests..."

# 1. Unit tests
echo "Running unit tests..."
pytest tests/unit/ --junitxml=results/unit-tests.xml

# 2. Integration tests (subset)
echo "Running smoke integration tests..."
pytest tests/integration/ -m smoke --junitxml=results/integration-smoke.xml

# 3. API tests
echo "Running API tests..."
newman run tests/postman/keyfactor-api-tests.json --reporters cli,junit --reporter-junit-export results/api-tests.xml

# 4. Security checks
echo "Running security checks..."
bandit -r src/ -f json -o results/security-scan.json

# 5. Generate report
echo "Generating test report..."
python scripts/generate-test-report.py

echo "Test execution complete. Results in results/"
```

---

## 9. Acceptance Criteria

### 9.1 Functional Acceptance Criteria

| Requirement | Acceptance Criteria | Test Method |
|-------------|-------------------|-------------|
| **Certificate Issuance** | 95% of requests complete within 15 minutes | Performance test |
| **Auto-Renewal** | 99% of eligible certificates renew automatically | System test + production monitoring |
| **RBAC** | 100% of unauthorized requests blocked | Security test |
| **High Availability** | 99.9% uptime | Production monitoring |
| **Disaster Recovery** | RTO < 4 hours, RPO < 1 hour | DR test |
| **API Performance** | P95 response time < 2 seconds | Performance test |

### 9.2 Non-Functional Acceptance Criteria

| Category | Criteria | Measurement |
|----------|----------|-------------|
| **Security** | No critical vulnerabilities | Penetration test |
| **Compliance** | 100% SOC 2 controls implemented | Audit |
| **Usability** | 90% user satisfaction score | UAT survey |
| **Documentation** | 100% features documented | Documentation review |
| **Training** | 100% operators trained | Training completion |

### 9.3 Go-Live Checklist

```markdown
# Production Go-Live Checklist

## Pre-Go-Live (2 weeks before)
☐ All UAT scenarios passed
☐ No critical or high defects open
☐ Performance testing completed and accepted
☐ Security testing completed, all critical issues resolved
☐ DR test completed successfully
☐ Production environment provisioned and configured
☐ All integrations tested in pre-production
☐ Monitoring and alerting configured
☐ Backup procedures tested
☐ Documentation complete and reviewed
☐ Training completed for all operators
☐ Runbooks reviewed and validated
☐ Communication plan prepared
☐ Rollback plan documented and tested

## Go-Live Day
☐ Final backup of existing systems
☐ Deploy to production
☐ Smoke test critical paths
☐ Verify monitoring and alerting
☐ Verify integrations
☐ Communication sent to stakeholders
☐ Support team on standby

## Post-Go-Live (First Week)
☐ Daily health checks
☐ User feedback collection
☐ Issue tracking and resolution
☐ Performance monitoring
☐ Post-implementation review scheduled
```

---

## 10. Test Environments

### 10.1 Environment Configuration

| Environment | Purpose | Data | Users | Availability |
|------------|---------|------|-------|--------------|
| **DEV** | Development and unit testing | Mock/synthetic | Developers | 90% |
| **TEST** | Integration and system testing | Anonymized production | QA team | 95% |
| **UAT** | User acceptance testing | Production-like | Business users | 99% |
| **PERF** | Performance and load testing | Synthetic load | Automated tests | On-demand |
| **PROD** | Production | Live | All users | 99.9% |

### 10.2 Test Data Management

**Test Data Requirements**:
- User accounts (various roles)
- Certificate templates (all types)
- Certificate stores (Azure KV, HashiCorp, F5, etc.)
- Test certificates (valid, expired, revoked)
- Asset inventory data

**Test Data Creation Script**:
```python
# scripts/create-test-data.py
import requests
import json

def create_test_users():
    """Create test users with various roles"""
    users = [
        {"email": "admin@test.com", "role": "PKIAdministrator"},
        {"email": "operator@test.com", "role": "CAOperator"},
        {"email": "manager@test.com", "role": "CertificateManager"},
        {"email": "auditor@test.com", "role": "Auditor"}
    ]
    for user in users:
        # Create user via API
        pass

def create_test_templates():
    """Create certificate templates for testing"""
    templates = ["WebServer-Test", "CodeSigning-Test", "ClientAuth-Test"]
    # Create templates
    pass

def create_test_stores():
    """Create certificate stores for testing"""
    # Create test stores
    pass

if __name__ == "__main__":
    create_test_users()
    create_test_templates()
    create_test_stores()
    print("Test data created successfully")
```

---

## Appendix A: Test Tools

| Tool | Purpose | License | Installation |
|------|---------|---------|--------------|
| **pytest** | Python unit/integration testing | MIT | `pip install pytest pytest-cov` |
| **xUnit** | .NET unit testing | Apache 2.0 | Built into .NET |
| **Jest** | JavaScript testing | MIT | `npm install --save-dev jest` |
| **Postman/Newman** | API testing | Postman EULA | Download from postman.com |
| **JMeter** | Performance testing | Apache 2.0 | Download from jmeter.apache.org |
| **Locust** | Performance testing (Python) | MIT | `pip install locust` |
| **OWASP ZAP** | Security scanning | Apache 2.0 | Download from zaproxy.org |
| **SonarQube** | Code quality | LGPL | Docker or download |

---

## Document Maintenance

**Review Schedule**: Before each major release  
**Owner**: QA Team Lead  
**Last Reviewed**: October 22, 2025  
**Next Review**: Before v2.0 release

**Change Log**:
| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-22 | Adrian Johnson | Initial comprehensive test plan |

---

**For testing questions, contact**: adrian207@gmail.com

**End of Testing & Validation Document**

