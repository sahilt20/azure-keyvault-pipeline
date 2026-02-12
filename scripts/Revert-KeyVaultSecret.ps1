<#
.SYNOPSIS
    Reverts an Azure Key Vault secret to a previous version.

.DESCRIPTION
    Lists secret versions, identifies the target version (by ID or N versions back),
    fetches its value, and sets it as the current version. Creates a backup before reverting.

.PARAMETER KeyVaultName
    The name of the Azure Key Vault.

.PARAMETER SecretName
    The name of the secret to revert.

.PARAMETER VersionId
    Specific version ID to revert to. If empty, uses VersionsBack parameter.

.PARAMETER VersionsBack
    Number of versions to go back (default: 1 = previous version).

.PARAMETER CreateBackup
    If true, creates a backup before reverting.

.PARAMETER DryRun
    If true, only shows what would be reverted without making changes.

.EXAMPLE
    .\Revert-KeyVaultSecret.ps1 -KeyVaultName "my-kv" -SecretName "my-secret" -VersionsBack 1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$SecretName,

    [Parameter(Mandatory = $false)]
    [string]$VersionId = "",

    [Parameter(Mandatory = $false)]
    [int]$VersionsBack = 1,

    [Parameter(Mandatory = $false)]
    [switch]$CreateBackup = $true,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false,

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

function Get-SecretVersions {
    param (
        [string]$VaultName,
        [string]$Name
    )

    $versionsJson = az keyvault secret list-versions `
        --vault-name $VaultName `
        --name $Name `
        --query "[].{id:id, created:attributes.created, enabled:attributes.enabled, version:id}" `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list secret versions: $versionsJson"
    }

    $versions = $versionsJson | ConvertFrom-Json

    # Extract version ID from the full ID URL and sort by created date descending
    $versions = $versions | ForEach-Object {
        $versionId = ($_.id -split '/')[-1]
        [PSCustomObject]@{
            VersionId = $versionId
            Created   = $_.created
            Enabled   = $_.enabled
            FullId    = $_.id
        }
    } | Sort-Object -Property Created -Descending

    return $versions
}

function Get-SecretByVersion {
    param (
        [string]$VaultName,
        [string]$Name,
        [string]$Version
    )

    $value = az keyvault secret show `
        --vault-name $VaultName `
        --name $Name `
        --version $Version `
        --query "value" `
        --output tsv 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch secret version '$Version': $value"
    }

    return $value
}

try {
    Write-LogMessage "=====================================" -Level "Section"
    Write-LogMessage "Key Vault Secret Revert" -Level "Section"
    Write-LogMessage "=====================================" -Level "Section"
    Write-LogMessage "Environment: $EnvironmentName"
    Write-LogMessage "Key Vault: $KeyVaultName"
    Write-LogMessage "Secret: $SecretName"
    Write-LogMessage "Dry Run: $DryRun"

    # List all versions
    Write-LogMessage "Fetching secret versions..."
    $versions = Get-SecretVersions -VaultName $KeyVaultName -Name $SecretName

    if ($versions.Count -lt 2 -and [string]::IsNullOrWhiteSpace($VersionId)) {
        throw "Secret '$SecretName' has fewer than 2 versions. Nothing to revert to."
    }

    Write-LogMessage "Found $($versions.Count) version(s):" -Level "Section"
    $index = 0
    foreach ($v in $versions) {
        $label = if ($index -eq 0) { " (current)" } else { "" }
        Write-LogMessage "  [$index] Version: $($v.VersionId) | Created: $($v.Created) | Enabled: $($v.Enabled)$label"
        $index++
    }

    # Determine target version
    $targetVersion = $null
    if (-not [string]::IsNullOrWhiteSpace($VersionId)) {
        # Find by version ID
        $targetVersion = $versions | Where-Object { $_.VersionId -eq $VersionId }
        if ($null -eq $targetVersion) {
            throw "Version ID '$VersionId' not found for secret '$SecretName'"
        }
        Write-LogMessage "Target version (by ID): $($targetVersion.VersionId)"
    }
    else {
        # Go back N versions
        if ($VersionsBack -ge $versions.Count) {
            throw "Cannot go back $VersionsBack versions. Only $($versions.Count) versions exist."
        }
        $targetVersion = $versions[$VersionsBack]
        Write-LogMessage "Target version ($VersionsBack version(s) back): $($targetVersion.VersionId)"
    }

    Write-LogMessage "Reverting to version: $($targetVersion.VersionId) (created: $($targetVersion.Created))"

    # Fetch the target version value
    Write-LogMessage "Fetching target version value..."
    $targetValue = Get-SecretByVersion -VaultName $KeyVaultName -Name $SecretName -Version $targetVersion.VersionId

    if ([string]::IsNullOrWhiteSpace($targetValue)) {
        throw "Target version value is empty"
    }

    # Validate it's valid JSON
    try {
        $targetValue | ConvertFrom-Json | Out-Null
        Write-LogMessage "Target version contains valid JSON"
    }
    catch {
        Write-LogMessage "Target version does not contain JSON - will revert as plain text" -Level "Warning"
    }

    if ($DryRun) {
        Write-LogMessage "DRY RUN - Would revert secret '$SecretName' to version $($targetVersion.VersionId)" -Level "Warning"
        Write-LogMessage "DRY RUN - Target version created at: $($targetVersion.Created)" -Level "Warning"

        # Show a preview (masked)
        $preview = if ($targetValue.Length -gt 50) {
            $targetValue.Substring(0, 20) + "..." + $targetValue.Substring($targetValue.Length - 20)
        } else { "****" }
        Write-LogMessage "DRY RUN - Value preview: $preview"
        exit 0
    }

    # Create backup of current version before reverting
    if ($CreateBackup) {
        Write-LogMessage "Creating backup of current version before revert..."
        $currentValue = Get-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName
        if ($null -ne $currentValue) {
            $backupName = "$SecretName-pre-revert-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $backupName -SecretValue $currentValue -Tags @{
                operation   = "pre-revert-backup"
                sourceSecret = $SecretName
                revertedTo  = $targetVersion.VersionId
            }
            Write-LogMessage "Backup created: $backupName" -Level "Success"
        }
    }

    # Set the reverted value as the new current version
    Write-LogMessage "Setting reverted value as new current version..."
    Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $SecretName -SecretValue $targetValue -Tags @{
        lastOperation = "revert"
        revertedFrom  = $versions[0].VersionId
        revertedTo    = $targetVersion.VersionId
        revertedAt    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }

    Write-LogMessage "=====================================" -Level "Section"
    Write-LogMessage "Secret reverted successfully!" -Level "Success"
    Write-LogMessage "Previous version: $($versions[0].VersionId)" -Level "Success"
    Write-LogMessage "Reverted to: $($targetVersion.VersionId)" -Level "Success"
    Write-LogMessage "=====================================" -Level "Section"

    Write-Host "##vso[task.setvariable variable=SecretRevertStatus]Success"
    Write-Host "##vso[task.setvariable variable=RevertedToVersion]$($targetVersion.VersionId)"
}
catch {
    Write-LogMessage "Revert failed: $_" -Level "Error"
    Write-LogMessage $_.ScriptStackTrace -Level "Error"
    Write-Host "##vso[task.setvariable variable=SecretRevertStatus]Failed"
    exit 1
}
