# output "subnet_id" {
#     description = "The subnet ID where the compute resources are deployed"
#     value       = var.subnet_id
# }


// deployment outputs
output "subnet_ids" {
  description = "The subnet prefixes used in the deployment"
  value       = var.subnet_prefixes
}

output "mssql_server_name" {
  description = "The name of the MSSQL Server"
  value       = var.mssql_server_name
}

output "mssql_db_name" {
  description = "The name of the MSSQL Database"
  value       = var.mssql_db_name
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = var.resource_group_name
}

output "user_assigned_principal_id" {
  description = "The principal ID of the user assigned identity"
  value       = azurerm_user_assigned_identity.uai-webappdata.principal_id
}

output "user_assigned_tenant_id" {
  description = "The tenant ID of the user assigned identity"
  value       = azurerm_user_assigned_identity.uai-webappdata.tenant_id
}

output "user_assigned_id" {
  description = "The ID of the user assigned identity"
  value       = azurerm_user_assigned_identity.uai-webappdata.id
} 

// output linux web app details

# output "linux_web_app_id" {
#   description = "The ID of the Linux Web App"
#   value       = azurerm_linux_web_app.liweb.id
# }

# output "fqdn" {
#   description = "The fully qualified domain name of the Linux Web App"
#   value       = azurerm_linux_web_app.liweb.default_site_hostname
# }




