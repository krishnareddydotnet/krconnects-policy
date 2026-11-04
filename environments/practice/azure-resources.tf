# -----------------------------------------------------------------------------
# Top Azure RESOURCE policies (not AKS): governance, network, storage, Key Vault, SQL.
# Same pattern as main.tf: data block = read the BUILT-IN definition by GUID, resource block = our assignment.
#
# Two kinds of built-ins here:
#   - With an "effect" parameter (Audit / Deny): controlled by var.azure_resource_policy_effect.
#   - Without one (the rule itself says Deny): controlled by "enforce" (true = block, false = DoNotEnforce).
#     DoNotEnforce still evaluates every resource, so Compliance shows what WOULD be blocked: the safe first step.
# -----------------------------------------------------------------------------

# =============================================================================
# GOVERNANCE
# =============================================================================

# 15. Allowed locations: resources only in approved regions (data residency, cost, support).
data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c" # Allowed locations
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "az-allowed-locations"
  display_name         = "Azure: allowed locations"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
  enforce              = var.enforce_fixed_deny_policies

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })

  non_compliance_message {
    content = "Create resources only in the approved regions (Central India, South India)."
  }
}

# 16. Required tag: every resource must carry the tag (cost reports, ownership, clean-up).
data "azurerm_policy_definition" "require_tag" {
  name = "871b6d14-10aa-478d-b590-94f262ecfa99" # Require a tag on resources
}

resource "azurerm_resource_group_policy_assignment" "require_tag" {
  name                 = "az-require-tag-${var.required_tag_name}"
  display_name         = "Azure: require tag '${var.required_tag_name}'"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.require_tag.id
  enforce              = var.enforce_fixed_deny_policies

  parameters = jsonencode({
    tagName = { value = var.required_tag_name }
  })

  non_compliance_message {
    content = "Every resource needs the '${var.required_tag_name}' tag."
  }
}

# =============================================================================
# NETWORK
# =============================================================================

# 17. No public IP on network interfaces: no VM directly reachable from the internet (use Bastion / private IP).
data "azurerm_policy_definition" "nic_no_public_ip" {
  name = "83a86a26-fd1f-447c-b59d-e51f44264114" # Network interfaces should not have public IPs
}

resource "azurerm_resource_group_policy_assignment" "nic_no_public_ip" {
  name                 = "az-nic-no-public-ip"
  display_name         = "Azure: no public IP on network interfaces"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.nic_no_public_ip.id
  enforce              = var.enforce_fixed_deny_policies

  non_compliance_message {
    content = "Network interfaces must not have a public IP. Use Azure Bastion or a private IP."
  }
}

# 18. Every subnet has an NSG: no subnet without firewall rules.
#     AuditIfNotExists = report only (it checks a RELATED resource, the NSG link, so it cannot deny).
data "azurerm_policy_definition" "subnet_nsg" {
  name = "e71308d3-144b-4262-b144-efdc3cc90517" # Subnets should be associated with a Network Security Group
}

resource "azurerm_resource_group_policy_assignment" "subnet_nsg" {
  name                 = "az-subnet-requires-nsg"
  display_name         = "Azure: subnets must have an NSG"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.subnet_nsg.id

  parameters = jsonencode({
    effect = { value = "AuditIfNotExists" } # only AuditIfNotExists or Disabled are allowed
  })

  non_compliance_message {
    content = "Associate a Network Security Group with every subnet."
  }
}

# =============================================================================
# STORAGE ACCOUNT
# =============================================================================

# 19. No anonymous blob access: the classic data-leak cause (public containers).
data "azurerm_policy_definition" "storage_no_public_blob" {
  name = "4fa4b6c0-31ca-4c0d-b10d-24b96f62a751" # Storage account public access should be disallowed
}

resource "azurerm_resource_group_policy_assignment" "storage_no_public_blob" {
  name                 = "az-storage-no-public-blob"
  display_name         = "Azure: storage, no anonymous blob access"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.storage_no_public_blob.id

  parameters = jsonencode({
    effect = { value = var.azure_resource_policy_effect }
  })

  non_compliance_message {
    content = "Set allowBlobPublicAccess to false on storage accounts."
  }
}

# 20. HTTPS only (secure transfer): no unencrypted HTTP access to storage.
data "azurerm_policy_definition" "storage_secure_transfer" {
  name = "404c3081-a854-4457-ae30-26a93ef643f9" # Secure transfer to storage accounts should be enabled
}

