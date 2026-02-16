// backend configuration for Terraform state
terraform {
  backend "azurerm" {
    resource_group_name  = "webdatadev-webdata-rg"
    storage_account_name = "webdatadev"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}