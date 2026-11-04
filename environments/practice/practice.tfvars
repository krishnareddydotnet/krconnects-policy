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
