# Azure Key Vault Secret Lifecycle Management Pipeline

A production-grade Azure DevOps YAML pipeline for full lifecycle management of JSON-based secrets in Azure Key Vault. Supports adding, updating, deleting keys, reverting to previous versions, backup/restore, and auditing — all with approval gates, dry-run mode, and sensitive value masking.

## Features

- **8 Operations**: add, update, delete-key, revert, backup, restore, list-versions, list-secrets
- **Vault Name Dropdown**: Pre-configured vault names selectable from the pipeline UI
- **Nested JSON Support**: Update deep keys using dot notation (`database.connection.host`)
- **Version Revert**: Roll back to any previous secret version by ID or N-versions-back
- **Backup & Restore**: Named backups with restore capability, plus Azure-native `.bak` file export
- **Dry Run Mode**: Preview any operation without making changes
- **Automatic Backups**: Creates backups before all destructive operations
- **Multi-Environment**: Dev, Staging, Production with environment-based approval gates
- **Audit Trail**: All operations tagged with metadata (operation type, timestamp, changed keys)
- **Sensitive Masking**: Secret values masked in all pipeline logs

## Prerequisites

1. **Azure DevOps Project** with Pipelines enabled
2. **Azure Subscription** with Key Vault(s) configured
3. **Service Connections** for each environment with Key Vault permissions:
   - `Microsoft.KeyVault/vaults/secrets/read`
   - `Microsoft.KeyVault/vaults/secrets/write`
   - `Microsoft.KeyVault/vaults/secrets/list`
4. **Azure DevOps Environments** configured for approval gates (staging/prod)

## Quick Start

### 1. Import the Pipeline

1. Push this repository to your Azure DevOps project
2. Navigate to **Pipelines** > **New Pipeline**
3. Select your repository and choose "Existing Azure Pipelines YAML file"
4. Select `/azure-pipelines.yml`

### 2. Configure Vault Names

Edit the `keyVaultName` parameter values in `azure-pipelines.yml` to match your vault names:

```yaml
- name: keyVaultName
  values:
    - 'select-vault'
    - 'your-vault-dev'
    - 'your-vault-staging'
    - 'your-vault-prod'
```

Also update `configs/environments.yml` with your vault registry.

### 3. Configure Service Connections

Create Azure Resource Manager service connections:
- `azure-dev-connection`
- `azure-staging-connection`
- `azure-prod-connection`

### 4. Set Up Environments (for Approvals)

1. Go to **Pipelines** > **Environments**
2. Create environments: `dev`, `staging`, `prod`
3. For `staging` and `prod`, add **Approvals and checks**

## Operations

### Update Keys in a JSON Secret

Update one or more keys inside an existing JSON secret.

```
Operation:    update
Key Vault:    kv-app-dev
Secret Name:  app-config
Key Path:     database.connection.host
Value:        newdb.server.com
```

Or use bulk updates:
```
Bulk JSON Updates: database.host=newdb.com,database.port=5432,api.key=new-key
```

### Add a New Secret

Create a brand new secret (fails if it already exists).

**Option A - Full JSON body:**
```
Operation:        add
Secret Name:      new-service-config
Full JSON Body:   {"apiUrl":"https://api.example.com","timeout":30,"auth":{"clientId":"abc","scope":"read"}}
```

**Option B - Key-value pairs:**
```
Operation:        add
Secret Name:      new-service-config
Bulk JSON Updates: apiUrl=https://api.example.com,timeout=30,auth.clientId=abc
```

### Delete a Key from JSON

Remove a specific key (including nested) from the JSON object.

```
Operation:    delete-key
Secret Name:  app-config
Key Path:     deprecated.oldSetting
```

### Revert to Previous Version

Roll back a secret to any previous version.

**Revert to the previous version:**
```
Operation:          revert
Secret Name:        app-config
Versions Back:      1
```

**Revert to a specific version:**
```
Operation:          revert
Secret Name:        app-config
Version ID:         abc123def456...
```

Use `list-versions` first to find the version ID you need.

### Backup a Secret

Create a named backup copy of the current secret value.

```
Operation:    backup
Secret Name:  app-config
Backup Name:  app-config-before-migration  (optional, auto-generated if empty)
```

### Restore from Backup

Restore a secret from a previously created backup.

```
Operation:    restore
Secret Name:  app-config
Backup Name:  app-config-before-migration
```

### List Secret Versions

View the version history of a secret.

