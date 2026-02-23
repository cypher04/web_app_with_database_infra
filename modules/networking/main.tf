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

// create private endpoint for database

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


// Private endpoint for App Service has been moved to root module to avoid circular dependency