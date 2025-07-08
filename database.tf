resource "azurerm_user_assigned_identity" "mydatabaseusers_database" {
  name                = "mydatabaseusers-database"
  resource_group_name = azurerm_resource_group.mydatabaseusers.name
  location            = azurerm_resource_group.mydatabaseusers.location
}

resource "azurerm_mssql_server" "mydatabaseusers" {
  name                = "mydatabaseusers"
  resource_group_name = azurerm_resource_group.mydatabaseusers.name
  location            = azurerm_resource_group.mydatabaseusers.location
  version             = "12.0"
  minimum_tls_version = "1.2"

  azuread_administrator {
    azuread_authentication_only = true
    login_username              = azurerm_user_assigned_identity.mydatabaseusers_database.name
    object_id                   = azurerm_user_assigned_identity.mydatabaseusers_database.principal_id
  }
}

resource "azurerm_mssql_database" "mydatabaseusers" {
  name        = "mydatabaseusers"
  server_id   = azurerm_mssql_server.mydatabaseusers.id
  collation   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb = 250
  sku_name    = "S0"
}
