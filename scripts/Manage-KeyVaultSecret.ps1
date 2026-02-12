<#
.SYNOPSIS
    Unified orchestrator for Azure Key Vault secret lifecycle management.

.DESCRIPTION
    Routes operations (add, update, delete-key, revert, backup, restore, list-versions, list-secrets)
    to the appropriate handler scripts. This is the single entry point called by the pipeline.

.PARAMETER Operation
    The operation to perform: add, update, delete-key, revert, backup, restore, list-versions, list-secrets.

.PARAMETER KeyVaultName
    The name of the Azure Key Vault.

.PARAMETER SecretName
    The name of the secret.

.PARAMETER KeyPath
    JSON key path (dot notation) for targeted operations.

.PARAMETER KeyValue
    Value for add/update operations.

.PARAMETER JsonUpdates
    Comma-separated key-value pairs for bulk operations.

.PARAMETER NewSecretJson
    Full JSON body for creating a new secret.

.PARAMETER SupportNestedKeys
    Enable dot-notation nested key support.

.PARAMETER CreateBackup
    Create backup before destructive operations.

.PARAMETER DryRun
    Preview mode - no changes made.

.PARAMETER RevertVersionId
    Specific version ID for revert operation.

.PARAMETER RevertVersionsBack
    Number of versions to go back for revert.

.PARAMETER BackupName
    Name of backup secret for restore operation.

.PARAMETER MaxVersions
    Maximum versions to display in list operations.

.PARAMETER EnvironmentName
    Target environment name for logging.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("add", "update", "delete-key", "revert", "backup", "restore", "list-versions", "list-secrets")]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [string]$SecretName = "",

    [Parameter(Mandatory = $false)]
    [string]$KeyPath = "",

    [Parameter(Mandatory = $false)]
    [string]$KeyValue = "",

    [Parameter(Mandatory = $false)]
    [string]$JsonUpdates = "",

    [Parameter(Mandatory = $false)]
    [string]$NewSecretJson = "",

    [Parameter(Mandatory = $false)]
    [switch]$SupportNestedKeys = $true,

    [Parameter(Mandatory = $false)]
    [switch]$CreateBackup = $true,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false,

    [Parameter(Mandatory = $false)]
    [string]$RevertVersionId = "",

    [Parameter(Mandatory = $false)]
    [int]$RevertVersionsBack = 1,

    [Parameter(Mandatory = $false)]
    [string]$BackupName = "",

    [Parameter(Mandatory = $false)]
    [int]$MaxVersions = 10,

    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = "unknown"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath/Get-KeyVaultSecret.ps1"
. "$scriptPath/Set-KeyVaultSecret.ps1"

$ErrorActionPreference = "Stop"

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

function ConvertTo-Hashtable {
    param ([Parameter(Mandatory = $true)][PSCustomObject]$InputObject)
    $hashtable = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.Value -is [PSCustomObject]) {
            $hashtable[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        elseif ($property.Value -is [System.Collections.IEnumerable] -and -not ($property.Value -is [string])) {
            $arrayItems = @()
            foreach ($item in $property.Value) {
                if ($item -is [PSCustomObject]) {
                    $arrayItems += ConvertTo-Hashtable -InputObject $item
                } else {
                    $arrayItems += $item
                }
            }
            $hashtable[$property.Name] = $arrayItems
        }
        else {
            $hashtable[$property.Name] = $property.Value
        }
    }
    return $hashtable
}

function Set-NestedValue {
    param (
        [hashtable]$Object,
        [string]$Path,
        [AllowEmptyString()]$Value
    )
    $keys = $Path -split '\.'
    $current = $Object
    for ($i = 0; $i -lt $keys.Count - 1; $i++) {
        $key = $keys[$i]
        if (-not $current.ContainsKey($key)) {
            $current[$key] = @{}
        }
        elseif ($current[$key] -isnot [hashtable]) {
            $current[$key] = @{}
        }
        $current = $current[$key]
    }
    $current[$keys[-1]] = $Value
}

