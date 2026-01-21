# Azure Key Vault Pipeline - Quick Reference Guide

## 🚀 Quick Start

### Run the Pipeline

```yaml
# Minimal Example
keyVaultName: myapp-keyvault-dev
secretName: app-config
jsonUpdates: database.host=newdb.com
```

### Common Use Cases

| Use Case | Example Parameters |
|----------|-------------------|
| **Update single value** | `jsonUpdates: apiKey=new-key-123` |
| **Update nested value** | `jsonUpdates: database.connection.host=newdb.com` |
| **Update multiple values** | `jsonUpdates: host=newdb.com,port=5432,user=admin` |
| **Preview changes (dry-run)** | `dryRun: true` |
| **Target specific environment** | `targetEnvironment: prod` |
| **Update without backup** | `createBackup: false` |

---

## 📋 Parameter Reference

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `keyVaultName` | string | ✅ | - | Azure Key Vault name |
| `secretName` | string | ✅ | - | Secret to update |
| `jsonUpdates` | string | ✅ | - | Comma-separated key=value pairs |
| `supportNestedKeys` | boolean | ❌ | `true` | Enable dot notation (e.g., `a.b.c`) |
| `createBackup` | boolean | ❌ | `true` | Auto-backup before update |
| `dryRun` | boolean | ❌ | `false` | Preview mode (no changes) |
| `targetEnvironment` | string | ❌ | `''` (all) | Target: `dev`, `staging`, `prod`, or all |

---

## 🎯 Environment Matrix

```
┌─────────────┬──────────────┬────────────────────────────────┬──────────────┐
│ Environment │ Auto-Deploy  │ Approvers                      │ Timeout      │
├─────────────┼──────────────┼────────────────────────────────┼──────────────┤
│ Dev         │ ✅ Yes       │ None                           │ N/A          │
│ Staging     │ ❌ No        │ Team Leads                     │ 3 days       │
│ Production  │ ❌ No        │ Senior Engineers + Security    │ 1 day        │
└─────────────┴──────────────┴────────────────────────────────┴──────────────┘
```

---

## 🔄 Workflow Stages

```
1. VALIDATION
   ├─ Validate keyVaultName ✓
   ├─ Validate secretName ✓
   └─ Validate jsonUpdates ✓

2. DEV (if targeted)
   └─ Execute update (no approval)

3. STAGING (if targeted)
   ├─ Wait for Team Leads approval
   └─ Execute update

4. PRODUCTION (if targeted)
   ├─ Wait for Senior Engineers + Security approval
   └─ Execute update
```

---

## 🔧 JSON Update Syntax

### Simple Updates (Flat JSON)

```yaml
# Input
jsonUpdates: "apiKey=new-key-123,environment=production"

# Original JSON
{
  "apiKey": "old-key-456",
  "environment": "staging"
}

# Result
{
  "apiKey": "new-key-123",
  "environment": "production"
}
```

### Nested Updates (Hierarchical JSON)

```yaml
# Input
jsonUpdates: "database.connection.host=newdb.com,database.connection.port=5432"

# Original JSON
{
  "database": {
    "connection": {
      "host": "olddb.com",
      "port": 3306
    }
  }
}

# Result
{
  "database": {
    "connection": {
      "host": "newdb.com",
      "port": 5432
    }
  }
}
```

### Handling Special Characters

```yaml
# Quotes in values
jsonUpdates: 'message="Hello, World!",status=active'

# Commas in values (use quotes)
jsonUpdates: 'tags="azure,devops,automation",enabled=true'

# Equals signs in values (use quotes)
jsonUpdates: 'formula="a=b+c",result=42'
```

---

## 💾 Backup System

### Automatic Backups

When `createBackup = true` (default), a backup is created **before** every update:

```
Backup Name Format: {secretName}-backup-{timestamp}

Example:
Original secret: app-config
Backup created: app-config-backup-20260121-143530
```

### Backup Behavior

| Scenario | Backup Created? |
|----------|----------------|
| Normal update (`createBackup=true`, `dryRun=false`) | ✅ Yes |
| Dry-run mode (`dryRun=true`) | ❌ No |
| Backup disabled (`createBackup=false`) | ❌ No |
| Update fails | ✅ Yes (before attempt) |

