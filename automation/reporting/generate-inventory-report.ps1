<#
.SYNOPSIS
    Certificate Inventory Report Generator
.DESCRIPTION
    Generates detailed reports of all certificates managed by Keyfactor.
#>

param(
    [string]$OutputPath = "C:\Reports\Keyfactor"
)

# Configuration
$KeyfactorHost = $env:KEYFACTOR_HOST
$KeyfactorUsername = $env:KEYFACTOR_USERNAME
$KeyfactorPassword = $env:KEYFACTOR_PASSWORD | ConvertTo-SecureString -AsPlainText -Force
$KeyfactorDomain = $env:KEYFACTOR_DOMAIN

$LogFile = "C:\Logs\keyfactor-reporting-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Level - $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

# Create API credential
$credential = New-Object System.Management.Automation.PSCredential(
    "$KeyfactorDomain\$KeyfactorUsername",
    $KeyfactorPassword
)

function Get-AllCertificates {
    Write-Log "Retrieving all certificates..."
    
    $allCerts = @()
    $page = 1
    $pageSize = 1000
    
    do {
        $apiUrl = "$KeyfactorHost/KeyfactorAPI/Certificates"
        $params = @{
            'pq.pageReturned' = $page
            'pq.returnLimit' = $pageSize
        }
        
        try {
            $response = Invoke-RestMethod -Uri $apiUrl `
                -Method GET `
                -Credential $credential `
                -Body $params `
                -ContentType "application/json"
            
            if ($response.Count -gt 0) {
                $allCerts += $response
                Write-Log "Retrieved $($allCerts.Count) certificates..."
                $page++
            }
            else {
                break
            }
        }
        catch {
            Write-Log "Failed to get certificates: $_" -Level "ERROR"
            break
        }
    } while ($true)
    
    return $allCerts
}

function New-InventoryReport {
    param($Certificates)
    
    Write-Log "Generating inventory report..."
    
    # Process certificates
    $reportData = $Certificates | ForEach-Object {
        $expiry = [datetime]$_.NotAfter
        $daysUntilExpiry = ($expiry - (Get-Date)).Days
        
        $status = switch ($daysUntilExpiry) {
            { $_ -lt 0 } { "Expired"; break }
            { $_ -le 7 } { "Critical (< 7 days)"; break }
            { $_ -le 30 } { "Warning (< 30 days)"; break }
            { $_ -le 90 } { "Attention (< 90 days)"; break }
            default { "OK" }
        }
        
        [PSCustomObject]@{
            Subject = $_.IssuedDN
            Thumbprint = $_.Thumbprint
            Issuer = $_.IssuerDN
            Expiry = $expiry
            DaysUntilExpiry = $daysUntilExpiry
            Status = $status
            SerialNumber = $_.SerialNumber
        }
    }
    
    # Generate summary
    $summary = $reportData | Group-Object Status | Select-Object Name, Count
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    # Generate Excel report
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $excelFile = "$OutputPath\inventory-$timestamp.xlsx"
    
    # Check if ImportExcel module is available
    if (Get-Module -ListAvailable -Name ImportExcel) {
        Import-Module ImportExcel
        
        # Summary sheet
        $summary | Export-Excel -Path $excelFile -WorksheetName "Summary" -AutoSize -TableName "Summary"
        
        # All certificates sheet
        $reportData | Export-Excel -Path $excelFile -WorksheetName "All Certificates" -AutoSize -TableName "AllCerts"
        
        # Expiring soon sheet
        $expiring = $reportData | Where-Object { $_.DaysUntilExpiry -le 30 } | Sort-Object DaysUntilExpiry
        $expiring | Export-Excel -Path $excelFile -WorksheetName "Expiring Soon" -AutoSize -TableName "ExpiringSoon"
        
        # By issuer sheet
        $byIssuer = $reportData | Group-Object Issuer | Select-Object Name, Count
        $byIssuer | Export-Excel -Path $excelFile -WorksheetName "By Issuer" -AutoSize -TableName "ByIssuer"
        
        Write-Log "Excel report saved: $excelFile"
    }
    else {
        # Fallback to CSV if ImportExcel module is not available
        $csvFile = "$OutputPath\inventory-$timestamp.csv"
        $reportData | Export-Csv -Path $csvFile -NoTypeInformation
        Write-Log "CSV report saved: $csvFile (Install-Module ImportExcel for Excel reports)"
    }
    
    # Display summary
    Write-Log "=" * 60
    Write-Log "Report Summary:"
    foreach ($item in $summary) {
        Write-Log "  $($item.Name): $($item.Count)"
    }
    Write-Log "=" * 60
    
    return $excelFile
}

# Main logic
Write-Log "Starting certificate inventory report generation"

if (-not $KeyfactorHost -or -not $KeyfactorUsername -or -not $KeyfactorPassword) {
    Write-Log "Missing Keyfactor credentials" -Level "ERROR"
    exit 1
}

$certificates = Get-AllCertificates
Write-Log "Total certificates: $($certificates.Count)"

if ($certificates.Count -eq 0) {
    Write-Log "No certificates found" -Level "WARN"
    exit 0
}

$reportFile = New-InventoryReport -Certificates $certificates
Write-Log "Report generated successfully: $reportFile"

exit 0