function Get-NestedValue {
    param (
        [hashtable]$Object,
        [string]$Path
    )
    $keys = $Path -split '\.'
    $current = $Object
    foreach ($key in $keys) {
        if ($current -is [hashtable] -and $current.ContainsKey($key)) {
            $current = $current[$key]
        } else {
            return $null
        }
    }
    return $current
}

function Remove-NestedKey {
    param (
        [hashtable]$Object,
        [string]$Path
    )
    $keys = $Path -split '\.'
    $current = $Object
    for ($i = 0; $i -lt $keys.Count - 1; $i++) {
        $key = $keys[$i]
        if ($current -is [hashtable] -and $current.ContainsKey($key)) {
            $current = $current[$key]
        } else {
            return $false
        }
    }
    $finalKey = $keys[-1]
    if ($current -is [hashtable] -and $current.ContainsKey($finalKey)) {
        $current.Remove($finalKey)
        return $true
    }
    return $false
}

function Parse-JsonUpdates {
    param ([string]$UpdateString)
    $updates = @{}
    $pairs = $UpdateString -split ',(?=(?:[^"]*"[^"]*")*[^"]*$)'
    foreach ($pair in $pairs) {
        $pair = $pair.Trim()
        if ([string]::IsNullOrWhiteSpace($pair)) { continue }
        $eqIndex = $pair.IndexOf('=')
        if ($eqIndex -gt 0) {
            $key = $pair.Substring(0, $eqIndex).Trim()
            $value = $pair.Substring($eqIndex + 1).Trim()
            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $updates[$key] = $value
        }
    }
    return $updates
}

