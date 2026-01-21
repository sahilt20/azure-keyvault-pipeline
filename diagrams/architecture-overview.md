# Architecture Overview Diagram

## System Architecture

```mermaid
C4Context
    title System Context Diagram - Azure Key Vault Pipeline

    Person(devops, "DevOps Engineer", "Manages secrets and configurations")
    Person(approver, "Approver", "Approves production changes")

    System_Boundary(pipeline, "Azure Key Vault Pipeline") {
        System(core, "Pipeline Core", "Orchestrates secret updates with validation and approvals")
    }

    System_Ext(azdo, "Azure DevOps", "CI/CD Platform")
    System_Ext(kv, "Azure Key Vault", "Secrets Management")
    System_Ext(arm, "Azure Resource Manager", "Authentication & RBAC")

    Rel(devops, core, "Triggers updates", "YAML parameters")
    Rel(approver, core, "Approves changes", "Azure Environments")
    Rel(core, azdo, "Runs on", "Pipeline execution")
    Rel(core, kv, "Manages secrets", "Azure CLI / PowerShell")
    Rel(core, arm, "Authenticates via", "Service connections")
```

## Component Architecture

```mermaid
graph TB
    subgraph "Presentation Layer"
        UI[Azure DevOps UI<br/>Pipeline Parameters]
    end

    subgraph "Orchestration Layer"
        PIPE[azure-pipelines.yml<br/>Main Pipeline]
        VAL[Validation Stage]
        DEV[Dev Stage]
        STG[Staging Stage]
        PROD[Production Stage]
    end

    subgraph "Template Layer"
        STAGE[update-secret-stage.yml<br/>Reusable Stage]
        JOB[update-secret-job.yml<br/>Deployment Job]
    end

    subgraph "Business Logic Layer"
        MAIN[Update-KeyVaultSecret.ps1<br/>Main Orchestrator<br/>• Parse updates<br/>• Apply changes<br/>• Manage workflow]
        GET[Get-KeyVaultSecret.ps1<br/>Read Operations]
        SET[Set-KeyVaultSecret.ps1<br/>Write Operations<br/>• Set secret<br/>• Create backup]
    end

    subgraph "Integration Layer"
        CLI[Azure CLI<br/>Primary Method]
        PS[Az PowerShell Module<br/>Fallback Method]
    end

    subgraph "Data Layer"
        KV_DEV[(Azure Key Vault<br/>Development)]
        KV_STG[(Azure Key Vault<br/>Staging)]
        KV_PROD[(Azure Key Vault<br/>Production)]
    end

    subgraph "Configuration Layer"
        ENV[environments.yml<br/>Environment Config]
    end

    subgraph "Security Layer"
        SC1[Service Connection<br/>Dev]
        SC2[Service Connection<br/>Staging]
        SC3[Service Connection<br/>Production]
        RBAC[Azure RBAC<br/>Permissions]
    end

    UI --> PIPE
    PIPE --> VAL
    VAL --> DEV
    VAL --> STG
    VAL --> PROD

    DEV --> STAGE
    STG --> STAGE
    PROD --> STAGE

    STAGE --> JOB
    JOB --> MAIN

    MAIN --> GET
    MAIN --> SET

    GET --> CLI
    GET --> PS
    SET --> CLI
    SET --> PS

    CLI --> KV_DEV
    CLI --> KV_STG
    CLI --> KV_PROD

    PS --> KV_DEV
    PS --> KV_STG
    PS --> KV_PROD

    ENV -.configures.-> PIPE

    SC1 -.authenticates.-> KV_DEV
    SC2 -.authenticates.-> KV_STG
    SC3 -.authenticates.-> KV_PROD

    RBAC -.controls.-> SC1
    RBAC -.controls.-> SC2
    RBAC -.controls.-> SC3

    style UI fill:#e1f5ff,stroke:#0078d4,stroke-width:2px
    style PIPE fill:#ff6b6b,stroke:#d63031,stroke-width:2px
    style MAIN fill:#4ecdc4,stroke:#1abc9c,stroke-width:2px
    style KV_DEV fill:#95e1d3,stroke:#16a085,stroke-width:2px
    style KV_STG fill:#ffd93d,stroke:#f39c12,stroke-width:2px
    style KV_PROD fill:#ff6b6b,stroke:#e74c3c,stroke-width:2px
```

## Data Flow Architecture

```mermaid
graph LR
    subgraph "Input"
        A[User Parameters]
        B[Environment Config]
    end

    subgraph "Processing Pipeline"
        C[Validation]
        D[Fetch Current Secret]
        E[Parse JSON]
        F[Apply Updates]
        G[Generate Backup]
        H[Convert to JSON]
        I[Update Secret]
    end

    subgraph "Storage"
        J[Original Secret]
        K[Backup Secret]
        L[Updated Secret]
    end

    subgraph "Output"
        M[Pipeline Variables]
        N[Log Output]
        O[Summary Report]
    end

    A --> C
    B --> C
    C --> D
    D --> J
    J --> E
    E --> F
    F --> G
    G --> K
    F --> H
    H --> I
    I --> L

    L --> M
    I --> N
    I --> O

    style A fill:#e1f5ff
    style C fill:#ffd93d
    style F fill:#4ecdc4
    style L fill:#95e1d3
    style M fill:#95e1d3
```

## Deployment Architecture

