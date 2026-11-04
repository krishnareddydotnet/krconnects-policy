# prod (placeholder)

Same pattern as `../practice/`, with:
- Scope: management group `mg-prod` (`azurerm_management_group_policy_assignment`)
- Effect: **Deny** (only after the same policies ran clean in nonprod)
- Apply: pipeline with a GitHub Environment `prod` that needs manual approval; Azure login with OIDC (no client secret)
- State: remote (azurerm backend), key `policy/prod.tfstate`

Not created yet: only `practice` is deployed.