function Get-MaskedValue {
    param ([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return "(empty)" }
    if ($Value.Length -gt 4) {
        return $Value.Substring(0, 2) + "****" + $Value.Substring($Value.Length - 2)
    }
    return "****"
}

function Get-SecretVersionList {
    param (
        [string]$VaultName,
        [string]$Name,
        [int]$Max = 10
    )
    $versionsJson = az keyvault secret list-versions `
        --vault-name $VaultName `
        --name $Name `
        --query "[].{id:id, created:attributes.created, updated:attributes.updated, enabled:attributes.enabled, contentType:contentType}" `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list secret versions: $versionsJson"
    }

    $versions = $versionsJson | ConvertFrom-Json
    $versions = $versions | ForEach-Object {
        $versionId = ($_.id -split '/')[-1]
        [PSCustomObject]@{
            VersionId   = $versionId
            Created     = $_.created
            Updated     = $_.updated
            Enabled     = $_.enabled
            ContentType = $_.contentType
            FullId      = $_.id
        }
    } | Sort-Object -Property Created -Descending | Select-Object -First $Max

    return $versions
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================
try {
    Write-LogMessage "==========================================================" -Level "Section"
    Write-LogMessage "Key Vault Secret Lifecycle Manager - Operation: $Operation" -Level "Section"
    Write-LogMessage "==========================================================" -Level "Section"
    Write-LogMessage "Environment: $EnvironmentName"
    Write-LogMessage "Key Vault:   $KeyVaultName"
    Write-LogMessage "Secret:      $SecretName"
    Write-LogMessage "Operation:   $Operation"
    Write-LogMessage "Dry Run:     $DryRun"
    Write-LogMessage "=========================================================="

    switch ($Operation) {

        # ==============================================================
        # ADD - Create a completely new secret
        # ==============================================================
        "add" {
            Write-LogMessage "Operation: Add New Secret" -Level "Section"

            # Check if secret already exists
            $existing = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName
            if ($null -ne $existing) {
                throw "Secret '$SecretName' already exists in vault '$KeyVaultName'. Use 'update' operation to modify it."
            }

            # Build the JSON content
            $jsonObject = @{}
            if (-not [string]::IsNullOrWhiteSpace($NewSecretJson)) {
                # Full JSON body provided
                try {
                    $parsed = $NewSecretJson | ConvertFrom-Json
                    $jsonObject = ConvertTo-Hashtable -InputObject $parsed
                    Write-LogMessage "Using provided JSON body"
                }
                catch {
                    throw "Invalid JSON body provided: $_"
                }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($JsonUpdates)) {
                # Build from key-value pairs
                $updates = Parse-JsonUpdates -UpdateString $JsonUpdates
                foreach ($key in $updates.Keys) {
                    if ($SupportNestedKeys -and $key.Contains('.')) {
                        Set-NestedValue -Object $jsonObject -Path $key -Value $updates[$key]
                    } else {
                        $jsonObject[$key] = $updates[$key]
                    }
                }
                Write-LogMessage "Built JSON from $($updates.Count) key-value pair(s)"
            }

            # Show preview
            $jsonPreview = $jsonObject | ConvertTo-Json -Depth 10
            Write-LogMessage "New secret structure:" -Level "Section"
            Write-Host $jsonPreview

            if ($DryRun) {
                Write-LogMessage "DRY RUN - Would create secret '$SecretName' with above JSON" -Level "Warning"
                exit 0
            }

            $compressedJson = $jsonObject | ConvertTo-Json -Depth 10 -Compress
            Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $compressedJson -Tags @{
                createdBy     = "keyvault-pipeline"
                createdAt     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                lastOperation = "add"
            }

            Write-LogMessage "Secret '$SecretName' created successfully!" -Level "Success"
            Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Success"
            Write-Host "##vso[task.setvariable variable=OperationType]Add"
        }

        # ==============================================================
        # UPDATE - Update keys inside an existing JSON secret
        # ==============================================================
        "update" {
            Write-LogMessage "Operation: Update Secret Keys" -Level "Section"

            $updates = Parse-JsonUpdates -UpdateString $JsonUpdates
            if ($updates.Count -eq 0) {
                throw "No valid updates found in: $JsonUpdates"
            }

            Write-LogMessage "Found $($updates.Count) update(s):"
            foreach ($key in $updates.Keys) {
                Write-LogMessage "  - $key = $(Get-MaskedValue $updates[$key])"
            }

            # Fetch existing
            $existingSecret = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName
            if ($null -eq $existingSecret) {
                Write-LogMessage "Secret not found. Creating new secret with provided values." -Level "Warning"
                $jsonObject = @{}
            } else {
                try {
                    $parsed = $existingSecret | ConvertFrom-Json
                    $jsonObject = ConvertTo-Hashtable -InputObject $parsed
                } catch {
                    throw "Failed to parse existing secret as JSON: $_"
                }
            }

            # Backup
            if ($CreateBackup -and -not $DryRun -and $null -ne $existingSecret) {
                Write-LogMessage "Creating backup..."
                $backupSecretName = "$SecretName-backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
                Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $backupSecretName -SecretValue $existingSecret -Tags @{
                    operation    = "pre-update-backup"
                    sourceSecret = $SecretName
                }
                Write-LogMessage "Backup created: $backupSecretName" -Level "Success"
            }

            # Apply updates
            $changeLog = @()
            foreach ($key in $updates.Keys) {
                $newValue = $updates[$key]
                if ($SupportNestedKeys -and $key.Contains('.')) {
                    $oldValue = Get-NestedValue -Object $jsonObject -Path $key
                    Set-NestedValue -Object $jsonObject -Path $key -Value $newValue
                } else {
                    $oldValue = if ($jsonObject.ContainsKey($key)) { $jsonObject[$key] } else { $null }
                    $jsonObject[$key] = $newValue
                }
                $changeLog += @{ Key = $key; OldValue = $oldValue; NewValue = $newValue }
            }

            Write-LogMessage "Changes:" -Level "Section"
            foreach ($change in $changeLog) {
                $oldMasked = if ($null -eq $change.OldValue) { "(new)" } else { Get-MaskedValue $change.OldValue.ToString() }
                $newMasked = Get-MaskedValue $change.NewValue
                Write-LogMessage "  $($change.Key): $oldMasked -> $newMasked"
            }

            if ($DryRun) {
                Write-LogMessage "DRY RUN - No changes made" -Level "Warning"
                $jsonObject | ConvertTo-Json -Depth 10 | Write-Host
                exit 0
            }

            $updatedJson = $jsonObject | ConvertTo-Json -Depth 10 -Compress
            Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $updatedJson -Tags @{
                lastOperation = "update"
                updatedAt     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                updatedKeys   = ($updates.Keys -join ",")
            }

            Write-LogMessage "Secret updated successfully! ($($updates.Count) key(s) modified)" -Level "Success"
            Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Success"
            Write-Host "##vso[task.setvariable variable=OperationType]Update"
            Write-Host "##vso[task.setvariable variable=UpdatedKeysCount]$($updates.Count)"
        }

        # ==============================================================
        # DELETE-KEY - Remove a key from the JSON object
        # ==============================================================
        "delete-key" {
            Write-LogMessage "Operation: Delete Key from Secret" -Level "Section"
            Write-LogMessage "Key to delete: $KeyPath"

            if ([string]::IsNullOrWhiteSpace($KeyPath)) {
                throw "KeyPath is required for delete-key operation"
            }

            # Fetch existing
            $existingSecret = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName
            if ($null -eq $existingSecret) {
                throw "Secret '$SecretName' not found in vault '$KeyVaultName'"
            }

            try {
                $parsed = $existingSecret | ConvertFrom-Json
                $jsonObject = ConvertTo-Hashtable -InputObject $parsed
            } catch {
                throw "Failed to parse existing secret as JSON: $_"
            }

            # Check key exists
            $existingValue = Get-NestedValue -Object $jsonObject -Path $KeyPath
            if ($null -eq $existingValue) {
                throw "Key '$KeyPath' does not exist in secret '$SecretName'"
            }

            Write-LogMessage "Current value at '$KeyPath': $(Get-MaskedValue $existingValue.ToString())"

            if ($DryRun) {
                Write-LogMessage "DRY RUN - Would delete key '$KeyPath' from secret '$SecretName'" -Level "Warning"
                exit 0
            }

            # Backup
            if ($CreateBackup) {
                Write-LogMessage "Creating backup..."
                $backupSecretName = "$SecretName-backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
                Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $backupSecretName -SecretValue $existingSecret -Tags @{
                    operation    = "pre-delete-key-backup"
                    sourceSecret = $SecretName
                    deletedKey   = $KeyPath
                }
                Write-LogMessage "Backup created: $backupSecretName" -Level "Success"
            }

            # Remove the key
            $removed = Remove-NestedKey -Object $jsonObject -Path $KeyPath
            if (-not $removed) {
                throw "Failed to remove key '$KeyPath'"
            }

            $updatedJson = $jsonObject | ConvertTo-Json -Depth 10 -Compress
            Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $updatedJson -Tags @{
                lastOperation = "delete-key"
                deletedKey    = $KeyPath
                updatedAt     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }

            Write-LogMessage "Key '$KeyPath' deleted from secret '$SecretName'" -Level "Success"
            Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Success"
            Write-Host "##vso[task.setvariable variable=OperationType]DeleteKey"
        }

        # ==============================================================
        # REVERT - Delegate to Revert-KeyVaultSecret.ps1
        # ==============================================================
        "revert" {
            Write-LogMessage "Operation: Revert Secret to Previous Version" -Level "Section"

            $revertArgs = @{
                KeyVaultName    = $KeyVaultName
                SecretName      = $SecretName
                EnvironmentName = $EnvironmentName
            }

            if (-not [string]::IsNullOrWhiteSpace($RevertVersionId)) {
                $revertArgs['VersionId'] = $RevertVersionId
            } else {
                $revertArgs['VersionsBack'] = $RevertVersionsBack
            }

            if ($CreateBackup) { $revertArgs['CreateBackup'] = $true }
            if ($DryRun) { $revertArgs['DryRun'] = $true }

            & "$scriptPath/Revert-KeyVaultSecret.ps1" @revertArgs

            Write-Host "##vso[task.setvariable variable=OperationType]Revert"
        }

        # ==============================================================
        # BACKUP - Create a named backup of the current secret
        # ==============================================================
        "backup" {
            Write-LogMessage "Operation: Backup Secret" -Level "Section"

            $existingSecret = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName
            if ($null -eq $existingSecret) {
                throw "Secret '$SecretName' not found in vault '$KeyVaultName'"
            }

            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $backupSecretName = if (-not [string]::IsNullOrWhiteSpace($BackupName)) {
                $BackupName
            } else {
                "$SecretName-backup-$timestamp"
            }

            Write-LogMessage "Backup target: $backupSecretName"

            if ($DryRun) {
                Write-LogMessage "DRY RUN - Would create backup '$backupSecretName'" -Level "Warning"
                exit 0
            }

            Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $backupSecretName -SecretValue $existingSecret -Tags @{
                operation      = "manual-backup"
                sourceSecret   = $SecretName
                backupTimestamp = $timestamp
                createdBy      = "keyvault-pipeline"
            }

            # Also use Azure CLI native backup to file (blob-based backup)
            Write-LogMessage "Creating Azure-native backup file..."
            $backupFile = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY/$SecretName-$timestamp.bak"
            if (-not [string]::IsNullOrWhiteSpace($env:BUILD_ARTIFACTSTAGINGDIRECTORY)) {
                az keyvault secret backup --vault-name $KeyVaultName --name $SecretName --file $backupFile 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-LogMessage "Azure-native backup saved to: $backupFile" -Level "Success"
                } else {
                    Write-LogMessage "Azure-native backup failed (non-critical)" -Level "Warning"
                }
            }

            Write-LogMessage "Backup '$backupSecretName' created successfully!" -Level "Success"
            Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Success"
            Write-Host "##vso[task.setvariable variable=OperationType]Backup"
            Write-Host "##vso[task.setvariable variable=BackupSecretName]$backupSecretName"
        }

        # ==============================================================
        # RESTORE - Restore from a named backup
        # ==============================================================
        "restore" {
            Write-LogMessage "Operation: Restore Secret from Backup" -Level "Section"
            Write-LogMessage "Restore from: $BackupName"

            if ([string]::IsNullOrWhiteSpace($BackupName)) {
                throw "Backup Name is required for restore operation"
            }

            # Fetch backup value
            $backupValue = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $BackupName
            if ($null -eq $backupValue) {
                throw "Backup secret '$BackupName' not found in vault '$KeyVaultName'"
            }

            # Validate JSON
            try {
                $backupValue | ConvertFrom-Json | Out-Null
                Write-LogMessage "Backup contains valid JSON"
            } catch {
                Write-LogMessage "Backup does not contain JSON - will restore as plain text" -Level "Warning"
            }

            if ($DryRun) {
                Write-LogMessage "DRY RUN - Would restore secret '$SecretName' from backup '$BackupName'" -Level "Warning"
                $preview = if ($backupValue.Length -gt 80) {
                    $backupValue.Substring(0, 30) + "..." + $backupValue.Substring($backupValue.Length - 30)
                } else { "****" }
                Write-LogMessage "DRY RUN - Value preview: $preview"
                exit 0
            }

            # Backup current value before restore
            if ($CreateBackup) {
                $currentValue = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName
                if ($null -ne $currentValue) {
                    $preRestoreBackup = "$SecretName-pre-restore-$(Get-Date -Format 'yyyyMMddHHmmss')"
                    Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $preRestoreBackup -SecretValue $currentValue -Tags @{
                        operation    = "pre-restore-backup"
                        sourceSecret = $SecretName
                    }
                    Write-LogMessage "Pre-restore backup created: $preRestoreBackup" -Level "Success"
                }
            }

            # Restore
            Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $backupValue -Tags @{
                lastOperation = "restore"
                restoredFrom  = $BackupName
                restoredAt    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            }

            Write-LogMessage "Secret '$SecretName' restored from '$BackupName'!" -Level "Success"
            Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Success"
            Write-Host "##vso[task.setvariable variable=OperationType]Restore"
        }

        # ==============================================================
        # LIST-VERSIONS - Show version history of a secret
        # ==============================================================
        "list-versions" {
            Write-LogMessage "Operation: List Secret Versions" -Level "Section"

            $versions = Get-SecretVersionList -VaultName $KeyVaultName -Name $SecretName -Max $MaxVersions

            Write-LogMessage "Found $($versions.Count) version(s) for secret '$SecretName':" -Level "Section"
            Write-Host ""
            Write-Host "| # | Version ID                           | Created              | Enabled | Content Type     |"
            Write-Host "|---|--------------------------------------|----------------------|---------|------------------|"

            $index = 0
            foreach ($v in $versions) {
                $label = if ($index -eq 0) { " (current)" } else { "" }
                $enabled = if ($v.Enabled) { "Yes" } else { "No" }
                $ct = if ($v.ContentType) { $v.ContentType } else { "N/A" }
                Write-Host "| $index | $($v.VersionId) | $($v.Created) | $enabled | $ct$label |"
                $index++
            }

            Write-Host ""
            Write-LogMessage "Use the Version ID with 'revert' operation to roll back to a specific version" -Level "Info"
            Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Success"
            Write-Host "##vso[task.setvariable variable=OperationType]ListVersions"
            Write-Host "##vso[task.setvariable variable=VersionCount]$($versions.Count)"
        }

        # ==============================================================
        # LIST-SECRETS - List all secrets in the vault
        # ==============================================================
        "list-secrets" {
            Write-LogMessage "Operation: List Secrets in Vault" -Level "Section"

            $secretsJson = az keyvault secret list `
                --vault-name $KeyVaultName `
                --query "[].{name:name, enabled:attributes.enabled, created:attributes.created, updated:attributes.updated, contentType:contentType}" `
                --output json 2>&1

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to list secrets: $secretsJson"
            }

            $secrets = $secretsJson | ConvertFrom-Json | Sort-Object -Property name

            Write-LogMessage "Found $($secrets.Count) secret(s) in vault '$KeyVaultName':" -Level "Section"
            Write-Host ""
            Write-Host "| # | Secret Name                    | Created              | Updated              | Enabled | Content Type     |"
            Write-Host "|---|--------------------------------|----------------------|----------------------|---------|------------------|"

            $index = 1
            foreach ($s in $secrets) {
                $enabled = if ($s.enabled) { "Yes" } else { "No" }
                $ct = if ($s.contentType) { $s.contentType } else { "N/A" }
                Write-Host "| $index | $($s.name) | $($s.created) | $($s.updated) | $enabled | $ct |"
                $index++
            }

            Write-Host ""
            Write-LogMessage "Total: $($secrets.Count) secret(s)" -Level "Success"
            Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Success"
            Write-Host "##vso[task.setvariable variable=OperationType]ListSecrets"
            Write-Host "##vso[task.setvariable variable=SecretCount]$($secrets.Count)"
        }

        default {
            throw "Unknown operation: $Operation"
        }
    }

    Write-LogMessage "==========================================================" -Level "Section"
    Write-LogMessage "Operation '$Operation' completed successfully" -Level "Success"
    Write-LogMessage "==========================================================" -Level "Section"
}
catch {
    Write-LogMessage "Operation '$Operation' failed: $_" -Level "Error"
    Write-LogMessage $_.ScriptStackTrace -Level "Error"
    Write-Host "##vso[task.setvariable variable=SecretOperationStatus]Failed"
    Write-Host "##vso[task.setvariable variable=OperationType]$Operation"
    exit 1
}