resource "azurerm_resource_group_policy_assignment" "storage_secure_transfer" {
  name                 = "az-storage-https-only"
  display_name         = "Azure: storage, HTTPS only"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.storage_secure_transfer.id

  parameters = jsonencode({
    effect = { value = var.azure_resource_policy_effect }
  })

  non_compliance_message {
    content = "Enable secure transfer (supportsHttpsTrafficOnly) on storage accounts."
  }
}

# 21. Minimum TLS 1.2: old TLS 1.0/1.1 have known weaknesses.
data "azurerm_policy_definition" "storage_min_tls" {
  name = "fe83a0eb-a853-422d-aac2-1bffd182c5d0" # Storage accounts should have the specified minimum TLS version
}

resource "azurerm_resource_group_policy_assignment" "storage_min_tls" {
  name                 = "az-storage-min-tls12"
  display_name         = "Azure: storage, minimum TLS 1.2"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.storage_min_tls.id

  parameters = jsonencode({
    effect            = { value = var.azure_resource_policy_effect }
    minimumTlsVersion = { value = "TLS1_2" }
  })

  non_compliance_message {
    content = "Set the minimum TLS version of storage accounts to TLS 1.2."
  }
}

# =============================================================================
# KEY VAULT
# =============================================================================

# 22. Purge protection: a deleted vault or secret cannot be destroyed for good during the retention period
#     (protects against ransomware and mistakes).
data "azurerm_policy_definition" "kv_purge_protection" {
  name = "0b60c0b2-2dc2-4e1c-b5c9-abbed971de53" # Key vaults should have deletion protection enabled
}

resource "azurerm_resource_group_policy_assignment" "kv_purge_protection" {
  name                 = "az-keyvault-purge-protection"
  display_name         = "Azure: Key Vault purge protection"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.kv_purge_protection.id

  parameters = jsonencode({
    effect = { value = var.azure_resource_policy_effect }
  })

  non_compliance_message {
    content = "Enable purge protection on Key Vaults."
  }
}

# 23. RBAC permission model: Azure RBAC (auditable, PIM-ready) instead of old vault access policies.
data "azurerm_policy_definition" "kv_rbac" {
  name = "12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5" # Azure Key Vault should use RBAC permission model
}

resource "azurerm_resource_group_policy_assignment" "kv_rbac" {
  name                 = "az-keyvault-rbac"
  display_name         = "Azure: Key Vault RBAC permission model"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.kv_rbac.id

  parameters = jsonencode({
    effect = { value = var.azure_resource_policy_effect }
  })

  non_compliance_message {
    content = "Use the Azure RBAC permission model on Key Vaults (enableRbacAuthorization: true)."
  }
}

# =============================================================================
# AZURE SQL
# =============================================================================

# 24. No public network access: the database is reachable only through a private endpoint.
data "azurerm_policy_definition" "sql_no_public_network" {
  name = "1b8ca024-1d5c-4dec-8995-b1a932b41780" # Public network access on Azure SQL Database should be disabled
}

resource "azurerm_resource_group_policy_assignment" "sql_no_public_network" {
  name                 = "az-sql-no-public-network"
  display_name         = "Azure: SQL, no public network access"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.sql_no_public_network.id

  parameters = jsonencode({
    effect = { value = var.azure_resource_policy_effect }
  })

  non_compliance_message {
    content = "Disable public network access on Azure SQL; use a private endpoint."
  }
}

# 25. Entra ID only: no SQL usernames/passwords to leak or rotate (passwordless with managed identity).
data "azurerm_policy_definition" "sql_entra_only" {
  name = "b3a22bc9-66de-45fb-98fa-00f5df42f41a" # Azure SQL Database should have Microsoft Entra-only authentication enabled
}

resource "azurerm_resource_group_policy_assignment" "sql_entra_only" {
  name                 = "az-sql-entra-only-auth"
  display_name         = "Azure: SQL, Microsoft Entra-only authentication"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.sql_entra_only.id

  parameters = jsonencode({
    effect = { value = var.azure_resource_policy_effect }
  })

  non_compliance_message {
    content = "Enable Microsoft Entra-only authentication on Azure SQL (no SQL logins)."
  }
}
