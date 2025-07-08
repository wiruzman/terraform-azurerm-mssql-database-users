locals {
  add_identity_to_database_script_name = "add_identity_to_database.ps1"
}

resource "azurerm_user_assigned_identity" "mydatabaseusers_user" {
  name                = "mydatabaseusers-user"
  resource_group_name = azurerm_resource_group.mydatabaseusers.name
  location            = azurerm_resource_group.mydatabaseusers.location
}

resource "azurerm_automation_account" "mydatabaseusers" {
  name                = "mydatabaseusers"
  resource_group_name = azurerm_resource_group.mydatabaseusers.name
  location            = azurerm_resource_group.mydatabaseusers.location
  sku_name            = "Basic"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.mydatabaseusers_database.id]
  }
}

resource "azurerm_automation_powershell72_module" "sqlserver" {
  name                  = "SQLServer"
  automation_account_id = azurerm_automation_account.mydatabaseusers.id
  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/SQLServer/22.3.0"
  }
}

resource "azurerm_automation_powershell72_module" "azaccounts" {
  name                  = "Az.Accounts"
  automation_account_id = azurerm_automation_account.mydatabaseusers.id
  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/4.2.0"
  }
}

resource "azurerm_automation_variable_string" "variable_user_assigned_identity_id" {
  name                    = "UserAssignedIdentityId"
  resource_group_name     = azurerm_resource_group.mydatabaseusers.name
  automation_account_name = azurerm_automation_account.mydatabaseusers.name
  value                   = azurerm_user_assigned_identity.mydatabaseusers_database.client_id
}

resource "azurerm_automation_variable_string" "variable_sql_server" {
  name                    = "SqlServer"
  resource_group_name     = azurerm_resource_group.mydatabaseusers.name
  automation_account_name = azurerm_automation_account.mydatabaseusers.name
  value                   = azurerm_mssql_server.mydatabaseusers.fully_qualified_domain_name
}

resource "azurerm_automation_variable_string" "variable_database" {
  name                    = "Database"
  resource_group_name     = azurerm_resource_group.mydatabaseusers.name
  automation_account_name = azurerm_automation_account.mydatabaseusers.name
  value                   = azurerm_mssql_database.mydatabaseusers.name
}

resource "azurerm_automation_variable_string" "variable_identity_name" {
  name                    = "IdentityName"
  resource_group_name     = azurerm_resource_group.mydatabaseusers.name
  automation_account_name = azurerm_automation_account.mydatabaseusers.name
  value                   = azurerm_user_assigned_identity.mydatabaseusers_user.name
}

resource "azurerm_automation_variable_string" "variable_identity_client_id" {
  name                    = "IdentityId"
  resource_group_name     = azurerm_resource_group.mydatabaseusers.name
  automation_account_name = azurerm_automation_account.mydatabaseusers.name
  value                   = azurerm_user_assigned_identity.mydatabaseusers_user.client_id
}

resource "azurerm_automation_runbook" "add_identity_to_database" {
  name                    = "mydatabaseusers"
  location                = azurerm_resource_group.mydatabaseusers.location
  resource_group_name     = azurerm_resource_group.mydatabaseusers.name
  automation_account_name = azurerm_automation_account.mydatabaseusers.name
  runbook_type            = "PowerShell72"
  log_verbose             = true
  log_progress            = true
  description             = "Add Entra ID identity to SQL Database"
  content                 = file(local.add_identity_to_database_script_name)

  depends_on = [
    azurerm_automation_powershell72_module.sqlserver,
    azurerm_automation_powershell72_module.azaccounts,
    azurerm_automation_variable_string.variable_user_assigned_identity_id,
    azurerm_automation_variable_string.variable_sql_server,
    azurerm_automation_variable_string.variable_database,
    azurerm_automation_variable_string.variable_identity_name,
    azurerm_automation_variable_string.variable_identity_client_id
  ]
}

resource "null_resource" "trigger_add_identity_to_database" {
  provisioner "local-exec" {
    command     = "./runbook_trigger.ps1 -AutomationAccountName \"${azurerm_automation_account.mydatabaseusers.name}\" -ResourceGroupName \"${azurerm_resource_group.mydatabaseusers.name}\" -RunbookName \"${azurerm_automation_runbook.add_identity_to_database.name}\""
    interpreter = ["pwsh", "-Command"]
    working_dir = path.module
  }

  depends_on = [azurerm_automation_runbook.add_identity_to_database]

  triggers = {
    trigger            = "1"
    runbook            = azurerm_automation_runbook.add_identity_to_database.runbook_type
    runbook_hash       = sha1(file(local.add_identity_to_database_script_name))
    identity_id_hash   = sha1(azurerm_user_assigned_identity.mydatabaseusers_user.client_id)
    identity_name_hash = sha1(azurerm_user_assigned_identity.mydatabaseusers_user.name)
  }
}
