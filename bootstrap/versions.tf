terraform {
  required_version = ">= 1.17"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }


}
provider "azurerm" {
  resource_provider_registrations = "none"
  features {

  }
} 