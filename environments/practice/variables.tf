variable "subscription_id" {
  description = "Azure subscription that contains the AKS resource group."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that is the SCOPE of every assignment (the AKS cluster lives in it)."
  type        = string
}

variable "workload_policy_effect" {
  description = "Effect for the pod/container policies. Start with Audit (report only), switch to Deny (block) once compliance is clean."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.workload_policy_effect)
    error_message = "workload_policy_effect must be Audit, Deny or Disabled."
  }
}

variable "resource_limits_effect" {
  description = "Effect for the CPU/memory limits policy. Kept separate: our apps set memory limits only (no CPU limit on purpose), so Deny would block them."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.resource_limits_effect)
    error_message = "resource_limits_effect must be Audit, Deny or Disabled."
  }
}

variable "cluster_policy_effect" {
  description = "Effect for the AKS cluster-level policies. These built-ins only support Audit or Disabled."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Disabled"], var.cluster_policy_effect)
    error_message = "cluster_policy_effect must be Audit or Disabled."
  }
}

variable "excluded_namespaces" {
  description = "Namespaces no workload policy checks: AKS and Gatekeeper system pods, plus the AKS-managed Istio namespaces (Microsoft images and settings)."
  type        = list(string)
  default = [
    "kube-system",
    "gatekeeper-system",
    "azure-arc",
    "azure-extensions-usage-system",
    "aks-istio-system",
    "aks-istio-ingress",
    "aks-istio-egress",
  ]
}

variable "istio_excluded_containers" {
  description = "Istio sidecar containers skipped by some policies: istio-init needs root + NET_ADMIN to set up traffic redirection, and both come from Microsoft's registry (mcr.microsoft.com)."
  type        = list(string)
  default     = ["istio-init", "istio-proxy"]
}

variable "allowed_container_images_regex" {
  description = "Regex an image must match to be allowed. Only our private ACR."
  type        = string
}

variable "cpu_limit_max" {
  description = "Highest CPU limit one container may set (e.g. 1000m = 1 CPU)."
  type        = string
  default     = "1000m"
}

variable "memory_limit_max" {
  description = "Highest memory limit one container may set."
  type        = string
  default     = "1Gi"
}
