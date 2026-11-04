# krconnects-policy

Azure Policy as code (Terraform) for the KRConnects AKS cluster and Azure resources.
Built-in policies are only **read** (data sources); this repo owns the **assignments**: scope, effect and parameters.

## Folder structure

```
krconnects-policy/
├── .github/workflows/terraform-ci.yml   manual only (workflow_dispatch): fmt + validate, no Azure login
├── definitions/                         CUSTOM policy definitions (company-specific rules only; empty for now)
└── environments/                        one folder = one Terraform root = one state
    ├── practice/                        DEPLOYABLE: scope rg-krconnects-practice-cin-001
    │   ├── main.tf                      AKS policies (#1-14)
    │   └── azure-resources.tf           Azure resource policies (#15-25)
    ├── nonprod/                         placeholder: scope mg-nonprod, effect Audit
    └── prod/                            placeholder: scope mg-prod, effect Deny + manual approval
```

## Policy catalog (managed by Terraform)

All are **built-in** definitions, assigned at resource group scope: AKS in `environments/practice/main.tf`,
Azure resources in `environments/practice/azure-resources.tf`.

### A. Workload policies (pods/containers, enforced in AKS by Gatekeeper)

| # | Built-in policy | Definition ID | Practice effect | Why |
|---|---|---|---|---|
| 1 | Kubernetes cluster should not allow privileged containers | `95edb821-ddaf-4404-9732-666045e056b4` | Deny | Privileged = almost root on the node |
| 2 | Kubernetes clusters should not allow container privilege escalation | `1c6e92c9-99f0-4e55-9cf2-0c234dc48f99` | Deny | No setuid tricks to gain rights |
| 3 | Kubernetes cluster pods and containers should only run with approved user and group IDs | `f06ddb64-5fa3-4b77-b166-acb36f7f6042` | Deny | No root (UID 0) containers |
| 4 | Kubernetes cluster containers should run with a read only root file system | `df49d893-a74c-421d-bc95-c663042e5b80` | Deny | Files in the image cannot be changed |
| 5 | Kubernetes cluster containers should only use allowed capabilities | `c26596ff-4d70-4e6a-9a30-c2506bd2f80c` | Deny | Must drop ALL Linux capabilities |
| 6 | Kubernetes cluster containers should only use allowed images | `febd0533-8e55-448f-b837-bd0e06f16469` | Deny | Only `krconnectspractice.azurecr.io` |
| 7 | Kubernetes cluster container images should not include latest image tag | `021f8078-41a0-40e6-81b6-c6597da9f3ee` | Deny | Known, pinned versions only |
| 8 | Kubernetes cluster pods should only use approved host network and port list | `82985f06-dc18-4a48-bc1c-b9f4f0098cfe` | Deny | No hostNetwork / hostPort |
| 9 | Kubernetes cluster containers should not share host namespaces | `47a1ee2f-2a2a-4576-bf2a-e0e36709c2b8` | Deny | No hostPID / hostIPC |
| 10 | Kubernetes cluster pod hostPath volumes should only use allowed host paths | `098fc59e-46c7-4d99-9b16-64990e543d75` | Deny | No node folders mounted |
| 11 | Kubernetes clusters should disable automounting API credentials | `423dd1ba-798e-40e4-9c4d-b6902674b423` | Deny | No API token in pods by default |
| 12 | Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits | `e345eecc-fa47-480f-9e88-67dcc122b164` | **Audit** | Apps have no CPU limit on purpose |

Excluded everywhere: system namespaces (`kube-system`, `gatekeeper-system`, `azure-arc`, `azure-extensions-usage-system`)
and AKS-managed Istio (`aks-istio-system`, `aks-istio-ingress`, `aks-istio-egress`).
Policies 2-6 and 12 also skip the Istio sidecar containers `istio-init` and `istio-proxy` (root + NET_ADMIN, Microsoft images).

### B. Cluster policies (AKS resource settings, checked by Azure Policy directly)

| # | Built-in policy | Definition ID | Practice effect | Why |
|---|---|---|---|---|
| 13 | Azure Kubernetes Service Clusters should have local authentication methods disabled | `993c2fcd-2b29-49d2-9eb0-df2c3a730c32` | Audit | Entra ID login only |
| 14 | Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters | `0a15ec92-a229-4763-bb14-0ea34a568f8d` | Audit | Without it, section A does nothing |

### C. Azure resource policies (governance, network, storage, Key Vault, SQL)

