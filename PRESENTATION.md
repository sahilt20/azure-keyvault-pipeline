# Azure Key Vault Secret Management Pipeline
## Comprehensive Technical Presentation

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [System Overview](#system-overview)
3. [Architecture & Components](#architecture--components)
4. [Key Features](#key-features)
5. [Workflow Diagrams](#workflow-diagrams)
6. [Technical Implementation](#technical-implementation)
7. [Security & Compliance](#security--compliance)
8. [Use Cases & Examples](#use-cases--examples)
9. [Deployment & Operations](#deployment--operations)

---

## Executive Summary

### What is this?
**Azure Key Vault Pipeline** is an enterprise-grade, automated pipeline framework for managing JSON-based secrets in Azure Key Vault with built-in safety controls, approval workflows, and comprehensive audit capabilities.

### Key Value Propositions
- ✅ **Safe Updates**: Dry-run mode + automatic backups before changes
- ✅ **Controlled Deployment**: Multi-environment support with approval gates
- ✅ **Developer Friendly**: Nested JSON updates using simple dot notation
- ✅ **Enterprise Ready**: Comprehensive logging, error handling, and rollback
- ✅ **Security First**: Sensitive value masking and RBAC integration

### Target Users
- **DevOps Engineers** - Automate secret rotation and updates
- **Security Teams** - Maintain control over sensitive credential changes
- **Development Teams** - Update configuration secrets across environments
- **Platform Teams** - Standardize Key Vault operations

---

## System Overview

### High-Level Architecture

```mermaid
graph TB
    subgraph "User Interface"
        A[Azure DevOps Pipeline UI]
        B[Pipeline Parameters]
    end

    subgraph "Pipeline Orchestration Layer"
        C[azure-pipelines.yml]
        D[Validation Stage]
        E1[Dev Stage]
        E2[Staging Stage]
        E3[Production Stage]
    end

    subgraph "Template Layer"
        F[update-secret-stage.yml]
        G[update-secret-job.yml]
    end

    subgraph "Execution Layer"
        H[Update-KeyVaultSecret.ps1]
        I[Get-KeyVaultSecret.ps1]
        J[Set-KeyVaultSecret.ps1]
    end

    subgraph "Azure Services"
        K[Azure Key Vault - Dev]
        L[Azure Key Vault - Staging]
        M[Azure Key Vault - Production]
        N[Service Connections]
    end

    subgraph "Configuration"
        O[environments.yml]
    end

    A --> B
    B --> C
    C --> D
    D --> E1
    E1 --> E2
    E2 --> E3

    E1 --> F
    E2 --> F
    E3 --> F

    F --> G
    G --> H
    H --> I
    H --> J

    I --> K
    I --> L
    I --> M

    J --> K
    J --> L
    J --> M

    N -.authenticates.-> K
    N -.authenticates.-> L
    N -.authenticates.-> M

    O -.configures.-> C

    style A fill:#e1f5ff
    style C fill:#ffe1e1
    style H fill:#e1ffe1
    style K fill:#f0e1ff
    style L fill:#f0e1ff
    style M fill:#f0e1ff
```

### Technology Stack

```mermaid
graph LR
    subgraph "Platform"
        A[Azure DevOps]
        B[Azure Key Vault]
    end

    subgraph "Languages"
        C[YAML]
        D[PowerShell Core]
        E[Bash]
    end

    subgraph "Tools"
        F[Azure CLI]
        G[Az PowerShell Module]
        H[Git]
    end

    A --> C
    A --> D
    A --> E

    D --> F
    D --> G

    F --> B
    G --> B

    style A fill:#0078d4
    style B fill:#0078d4
    style C fill:#ff6b6b
    style D fill:#4ecdc4
    style F fill:#95e1d3
```

---

## Architecture & Components

### Component Hierarchy

```mermaid
graph TD
    subgraph "Layer 1: Orchestration"
        A[azure-pipelines.yml<br/>Main Entry Point]
    end

    subgraph "Layer 2: Templates"
        B1[update-secret-stage.yml<br/>Stage Template]
        B2[update-secret-job.yml<br/>Job Template]
    end

    subgraph "Layer 3: Scripts"
        C1[Update-KeyVaultSecret.ps1<br/>Main Orchestrator<br/>331 lines]
        C2[Get-KeyVaultSecret.ps1<br/>Read Helper<br/>97 lines]
        C3[Set-KeyVaultSecret.ps1<br/>Write Helper<br/>205 lines]
    end

    subgraph "Layer 4: Configuration"
        D[environments.yml<br/>Environment Definitions]
    end

    subgraph "Layer 5: Azure Services"
        E1[Azure Key Vault]
        E2[Azure Environments<br/>with Approvals]
        E3[Service Connections]
    end

    A --> B1
    B1 --> B2
    B2 --> C1
    C1 --> C2
    C1 --> C3

    A -.reads.-> D
    B2 -.uses.-> E2
    B2 -.uses.-> E3
    C2 --> E1
    C3 --> E1

    style A fill:#ff6b6b
    style C1 fill:#4ecdc4
    style E1 fill:#95e1d3
```

### File Structure

```
azure-keyvault-pipeline/
│
├── 📄 azure-pipelines.yml          # Main pipeline (6.4 KB)
│   └── Parameters:
│       ├── keyVaultName
│       ├── secretName
│       ├── jsonUpdates
│       ├── supportNestedKeys (default: true)
│       ├── createBackup (default: true)
│       ├── dryRun (default: false)
│       └── targetEnvironment (default: all)
│
├── 📁 configs/
│   └── environments.yml            # Environment config
│       ├── Dev environment
│       ├── Staging environment
│       └── Production environment
│
├── 📁 scripts/
│   ├── Update-KeyVaultSecret.ps1   # Main orchestrator (331 lines)
│   │   ├── Write-LogMessage()
│   │   ├── ConvertTo-Hashtable()
│   │   ├── Set-NestedValue()
│   │   ├── Get-NestedValue()
│   │   └── Parse-JsonUpdates()
│   │
│   ├── Get-KeyVaultSecret.ps1      # Fetch helper (97 lines)
│   │   ├── Get-KeyVaultSecretValue()
│   │   └── Get-KeyVaultSecretValueAzModule()
│   │
│   └── Set-KeyVaultSecret.ps1      # Set/backup helper (205 lines)
│       ├── Set-KeyVaultSecretValue()
│       ├── Set-KeyVaultSecretValueAzModule()
│       └── Backup-KeyVaultSecret()
│
├── 📁 templates/
│   ├── stages/
│   │   └── update-secret-stage.yml # Stage template
│   └── jobs/
│       └── update-secret-job.yml   # Job template
│
└── 📄 README.md                     # Documentation (6.0 KB)
```

---

## Key Features

### 1. Runtime Parameters

```mermaid
graph LR
    A[Pipeline Parameters] --> B[keyVaultName]
    A --> C[secretName]
    A --> D[jsonUpdates]
    A --> E[supportNestedKeys]
    A --> F[createBackup]
    A --> G[dryRun]
    A --> H[targetEnvironment]

    B -.example.-> B1["my-keyvault-dev"]
    C -.example.-> C1["app-config"]
    D -.example.-> D1["db.host=new.server,db.port=5432"]
    E -.default.-> E1[true]
    F -.default.-> F1[true]
    G -.default.-> G1[false]
    H -.default.-> H1[all environments]

    style A fill:#ff6b6b
    style E fill:#4ecdc4
    style F fill:#4ecdc4
    style G fill:#4ecdc4
    style H fill:#4ecdc4
```

### 2. Multi-Environment Support

```mermaid
graph LR
    A[Target Environment] --> B{Selection}
    B -->|all or dev| C[Dev Environment]
    B -->|all or staging| D[Staging Environment]
    B -->|all or prod| E[Production Environment]

    C --> C1[No Approval Required]
    D --> D1[Team Leads Approval<br/>3-day timeout]
    E --> E1[Senior Engineers +<br/>Security Team Approval<br/>1-day timeout]

    C1 --> F[Execute Update]
    D1 --> F
    E1 --> F

    style C fill:#95e1d3
    style D fill:#ffd93d
    style E fill:#ff6b6b
    style D1 fill:#ffd93d
    style E1 fill:#ff6b6b
```

### 3. Nested JSON Updates

```mermaid
graph TD
    A[Input: database.connection.host=newdb.com] --> B[Parse Update String]
    B --> C{Nested Keys<br/>Supported?}

    C -->|Yes| D[Split by Dots]
    D --> E[Navigate: database]
    E --> F[Navigate: connection]
    F --> G[Set: host = newdb.com]

    C -->|No| H[Direct Property Assignment]

    G --> I[Updated JSON Structure]
    H --> I

    style A fill:#e1f5ff
    style G fill:#95e1d3
    style I fill:#4ecdc4
```

**Example Transformation:**

**Before:**
```json
{
  "database": {
    "connection": {
      "host": "olddb.server.com",
      "port": 3306,
      "username": "dbuser"
    },
    "pool": {
      "maxConnections": 10
    }
  }
}
```

**Update:** `database.connection.host=newdb.server.com,database.connection.port=5432`

**After:**
```json
{
  "database": {
    "connection": {
      "host": "newdb.server.com",
      "port": 5432,
      "username": "dbuser"
    },
    "pool": {
      "maxConnections": 10
    }
  }
}
```

### 4. Automatic Backup System

```mermaid
sequenceDiagram
    participant P as Pipeline
    participant S as Script
    participant KV as Key Vault

    P->>S: Execute Update (createBackup=true)
    S->>KV: Fetch existing secret
    KV-->>S: Return current value

    alt Backup Enabled & Not Dry-Run
        S->>S: Generate backup name<br/>(secret-backup-YYYYMMDD-HHmmss)
        S->>KV: Create backup secret
        KV-->>S: Backup created
    end

    S->>S: Apply updates
    S->>KV: Update original secret
    KV-->>S: Update complete
    S-->>P: Success + backup info
```

### 5. Dry-Run Mode

```mermaid
graph TD
    A[Start Pipeline<br/>dryRun = true] --> B[Fetch Existing Secret]
    B --> C[Parse JSON]
    C --> D[Apply Updates to Copy]
    D --> E[Display Changes Preview]
    E --> F[Show Updated JSON]
    F --> G{User Reviews}

    G -->|Satisfied| H[Re-run with dryRun=false]
    G -->|Need Changes| I[Adjust Parameters]

    H --> J[Actual Update Executes]
    I --> A

    style A fill:#ffd93d
    style E fill:#4ecdc4
    style F fill:#4ecdc4
    style J fill:#95e1d3

    Note right of F: No actual changes<br/>made to Key Vault
```

---

## Workflow Diagrams

### Complete Pipeline Execution Flow

```mermaid
graph TB
    Start([User Triggers Pipeline]) --> Input[Collect Parameters:<br/>- keyVaultName<br/>- secretName<br/>- jsonUpdates<br/>- supportNestedKeys<br/>- createBackup<br/>- dryRun<br/>- targetEnvironment]

    Input --> Validate{Validation Stage}

    Validate -->|keyVaultName empty| Fail1[❌ Fail: Missing Vault Name]
    Validate -->|secretName empty| Fail2[❌ Fail: Missing Secret Name]
    Validate -->|jsonUpdates empty| Fail3[❌ Fail: Missing Updates]
    Validate -->|All valid| Route{Route to<br/>Environments}

    Route -->|all or dev| Dev[Dev Stage]
    Route -->|all or staging| Staging[Staging Stage]
    Route -->|all or prod| Prod[Production Stage]

    Dev --> DevJob[Execute Update Job]
    Staging --> StagingApproval{Approval Gate:<br/>Team Leads}
    Prod --> ProdApproval{Approval Gate:<br/>Senior Engineers<br/>+ Security Team}

    StagingApproval -->|Approved| StagingJob[Execute Update Job]
    StagingApproval -->|Rejected| StagingFail[❌ Rejected]
    StagingApproval -->|Timeout| StagingTimeout[❌ Timeout: 3 days]

    ProdApproval -->|Approved| ProdJob[Execute Update Job]
    ProdApproval -->|Rejected| ProdFail[❌ Rejected]
    ProdApproval -->|Timeout| ProdTimeout[❌ Timeout: 1 day]

    DevJob --> DevUpdate[Update Dev Key Vault]
    StagingJob --> StagingUpdate[Update Staging Key Vault]
    ProdJob --> ProdUpdate[Update Prod Key Vault]

    DevUpdate --> Success1[✅ Dev Complete]
    StagingUpdate --> Success2[✅ Staging Complete]
    ProdUpdate --> Success3[✅ Production Complete]

    Success1 --> End([Pipeline Complete])
    Success2 --> End
    Success3 --> End

    style Start fill:#e1f5ff
    style Validate fill:#ffd93d
    style Dev fill:#95e1d3
    style Staging fill:#ffd93d
    style Prod fill:#ff6b6b
    style End fill:#4ecdc4
    style Fail1 fill:#ff6b6b
    style Fail2 fill:#ff6b6b
    style Fail3 fill:#ff6b6b
```

### Secret Update Process (Detailed)

```mermaid
graph TB
    Start([Start Update-KeyVaultSecret.ps1]) --> Init[Initialize:<br/>- Parse parameters<br/>- Set error handling<br/>- Start logging]

    Init --> Parse[Parse jsonUpdates:<br/>Split by comma<br/>Handle quoted values<br/>Validate format]

    Parse --> Fetch{Fetch Existing<br/>Secret}

    Fetch -->|Azure CLI| FetchCLI[az keyvault secret show]
    Fetch -->|Fallback| FetchPS[Az.KeyVault module]

    FetchCLI --> ParseJSON[Parse JSON Content<br/>to PSCustomObject]
    FetchPS --> ParseJSON

    ParseJSON --> Convert[Convert to<br/>Hashtable]

    Convert --> CheckBackup{Backup<br/>Enabled?}

    CheckBackup -->|Yes + Not Dry-Run| CreateBackup[Create Backup:<br/>secret-backup-timestamp]
    CheckBackup -->|No or Dry-Run| ApplyUpdates

    CreateBackup --> ApplyUpdates[Apply Updates:<br/>For each key-value pair]

    ApplyUpdates --> Nested{Nested Keys<br/>Supported?}

    Nested -->|Yes + Contains dots| UseNested[Use Set-NestedValue:<br/>Navigate hierarchy<br/>Update leaf value]
    Nested -->|No or Simple key| UseDirect[Direct Assignment:<br/>hashtable[key] = value]

    UseNested --> Track[Track Changes:<br/>Store old/new values<br/>Mask sensitive data]
    UseDirect --> Track

    Track --> Preview[Display Changes Preview:<br/>key: old**** → new****]

    Preview --> CheckDryRun{Dry-Run<br/>Mode?}

    CheckDryRun -->|Yes| ShowJSON[Show Updated JSON<br/>Exit without saving]
    CheckDryRun -->|No| ConvertJSON[Convert Hashtable<br/>to JSON String]

    ConvertJSON --> SetSecret{Update Secret<br/>in Key Vault}

    SetSecret -->|Azure CLI| SetCLI[az keyvault secret set]
    SetSecret -->|Fallback| SetPS[Az.KeyVault module]

    SetCLI --> SetVars[Set Pipeline Variables:<br/>- SecretUpdateStatus<br/>- UpdatedKeysCount]
    SetPS --> SetVars

    SetVars --> Success[✅ Log Success<br/>Return 0]

    ShowJSON --> DryRunSuccess[✅ Dry-run Complete<br/>Return 0]

    Success --> End([End])
    DryRunSuccess --> End

    ParseJSON -.error.-> ErrorHandle[❌ Error Handler:<br/>Log error details<br/>Return 1]
    ApplyUpdates -.error.-> ErrorHandle
    SetSecret -.error.-> ErrorHandle

    ErrorHandle --> End

    style Start fill:#e1f5ff
    style CreateBackup fill:#ffd93d
    style CheckDryRun fill:#ffd93d
    style ShowJSON fill:#4ecdc4
    style Success fill:#95e1d3
    style ErrorHandle fill:#ff6b6b
```

### Error Handling & Fallback Strategy

```mermaid
graph TD
    A[Azure Operation Needed] --> B{Try Azure CLI}

    B -->|Success| C[✅ Operation Complete]
    B -->|Failure| D{Check Error Type}

    D -->|Command Not Found| E[Install Azure CLI]
    D -->|Authentication Failed| F[Check Service Connection]
    D -->|Other Error| G{Fallback to<br/>Az PowerShell Module}

    G -->|Module Available| H[Execute via Az.KeyVault]
    G -->|Module Missing| I[Install Az.KeyVault Module]

    H -->|Success| C
    H -->|Failure| J[❌ Log Detailed Error<br/>Exit 1]

    I --> H
    E --> B
    F --> K[❌ Authentication Issue<br/>Exit 1]

    style A fill:#e1f5ff
    style B fill:#ffd93d
    style C fill:#95e1d3
    style G fill:#ffd93d
    style J fill:#ff6b6b
    style K fill:#ff6b6b
```

### Approval Workflow

```mermaid
sequenceDiagram
    participant D as DevOps Engineer
    participant P as Pipeline
    participant E as Azure Environment
    participant A as Approvers
    participant KV as Key Vault

    D->>P: Trigger pipeline<br/>(targetEnvironment=prod)
    P->>P: Validation stage

    alt Target includes Dev
        P->>KV: Update Dev Key Vault
        Note over P,KV: No approval needed
    end

    alt Target includes Staging
        P->>E: Request Staging deployment
        E->>A: Notify Team Leads

        alt Approved
            A->>E: Approve deployment
            E->>P: Approval granted
            P->>KV: Update Staging Key Vault
        else Rejected
            A->>E: Reject deployment
            E->>P: Approval denied
            P->>D: ❌ Staging failed
        else Timeout (3 days)
            E->>P: Timeout
            P->>D: ❌ Approval timeout
        end
    end

    alt Target includes Production
        P->>E: Request Production deployment
        E->>A: Notify Senior Engineers<br/>+ Security Team

        alt Approved
            A->>E: Approve deployment
            E->>P: Approval granted
            P->>KV: Update Production Key Vault
        else Rejected
            A->>E: Reject deployment
            E->>P: Approval denied
            P->>D: ❌ Production failed
        else Timeout (1 day)
            E->>P: Timeout
            P->>D: ❌ Approval timeout
        end
    end

    P->>D: ✅ Pipeline complete
```

---

## Technical Implementation

### PowerShell Functions Overview

#### 1. Update-KeyVaultSecret.ps1

```mermaid
graph LR
    subgraph "Main Script Functions"
        A[Write-LogMessage]
        B[ConvertTo-Hashtable]
        C[Set-NestedValue]
        D[Get-NestedValue]
        E[Parse-JsonUpdates]
    end

    A -.used by.-> F[Main Logic]
    B -.used by.-> F
    C -.used by.-> F
    D -.used by.-> F
    E -.used by.-> F

    style F fill:#4ecdc4
```

**Function Details:**

| Function | Purpose | Key Features |
|----------|---------|--------------|
| `Write-LogMessage` | Formatted console logging | Supports levels: Info, Warning, Error, Success, Section |
| `ConvertTo-Hashtable` | Convert PSObject to hashtable | Recursive for nested objects |
| `Set-NestedValue` | Update nested property | Uses dot notation (e.g., "a.b.c") |
| `Get-NestedValue` | Retrieve nested property | Safe navigation with null checks |
| `Parse-JsonUpdates` | Parse CSV updates | Handles quotes in values |

#### 2. Get-KeyVaultSecret.ps1

```mermaid
graph TD
    A[Get-KeyVaultSecretValue] --> B{Try Azure CLI}
    B -->|Success| C[Return Secret Value]
    B -->|Failure| D[Get-KeyVaultSecretValueAzModule]
    D --> E{Try Az.KeyVault}
    E -->|Success| C
    E -->|Failure| F[Return null/<br/>Throw Error]

    style A fill:#e1f5ff
    style C fill:#95e1d3
    style F fill:#ff6b6b
```

#### 3. Set-KeyVaultSecret.ps1

```mermaid
graph TD
    A[Set-KeyVaultSecretValue] --> B{Try Azure CLI}
    B -->|Success| C[Secret Updated]
    B -->|Failure| D[Set-KeyVaultSecretValueAzModule]
    D --> E{Try Az.KeyVault}
    E -->|Success| C
    E -->|Failure| F[Throw Error]

    G[Backup-KeyVaultSecret] --> H[Generate Backup Name:<br/>secret-backup-timestamp]
    H --> I[Call Set-KeyVaultSecretValue<br/>with original content]
    I --> J[Backup Created]

    style A fill:#e1f5ff
    style C fill:#95e1d3
    style F fill:#ff6b6b
    style G fill:#ffd93d
```

### Data Flow

```mermaid
graph LR
    A[User Input:<br/>jsonUpdates] --> B[Parse-JsonUpdates]
    B --> C[Key-Value Pairs<br/>Hashtable]

    D[Azure Key Vault] --> E[Get-KeyVaultSecret]
    E --> F[JSON String]
    F --> G[ConvertFrom-Json]
    G --> H[PSCustomObject]
    H --> I[ConvertTo-Hashtable]
    I --> J[Editable Hashtable]

    C --> K[Apply Updates]
    J --> K

    K --> L{Nested Key?}
    L -->|Yes| M[Set-NestedValue]
    L -->|No| N[Direct Assignment]

    M --> O[Modified Hashtable]
    N --> O

    O --> P[ConvertTo-Json]
    P --> Q[JSON String]
    Q --> R[Set-KeyVaultSecret]
    R --> S[Azure Key Vault<br/>Updated]

    style A fill:#e1f5ff
    style D fill:#ffd93d
    style S fill:#95e1d3
```

---

## Security & Compliance

### Security Features

```mermaid
graph TB
    subgraph "Authentication & Authorization"
        A[Azure Service Connections<br/>with Managed Identity]
        B[Role-Based Access Control<br/>RBAC]
        C[Key Vault Access Policies]
    end

    subgraph "Approval Controls"
        D[Environment-Based<br/>Approval Gates]
        E[Multi-Approver<br/>Requirements]
        F[Timeout Policies]
    end

    subgraph "Data Protection"
        G[Sensitive Value Masking<br/>in Logs]
        H[Automatic Backups<br/>Before Changes]
        I[Dry-Run Preview<br/>Mode]
    end

    subgraph "Audit & Compliance"
        J[Comprehensive Logging]
        K[Change Tracking]
        L[Error Reporting]
    end

    A --> M[Secure Secret Access]
    B --> M
    C --> M

    D --> N[Controlled Deployments]
    E --> N
    F --> N

    G --> O[Data Security]
    H --> O
    I --> O

    J --> P[Audit Trail]
    K --> P
    L --> P

    M --> Q[Enterprise Security]
    N --> Q
    O --> Q
    P --> Q

    style Q fill:#95e1d3
```

### Sensitive Value Masking

**Implementation:**
```
Original Value: "SuperSecretPassword123!"
Masked in Logs: "Su****3!"
```

**Pattern:** First 2 characters + **** + Last 2 characters

**Example Log Output:**
```
[INFO] Updating key 'database.password'
  Old value: ol****rd
  New value: ne****rd
```

### Approval Matrix

| Environment | Approvers | Timeout | Auto-Approve |
|-------------|-----------|---------|--------------|
| **Dev** | None | N/A | ✅ Yes |
| **Staging** | Team Leads | 3 days | ❌ No |
| **Production** | Senior Engineers + Security Team | 1 day | ❌ No |

### RBAC Requirements

```mermaid
graph TD
    subgraph "Key Vault Permissions"
        A[Service Connection Identity]
        B[Get Secret Permission]
        C[Set Secret Permission]
        D[List Secrets Permission]
    end

    A --> B
    A --> C
    A --> D

    E[Pipeline Execution] --> A

    F{Environment}
    F -->|Dev| G[Minimal Oversight]
    F -->|Staging| H[Approval Required]
    F -->|Production| I[Strict Approval<br/>+ Audit]

    style A fill:#e1f5ff
    style I fill:#ff6b6b
```

---

## Use Cases & Examples

### Use Case 1: Database Connection Update

**Scenario:** Update database connection string across all environments

**Parameters:**
```yaml
keyVaultName: 'myapp-keyvault-$(environment)'
secretName: 'database-config'
jsonUpdates: 'connection.host=newdb.azure.com,connection.port=5432'
supportNestedKeys: true
createBackup: true
dryRun: false
targetEnvironment: 'all'
```

**Before:**
```json
{
  "connection": {
    "host": "olddb.azure.com",
    "port": 3306,
    "database": "appdb",
    "username": "dbuser"
  }
}
```

**After:**
```json
{
  "connection": {
    "host": "newdb.azure.com",
    "port": 5432,
    "database": "appdb",
    "username": "dbuser"
  }
}
```

**Execution Flow:**
1. Dev → Updated immediately (no approval)
2. Staging → Pending approval from Team Leads
3. Production → Pending approval from Senior Engineers + Security

---

### Use Case 2: API Key Rotation

**Scenario:** Rotate third-party API key in production only

**Parameters:**
```yaml
keyVaultName: 'myapp-keyvault-prod'
secretName: 'external-api-config'
jsonUpdates: 'apiKey=new-api-key-12345,apiSecret=new-secret-67890'
supportNestedKeys: false
createBackup: true
dryRun: false
targetEnvironment: 'prod'
```

**Process:**
1. Pipeline requests production deployment
2. Senior Engineers + Security Team notified
3. Approval granted
4. Backup created: `external-api-config-backup-20260121-143022`
5. Secret updated with new credentials
6. Old backup retained for rollback

---

### Use Case 3: Configuration Preview (Dry-Run)

**Scenario:** Preview changes before applying to production

**Parameters:**
```yaml
keyVaultName: 'myapp-keyvault-prod'
secretName: 'app-settings'
jsonUpdates: 'features.enableNewUI=true,features.enableBetaFeatures=false'
supportNestedKeys: true
createBackup: true
dryRun: true
targetEnvironment: 'prod'
```

**Output:**
```
[INFO] DRY-RUN MODE: No changes will be saved to Key Vault

[INFO] Proposed changes:
  - features.enableNewUI: fa**** → tr****
  - features.enableBetaFeatures: tr**** → fa****

[INFO] Updated JSON Preview:
{
  "features": {
    "enableNewUI": true,
    "enableBetaFeatures": false,
    "maxUsers": 1000
  }
}

[SUCCESS] Dry-run completed successfully
```

---

### Use Case 4: Multi-Key Update

**Scenario:** Update multiple configuration values in one operation

**Parameters:**
```yaml
keyVaultName: 'myapp-keyvault-staging'
secretName: 'service-config'
jsonUpdates: 'smtp.host=smtp.newprovider.com,smtp.port=587,smtp.encryption=tls,cache.ttl=3600'
supportNestedKeys: true
createBackup: true
dryRun: false
targetEnvironment: 'staging'
```

**Updates Applied:**
- `smtp.host` → smtp.newprovider.com
- `smtp.port` → 587
- `smtp.encryption` → tls
- `cache.ttl` → 3600

**Result:** 4 keys updated in single atomic operation

---

## Deployment & Operations

### Initial Setup

```mermaid
graph TD
    A[1. Create Azure Key Vaults] --> B[One per environment:<br/>- dev-keyvault<br/>- staging-keyvault<br/>- prod-keyvault]

    B --> C[2. Configure Service Connections]
    C --> D[Create in Azure DevOps:<br/>- dev-connection<br/>- staging-connection<br/>- prod-connection]

    D --> E[3. Set up Environments]
    E --> F[Configure Azure DevOps Environments:<br/>- dev no approvals<br/>- staging Team Leads approval<br/>- prod Senior + Security approval]

    F --> G[4. Grant Permissions]
    G --> H[Assign RBAC to Service Connections:<br/>- Get Secret<br/>- Set Secret<br/>- List Secrets]

    H --> I[5. Import Pipeline]
    I --> J[Add azure-pipelines.yml<br/>to Azure DevOps]

    J --> K[6. Configure Variables]
    K --> L[Set pipeline variables if needed]

    L --> M[✅ Ready to Use]

    style A fill:#e1f5ff
    style M fill:#95e1d3
```

### Running the Pipeline

**Step-by-Step:**

1. **Navigate to Pipelines** in Azure DevOps
2. **Select** the Azure Key Vault Pipeline
3. **Click "Run pipeline"**
4. **Fill Parameters:**
   - Key Vault Name: `myapp-keyvault-dev`
   - Secret Name: `app-config`
   - JSON Updates: `db.host=newdb.com,db.port=5432`
   - Support Nested Keys: ✅ (checked)
   - Create Backup: ✅ (checked)
   - Dry Run: ☐ (unchecked)
   - Target Environment: `all`
5. **Click "Run"**

**Pipeline Execution:**
```
✅ Validation (1 min)
    ├─ Validate keyVaultName: ✓
    ├─ Validate secretName: ✓
    └─ Validate jsonUpdates: ✓

✅ Update_dev (2 min)
    ├─ Fetch secret from dev-keyvault: ✓
    ├─ Create backup: ✓
    ├─ Apply 2 updates: ✓
    └─ Update secret: ✓

⏸️  Update_staging (pending approval)
    └─ Waiting for Team Leads approval...

⏸️  Update_prod (pending approval)
    └─ Waiting for Senior Engineers + Security approval...
```

### Monitoring & Logging

**Log Levels:**
- `[INFO]` - General information
- `[WARNING]` - Non-critical issues
- `[ERROR]` - Failures requiring attention
- `[SUCCESS]` - Successful operations
- `[SECTION]` - Major workflow steps

**Example Log:**
```
============================================================
[SECTION] Azure Key Vault Secret Update
============================================================
[INFO] Environment: staging
[INFO] Key Vault: myapp-keyvault-staging
[INFO] Secret Name: database-config
[INFO] Support Nested Keys: True
[INFO] Create Backup: True
[INFO] Dry-Run Mode: False
============================================================

[INFO] Parsing JSON updates...
[INFO] Found 2 update(s) to apply

[INFO] Fetching existing secret 'database-config' from Key Vault...
[SUCCESS] Secret retrieved successfully

[INFO] Creating backup before update...
[SUCCESS] Backup created: database-config-backup-20260121-143530

[INFO] Applying updates to JSON structure...

[INFO] Changes to be applied:
  - connection.host: ol****om → ne****om
  - connection.port: 33**** → 54****

[INFO] Updating secret 'database-config' in Key Vault...
[SUCCESS] Secret updated successfully in Key Vault

============================================================
[SUCCESS] Secret update completed successfully
[INFO] Updated keys: 2
[INFO] Backup available at: database-config-backup-20260121-143530
============================================================
```

### Rollback Procedure

**If update causes issues:**

```mermaid
graph TD
    A[Issue Detected] --> B{Backup Available?}

    B -->|Yes| C[Identify Backup Secret<br/>secret-backup-timestamp]
    B -->|No| D[Manual Rollback Required]

    C --> E[Run Pipeline Again]
    E --> F[Parameters:<br/>- secretName: original-secret<br/>- jsonUpdates: copy from backup<br/>- createBackup: true]

    F --> G[Execute Update]
    G --> H[Verify Rollback]

    H -->|Success| I[✅ Rollback Complete]
    H -->|Failure| J[❌ Manual Intervention]

    D --> K[Contact Key Vault Admin]

    style A fill:#ff6b6b
    style I fill:#95e1d3
    style J fill:#ff6b6b
```

**Quick Rollback Command:**
1. Find backup secret in Key Vault: `secret-backup-YYYYMMDD-HHmmss`
2. Copy the backup secret value
3. Re-run pipeline to restore:
   - Parse backup JSON
   - Create update string from backup
   - Apply to original secret

---

## Best Practices

### ✅ DO's

1. **Always use dry-run first** for production changes
2. **Enable backups** for all critical secrets
3. **Use descriptive secret names** (e.g., `database-config`, not `secret1`)
4. **Follow naming conventions** for Key Vaults per environment
5. **Review approval notifications** promptly to avoid timeouts
6. **Document secret structure** in team documentation
7. **Test in dev** before promoting to staging/production
8. **Use nested keys** for complex JSON structures

### ❌ DON'Ts

1. **Don't disable backups** for production updates
2. **Don't skip dry-run** for complex updates
3. **Don't use plain text** in pipeline logs (masking is automatic)
4. **Don't update all environments** without testing dev first
5. **Don't ignore validation errors**
6. **Don't use special characters** in secret names (use `-` only)
7. **Don't commit secrets** to source control
8. **Don't bypass approvals** for production

---

## Performance Metrics

### Typical Execution Times

| Stage | Duration | Notes |
|-------|----------|-------|
| Validation | 30s - 1m | Parameter validation |
| Dev Update | 1m - 2m | No approval wait |
| Staging Update | 1m - 2m + approval time | Depends on approvers |
| Production Update | 1m - 2m + approval time | Depends on approvers |
| **Total (all environments)** | 3m - 6m + approvals | Excluding approval delays |

### Resource Usage

- **Compute:** Ubuntu-latest agent (minimal CPU/memory)
- **Network:** Azure CLI calls to Key Vault API
- **Storage:** Backup secrets (count depends on frequency)

---

## Troubleshooting Guide

### Common Issues

```mermaid
graph TD
    A{Issue Type} --> B[Authentication Failure]
    A --> C[Secret Not Found]
    A --> D[JSON Parse Error]
    A --> E[Approval Timeout]

    B --> B1[✓ Check service connection<br/>✓ Verify RBAC permissions<br/>✓ Check Key Vault access policy]

    C --> C1[✓ Verify secret name spelling<br/>✓ Check Key Vault name<br/>✓ Ensure secret exists]

    D --> D1[✓ Validate JSON format<br/>✓ Check for trailing commas<br/>✓ Verify escape characters]

    E --> E1[✓ Notify approvers<br/>✓ Check environment settings<br/>✓ Re-run pipeline]

    style B fill:#ff6b6b
    style C fill:#ff6b6b
    style D fill:#ff6b6b
    style E fill:#ffd93d
```

---

## Future Enhancements

### Potential Features

1. **Secret Rotation Schedules** - Automated periodic updates
2. **Multi-Secret Updates** - Batch update multiple secrets
3. **Rollback Automation** - One-click rollback to previous version
4. **Secret Validation** - JSON schema validation before update
5. **Notification Integration** - Teams/Slack notifications
6. **Audit Dashboard** - Centralized change tracking UI
7. **Secret Versioning UI** - Browse and compare secret versions
8. **Template Library** - Pre-built update templates

---

## Conclusion

### Key Takeaways

✅ **Enterprise-Ready**: Production-grade security and controls
✅ **Developer-Friendly**: Simple parameter-based interface
✅ **Safe Operations**: Dry-run mode + automatic backups
✅ **Compliance-Focused**: Approval gates + comprehensive logging
✅ **Flexible**: Supports simple and complex JSON updates

### Success Metrics

- **~600 lines of code** - Comprehensive but maintainable
- **Multi-environment support** - Dev, Staging, Production
- **Nested JSON updates** - Complex configuration management
- **Automatic backups** - Safety-first approach
- **Approval workflows** - Enterprise compliance

### Contact & Support

- **Documentation:** README.md in repository
- **Issues:** Report via Azure DevOps feedback
- **Contributions:** Follow standard PR process

---

## Appendix: Reference Materials

### A. Parameter Reference

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `keyVaultName` | string | ✅ Yes | - | Target Azure Key Vault name |
| `secretName` | string | ✅ Yes | - | Name of the secret to update |
| `jsonUpdates` | string | ✅ Yes | - | CSV format: key1=value1,key2=value2 |
| `supportNestedKeys` | boolean | ❌ No | true | Enable dot notation for nested keys |
| `createBackup` | boolean | ❌ No | true | Create backup before update |
| `dryRun` | boolean | ❌ No | false | Preview mode (no actual changes) |
| `targetEnvironment` | string | ❌ No | '' (all) | Environment: dev, staging, prod, or all |

### B. Environment Configuration Schema

```yaml
environments:
  - name: dev
    displayName: Development
    serviceConnection: azure-dev-connection
    approvalRequired: false

  - name: staging
    displayName: Staging
    serviceConnection: azure-staging-connection
    approvalRequired: true
    approvers:
      - team-leads
    timeout: 3 days

  - name: prod
    displayName: Production
    serviceConnection: azure-prod-connection
    approvalRequired: true
    approvers:
      - senior-engineers
      - security-team
    timeout: 1 day

validation:
  keyVaultNameRegex: '^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$'
  secretNameRegex: '^[a-zA-Z][a-zA-Z0-9-]*$'
  maxSecretSize: 25600
```

### C. Script Functions API

#### Update-KeyVaultSecret.ps1

```powershell
# Write-LogMessage -Message "text" -Level "Info|Warning|Error|Success|Section"
# ConvertTo-Hashtable -InputObject $psObject
# Set-NestedValue -Hashtable $hash -Path "a.b.c" -Value "newValue"
# Get-NestedValue -Hashtable $hash -Path "a.b.c"
# Parse-JsonUpdates -UpdatesString "key1=value1,key2=value2"
```

#### Get-KeyVaultSecret.ps1

```powershell
# Get-KeyVaultSecretValue -VaultName "vault" -SecretName "secret"
# Get-KeyVaultSecretValueAzModule -VaultName "vault" -SecretName "secret"
```

#### Set-KeyVaultSecret.ps1

```powershell
# Set-KeyVaultSecretValue -VaultName "vault" -SecretName "secret" -Value "json"
# Set-KeyVaultSecretValueAzModule -VaultName "vault" -SecretName "secret" -Value "json"
# Backup-KeyVaultSecret -VaultName "vault" -SecretName "secret" -SecretValue "json"
```

---

**End of Presentation**

*Generated: 2026-01-21*
*Repository: azure-keyvault-pipeline*
*Version: 1.0*
