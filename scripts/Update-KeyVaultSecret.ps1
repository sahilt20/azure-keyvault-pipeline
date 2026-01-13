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

# Set strict error handling
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
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$InputObject
    )
    
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
                }
                else {
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
        [Parameter(Mandatory = $true)]
        [hashtable]$Object,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        $Value
    )
    
    $keys = $Path -split '\.'
    $current = $Object
    
    for ($i = 0; $i -lt $keys.Count - 1; $i++) {
        $key = $keys[$i]
        
        if (-not $current.ContainsKey($key)) {
            $current[$key] = @{}
        }
        elseif ($current[$key] -isnot [hashtable]) {
            # Convert to hashtable if needed
            $current[$key] = @{}
        }
        
        $current = $current[$key]
    }
    
    $finalKey = $keys[-1]
    $current[$finalKey] = $Value
}

function Get-NestedValue {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Object,
        
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $keys = $Path -split '\.'
    $current = $Object
    
    foreach ($key in $keys) {
        if ($current -is [hashtable] -and $current.ContainsKey($key)) {
            $current = $current[$key]
        }
        else {
            return $null
        }
    }
    
    return $current
}

function Parse-JsonUpdates {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UpdateString
    )
    
    $updates = @{}
    
    # Split by comma, but handle values that might contain commas in quotes
    $pairs = $UpdateString -split ',(?=(?:[^"]*"[^"]*")*[^"]*$)'
    
    foreach ($pair in $pairs) {
        $pair = $pair.Trim()
        if ([string]::IsNullOrWhiteSpace($pair)) { continue }
        
        # Split by first = sign only
        $eqIndex = $pair.IndexOf('=')
        if ($eqIndex -gt 0) {
            $key = $pair.Substring(0, $eqIndex).Trim()
            $value = $pair.Substring($eqIndex + 1).Trim()
            
            # Remove surrounding quotes if present
            if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            
            $updates[$key] = $value
        }
    }
    
    return $updates
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
        throw "No valid updates found in the input string: $JsonUpdates"
    }
    
    Write-LogMessage "Found $($updates.Count) update(s) to apply:"
    foreach ($key in $updates.Keys) {
        # Mask sensitive values in logs
        $maskedValue = if ($updates[$key].Length -gt 4) {
            $updates[$key].Substring(0, 2) + "****" + $updates[$key].Substring($updates[$key].Length - 2)
        } else {
            "****"
        }
        Write-LogMessage "  - $key = $maskedValue"
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
            $parsedJson = $existingSecret | ConvertFrom-Json
            $jsonObject = ConvertTo-Hashtable -InputObject $parsedJson
        }
        catch {
            throw "Failed to parse existing secret as JSON: $_"
        }
    }
    
    # Create backup if requested
    if ($CreateBackup -and -not $DryRun -and $null -ne $existingSecret) {
        Write-LogMessage "Creating backup of existing secret..."
        $backupSecretName = "$SecretName-backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $backupSecretName -SecretValue $existingSecret
        Write-LogMessage "Backup created: $backupSecretName" -Level "Success"
    }
    
    # Apply updates
    Write-LogMessage "Applying updates to JSON..."
    $changeLog = @()
    
    foreach ($key in $updates.Keys) {
        $newValue = $updates[$key]
        
        if ($SupportNestedKeys -and $key.Contains('.')) {
            $oldValue = Get-NestedValue -Object $jsonObject -Path $key
            Set-NestedValue -Object $jsonObject -Path $key -Value $newValue
        }
        else {
            $oldValue = if ($jsonObject.ContainsKey($key)) { $jsonObject[$key] } else { $null }
            $jsonObject[$key] = $newValue
        }
        
        $changeLog += @{
            Key = $key
            OldValue = $oldValue
            NewValue = $newValue
        }
    }
    
    # Display changes
    Write-LogMessage "Changes to be applied:" -Level "Section"
    foreach ($change in $changeLog) {
        $oldMasked = if ($null -eq $change.OldValue) { "(new)" } 
                     elseif ($change.OldValue.ToString().Length -gt 4) {
                         $change.OldValue.ToString().Substring(0, 2) + "****"
                     } else { "****" }
        $newMasked = if ($change.NewValue.Length -gt 4) {
            $change.NewValue.Substring(0, 2) + "****"
        } else { "****" }
        Write-LogMessage "  $($change.Key): $oldMasked -> $newMasked"
    }
    
    if ($DryRun) {
        Write-LogMessage "DRY RUN MODE - No changes were made" -Level "Warning"
        Write-LogMessage "Preview of updated JSON structure:"
        $jsonObject | ConvertTo-Json -Depth 10 | Write-Host
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
    Write-Host "##vso[task.setvariable variable=UpdatedKeysCount]$($updates.Count)"
}
catch {
    Write-LogMessage "Script execution failed: $_" -Level "Error"
    Write-LogMessage $_.ScriptStackTrace -Level "Error"
    Write-Host "##vso[task.setvariable variable=SecretUpdateStatus]Failed"
    exit 1
}