### Manual Rollback

1. Find backup in Key Vault: `{secret}-backup-YYYYMMDD-HHmmss`
2. Copy backup secret value
3. Re-run pipeline to restore original secret

---

## 🧪 Dry-Run Mode

**Use dry-run to preview changes without applying them.**

```yaml
# Preview mode
dryRun: true
```

### Dry-Run Output

```
[INFO] DRY-RUN MODE: No changes will be saved to Key Vault

[INFO] Changes to be applied:
  - database.host: ol****om → ne****om
  - database.port: 33**** → 54****

[INFO] Updated JSON Preview:
{
  "database": {
    "host": "newdb.com",
    "port": 5432
  }
}

[SUCCESS] Dry-run completed successfully
```

**What happens in dry-run:**
- ✅ Fetches existing secret
- ✅ Parses JSON
- ✅ Applies updates to local copy
- ✅ Displays preview
- ❌ Does NOT create backup
- ❌ Does NOT update Key Vault

---

## 🔒 Security Features

### 1. Sensitive Value Masking

All values are masked in logs:

```
Pattern: XX****XX

Examples:
- "SuperSecretPassword123" → "Su****23"
- "api-key-abc-def-ghi" → "ap****hi"
- "true" → "tr****ue"
```

### 2. RBAC Permissions Required

Service connection identity needs:

```
Key Vault Permissions:
├─ Get (secrets)
├─ Set (secrets)
└─ List (secrets)
```

### 3. Approval Gates

| Environment | Required Approvers | Can Skip? |
|-------------|--------------------|-----------|
| Dev | None | N/A |
| Staging | Team Leads | ❌ No |
| Production | Senior Engineers + Security Team | ❌ No |

---

## 📊 Pipeline Outputs

### Pipeline Variables

After execution, these variables are set:

```yaml
SecretUpdateStatus: "Success" or "Failed"
UpdatedKeysCount: <number of keys updated>
BackupSecretName: "<backup-secret-name>" (if backup created)
```

### Log Levels

```
[INFO]     - General information
[WARNING]  - Non-critical issues
[ERROR]    - Failures
[SUCCESS]  - Successful operations
[SECTION]  - Major workflow steps
```

---

## 🛠️ Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| **Key Vault name required** | `keyVaultName` is empty | Provide valid Key Vault name |
| **Secret name required** | `secretName` is empty | Provide valid secret name |
| **Updates required** | `jsonUpdates` is empty | Provide at least one update |
| **Authentication failed** | Service connection issue | Verify service connection and RBAC |
| **Secret not found** | Secret doesn't exist | Check secret name or allow creation |
| **Invalid JSON** | Existing secret has invalid JSON | Fix JSON in Key Vault manually |
| **Approval timeout** | No approval within timeout | Re-run pipeline or adjust timeout |

### Azure CLI vs PowerShell

The pipeline uses **Azure CLI first**, then falls back to **Az PowerShell Module** if CLI fails.

```
Execution Flow:
1. Try: az keyvault secret <operation>
2. If fails: Try Az.KeyVaultSecret cmdlets
3. If both fail: Report error
```

---

## 📈 Best Practices

### ✅ DO

- ✅ Always use **dry-run first** for production
- ✅ Enable **backups** for critical secrets
- ✅ Use **descriptive secret names**
- ✅ Test in **dev** before promoting
- ✅ Use **nested keys** for complex JSON
- ✅ Review **logs** after execution
- ✅ Document **secret structure**
- ✅ Follow **approval workflows**

### ❌ DON'T

- ❌ Don't disable backups for production
- ❌ Don't skip dry-run for complex updates
- ❌ Don't update all environments without testing
- ❌ Don't ignore validation errors
- ❌ Don't use special characters in secret names
- ❌ Don't commit secrets to source control
- ❌ Don't bypass approvals
- ❌ Don't use plain text in logs (auto-masked)

---

## 🎓 Examples

### Example 1: Simple Update

```yaml
keyVaultName: myapp-keyvault-dev
secretName: api-config
jsonUpdates: apiEndpoint=https://api.newdomain.com
targetEnvironment: dev
```

### Example 2: Database Migration

