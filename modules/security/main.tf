
resource "azurerm_network_security_group" "nsg" {
  
    name                = "nsg-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name

    security_rule {
        name                       = "Allow-HTTP"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "65200-65535"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Allow-HTTPS"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "65200-65535"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }    
}

resource "azurerm_network_security_group" "fordb" {
    name                = "sg-db-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name

    security_rule {
        name                       = "Allow-DB-Access"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "3000"
        destination_port_range     = "1433"
        source_address_prefix      = var.subnet_prefixes["app"]
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Deny-All-Other"
        priority                   = 200
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Allow-DB-Outbound"
        priority                   = 100
        direction                  = "Outbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Deny-All-Other-Outbound"
        priority                   = 200
        direction                  = "Outbound"
        access                     = "Deny"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

}



resource "azurerm_subnet_network_security_group_association" "app_subnet_nsg_association" {
    subnet_id                 = var.subnet_ids[0]
    network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db_subnet_nsg_association" {
    subnet_id                 = var.subnet_ids[1]
    network_security_group_id = azurerm_network_security_group.fordb.id
}


locals {
  backend_address_pool_name = "appg-backend-pool"
  frontend_ip_configuration_name = "appg-frontend-ip"
  http_listener_name = "appg-http-listener"
  frontend_port_name = "frontendPort80"
  backend_http_settings_name = "appg-backend-http-settings"
  request_routing_rule_name = "appg-routing-rule"
  gateway_ip_configuration_name = "appg-ip-config"
}

resource "azurerm_application_gateway" "appg" {
    name                = "appg-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name
    identity {
        type = "UserAssigned"
        identity_ids = [var.user_identity_id]
    }
    sku {
        name = "WAF_v2"
        tier = "WAF_v2"
    }
    autoscale_configuration {
      min_capacity = 2
      max_capacity = 10
    }
    gateway_ip_configuration {
        name      = local.gateway_ip_configuration_name
        subnet_id = var.subnet_ids[0]
    }
    frontend_port {
        name = local.frontend_port_name
        port = 80
    }
    frontend_ip_configuration {
        name                 = local.frontend_ip_configuration_name
        public_ip_address_id = var.pip_id
    }
    backend_address_pool {
        name = local.backend_address_pool_name
    }
    backend_http_settings {
        name                  = local.backend_http_settings_name
        cookie_based_affinity = "Disabled"
        port                  = 80
        protocol              = "Http"
        request_timeout       = 20
    }
    http_listener {
        name                           = local.http_listener_name
        frontend_ip_configuration_name = local.frontend_ip_configuration_name
        frontend_port_name             = local.frontend_port_name
        protocol                       = "Http"
    }
    request_routing_rule {
        name                       = local.request_routing_rule_name
        priority = 9
        rule_type                  = "Basic"
        http_listener_name         = local.http_listener_name
        backend_address_pool_name  = local.backend_address_pool_name
        backend_http_settings_name = local.backend_http_settings_name
    }

    firewall_policy_id = azurerm_web_application_firewall_policy.waf_policy.id
}

resource "azurerm_web_application_firewall_policy" "waf_policy" {
    name                = "waf-policy-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name

     custom_rules {
    name      = "Rule1"
    priority  = 1
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["192.168.1.0/24", "10.0.0.0/24"]
    }

    action = "Block"
  }

  custom_rules {
    name      = "Rule2"
    priority  = 2
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["192.168.1.0/24"]
    }

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "UserAgent"
      }

      operator           = "Contains"
      negation_condition = false
      match_values       = ["Windows"]
    }

    action = "Block"
  }

    policy_settings {
      enabled = true
      mode = "Prevention"
      request_body_check = true
     file_upload_limit_in_mb = 100
     max_request_body_size_in_kb = 128
    }

    managed_rules {

        exclusion {
      match_variable          = "RequestHeaderNames"
      selector                = "x-company-secret-header"
      selector_match_operator = "Equals"
    }
    exclusion {
      match_variable          = "RequestCookieNames"
      selector                = "too-tasty"
      selector_match_operator = "EndsWith"
    }
    managed_rule_set {
            type    = "OWASP"
            version = "3.2"
    rule_group_override {
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rule {
          id      = "920300"
          enabled = true
          action  = "Log"
        }

        rule {
          id      = "920440"
          enabled = true
          action  = "Block"
        }
      }
        }
    }
  
}
  









