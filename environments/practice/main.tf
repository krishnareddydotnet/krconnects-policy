# -----------------------------------------------------------------------------
# Azure Policy as code for the KRConnects AKS practice cluster.
#
# Pattern for every policy (same 2 blocks each time):
#   1. data     "azurerm_policy_definition"              -> READ a BUILT-IN definition (Microsoft owns it)
#   2. resource "azurerm_resource_group_policy_assignment" -> ASSIGN it to our resource group (we own this)
#
# Definitions are looked up by "name" (a fixed GUID), not by display name:
# display names are not unique and Microsoft can change them; the GUID never changes.
#
# What happens after "terraform apply":
#   Azure Policy assignment -> azure-policy pod in AKS syncs it (~15 min) -> Gatekeeper ConstraintTemplate
#   + Constraint -> new pods are checked at admission (Deny) and running pods are audited (Compliance).
# -----------------------------------------------------------------------------

# The scope: every assignment below applies to this resource group (and so to the AKS cluster in it).
data "azurerm_resource_group" "aks" {
  name = var.resource_group_name
}

# =============================================================================
# A. WORKLOAD POLICIES (pods and containers inside AKS, enforced by Gatekeeper)
# =============================================================================

# 1. No privileged containers: a privileged container is almost root on the NODE (container escape).
data "azurerm_policy_definition" "no_privileged" {
  name = "95edb821-ddaf-4404-9732-666045e056b4" # Kubernetes cluster should not allow privileged containers
}

resource "azurerm_resource_group_policy_assignment" "no_privileged" {
  name                 = "aks-no-privileged-containers"
  display_name         = "AKS: no privileged containers"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.no_privileged.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
  })

  non_compliance_message {
    content = "Privileged containers are not allowed (securityContext.privileged must be false)."
  }
}

# 2. No privilege escalation: a process may never gain more rights than it started with (setuid binaries).
data "azurerm_policy_definition" "no_privilege_escalation" {
  name = "1c6e92c9-99f0-4e55-9cf2-0c234dc48f99" # Kubernetes clusters should not allow container privilege escalation
}

resource "azurerm_resource_group_policy_assignment" "no_privilege_escalation" {
  name                 = "aks-no-privilege-escalation"
  display_name         = "AKS: no container privilege escalation"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.no_privilege_escalation.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
    excludedContainers = { value = var.istio_excluded_containers }
  })

  non_compliance_message {
    content = "Set securityContext.allowPrivilegeEscalation: false on every container."
  }
}

# 3. Non-root only: blocks containers that would run as UID 0 (root).
data "azurerm_policy_definition" "non_root" {
  name = "f06ddb64-5fa3-4b77-b166-acb36f7f6042" # Kubernetes cluster pods and containers should only run with approved user and group IDs
}

resource "azurerm_resource_group_policy_assignment" "non_root" {
  name                 = "aks-run-as-non-root"
  display_name         = "AKS: containers must run as non-root"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.non_root.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
    excludedContainers = { value = var.istio_excluded_containers } # istio-init must run as root
    runAsUserRule      = { value = "MustRunAsNonRoot" }            # the only rule we need; group rules stay RunAsAny
  })

  non_compliance_message {
    content = "Containers must run as non-root (securityContext.runAsNonRoot: true and a non-zero runAsUser)."
  }
}

# 4. Read-only root filesystem: nobody can change files or drop tools inside the container.
data "azurerm_policy_definition" "read_only_root_fs" {
  name = "df49d893-a74c-421d-bc95-c663042e5b80" # Kubernetes cluster containers should run with a read only root file system
}

resource "azurerm_resource_group_policy_assignment" "read_only_root_fs" {
  name                 = "aks-read-only-root-filesystem"
  display_name         = "AKS: read-only root filesystem"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.read_only_root_fs.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
    excludedContainers = { value = var.istio_excluded_containers }
  })

  non_compliance_message {
    content = "Set securityContext.readOnlyRootFilesystem: true; use an emptyDir volume for folders that must be writable."
  }
}

