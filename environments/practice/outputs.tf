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
