# IDs of the assignments. The last part of each ID is the assignment name (e.g. aks-no-privileged-containers);
# in AKS each workload assignment shows up as a Gatekeeper constraint named azurepolicy-<template>-<id suffix>.
output "workload_policy_assignment_ids" {
  description = "Policy assignment IDs for the pod/container policies."
  value = {
    no_privileged           = azurerm_resource_group_policy_assignment.no_privileged.id
    no_privilege_escalation = azurerm_resource_group_policy_assignment.no_privilege_escalation.id
    non_root                = azurerm_resource_group_policy_assignment.non_root.id
    read_only_root_fs       = azurerm_resource_group_policy_assignment.read_only_root_fs.id
    drop_all_capabilities   = azurerm_resource_group_policy_assignment.drop_all_capabilities.id
    allowed_images          = azurerm_resource_group_policy_assignment.allowed_images.id
    no_latest_tag           = azurerm_resource_group_policy_assignment.no_latest_tag.id
    no_host_network         = azurerm_resource_group_policy_assignment.no_host_network.id
    no_host_namespaces      = azurerm_resource_group_policy_assignment.no_host_namespaces.id
    no_host_path            = azurerm_resource_group_policy_assignment.no_host_path.id
    no_automount_token      = azurerm_resource_group_policy_assignment.no_automount_token.id
    resource_limits         = azurerm_resource_group_policy_assignment.resource_limits.id
  }
}

output "cluster_policy_assignment_ids" {
  description = "Policy assignment IDs for the AKS cluster-level policies."
  value = {
    local_auth_disabled  = azurerm_resource_group_policy_assignment.local_auth_disabled.id
    policy_addon_enabled = azurerm_resource_group_policy_assignment.policy_addon_enabled.id
  }
}

output "azure_resource_policy_assignment_ids" {
  description = "Policy assignment IDs for the Azure resource policies (azure-resources.tf)."
  value = {
    allowed_locations       = azurerm_resource_group_policy_assignment.allowed_locations.id
    require_tag             = azurerm_resource_group_policy_assignment.require_tag.id
    nic_no_public_ip        = azurerm_resource_group_policy_assignment.nic_no_public_ip.id
    subnet_nsg              = azurerm_resource_group_policy_assignment.subnet_nsg.id
    storage_no_public_blob  = azurerm_resource_group_policy_assignment.storage_no_public_blob.id
    storage_secure_transfer = azurerm_resource_group_policy_assignment.storage_secure_transfer.id
    storage_min_tls         = azurerm_resource_group_policy_assignment.storage_min_tls.id
    kv_purge_protection     = azurerm_resource_group_policy_assignment.kv_purge_protection.id
    kv_rbac                 = azurerm_resource_group_policy_assignment.kv_rbac.id
    sql_no_public_network   = azurerm_resource_group_policy_assignment.sql_no_public_network.id
    sql_entra_only          = azurerm_resource_group_policy_assignment.sql_entra_only.id
  }
}