# 5. Capabilities: every container must drop ALL Linux capabilities and may add none back.
data "azurerm_policy_definition" "drop_all_capabilities" {
  name = "c26596ff-4d70-4e6a-9a30-c2506bd2f80c" # Kubernetes cluster containers should only use allowed capabilities
}

resource "azurerm_resource_group_policy_assignment" "drop_all_capabilities" {
  name                 = "aks-drop-all-capabilities"
  display_name         = "AKS: drop ALL capabilities"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.drop_all_capabilities.id

  parameters = jsonencode({
    effect                   = { value = var.workload_policy_effect }
    excludedNamespaces       = { value = var.excluded_namespaces }
    excludedContainers       = { value = var.istio_excluded_containers } # istio-init needs NET_ADMIN and NET_RAW
    allowedCapabilities      = { value = [] }                            # nothing may be added back
    requiredDropCapabilities = { value = ["ALL"] }                       # capabilities: drop: ["ALL"] is mandatory
  })

  non_compliance_message {
    content = "Containers must set capabilities.drop: [\"ALL\"] and add no capabilities."
  }
}

# 6. Allowed images: only images from our private ACR (supply chain: scanned and signed images only).
data "azurerm_policy_definition" "allowed_images" {
  name = "febd0533-8e55-448f-b837-bd0e06f16469" # Kubernetes cluster containers should only use allowed images
}

resource "azurerm_resource_group_policy_assignment" "allowed_images" {
  name                 = "aks-allowed-images-acr-only"
  display_name         = "AKS: images from krconnectspractice ACR only"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.allowed_images.id

  parameters = jsonencode({
    effect                      = { value = var.workload_policy_effect }
    excludedNamespaces          = { value = var.excluded_namespaces }
    excludedContainers          = { value = var.istio_excluded_containers } # sidecar images come from mcr.microsoft.com
    allowedContainerImagesRegex = { value = var.allowed_container_images_regex }
  })

  non_compliance_message {
    content = "Only images from krconnectspractice.azurecr.io are allowed."
  }
}

# 7. No ":latest" tag: a moving tag means you cannot tell which version runs (we pin by digest anyway).
data "azurerm_policy_definition" "no_latest_tag" {
  name = "021f8078-41a0-40e6-81b6-c6597da9f3ee" # Kubernetes cluster container images should not include latest image tag
}

resource "azurerm_resource_group_policy_assignment" "no_latest_tag" {
  name                 = "aks-no-latest-image-tag"
  display_name         = "AKS: no latest image tag"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.no_latest_tag.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
  })

  non_compliance_message {
    content = "Do not use the :latest tag; pin a version tag and digest (image:tag@sha256:...)."
  }
}

# 8. No host network or host ports: a pod must not use the NODE's network directly.
data "azurerm_policy_definition" "no_host_network" {
  name = "82985f06-dc18-4a48-bc1c-b9f4f0098cfe" # Kubernetes cluster pods should only use approved host network and port list
}

resource "azurerm_resource_group_policy_assignment" "no_host_network" {
  name                 = "aks-no-host-network-ports"
  display_name         = "AKS: no host network or host ports"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.no_host_network.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
    allowHostNetwork   = { value = false } # hostNetwork: true is not allowed
    allowedHostPorts   = { value = [] }    # no hostPort at all
  })

  non_compliance_message {
    content = "hostNetwork and hostPort are not allowed."
  }
}

# 9. No host PID / IPC: a pod must not see or signal the NODE's processes.
data "azurerm_policy_definition" "no_host_namespaces" {
  name = "47a1ee2f-2a2a-4576-bf2a-e0e36709c2b8" # Kubernetes cluster containers should not share host namespaces
}

resource "azurerm_resource_group_policy_assignment" "no_host_namespaces" {
  name                 = "aks-no-host-pid-ipc"
  display_name         = "AKS: no host PID or IPC namespace"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.no_host_namespaces.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
  })

  non_compliance_message {
    content = "hostPID and hostIPC are not allowed."
  }
}

