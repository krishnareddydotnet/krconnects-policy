# Non-secret values for the practice environment (committed on purpose; see .gitignore).
# Replace the subscription ID with yours: az account show --query id --output tsv
subscription_id     = "00000000-0000-0000-0000-000000000000"
resource_group_name = "rg-krconnects-practice-cin-001"

# Rollout: Audit first (report only), Deny once Compliance shows no violations.
# Our apps already pass every workload policy, so practice goes straight to Deny.
workload_policy_effect = "Deny"
resource_limits_effect = "Audit" # apps have no CPU limit on purpose
cluster_policy_effect  = "Audit" # only Audit or Disabled is supported

# Only our ACR. "^" = start, "\\." = a literal dot, ".+" = any repository/tag/digest after the slash.
allowed_container_images_regex = "^krconnectspractice\\.azurecr\\.io/.+$"

# ----- Azure resource policies (azure-resources.tf) -----
# Audit first: shows non-compliant storage / Key Vault / SQL in Compliance without blocking anything.
azure_resource_policy_effect = "Audit"

# false = DoNotEnforce for the always-Deny built-ins (locations, tag, NIC public IP): evaluated, not blocked.
# Switch to true only after Compliance is clean, or existing untagged resources can no longer be updated.
enforce_fixed_deny_policies = false

allowed_locations = ["centralindia", "southindia"]
required_tag_name = "environment"
