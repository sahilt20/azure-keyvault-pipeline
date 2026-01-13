# Azure Key Vault Secret Update Pipeline

A robust Azure DevOps YAML pipeline framework for updating JSON-based secrets in Azure Key Vault with user inputs, approval gates, and comprehensive error handling.

## Features

- ✅ **Runtime Parameters**: Accept user input for Key Vault name, secret name, and JSON updates
- ✅ **Multi-Environment Support**: Deploy across Dev, Staging, and Production with environment-specific configurations
- ✅ **Approval Gates**: Environment-based approvals using Azure DevOps Environments
- ✅ **Nested JSON Support**: Update nested keys using dot notation (e.g., `database.connection.host`)
- ✅ **Backup Creation**: Automatic backup of secrets before updates
- ✅ **Dry Run Mode**: Preview changes without modifying secrets
- ✅ **Comprehensive Logging**: Masked sensitive values with detailed audit trail
- ✅ **Error Handling**: Robust try-catch with rollback capabilities

## Prerequisites

1. **Azure DevOps Project** with Pipelines enabled
2. **Azure Subscription** with Key Vault(s) configured
3. **Service Connection** to Azure with Key Vault access permissions:
   - `Microsoft.KeyVault/vaults/secrets/read`
   - `Microsoft.KeyVault/vaults/secrets/write`
4. **Azure DevOps Environments** configured for approvals (optional)

## Quick Start

### 1. Import the Pipeline

1. Copy this repository to your Azure DevOps project
2. Navigate to **Pipelines** > **New Pipeline**
3. Select your repository and choose "Existing Azure Pipelines YAML file"
4. Select `/azure-pipelines.yml`

### 2. Configure Service Connections

Create Azure Resource Manager service connections for each environment:

1. Go to **Project Settings** > **Service connections**
2. Create connections named:
   - `azure-dev-connection`
   - `azure-staging-connection`
   - `azure-prod-connection`

### 3. Set Up Environments (for Approvals)

1. Go to **Pipelines** > **Environments**
2. Create environments: `dev`, `staging`, `prod`
3. For `staging` and `prod`, add **Approvals and checks**:
   - Click on the environment
   - Go to **Approvals and checks**
   - Add **Approvals** and specify approvers

### 4. Run the Pipeline

1. Navigate to your pipeline
2. Click **Run pipeline**
3. Fill in the parameters:
   - **Key Vault Name**: e.g., `my-keyvault`
   - **Secret Name**: e.g., `app-config`
   - **JSON Updates**: e.g., `apiKey=newValue,database.host=newserver.com`

## Usage Examples

### Basic Update

Update a single key in a JSON secret:

```
Key Vault Name: my-keyvault
Secret Name: app-settings
JSON Updates: apiKey=new-api-key-value
```

### Multiple Updates

Update multiple keys:

```
JSON Updates: apiKey=newkey123,environment=production,feature.enabled=true
```

### Nested Key Updates

Update nested JSON properties using dot notation:

```
JSON Updates: database.connection.host=newdb.server.com,database.connection.port=5432
```

**Before:**
```json
{
  "database": {
    "connection": {
      "host": "olddb.server.com",
      "port": 3306
    }
  }
}
```

**After:**
```json
{
  "database": {
    "connection": {
      "host": "newdb.server.com",
      "port": "5432"
    }
  }
}
```

### Dry Run Mode

Preview changes without modifying the secret:

1. Check **Dry Run (Preview Changes Only)** when running the pipeline
2. Review the output to see what would be changed

### Target Specific Environment

To run only on a specific environment (skip others):

```
Target Specific Environment: prod
```

## Pipeline Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `keyVaultName` | Name of the Azure Key Vault | Yes | - |
| `secretName` | Name of the secret to update | Yes | - |
| `jsonUpdates` | Key-value pairs (format: `key1=value1,key2=value2`) | Yes | - |
| `supportNestedKeys` | Enable nested key updates with dot notation | No | `true` |
| `createBackup` | Create backup before updating | No | `true` |
| `dryRun` | Preview changes only | No | `false` |
| `targetEnvironment` | Run on specific environment only | No | `` (all) |

## File Structure

```
azure-keyvault-pipeline/
├── azure-pipelines.yml           # Main pipeline definition
├── templates/
│   ├── stages/
│   │   └── update-secret-stage.yml   # Stage template
│   └── jobs/
│       └── update-secret-job.yml     # Job template with deployment
├── scripts/
│   ├── Update-KeyVaultSecret.ps1     # Main orchestration script
│   ├── Get-KeyVaultSecret.ps1        # Fetch secret helper
│   └── Set-KeyVaultSecret.ps1        # Set secret helper
├── configs/
│   └── environments.yml              # Environment configurations
└── README.md                         # This file
```

## Security Best Practices

1. **Least Privilege**: Grant minimal required permissions to service principals
2. **Audit Logging**: All operations are logged with masked sensitive values
3. **Approval Gates**: Require approvals for staging and production changes
4. **Backup Before Update**: Always enable backup creation for production
5. **Dry Run First**: Use dry run mode to preview changes before applying

## Troubleshooting

### Common Issues

**"SecretNotFound" Error**
- Verify the secret name is correct
- Check service principal has read permissions on Key Vault

**"Unauthorized" Error**
- Verify service connection is configured correctly
- Check service principal has Key Vault access policies or RBAC roles

**"Invalid JSON" Error**
- Ensure the existing secret contains valid JSON
- Check for special characters in values (use quotes if needed)

### Debug Mode

Add `-Verbose` to the PowerShell script for detailed logging:

```yaml
arguments: >-
  -KeyVaultName "${{ parameters.keyVaultName }}"
  -SecretName "${{ parameters.secretName }}"
  -Verbose
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Test with dry run mode
4. Submit a pull request

## License

MIT License - See [LICENSE](LICENSE) for details.
