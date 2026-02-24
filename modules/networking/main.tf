resource "azurerm_virtual_network" "main" {
    name                = "vnet-${var.environment}"
    address_space       = var.address_space
    location            = var.location
    resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "main" {
    name                 = "subnet-${var.environment}"
    resource_group_name  = var.resource_group_name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes     = [var.subnet_prefixes["main"]]
}

resource "azurerm_subnet" "database" {
    name                 = "subnet-db-${var.environment}"
    resource_group_name  = var.resource_group_name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes     = [var.subnet_prefixes["database"]]
}

resource "azurerm_subnet" "app" {
    name                 = "subnet-app-${var.environment}"
    resource_group_name  = var.resource_group_name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes     = [var.subnet_prefixes["app"]]

    delegation {
        name = "delegation-app-${var.environment}"
        service_delegation {
            name    = "Microsoft.Web/serverFarms"
            actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
    }
}

resource "azurerm_public_ip" "pip" {
    name                = "pip-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name
    allocation_method   = "Static"
}

// create private endpoint dns zone for database

resource "azurerm_private_dns_zone" "pdz" {
    name                = "privatelink.azurewebsites.net"
    resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "pdz_vnet_link" {
    name                  = "${var.project_name}-pdz-vnet-link-${var.environment}"
    resource_group_name   = var.resource_group_name
    private_dns_zone_name = azurerm_private_dns_zone.pdz.name
    virtual_network_id    = azurerm_virtual_network.main.id
    registration_enabled  = false
}

resource "azurerm_private_endpoint" "pe-database" {
    name                = "${var.project_name}-pe-database-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name
    subnet_id           = azurerm_subnet.database.id

    private_service_connection {
        name                           = "${var.project_name}-psc-database-${var.environment}"
        private_connection_resource_id = var.mssql_server_id
        is_manual_connection           = false
        subresource_names              = ["sqlServer"]
    }

    private_dns_zone_group {
        name                 = "db-dns-zone-group"
        private_dns_zone_ids = [azurerm_private_dns_zone.pdz.id]
    }

    # depends_on = [module.database]
  
}




