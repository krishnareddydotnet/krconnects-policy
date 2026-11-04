# Pin Terraform and the provider so every run (laptop or pipeline) behaves the same.
terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.12" # any 5.x from 5.12 on, never a breaking 6.0
    }
  }
}

provider "azurerm" {
  features {}

  # Which subscription to work in. Set it in practice.tfvars (an ID is not a secret).
  subscription_id = var.subscription_id
}
