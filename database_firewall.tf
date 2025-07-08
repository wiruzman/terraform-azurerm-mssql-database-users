resource "azurerm_mssql_firewall_rule" "all_azure-internal_ip_addresses" {
  name             = "AllowAllWindowsAzureIps"
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
  server_id        = azurerm_mssql_server.mydatabaseusers.id
}
