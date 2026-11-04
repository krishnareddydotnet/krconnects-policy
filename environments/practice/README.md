# practice

## What it deploys

25 Azure Policy assignments on resource group `rg-krconnects-practice-cin-001`:
- `main.tf`: 12 AKS workload + 2 AKS cluster policies
- `azure-resources.tf`: 11 Azure resource policies (locations, tags, network, storage, Key Vault, SQL)
Full list: root `README.md` (Policy catalog). No other Azure resources and no cost.

## Prerequisites

- Terraform >= 1.17, Azure CLI, `az login` with rights to assign policy on the resource group (Owner or Resource Policy Contributor).
- AKS cluster running with the Azure Policy add-on (`gatekeeper-system` namespace exists).
- Your subscription ID in `practice.tfvars` (`az account show --query id --output tsv`).
- **Delete the portal assignment** "Kubernetes cluster should not allow privileged containers" first (Policy -> Assignments),
  otherwise the cluster gets the same rule twice. (Alternative: `terraform import` it.)

## How to run (PowerShell 7, from this folder)

```powershell
az login
```

```powershell
terraform init
```

The first `init` creates `.terraform.lock.hcl` (exact provider version + checksums): commit it, so every run uses the same provider.

```powershell
terraform plan -var-file="practice.tfvars" -out="practice.tfplan"
```

```powershell
terraform apply "practice.tfplan"
```

## How to verify

Wait ~15-20 minutes for the add-on to sync, then:

```powershell
kubectl get constrainttemplates
```

```powershell
kubectl get constraints
```

Each workload policy shows as a constraint with ENFORCEMENT-ACTION `deny` (or `dryrun` for Audit) and TOTAL-VIOLATIONS `0`.
Portal: **Policy -> Compliance** (first scan can take ~30 minutes). The Azure resource policies (#15-25) show only there,
not in kubectl. Start a scan right away with:

```powershell
az policy state trigger-scan --resource-group rg-krconnects-practice-cin-001
```

## Clean up

```powershell
terraform destroy -var-file="practice.tfvars"
```
