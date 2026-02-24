output "database_subnet_id" {
    description = "The subnet ID where the database is deployed"
    value       = var.subnet_id
  
}

output "target_resource_id" {
    description = "The resource group name for compute resources"
    value       = var.resource_group_name
  
}

output "linux_web_app_id" {
    description = "The ID of the Linux Web App"
    value       = azurerm_linux_web_app.liweb.id
}

output "fqdn" {
  description = "The fully qualified domain name of the Linux Web App"
  value       = azurerm_linux_web_app.liweb.default_hostname
}


