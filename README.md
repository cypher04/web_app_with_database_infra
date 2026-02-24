# Azure Web Application with Database Infrastructure

A production-ready Terraform project that deploys a secure web application infrastructure on Azure with MSSQL database, private networking, WAF-protected Application Gateway, and private endpoints.

## Overview

This Terraform project provisions a complete Azure infrastructure for hosting a web application with the following components:

- **Application Gateway**: Azure Application Gateway (WAF_v2) with autoscaling, Web Application Firewall policy, and FQDN-based backend routing
- **Compute**: Linux App Service (P1v2) with system-assigned managed identity, client certificate authentication, and VNet integration
- **Database**: Azure MSSQL Server (v12.0) with public network access disabled, accessible only via private endpoint
- **Networking**: Virtual Network with segregated subnets, private endpoints for both App Service and MSSQL, and Private DNS Zone
- **Security**: Network Security Groups, WAF policy with OWASP 3.2 rules, and user-assigned managed identity

## Architecture

```
Resource Group (rg-webapp-dev)
│
├── User-Assigned Managed Identity (uai-webappdata-dev)
│   └── Assigned to Application Gateway
│
├── Virtual Network: vnet-dev (10.0.0.0/16)
│   ├── Main Subnet: subnet-dev (10.0.1.0/24)
│   │   └── Application Gateway (WAF_v2, autoscale 2-10)
│   ├── Database Subnet: subnet-db-dev (10.0.2.0/24)
│   │   ├── Private Endpoint → MSSQL Server (sqlServer)
│   │   └── Private Endpoint → Linux Web App (sites)
│   └── App Subnet: subnet-app-dev (10.0.3.0/24)
│       └── Delegated to Microsoft.Web/serverFarms
│           └── App Service VNet Integration
│
├── Public IP: pip-dev (Static)
│   └── Frontend IP for Application Gateway
│
├── Private DNS Zone: privatelink.azurewebsites.net
│   └── Linked to vnet-dev
│
├── Application Gateway: appg-dev
│   ├── SKU: WAF_v2 (autoscale min 2, max 10)
│   ├── Frontend: pip-dev on port 80
│   ├── Backend Pool: Web App FQDN
│   ├── WAF Policy: Prevention mode, OWASP 3.2
│   └── Routing: Basic rule → backend HTTP settings (port 80)
│
├── App Service Plan: asp-dev (P1v2, Linux)
│   └── Linux Web App: webappdata-dev
│       ├── System-Assigned Managed Identity
│       ├── Client Certificate: Required
│       ├── Auth: Enabled (redirect unauthenticated)
│       ├── Port: 3000
│       └── DATABASE_URL → MSSQL connection string
│
├── MSSQL Server: webapp-mssql-server-dev
│   ├── Version: 12.0
│   ├── Public Network Access: Disabled
│   ├── System-Assigned Managed Identity
│   └── Database: maindb (S0, 2GB, VBS enclave)
│
└── Network Security Groups
    ├── nsg-dev → subnet-app-dev
    │   └── Allow ports 65200-65535 (App Gateway management)
    └── sg-db-dev → subnet-db-dev
        ├── Allow TCP 1433 from app subnet (10.0.3.0/24)
        └── Deny all other inbound/outbound
```

## Project Structure

```
web_app_with_database_infra/
├── README.md
├── ARCHITECTURE.md
├── Traffic_flow.md
├── backend/
│   ├── main.tf                  # Backend state storage resources
│   └── providers.tf
├── env/
│   ├── dev/
│   │   ├── main.tf              # Root module — orchestrates all modules
│   │   ├── variables.tf         # Input variable declarations
│   │   ├── outputs.tf           # Deployment output values
│   │   ├── providers.tf         # Azure provider config (azurerm 4.1.0)
│   │   ├── backend.tf           # Remote state backend (Azure Storage)
│   │   └── terraform.tfvars     # Environment-specific values
│   ├── stage/                   # Staging environment (placeholder)
│   └── prod/                    # Production environment (placeholder)
├── modules/
│   ├── compute/                 # App Service Plan + Linux Web App + VNet integration
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── database/                # MSSQL Server + Database
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/              # VNet, subnets, Public IP, Private DNS, DB private endpoint
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── security/                # NSGs, Application Gateway, WAF Policy
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── workspace/
    ├── module_web_app_with_database_infra.code-workspace
    └── root_web_app_with_database_infra.code-workspace
```

## Getting Started

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.0
- Azure subscription with appropriate permissions
- Azure CLI authenticated (`az login`)

### Installation

1. **Clone the repository**
   ```bash
   cd /path/to/web_app_with_database_infra
   ```

2. **Authenticate with Azure**
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

3. **Navigate to the environment**
   ```bash
   cd env/dev
   ```

4. **Configure variables**

   Edit `terraform.tfvars` with your values:
   ```hcl
   resource_group_name    = "rg-webapp-dev"
   project_name           = "webapp"
   location               = "West Europe"
   environment            = "dev"
   administrator_login    = "your-admin-username"
   administrator_password = "<use-secure-password>"
   subscription_id        = "<your-subscription-id>"
   mssql_server_name      = "webapp-sqlserver-dev"
   mssql_db_name          = "webappdbdev"
   address_space          = ["10.0.0.0/16"]
   subnet_prefixes = {
     main     = "10.0.1.0/24"
     database = "10.0.2.0/24"
     app      = "10.0.3.0/24"
   }
   ```

5. **Initialize Terraform**
   ```bash
   terraform init
   ```

6. **Review the execution plan**
   ```bash
   terraform plan
   ```

7. **Apply the configuration**
   ```bash
   terraform apply
   ```

## Configuration

