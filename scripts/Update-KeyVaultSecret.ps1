<#
.SYNOPSIS
    Updates a JSON-based secret in Azure Key Vault.

.DESCRIPTION
    This script fetches an existing secret from Azure Key Vault, parses its JSON content,
    updates specified key-value pairs, and writes the updated secret back to Key Vault.

.PARAMETER KeyVaultName
    The name of the Azure Key Vault.

.PARAMETER SecretName
    The name of the secret to update.

.PARAMETER JsonUpdates
    Comma-separated key-value pairs to update (format: key1=value1,key2=value2).
    Supports nested keys with dot notation (e.g., parent.child.key=value).

.PARAMETER SupportNestedKeys
    If true, supports nested JSON key updates using dot notation.

.PARAMETER CreateBackup
    If true, creates a backup tag before updating the secret.

.PARAMETER DryRun
    If true, only shows what would be changed without making actual updates.

.PARAMETER EnvironmentName
    The target environment name for logging purposes.

.EXAMPLE
    .\Update-KeyVaultSecret.ps1 -KeyVaultName "my-keyvault" -SecretName "my-secret" -JsonUpdates "apiKey=newValue,database.host=newhost"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$SecretName,

    [Parameter(Mandatory = $true)]
    [string]$JsonUpdates,

    [Parameter(Mandatory = $false)]
    [switch]$SupportNestedKeys = $true,

    [Parameter(Mandatory = $false)]
    [switch]$CreateBackup = $true,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false,

    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "unknown"
)

# Import helper scripts
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath/Get-KeyVaultSecret.ps1"
. "$scriptPath/Set-KeyVaultSecret.ps1"
. "$scriptPath/KeyVaultSecretUpdate.Core.ps1"

# Set strict error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-LogMessage {
    param (
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success", "Section")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Level) {
        "Info"    { Write-Host "[$timestamp] INFO: $Message" }
        "Warning" { Write-Host "##[warning][$timestamp] WARNING: $Message" }
        "Error"   { Write-Host "##[error][$timestamp] ERROR: $Message" }
        "Success" { Write-Host "##[section][$timestamp] SUCCESS: $Message" }
        "Section" { Write-Host "##[section][$timestamp] $Message" }
    }
}