```yaml
keyVaultName: myapp-keyvault-prod
secretName: database-config
jsonUpdates: connection.host=newdb.azure.com,connection.port=5432,connection.ssl=true
supportNestedKeys: true
createBackup: true
dryRun: false
targetEnvironment: prod
```

### Example 3: Multi-Environment Rollout

```yaml
# Phase 1: Dev
targetEnvironment: dev
jsonUpdates: feature.enableNewUI=true

# Phase 2: Staging (after dev success)
targetEnvironment: staging
jsonUpdates: feature.enableNewUI=true

# Phase 3: Production (after staging success)
targetEnvironment: prod
jsonUpdates: feature.enableNewUI=true
```

### Example 4: Preview Production Change

```yaml
keyVaultName: myapp-keyvault-prod
secretName: app-settings
jsonUpdates: cache.ttl=7200,cache.provider=redis
dryRun: true
targetEnvironment: prod

# Review output, then re-run with dryRun: false
```

### Example 5: API Key Rotation

```yaml
keyVaultName: myapp-keyvault-prod
secretName: external-apis
jsonUpdates: stripe.apiKey=sk_live_new_key_123,stripe.webhookSecret=whsec_new_secret_456
createBackup: true
targetEnvironment: prod
```

---

## 📞 Support

### Documentation
- **Full Documentation**: `README.md`
- **Detailed Presentation**: `PRESENTATION.md`
- **Architecture Diagrams**: `diagrams/` directory

### Reporting Issues
- **Azure DevOps**: Create work item
- **Team Contact**: DevOps team channel

---

## 📐 Naming Conventions

### Key Vault Names

```
Format: {app}-{environment}-kv

Examples:
✅ myapp-dev-kv
✅ myapp-staging-kv
✅ myapp-prod-kv

❌ MyApp_Dev_KV (no underscores)
❌ app (too short)
```

### Secret Names

```
Format: {purpose}-{type}

Examples:
✅ database-config
✅ api-keys
✅ app-settings
✅ smtp-credentials

❌ secret1 (not descriptive)
❌ db_config (no underscores)
❌ api-keys! (no special chars)
```

### Backup Names (Auto-Generated)

```
Format: {secretName}-backup-{timestamp}

Example:
app-config-backup-20260121-143530
│          │      │          │
│          │      │          └─ Time (HHmmss)
│          │      └─ Date (YYYYMMDD)
│          └─ Suffix
└─ Original secret name
```

---

## 🔍 Validation Rules

### Key Vault Name
- **Pattern**: `^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$`
- **Length**: 3-24 characters
- **Allowed**: Letters, numbers, hyphens
- **Must start**: With letter
- **Must end**: With letter or number

### Secret Name
- **Pattern**: `^[a-zA-Z][a-zA-Z0-9-]*$`
- **Length**: 1-127 characters
- **Allowed**: Letters, numbers, hyphens
- **Must start**: With letter

### Secret Size
- **Max size**: 25,600 characters
- **Format**: UTF-8 encoded

---

## ⚡ Performance

### Typical Execution Times

| Stage | Duration |
|-------|----------|
| Validation | 30s - 1m |
| Dev update | 1m - 2m |
| Staging update | 1m - 2m (+ approval wait) |
| Production update | 1m - 2m (+ approval wait) |
| **Total** | 3m - 6m (excluding approvals) |

### Resource Usage

- **Compute**: Ubuntu-latest agent (minimal)
- **Network**: Azure API calls only
- **Storage**: Backup secrets in Key Vault

---

## 🔗 Related Files

```
Repository Structure:
├── README.md                    # Main documentation
├── PRESENTATION.md              # Detailed presentation
├── QUICK-REFERENCE.md          # This file
├── azure-pipelines.yml         # Main pipeline
├── configs/
│   └── environments.yml        # Environment config
├── scripts/
│   ├── Update-KeyVaultSecret.ps1
│   ├── Get-KeyVaultSecret.ps1
│   └── Set-KeyVaultSecret.ps1
├── templates/
│   ├── stages/
│   │   └── update-secret-stage.yml
│   └── jobs/
│       └── update-secret-job.yml
└── diagrams/
    ├── architecture-overview.md
    └── workflow-flowcharts.md
```

---

**Version**: 1.0
**Last Updated**: 2026-01-21
**Repository**: azure-keyvault-pipeline
