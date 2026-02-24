resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = var.environment
  }
}

resource "azurerm_user_assigned_identity" "uai-webappdata" {
  name                = "uai-webappdata-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

data "azurerm_client_config" "current" {
  
}

module "compute" {
  source = "../../modules/compute"

  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  environment            = var.environment
  subnet_id              = module.networking.app
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password
#   subnet_prefixes        = [var.subnet_prefixes["app"]]
  mssql_server_name      = var.mssql_server_name
  mssql_db_name          = var.mssql_db_name
  mssql_server_id        = module.database.server_id
  # linux_web_app_id = module.compute.linux_web_app_id
  depends_on             = [ module.database]
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  address_space       = var.address_space
  subnet_prefixes     = var.subnet_prefixes
  subnet_ids           = module.networking.subnet_ids
  project_name         = var.project_name
  mssql_server_id      = module.database.mssql_server_id
  # depends_on             = [ module.database]
}

module "security" {
  source = "../../modules/security"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment         = var.environment
  subnet_ids          = module.networking.subnet_ids
  subnet_prefixes     = var.subnet_prefixes
  public_ip           = module.networking.public_ip
  user_identity_id = azurerm_user_assigned_identity.uai-webappdata.id
  depends_on          = [module.networking]
  pip_id = module.networking.pip_id
  fqdn = module.compute.fqdn
}

// Private Endpoint for App Service (moved here to avoid circular dependency)
resource "azurerm_private_endpoint" "pe-appservice" {
  name                = "${var.project_name}-pe-appservice-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.networking.database

  private_service_connection {
    name                           = "${var.project_name}-psc-appservice-${var.environment}"
    private_connection_resource_id = module.compute.linux_web_app_id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "app-dns-zone-group"
    private_dns_zone_ids = [module.networking.private_dns_zone_id]
  }

  depends_on = [module.compute, module.networking]
}

module "database" {
  source = "../../modules/database"

  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  subnet_id              = module.networking.database
  environment            = var.environment
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password
  subnet_prefixes        = [var.subnet_prefixes["database"]]
  mssql_server_name      = var.mssql_server_name
  mssql_db_name          = var.mssql_db_name
  project_name            = var.project_name
  # depends_on             = [module.networking]
}