# 10. No hostPath volumes: a pod must not mount NODE folders (e.g. / or the container runtime socket).
data "azurerm_policy_definition" "no_host_path" {
  name = "098fc59e-46c7-4d99-9b16-64990e543d75" # Kubernetes cluster pod hostPath volumes should only use allowed host paths
}

resource "azurerm_resource_group_policy_assignment" "no_host_path" {
  name                 = "aks-no-host-path-volumes"
  display_name         = "AKS: no hostPath volumes"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.no_host_path.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
    allowedHostPaths   = { value = { paths = [] } } # empty list = no host path is allowed
  })

  non_compliance_message {
    content = "hostPath volumes are not allowed; use emptyDir, a PVC or the Key Vault CSI driver."
  }
}

# 11. No automatic Kubernetes API token in pods: a stolen token cannot be used to call the API server.
data "azurerm_policy_definition" "no_automount_token" {
  name = "423dd1ba-798e-40e4-9c4d-b6902674b423" # Kubernetes clusters should disable automounting API credentials
}

resource "azurerm_resource_group_policy_assignment" "no_automount_token" {
  name                 = "aks-no-automount-sa-token"
  display_name         = "AKS: no automounted service account token"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.no_automount_token.id

  parameters = jsonencode({
    effect             = { value = var.workload_policy_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
  })

  non_compliance_message {
    content = "Set automountServiceAccountToken: false unless the pod really calls the Kubernetes API."
  }
}

# 12. CPU and memory limits must exist and stay under a maximum: one pod cannot starve the node.
#     Own effect variable (Audit): our apps set memory limits only (no CPU limit on purpose, to avoid throttling),
#     so Deny would block them. A good example of why rollout starts with Audit.
data "azurerm_policy_definition" "resource_limits" {
  name = "e345eecc-fa47-480f-9e88-67dcc122b164" # Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits
}

resource "azurerm_resource_group_policy_assignment" "resource_limits" {
  name                 = "aks-cpu-memory-limits"
  display_name         = "AKS: CPU and memory limits within maximum"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.resource_limits.id

  parameters = jsonencode({
    effect             = { value = var.resource_limits_effect }
    excludedNamespaces = { value = var.excluded_namespaces }
    excludedContainers = { value = var.istio_excluded_containers }
    cpuLimit           = { value = var.cpu_limit_max }
    memoryLimit        = { value = var.memory_limit_max }
  })

  non_compliance_message {
    content = "Every container needs CPU and memory limits no higher than the allowed maximum."
  }
}

# =============================================================================
# B. CLUSTER POLICIES (settings of the AKS resource itself, checked by Azure Policy directly)
#    These built-ins support only Audit or Disabled.
# =============================================================================

# 13. Local accounts off: only Entra ID login, no shared admin kubeconfig that never expires.
data "azurerm_policy_definition" "local_auth_disabled" {
  name = "993c2fcd-2b29-49d2-9eb0-df2c3a730c32" # Azure Kubernetes Service Clusters should have local authentication methods disabled
}

resource "azurerm_resource_group_policy_assignment" "local_auth_disabled" {
  name                 = "aks-local-auth-disabled"
  display_name         = "AKS: local accounts disabled"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.local_auth_disabled.id

  parameters = jsonencode({
    effect = { value = var.cluster_policy_effect }
  })

  non_compliance_message {
    content = "Disable local accounts on AKS (disableLocalAccounts: true) and use Entra ID."
  }
}

# 14. Azure Policy add-on installed: without it, none of the workload policies above reach the cluster.
data "azurerm_policy_definition" "policy_addon_enabled" {
  name = "0a15ec92-a229-4763-bb14-0ea34a568f8d" # Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters
}

resource "azurerm_resource_group_policy_assignment" "policy_addon_enabled" {
  name                 = "aks-policy-addon-enabled"
  display_name         = "AKS: Azure Policy add-on enabled"
  resource_group_id    = data.azurerm_resource_group.aks.id
  policy_definition_id = data.azurerm_policy_definition.policy_addon_enabled.id

  parameters = jsonencode({
    effect = { value = var.cluster_policy_effect }
  })

  non_compliance_message {
    content = "Enable the Azure Policy add-on on every AKS cluster."
  }
}