```
Operation:      list-versions
Secret Name:    app-config
Max Versions:   10
```

### List All Secrets

List all secrets in a vault.

```
Operation:    list-secrets
Key Vault:    kv-app-dev
```

## Pipeline Parameters

| Parameter | Description | Required For | Default |
|-----------|-------------|--------------|---------|
| `operation` | Operation to perform | All | `update` |
| `keyVaultName` | Vault name (dropdown) | All | - |
| `customKeyVaultName` | Custom vault name (if not in dropdown) | - | `''` |
| `secretName` | Secret name | All except list-secrets | - |
| `keyPath` | JSON key path (dot notation) | delete-key, single update | `''` |
| `keyValue` | Value for the key | single update | `''` |
| `jsonUpdates` | Bulk key=value pairs | update, add | `''` |
| `newSecretJson` | Full JSON body | add | `''` |
| `revertVersionId` | Specific version ID | revert | `''` |
| `revertVersionsBack` | Versions back to revert | revert | `1` |
| `backupName` | Backup secret name | restore, backup | `''` |
| `supportNestedKeys` | Enable dot-notation nesting | update, add | `true` |
| `createBackup` | Auto-backup before changes | update, delete-key, revert | `true` |
| `dryRun` | Preview only, no changes | All | `false` |
| `maxVersions` | Max versions to list | list-versions | `10` |
| `targetEnvironment` | Target environment | All | `dev` |

## File Structure

```
azure-keyvault-pipeline/
├── azure-pipelines.yml                         # Main pipeline definition
├── templates/
│   ├── stages/
│   │   ├── keyvault-operation-stage.yml         # Stage template (new)
│   │   └── update-secret-stage.yml              # Legacy stage template
│   └── jobs/
│       ├── keyvault-operation-job.yml           # Job template (new)
│       └── update-secret-job.yml                # Legacy job template
├── scripts/
│   ├── Manage-KeyVaultSecret.ps1                # Unified orchestrator (new)
│   ├── Revert-KeyVaultSecret.ps1                # Version revert logic (new)
│   ├── Update-KeyVaultSecret.ps1                # Legacy update script
│   ├── Get-KeyVaultSecret.ps1                   # Fetch/list helper
│   └── Set-KeyVaultSecret.ps1                   # Set/backup/restore helper
├── configs/
│   └── environments.yml                         # Environment + vault config
└── README.md
```

## JSON Secret Structure Example

Secrets are stored as JSON objects which can be deeply nested:

```json
{
  "database": {
    "connection": {
      "host": "db.server.com",
      "port": 5432,
      "username": "app_user",
      "password": "secret123"
    },
    "poolSize": 10
  },
  "api": {
    "key": "ak_live_xxxxx",
    "endpoint": "https://api.service.com",
    "auth": {
      "clientId": "abc-123",
      "clientSecret": "cs_xxxxx",
      "scope": "read write"
    }
  },
  "featureFlags": {
    "enableCaching": true,
    "maintenanceMode": false
  }
}
```

To update the database password:
```
Key Path: database.connection.password
Value:    newSecurePassword456
```

To update multiple values:
```
Bulk JSON Updates: database.connection.host=newdb.com,api.key=ak_live_newkey,featureFlags.enableCaching=false
```

## Security Best Practices

1. **Least Privilege**: Grant only required permissions to service principals
2. **Approval Gates**: Require approvals for staging and production
3. **Dry Run First**: Preview changes before applying to production
4. **Backup Always**: Keep `createBackup` enabled for all destructive operations
5. **Audit Tags**: All operations are tagged with metadata for audit trails
6. **Value Masking**: Sensitive values are never shown in plain text in logs
7. **Version History**: Use `list-versions` to audit changes before reverting

## Troubleshooting

### Common Issues

**"Secret already exists" on add**
- Use `update` operation to modify existing secrets
- `add` is only for creating brand new secrets

**"Key does not exist" on delete-key**
- Use `list-versions` + dry-run update to inspect the JSON structure
- Check the key path uses correct dot notation

**"Cannot revert - fewer than 2 versions"**
- The secret needs at least 2 versions to revert
- Use `list-versions` to check available versions

**"Unauthorized" errors**
- Verify service connection permissions include Key Vault access
- Check RBAC roles: Key Vault Secrets Officer or equivalent

### Debug Mode

Add `-Verbose` to script arguments in the job template for detailed logging.

## License

MIT License
