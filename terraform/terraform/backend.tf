terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "tfstate${substr(md5(terraform.workspace), 0, 8)}"
    container_name       = "tfstate"
    key                  = "product-microservice.tfstate"
  }
}