# Where Terraform keeps its state (the list of what it created).
#
# Practice: LOCAL state (terraform.tfstate on your laptop, ignored by Git). Simple, nothing to set up.
#
# Companies: REMOTE state in an Azure Storage Account, so the pipeline and the whole team share one state
# and a lock stops two runs at the same time. It would look like this (Entra ID auth, no storage keys):
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-tfstate-cin-001"
#     storage_account_name = "sttfstatekrconnects001"
#     container_name       = "tfstate"
#     key                  = "policy/practice.tfstate"   # one state file per environment
#     use_azuread_auth     = true
#   }
# }
