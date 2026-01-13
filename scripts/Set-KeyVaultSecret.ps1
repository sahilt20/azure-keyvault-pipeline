<#
.SYNOPSIS
    Sets a secret value in Azure Key Vault.

.DESCRIPTION
    This helper script creates or updates a secret in Azure Key Vault
    using the Azure CLI.

.PARAMETER KeyVaultName
    The name of the Azure Key Vault.

.PARAMETER SecretName
    The name of the secret to create/update.

.PARAMETER SecretValue
    The value to set for the secret.

.PARAMETER ContentType
    Optional content type for the secret (e.g., "application/json").

.PARAMETER Tags
    Optional hashtable of tags to apply to the secret.

.OUTPUTS
    Returns $true if successful, throws an error otherwise.
#>

function Set-KeyVaultSecretValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $true)]
        [string]$SecretValue,

        [Parameter(Mandatory = $false)]
        [string]$ContentType = "application/json",

        [Parameter(Mandatory = $false)]
        [hashtable]$Tags = @{}
    )

    try {
        Write-Verbose "Setting secret '$SecretName' in Key Vault '$KeyVaultName'..."
        
        # Build the Azure CLI command
        $arguments = @(
            "keyvault", "secret", "set",
            "--vault-name", $KeyVaultName,
            "--name", $SecretName,
            "--value", $SecretValue
        )

        # Add content type if specified
        if (-not [string]::IsNullOrWhiteSpace($ContentType)) {
            $arguments += "--content-type"
            $arguments += $ContentType
        }

        # Execute the command
        $result = & az @arguments 2>&1

        # Check if the command was successful
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set secret: $result"
        }

        Write-Verbose "Successfully set secret '$SecretName'"
        
        # Add tags if specified
        if ($Tags.Count -gt 0) {
            Write-Verbose "Applying tags to secret..."
            $tagString = ($Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " "
            
            az keyvault secret set-attributes `
                --vault-name $KeyVaultName `
                --name $SecretName `
                --tags $tagString 2>&1 | Out-Null
                
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to apply tags to secret, but secret was set successfully"
            }
        }

        return $true
    }
    catch {
        Write-Error "Error setting secret in Key Vault: $_"
        throw
    }
}

# Alternative function using Az PowerShell module (if available)
function Set-KeyVaultSecretValueAzModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $true)]
        [string]$SecretValue,

        [Parameter(Mandatory = $false)]
        [string]$ContentType = "application/json",

        [Parameter(Mandatory = $false)]
        [hashtable]$Tags = @{}
    )

    try {
        # Check if Az.KeyVault module is available
        if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
            throw "Az.KeyVault module is not installed. Please use Azure CLI method."
        }

        # Convert plain text to secure string
        $secureValue = ConvertTo-SecureString -String $SecretValue -AsPlainText -Force

        $params = @{
            VaultName   = $KeyVaultName
            Name        = $SecretName
            SecretValue = $secureValue
            ContentType = $ContentType
        }

        if ($Tags.Count -gt 0) {
            $params['Tag'] = $Tags
        }

        $secret = Set-AzKeyVaultSecret @params

        if ($null -eq $secret) {
            throw "Failed to set secret - no response from Key Vault"
        }

        Write-Verbose "Successfully set secret '$SecretName' (Version: $($secret.Version))"
        return $true
    }
    catch {
        Write-Error "Error setting secret using Az module: $_"
        throw
    }
}

# Function to create a versioned backup of a secret
function Backup-KeyVaultSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $false)]
        [string]$BackupSuffix = (Get-Date -Format "yyyyMMddHHmmss")
    )

    try {
        Write-Verbose "Creating backup of secret '$SecretName'..."
        
        # Get current secret value
        $currentValue = az keyvault secret show `
            --vault-name $KeyVaultName `
            --name $SecretName `
            --query "value" `
            --output tsv 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not create backup - secret may not exist"
            return $null
        }

        # Create backup with timestamp suffix
        $backupName = "$SecretName-backup-$BackupSuffix"
        
        az keyvault secret set `
            --vault-name $KeyVaultName `
            --name $backupName `
            --value $currentValue `
            --content-type "backup" 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create backup secret"
        }

        Write-Verbose "Backup created: $backupName"
        return $backupName
    }
    catch {
        Write-Error "Error creating backup: $_"
        throw
    }
}

# Export functions
Export-ModuleMember -Function Set-KeyVaultSecretValue, Set-KeyVaultSecretValueAzModule, Backup-KeyVaultSecret -ErrorAction SilentlyContinue