# Main execution
try {
    Write-LogMessage "=====================================" -Level "Section"
    Write-LogMessage "Key Vault Secret Update Script" -Level "Section"
    Write-LogMessage "=====================================" -Level "Section"
    Write-LogMessage "Environment: $EnvironmentName"
    Write-LogMessage "Key Vault: $KeyVaultName"
    Write-LogMessage "Secret: $SecretName"
    Write-LogMessage "Dry Run: $DryRun"
    Write-LogMessage "Create Backup: $CreateBackup"
    Write-LogMessage "Support Nested Keys: $SupportNestedKeys"
    Write-LogMessage "====================================="
    
    # Parse the updates
    Write-LogMessage "Parsing JSON updates..."
    $updates = Parse-JsonUpdates -UpdateString $JsonUpdates

    if ($updates.Count -eq 0) {
        throw "No valid updates found in the input string."
    }

    Write-LogMessage "Found $($updates.Count) update(s) to apply."
    foreach ($key in $updates.Keys) {
        Write-LogMessage "  - $key = $(Get-MaskedValue -Value $updates[$key])"
    }
    
    # Fetch existing secret
    Write-LogMessage "Fetching existing secret from Key Vault..."
    $existingSecret = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName
    
    if ($null -eq $existingSecret) {
        Write-LogMessage "Secret not found. Creating new secret with provided values." -Level "Warning"
        $jsonObject = @{}
    }
    else {
        Write-LogMessage "Secret found. Parsing JSON content..."
        try {
            $parsedJson = $existingSecret | ConvertFrom-Json -Depth 50
            $jsonObject = ConvertTo-Hashtable -InputObject $parsedJson
            if ($jsonObject -isnot [hashtable]) {
                throw "Existing secret JSON must be an object at the root (e.g. {""key"":""value""})."
            }
        }
        catch {
            throw "Failed to parse existing secret as JSON: $_"
        }
    }
    
    # Create backup if requested
    if ($CreateBackup -and -not $DryRun -and $null -ne $existingSecret) {
        Write-LogMessage "Creating backup of existing secret..."
        $backupSecretName = Backup-KeyVaultSecret -KeyVaultName $KeyVaultName -SecretName $SecretName
        if ([string]::IsNullOrWhiteSpace($backupSecretName)) {
            throw "Backup was requested but could not be created."
        }
        Write-LogMessage "Backup created: $backupSecretName" -Level "Success"
    }
    
    # Apply updates
    Write-LogMessage "Applying updates to JSON..."
    $changeLog = @()
    $changedCount = 0

    foreach ($key in $updates.Keys) {
        $newValue = $updates[$key]
        
        if ($SupportNestedKeys -and $key.Contains('.')) {
            $oldValue = Get-NestedValue -Object $jsonObject -Path $key
            if (Test-ValueChanged -OldValue $oldValue -NewValue $newValue) {
                Set-NestedValue -Object $jsonObject -Path $key -Value $newValue
                $changedCount++
            }
        }
        else {
            $oldValue = if ($jsonObject.ContainsKey($key)) { $jsonObject[$key] } else { $null }
            if (Test-ValueChanged -OldValue $oldValue -NewValue $newValue) {
                $jsonObject[$key] = $newValue
                $changedCount++
            }
        }
        
        $changeLog += @{
            Key = $key
            OldValue = $oldValue
            NewValue = $newValue
            Changed = (Test-ValueChanged -OldValue $oldValue -NewValue $newValue)
        }
    }
    
    # Display changes
    Write-LogMessage "Changes to be applied:" -Level "Section"
    foreach ($change in $changeLog) {
        $oldMasked = if ($null -eq $change.OldValue) { "(new)" } else { Get-MaskedValue -Value $change.OldValue }
        $newMasked = Get-MaskedValue -Value $change.NewValue
        $status = if ($change.Changed) { "changed" } else { "unchanged" }
        Write-LogMessage "  $($change.Key): $oldMasked -> $newMasked ($status)"
    }

    if ($changedCount -eq 0) {
        Write-LogMessage "No effective changes detected. Secret update skipped." -Level "Warning"
        Write-Host "##vso[task.setvariable variable=SecretUpdateStatus]NoChanges"
        Write-Host "##vso[task.setvariable variable=UpdatedKeysCount]0"
        exit 0
    }
    
    if ($DryRun) {
        Write-LogMessage "DRY RUN MODE - No changes were made" -Level "Warning"
        Write-LogMessage "Skipping JSON preview to avoid secret value exposure in logs."
        Write-Host "##vso[task.setvariable variable=SecretUpdateStatus]DryRun"
        Write-Host "##vso[task.setvariable variable=UpdatedKeysCount]$changedCount"
        exit 0
    }
    
    # Convert back to JSON and update secret
    Write-LogMessage "Converting updated object back to JSON..."
    $updatedJson = $jsonObject | ConvertTo-Json -Depth 10 -Compress
    
    Write-LogMessage "Updating secret in Key Vault..."
    Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $updatedJson
    
    Write-LogMessage "=====================================" -Level "Section"
    Write-LogMessage "Secret updated successfully!" -Level "Success"
    Write-LogMessage "=====================================" -Level "Section"
    
    # Output summary for Azure DevOps
    Write-Host "##vso[task.setvariable variable=SecretUpdateStatus]Success"
    Write-Host "##vso[task.setvariable variable=UpdatedKeysCount]$changedCount"
}
catch {
    Write-LogMessage "Script execution failed: $_" -Level "Error"
    Write-LogMessage $_.ScriptStackTrace -Level "Error"
    Write-Host "##vso[task.setvariable variable=SecretUpdateStatus]Failed"
    exit 1
}
