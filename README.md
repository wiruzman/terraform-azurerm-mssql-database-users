# Terraform Azure SQL Database with Managed Identity Users

This Terraform module creates an Azure SQL Database with Azure AD authentication and automatically provisions managed identity users using Azure Automation runbooks.

## Architecture

The module provisions:

- **Azure SQL Server** with Azure AD-only authentication
- **Azure SQL Database** 
- **User-Assigned Managed Identities** for database administration and user access
- **Azure Automation Account** with PowerShell runbooks for user provisioning
- **Firewall rules** allowing Azure services access

## Features

- ✅ **Azure AD-only authentication** - No SQL authentication enabled
- ✅ **Automated user provisioning** - Uses Azure Automation runbooks to create database users
- ✅ **Managed Identity support** - Provisions user-assigned managed identities as database users
- ✅ **Idempotent operations** - Safe to run multiple times without side effects
- ✅ **CI/CD friendly** - Supports both federated token and Azure CLI authentication

## Prerequisites

- Azure CLI installed and configured
- PowerShell 7.2+ (for local execution)
- Terraform >= 1.0
- Appropriate Azure permissions to create:
  - Resource Groups
  - SQL Servers and Databases
  - User-Assigned Managed Identities
  - Automation Accounts
  - Role assignments

## Quick Start

1. **Clone and configure**:
   ```bash
   git clone <repository-url>
   cd terraform-azurerm-mssql-database-users
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan and apply**:
   ```bash
   terraform plan
   terraform apply
   ```

## What Gets Created

### Core Infrastructure

| Resource | Purpose |
|----------|---------|
| `azurerm_resource_group.mydatabaseusers` | Resource group containing all resources |
| `azurerm_mssql_server.mydatabaseusers` | SQL Server with Azure AD admin |
| `azurerm_mssql_database.mydatabaseusers` | SQL Database (S0 tier, 250GB max) |
| `azurerm_mssql_firewall_rule.all_azure-internal_ip_addresses` | Allows Azure services to connect |

### Identity Management

| Resource | Purpose |
|----------|---------|
| `azurerm_user_assigned_identity.mydatabaseusers_database` | Admin identity for SQL Server |
| `azurerm_user_assigned_identity.mydatabaseusers_user` | User identity to be provisioned in database |

### Automation Infrastructure

| Resource | Purpose |
|----------|---------|
| `azurerm_automation_account.mydatabaseusers` | Hosts PowerShell runbooks |
| `azurerm_automation_runbook.add_identity_to_database` | Runbook that creates database users |
| `azurerm_automation_variable_string.*` | Configuration variables for runbook |
| `azurerm_automation_powershell72_module.*` | Required PowerShell modules (SQLServer, Az.Accounts) |

## How It Works

1. **Infrastructure Creation**: Terraform creates the SQL Server, database, and managed identities
2. **Runbook Execution**: A PowerShell runbook is triggered to create the database user
3. **User Provisioning**: The runbook connects to SQL using managed identity and creates a database user with `db_datareader` role

### Authentication Flow

The system supports two authentication methods:

#### CI/CD (Federated Tokens)
```bash
export ARM_CLIENT_ID="<service-principal-client-id>"
export ARM_OIDC_TOKEN="<federated-token>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

#### Local Development (Azure CLI)
```bash
az login
```

## Files Description

| File | Purpose |
|------|---------|
| `main.tf` | Resource group definition |
| `provider.tf` | Terraform provider configuration |
| `database.tf` | SQL Server and database resources |
| `database_firewall.tf` | Firewall rule configuration |
| `database_users.tf` | User identities and automation resources |
| `add_identity_to_database.ps1` | PowerShell script for user provisioning |
| `runbook_trigger.ps1` | Script to trigger automation runbook |
| `_override.tf` | Terraform overrides (if any) |

## PowerShell Scripts

### `add_identity_to_database.ps1`
- Runs in Azure Automation Account
- Creates database users from managed identities
- Assigns `db_datareader` role to users
- Uses managed identity authentication

### `runbook_trigger.ps1`
- Triggers the automation runbook from Terraform
- Supports both federated token and Azure CLI authentication
- Waits for runbook completion with timeout
- Provides detailed logging and error handling

## Security Considerations

- ✅ **Azure AD-only authentication** - SQL authentication is disabled
- ✅ **Managed identities** - No passwords or connection strings stored
- ✅ **Least privilege** - Database users get only `db_datareader` role
- ✅ **Network security** - Firewall rules limit access to Azure services
- ✅ **Firewall rule** - Currently allows all Azure services (0.0.0.0-0.0.0.0) to avoid blocking Azure Automation

## Troubleshooting

### Common Issues

1. **Runbook fails to execute**:
   - Check that required PowerShell modules are installed
   - Verify managed identity has proper permissions
   - Review automation account logs

2. **SQL connection fails**:
   - Ensure firewall rules allow your IP/service
   - Verify managed identity is configured as SQL admin
   - Check that Azure AD authentication is enabled

3. **Permission errors**:
   - Ensure the user executing Terraform has sufficient Azure permissions
   - Verify service principal has required roles for CI/CD scenarios

### Debugging

Enable detailed logging by setting:
```bash
export TF_LOG=DEBUG
```

Check automation runbook logs in the Azure portal under:
`Automation Account > Process Automation > Jobs`

## Clean Up

To destroy all resources:
```bash
terraform destroy
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
