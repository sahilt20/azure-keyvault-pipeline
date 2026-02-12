<#
.SYNOPSIS
    Sets, backs up, and restores secrets in Azure Key Vault.

.DESCRIPTION
    Helper script for creating/updating secrets, creating backups,
    and restoring from backups in Azure Key Vault using Azure CLI.
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

        $arguments = @(
            "keyvault", "secret", "set",
            "--vault-name", $KeyVaultName,
            "--name", $SecretName,
            "--value", $SecretValue
        )

        if (-not [string]::IsNullOrWhiteSpace($ContentType)) {
            $arguments += "--content-type"
            $arguments += $ContentType
        }

        $result = & az @arguments 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set secret: $result"
        }

        Write-Verbose "Successfully set secret '$SecretName'"

        # Apply tags if specified
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

function Backup-KeyVaultSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $false)]
        [string]$BackupSuffix = (Get-Date -Format "yyyyMMddHHmmss"),

        [Parameter(Mandatory = $false)]
        [hashtable]$ExtraTags = @{}
    )

    try {
        Write-Verbose "Creating backup of secret '$SecretName'..."

        $currentValue = az keyvault secret show `
            --vault-name $KeyVaultName `
            --name $SecretName `
            --query "value" `
            --output tsv 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not create backup - secret may not exist"
            return $null
        }

        $backupName = "$SecretName-backup-$BackupSuffix"

        $tags = @{
            operation      = "backup"
            sourceSecret   = $SecretName
            backupTimestamp = $BackupSuffix
        }
        foreach ($key in $ExtraTags.Keys) {
            $tags[$key] = $ExtraTags[$key]
        }

        Set-KeyVaultSecretValue -KeyVaultName $KeyVaultName -SecretName $backupName -SecretValue $currentValue -ContentType "backup" -Tags $tags

        Write-Verbose "Backup created: $backupName"
        return $backupName
    }
    catch {
        Write-Error "Error creating backup: $_"
        throw
    }
}

function Backup-KeyVaultSecretToFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$SecretName,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    try {
        Write-Verbose "Creating Azure-native backup of '$SecretName' to file..."

        $result = az keyvault secret backup `
            --vault-name $KeyVaultName `
            --name $SecretName `
            --file $OutputPath 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create backup file: $result"
        }

        Write-Verbose "Backup file created: $OutputPath"
        return $OutputPath
    }
    catch {
        Write-Error "Error creating backup file: $_"
        throw
    }
}

function Restore-KeyVaultSecretFromFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $true)]
        [string]$BackupFilePath
    )

    try {
        Write-Verbose "Restoring secret from backup file..."

        $result = az keyvault secret restore `
            --vault-name $KeyVaultName `
            --file $BackupFilePath 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to restore from backup file: $result"
        }

        Write-Verbose "Secret restored from: $BackupFilePath"
        return $true
    }
    catch {
        Write-Error "Error restoring secret: $_"
        throw
    }
}

# Alternative function using Az PowerShell module
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
        if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
            throw "Az.KeyVault module is not installed. Please use Azure CLI method."
        }

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

Export-ModuleMember -Function Set-KeyVaultSecretValue, Set-KeyVaultSecretValueAzModule, Backup-KeyVaultSecret, Backup-KeyVaultSecretToFile, Restore-KeyVaultSecretFromFile -ErrorAction SilentlyContinue
