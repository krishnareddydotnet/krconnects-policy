# nonprod (placeholder)

Same pattern as `../practice/`, with:
- Scope: management group `mg-nonprod` (`azurerm_management_group_policy_assignment`), so every nonprod subscription inherits it
- Effect: **Audit** first, then Deny once Compliance is clean
- State: remote (azurerm backend), key `policy/nonprod.tfstate`

Not created yet: only `practice` is deployed.