```mermaid
graph TB
    subgraph "Azure DevOps Organization"
        subgraph "Project"
            REPO[Git Repository<br/>azure-keyvault-pipeline]
            PIPE[Pipeline Definition]
            ENV_DEV[Environment: dev]
            ENV_STG[Environment: staging<br/>+ Approval Gates]
            ENV_PROD[Environment: prod<br/>+ Approval Gates]
        end

        subgraph "Service Connections"
            SC_DEV[azure-dev-connection]
            SC_STG[azure-staging-connection]
            SC_PROD[azure-prod-connection]
        end
    end

    subgraph "Azure Subscription"
        subgraph "Resource Group: Development"
            KV_DEV[Key Vault: app-dev-kv]
        end

        subgraph "Resource Group: Staging"
            KV_STG[Key Vault: app-staging-kv]
        end

        subgraph "Resource Group: Production"
            KV_PROD[Key Vault: app-prod-kv]
        end

        AAD[Azure AD<br/>Service Principals]
        RBAC[RBAC Assignments]
    end

    REPO --> PIPE
    PIPE --> ENV_DEV
    PIPE --> ENV_STG
    PIPE --> ENV_PROD

    ENV_DEV --> SC_DEV
    ENV_STG --> SC_STG
    ENV_PROD --> SC_PROD

    SC_DEV --> AAD
    SC_STG --> AAD
    SC_PROD --> AAD

    AAD --> RBAC
    RBAC --> KV_DEV
    RBAC --> KV_STG
    RBAC --> KV_PROD

    style PIPE fill:#ff6b6b
    style ENV_STG fill:#ffd93d
    style ENV_PROD fill:#ff6b6b
    style KV_DEV fill:#95e1d3
    style KV_STG fill:#ffd93d
    style KV_PROD fill:#ff6b6b
```

## Security Architecture

```mermaid
graph TD
    subgraph "Authentication Layer"
        A[Azure DevOps Pipeline]
        B[Service Connection]
        C[Managed Identity /<br/>Service Principal]
    end

    subgraph "Authorization Layer"
        D[Azure RBAC]
        E[Key Vault Access Policy]
        F{Permission Check}
    end

    subgraph "Access Control"
        G[Get Secret]
        H[Set Secret]
        I[List Secrets]
    end

    subgraph "Data Protection"
        J[Sensitive Value Masking]
        K[Backup Creation]
        L[Dry-Run Preview]
    end

    subgraph "Audit Layer"
        M[Pipeline Logs]
        N[Azure Monitor]
        O[Key Vault Audit Logs]
    end

    subgraph "Compliance Layer"
        P[Approval Workflows]
        Q[Environment Gates]
        R[Change Tracking]
    end

    A --> B
    B --> C
    C --> D
    C --> E
    D --> F
    E --> F

    F -->|Authorized| G
    F -->|Authorized| H
    F -->|Authorized| I

    G --> J
    H --> K
    H --> L

    G --> M
    H --> M
    G --> N
    H --> N
    G --> O
    H --> O

    M --> R
    N --> R
    O --> R

    P --> Q
    Q --> F

    style A fill:#e1f5ff
    style F fill:#ffd93d
    style J fill:#95e1d3
    style K fill:#95e1d3
    style L fill:#95e1d3
    style P fill:#ff6b6b
```

## Integration Points

```mermaid
graph LR
    subgraph "Pipeline System"
        A[Azure Key Vault Pipeline]
    end

    subgraph "Azure Services"
        B[Azure Key Vault API]
        C[Azure Resource Manager API]
        D[Azure AD Authentication]
        E[Azure Monitor]
    end

    subgraph "DevOps Services"
        F[Azure Pipelines]
        G[Azure Environments]
        H[Azure Repos]
    end

    subgraph "External Integrations"
        I[Notification Services<br/>Email / Teams]
        J[Audit Systems]
        K[Monitoring Dashboards]
    end

    A -->|HTTPS/REST| B
    A -->|HTTPS/REST| C
    A -->|OAuth 2.0| D
    A -->|Telemetry| E

    A -->|Runs on| F
    A -->|Uses| G
    A -->|Source from| H

    A -.optional.-> I
    E -.feeds.-> J
    E -.feeds.-> K

    style A fill:#4ecdc4,stroke:#1abc9c,stroke-width:3px
```

## Technology Stack Layers

```mermaid
graph TB
    subgraph "User Interface Layer"
        UI[Azure DevOps Portal<br/>Web UI]
    end

    subgraph "Pipeline Definition Layer"
        YAML[YAML DSL<br/>azure-pipelines.yml<br/>Template YAML files]
    end

    subgraph "Execution Runtime Layer"
        AGENT[Ubuntu-latest Agent<br/>Bash Shell<br/>PowerShell Core 7+]
    end

    subgraph "Scripting Layer"
        PS[PowerShell Scripts<br/>• Update-KeyVaultSecret.ps1<br/>• Get-KeyVaultSecret.ps1<br/>• Set-KeyVaultSecret.ps1]
    end

    subgraph "SDK/CLI Layer"
        CLI[Azure CLI 2.x]
        MODULE[Az PowerShell Module]
    end

    subgraph "Protocol Layer"
        HTTPS[HTTPS/REST APIs]
        OAUTH[OAuth 2.0 / Azure AD]
    end

    subgraph "Service Layer"
        KV[Azure Key Vault Service]
        ARM[Azure Resource Manager]
        AAD[Azure Active Directory]
    end

    UI --> YAML
    YAML --> AGENT
    AGENT --> PS
    PS --> CLI
    PS --> MODULE
    CLI --> HTTPS
    MODULE --> HTTPS
    HTTPS --> OAUTH
    OAUTH --> KV
    OAUTH --> ARM
    OAUTH --> AAD

    style UI fill:#e1f5ff
    style YAML fill:#ff6b6b
    style PS fill:#4ecdc4
    style CLI fill:#95e1d3
    style KV fill:#0078d4
```
