# Custom policy definitions

Empty on purpose: every policy in this repo is **built-in** (Microsoft maintains and tests it).

Write a custom definition only for a company-specific rule no built-in covers, for example:
- every resource group needs a `cost-center` tag (ARM policy, `azurerm_policy_definition`)
- every pod needs a `team` label (AKS: own Gatekeeper ConstraintTemplate in Rego, wrapped in a custom Azure Policy)

Custom definitions are usually created at **management group** scope (e.g. `mg-krconnects`), so every subscription below can assign them.
