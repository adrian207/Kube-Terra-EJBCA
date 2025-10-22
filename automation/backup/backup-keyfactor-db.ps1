<#
.SYNOPSIS
    Backup Keyfactor database with retention management
#>

param(
    [int]$RetentionDays = 30
)

# Configuration
$SqlServer = $env:SQL_SERVER
$Database = "keyfactor"
$BackupPath = "C:\Backups\Keyfactor"
$LogFile = "C:\Logs\keyfactor-backup-$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

Write-Log "Starting Keyfactor database backup"

# Create backup directory if not exists
if (-not (Test-Path $BackupPath)) {
    New-Item -Path $BackupPath -ItemType Directory -Force
    Write-Log "Created backup directory: $BackupPath"
}

# Generate backup filename
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "$BackupPath\keyfactor-$timestamp.bak"

Write-Log "Backup file: $backupFile"

# Perform backup
try {
    $query = @"
BACKUP DATABASE [$Database]
TO DISK = '$backupFile'
WITH COMPRESSION, CHECKSUM, STATS = 10;
"@
    
    Invoke-Sqlcmd -ServerInstance $SqlServer -Query $query -QueryTimeout 0
    
    Write-Log "Database backup completed successfully"
    
    # Verify backup
    $verifyQuery = "RESTORE VERIFYONLY FROM DISK = '$backupFile'"
    Invoke-Sqlcmd -ServerInstance $SqlServer -Query $verifyQuery
    
    Write-Log "Backup verification successful"
    
    # Get backup size
    $size = (Get-Item $backupFile).Length / 1MB
    Write-Log "Backup size: $([math]::Round($size, 2)) MB"
    
} catch {
    Write-Log "ERROR: Backup failed - $_"
    exit 1
}

# Cleanup old backups
Write-Log "Cleaning up backups older than $RetentionDays days"

$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
$oldBackups = Get-ChildItem $BackupPath -Filter "keyfactor-*.bak" |
    Where-Object { $_.CreationTime -lt $cutoffDate }

foreach ($backup in $oldBackups) {
    Write-Log "Deleting old backup: $($backup.Name)"
    Remove-Item $backup.FullName -Force
}

Write-Log "Backup cleanup completed"

# Upload to Azure Blob Storage (optional)
$storageAccount = $env:AZURE_STORAGE_ACCOUNT
$storageKey = $env:AZURE_STORAGE_KEY
$container = "keyfactor-backups"

if ($storageAccount -and $storageKey) {
    Write-Log "Uploading backup to Azure Storage..."
    
    try {
        $ctx = New-AzStorageContext -StorageAccountName $storageAccount -StorageAccountKey $storageKey
        
        Set-AzStorageBlobContent -File $backupFile `
            -Container $container `
            -Blob "keyfactor-$timestamp.bak" `
            -Context $ctx `
            -Force
        
        Write-Log "Backup uploaded to Azure Storage successfully"
    } catch {
        Write-Log "WARNING: Failed to upload to Azure Storage - $_"
    }
}

Write-Log "Backup process completed"

