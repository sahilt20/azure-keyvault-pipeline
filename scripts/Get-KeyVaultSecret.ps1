<#
.SYNOPSIS
    Fetches a secret value from Azure Key Vault.

.DESCRIPTION
    This helper script retrieves the value of a secret from Azure Key Vault
    using the Azure CLI.

.PARAMETER KeyVaultName
    The name of the Azure Key Vault.

.PARAMETER SecretName
    The name of the secret to retrieve.

.OUTPUTS
    Returns the secret value as a string, or $null if not found.
#>

function Get-KeyVaultSecretValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName
    )

    try {
        Write-Verbose "Fetching secret '$SecretName' from Key Vault '$KeyVaultName'..."

        $arguments = @(
            "keyvault", "secret", "show",
            "--vault-name", $KeyVaultName,
            "--name", $SecretName,
            "--query", "value",
            "--output", "tsv",
            "--only-show-errors"
        )

        $secretValue = & az @arguments 2>&1

        # Check if the command was successful
        if ($LASTEXITCODE -ne 0) {
            $errorText = ($secretValue | Out-String).Trim()
            if ($errorText -match "(?i)SecretNotFound|was not found|not found") {
                Write-Verbose "Secret '$SecretName' not found in Key Vault '$KeyVaultName'"
                return $null
            }
            throw "Failed to fetch secret: $errorText"
        }

        if ([string]::IsNullOrWhiteSpace($secretValue)) {
            Write-Verbose "Secret '$SecretName' is empty or not found"
            return $null
        }

        Write-Verbose "Successfully retrieved secret '$SecretName'"
        return $secretValue
    }
    catch {
        Write-Error "Error fetching secret from Key Vault: $_"
        throw
    }
}

# Alternative function using Az PowerShell module (if available)
function Get-KeyVaultSecretValueAzModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName
    )

    try {
        # Check if Az.KeyVault module is available
        if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
            throw "Az.KeyVault module is not installed. Please use Azure CLI method."
        }

        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText -ErrorAction SilentlyContinue

        if ($null -eq $secret) {
            Write-Verbose "Secret '$SecretName' not found in Key Vault '$KeyVaultName'"
            return $null
        }

        return $secret
    }
    catch {
        Write-Error "Error fetching secret using Az module: $_"
        throw
    }
}

# Export functions
Export-ModuleMember -Function Get-KeyVaultSecretValue, Get-KeyVaultSecretValueAzModule -ErrorAction SilentlyContinue