### Required Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `resource_group_name` | `string` | Name of the resource group | `rg-webapp-dev` |
| `project_name` | `string` | Project name used in resource naming | `webapp` |
| `location` | `string` | Azure region | `West Europe` |
| `environment` | `string` | Environment name | `dev`, `stage`, `prod` |
| `administrator_login` | `string` | SQL Server admin username | `sqladminuser` |
| `administrator_password` | `string` (sensitive) | SQL Server admin password | `<secure-password>` |
| `subscription_id` | `string` | Azure subscription ID | `xxxxxxxx-xxxx-...` |
| `mssql_server_name` | `string` | MSSQL Server name | `webapp-sqlserver-dev` |
| `mssql_db_name` | `string` | Database name | `webappdbdev` |
| `address_space` | `list(string)` | VNet address space | `["10.0.0.0/16"]` |
| `subnet_prefixes` | `map(string)` | Subnet CIDR blocks (keys: `main`, `database`, `app`) | See above |

### Network Configuration

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `main` | `10.0.1.0/24` | Application Gateway |
| `database` | `10.0.2.0/24` | Private endpoints (MSSQL + App Service) |
| `app` | `10.0.3.0/24` | App Service VNet integration (delegated to `Microsoft.Web/serverFarms`) |

### State Backend

Remote state is stored in Azure Storage:

| Setting | Value |
|---------|-------|
| Resource Group | `webdatadev-webdata-rg` |
| Storage Account | `webdatastatedev` |
| Container | `tfstate` |
| Key | `terraform.tfstate` |

## Security Features

- **WAF v2 Application Gateway**: Web Application Firewall in Prevention mode with OWASP 3.2 managed rule set, custom IP blocking rules, and request body inspection
- **Private Endpoints**: Both the App Service and MSSQL Server are accessible only via private endpoints on the database subnet — no public network exposure
- **Private DNS Zone**: `privatelink.azurewebsites.net` linked to the VNet for private endpoint DNS resolution
- **Network Isolation**: Three subnets segregated by function (gateway, app integration, private endpoints)
- **NSG Rules**:
  - App subnet: Allows ports 65200-65535 (required for Application Gateway v2 management)
  - Database subnet: Allows SQL port 1433 only from the app subnet, denies all other traffic
- **Client Certificate Authentication**: Required on the Linux Web App
- **App Service Auth**: Enabled with redirect for unauthenticated clients
- **Managed Identities**: System-assigned on Web App and MSSQL Server; user-assigned on Application Gateway
- **MSSQL Public Access Disabled**: Database server is only reachable through the private endpoint
- **Sensitive Values**: Passwords marked as sensitive in Terraform variables

## Outputs

After deployment, Terraform outputs:

| Output | Description |
|--------|-------------|
| `subnet_ids` | Subnet prefix map |
| `mssql_server_name` | MSSQL Server name |
| `mssql_db_name` | Database name |
| `resource_group_name` | Resource group name |
| `user_assigned_principal_id` | Principal ID of the user-assigned managed identity |
| `user_assigned_tenant_id` | Tenant ID of the user-assigned managed identity |
| `user_assigned_id` | Resource ID of the user-assigned managed identity |

## Module Dependencies

The modules are deployed in the following order:

1. **Networking** — Creates VNet, subnets, Public IP, Private DNS Zone, and database private endpoint
2. **Database** — Creates MSSQL Server and database (uses networking subnet output)
3. **Compute** — Creates App Service Plan, Linux Web App, and VNet integration (depends on database for server ID)
4. **Security** — Creates NSGs, Application Gateway (WAF_v2), and WAF policy (depends on networking for subnets/IPs and compute for web app FQDN)
5. **App Service Private Endpoint** — Created in root module to avoid circular dependency (depends on compute and networking)

## Maintenance

### Updating Infrastructure

1. Modify the relevant `.tf` files or `terraform.tfvars`
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes

### Destroying Infrastructure

```bash
cd env/dev
terraform destroy
```

> **Warning**: This will delete all resources. Ensure you have backups if needed.

## Best Practices

1. **Secrets Management**:
   - Never commit `terraform.tfvars` with real passwords
   - Use Azure Key Vault for production secrets
   - Consider using environment variables for sensitive values

2. **State Management**:
   - Remote state backend is configured in `backend.tf` (Azure Storage)
   - State locking is enabled to prevent concurrent modifications

3. **Environment Management**:
   - Use separate state files for dev/stage/prod
   - Maintain consistent naming conventions
   - Tag resources with environment identifiers

4. **Resource Naming**:
   - Resources use the pattern `{resource}-{environment}` or `{project}-{resource}-{environment}`
   - Ensure globally unique names for resources that require it (e.g., MSSQL Server)

## Troubleshooting

### Common Issues

**Issue**: Dependency cycle error
- **Cause**: Circular references between modules (e.g., networking needing compute output while compute needs networking output)
- **Solution**: Resources that depend on outputs from multiple modules (like the App Service private endpoint) are created in the root module instead

**Issue**: "Resource names must be globally unique"
- **Solution**: Update `mssql_server_name` and `project_name` in `terraform.tfvars` to unique values

**Issue**: Authentication errors
- **Solution**: Run `az login` and ensure the subscription is set correctly with `az account set`

**Issue**: State lock errors
- **Solution**: Ensure no other Terraform process is running. If stuck, use `terraform force-unlock <LOCK_ID>`

## Additional Resources

- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Azure Naming Conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)

## License

This project structure is provided as-is for educational and development purposes.

## Contributing

For changes or improvements:
1. Test in dev environment first
2. Validate with `terraform validate`
3. Review changes with `terraform plan`
4. Document any new variables or outputs

---

**Version**: 2.0
**Terraform Version**: >= 1.0
**Azure Provider Version**: 4.1.0