| # | Built-in policy | Definition ID | Practice effect | Why |
|---|---|---|---|---|
| 15 | Allowed locations | `e56962a6-4747-49cd-b67b-bf8b01975c4c` | Deny, **DoNotEnforce** | Only Central India / South India (global resources always allowed) |
| 16 | Require a tag on resources (`environment`) | `871b6d14-10aa-478d-b590-94f262ecfa99` | Deny, **DoNotEnforce** | Cost reports and ownership |
| 17 | Network interfaces should not have public IPs | `83a86a26-fd1f-447c-b59d-e51f44264114` | Deny, **DoNotEnforce** | No VM reachable from the internet |
| 18 | Subnets should be associated with a Network Security Group | `e71308d3-144b-4262-b144-efdc3cc90517` | AuditIfNotExists | No subnet without firewall rules |
| 19 | Storage account public access should be disallowed | `4fa4b6c0-31ca-4c0d-b10d-24b96f62a751` | Audit | No anonymous blob access |
| 20 | Secure transfer to storage accounts should be enabled | `404c3081-a854-4457-ae30-26a93ef643f9` | Audit | HTTPS only |
| 21 | Storage accounts should have the specified minimum TLS version | `fe83a0eb-a853-422d-aac2-1bffd182c5d0` | Audit | TLS 1.2 or newer |
| 22 | Key vaults should have deletion protection enabled | `0b60c0b2-2dc2-4e1c-b5c9-abbed971de53` | Audit | Purge protection |
| 23 | Azure Key Vault should use RBAC permission model | `12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5` | Audit | Azure RBAC, not access policies |
| 24 | Public network access on Azure SQL Database should be disabled | `1b8ca024-1d5c-4dec-8995-b1a932b41780` | Audit | Private endpoint only |
| 25 | Azure SQL Database should have Microsoft Entra-only authentication enabled | `b3a22bc9-66de-45fb-98fa-00f5df42f41a` | Audit | No SQL logins/passwords |

**DoNotEnforce** (`enforce = false`): #15-17 have no effect parameter (always Deny), so they are switched on with
`enforce_fixed_deny_policies = true` once Compliance is clean. Until then they are evaluated and reported, but block nothing.
The others move from Audit to Deny with `azure_resource_policy_effect = "Deny"`.

### D. Other important Azure policies (interview list, not in code yet)

| Area | Built-in policy | Usual effect |
|---|---|---|
| Governance | Allowed locations for resource groups | Deny (subscription scope) |
| Governance | Not allowed resource types / Allowed virtual machine size SKUs | Deny |
| Governance | Inherit a tag from the resource group if missing | Modify (needs managed identity) |
| Network | Management ports should be closed on your virtual machines | AuditIfNotExists |
| Network | Web Application Firewall (WAF) should be enabled for Application Gateway / Azure Front Door | Audit or Deny |
| Storage | Storage accounts should disable public network access / should prevent shared key access | Audit or Deny |
| Key Vault | Azure Key Vault should disable public network access / Key Vault secrets should have an expiration date | Audit or Deny |
| SQL | Auditing on SQL server should be enabled / Transparent Data Encryption on SQL databases should be enabled | AuditIfNotExists or DeployIfNotExists |
| Compute | Azure Backup should be enabled for Virtual Machines / VMs should enable disk encryption or EncryptionAtHost | AuditIfNotExists / Audit |
| App Service | App Service apps should only be accessible over HTTPS / should use managed identity | Deny / Audit |
| ACR | Container registries should have local admin account disabled | Deny |
| Monitoring | Configure diagnostic settings to Log Analytics (per service) | DeployIfNotExists (needs managed identity + remediation) |
| Defender | Microsoft Defender for Cloud plans should be enabled (Servers, Storage, SQL, Containers) | AuditIfNotExists (subscription scope) |
| Baseline | **Microsoft cloud security benchmark** initiative (assigned by Defender for Cloud) | Audit |

Considered but not assigned (yet): HTTPS-only ingress (we use an Istio Gateway, no Ingress objects), internal load balancers only
(our Istio gateway is public), seccomp/AppArmor profiles, and the bundled *pod security restricted* initiative.

## How a policy reaches AKS

Terraform assignment -> `azure-policy` pod in AKS syncs it (~15 min) -> Gatekeeper ConstraintTemplate + Constraint
-> new pods checked at admission (Deny) -> running pods audited -> Azure Policy Compliance.

## Rollout (how companies do it)

1. Assign in **Audit** (nonprod first), check **Policy -> Compliance**, fix workloads.
2. Switch to **Deny** in nonprod, then prod (prod apply needs manual approval).
3. Exceptions are **exemptions as code** with a reason and an expiry date, never manual portal changes.

## Add a new policy

1. Find the built-in definition in **Policy -> Definitions** and copy its **name (GUID)**.
2. Add one `data` + one `resource` block in `environments/<env>/main.tf` (copy an existing pair).
3. Add a row to the catalog above, open a PR, review the plan, merge.

## CI

`.github/workflows/terraform-ci.yml` runs only when started by hand (Actions -> terraform ci -> Run workflow):
`terraform fmt -check` and `terraform validate`. No Azure login, no plan, no apply.
