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
    ├── nonprod/                         placeholder: scope mg-nonprod, effect Audit
    └── prod/                            placeholder: scope mg-prod, effect Deny + manual approval
```

## Policy catalog (managed by Terraform)

All are **built-in** definitions, assigned in `environments/practice/main.tf` at resource group scope.

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
