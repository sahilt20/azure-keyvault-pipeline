<#
.SYNOPSIS
    Fetches secret values and version history from Azure Key Vault.

.DESCRIPTION
    Helper script for retrieving secrets, listing versions, and fetching
    specific versions from Azure Key Vault using Azure CLI.
#>

function Get-KeyVaultSecretValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $false)]
        [string]$Version = ""
    )

    try {
        Write-Verbose "Fetching secret '$SecretName' from Key Vault '$KeyVaultName'..."

        $arguments = @(
            "keyvault", "secret", "show",
            "--vault-name", $KeyVaultName,
            "--name", $SecretName,
            "--query", "value",
            "--output", "tsv"
        )

        if (-not [string]::IsNullOrWhiteSpace($Version)) {
            $arguments += "--version"
            $arguments += $Version
        }

        $secretValue = & az @arguments 2>&1

        if ($LASTEXITCODE -ne 0) {
            if ($secretValue -match "SecretNotFound" -or $secretValue -match "not found") {
                Write-Verbose "Secret '$SecretName' not found in Key Vault '$KeyVaultName'"
                return $null
            }
            throw "Failed to fetch secret: $secretValue"
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

function Get-KeyVaultSecretVersions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 25
    )

    try {
        Write-Verbose "Listing versions for secret '$SecretName'..."

        $versionsJson = az keyvault secret list-versions `
            --vault-name $KeyVaultName `
            --name $SecretName `
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
        } | Sort-Object -Property Created -Descending | Select-Object -First $MaxResults

        Write-Verbose "Found $($versions.Count) version(s)"
        return $versions
    }
    catch {
        Write-Error "Error listing secret versions: $_"
        throw
    }
}

function Get-KeyVaultSecretList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName
    )

    try {
        Write-Verbose "Listing secrets in vault '$KeyVaultName'..."

        $secretsJson = az keyvault secret list `
            --vault-name $KeyVaultName `
            --query "[].{name:name, enabled:attributes.enabled, created:attributes.created, updated:attributes.updated, contentType:contentType}" `
            --output json 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list secrets: $secretsJson"
        }

        $secrets = $secretsJson | ConvertFrom-Json | Sort-Object -Property name
        Write-Verbose "Found $($secrets.Count) secret(s)"
        return $secrets
    }
    catch {
        Write-Error "Error listing secrets: $_"
        throw
    }
}

# Alternative function using Az PowerShell module
function Get-KeyVaultSecretValueAzModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName
    )

    try {
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

Export-ModuleMember -Function Get-KeyVaultSecretValue, Get-KeyVaultSecretVersions, Get-KeyVaultSecretList, Get-KeyVaultSecretValueAzModule -ErrorAction SilentlyContinue
