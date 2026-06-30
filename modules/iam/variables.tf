# ------------------------
# modules/iam/variables.tf
# ------------------------

variable "infra_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "infra_environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "infra_project_name" {
  description = "Project name"
  type        = string
}

variable "infra_create_eks_cluster_role" {
  description = "Flag to create EKS cluster IAM role"
  type        = bool
}

variable "infra_create_eks_nodegroup_role" {
  description = "Flag to create EKS nodegroup IAM role"
  type        = bool
}

# Policy selection: managed (default) or provide your own custom policy ARNs
variable "infra_use_managed_policies" {
  description = "When true, attach AWS-managed policies. When false, attach ARNs provided in the custom policy lists."
  type        = bool
  default     = true
}

variable "infra_control_plane_custom_policy_arns" {
  description = "Optional list of custom policy ARNs to attach to the EKS control plane role when `infra_use_managed_policies` is false."
  type        = list(string)
  default     = []
}

variable "infra_nodegroup_custom_policy_arns" {
  description = "Optional list of custom policy ARNs to attach to the EKS nodegroup role when `infra_use_managed_policies` is false."
  type        = list(string)
  default     = []
}

# IRSA (IAM Roles for Service Accounts) support
variable "infra_enable_irsa" {
  description = "Whether to create an IRSA IAM role in this module invocation"
  type        = bool
  default     = false
}

variable "infra_irsa_role_name" {
  description = "Name for the IRSA IAM role to create (when infra_enable_irsa = true)"
  type        = string
  default     = ""
}

variable "infra_irsa_subject" {
  description = "OIDC subject for the service account to allow (e.g. 'system:serviceaccount:namespace:name')"
  type        = string
  default     = "system:serviceaccount:default:aws-test"
}

variable "infra_irsa_policy_arns" {
  description = "List of policy ARNs to attach to the IRSA role"
  type        = list(string)
  default     = []
}

variable "infra_oidc_url" {
  description = "OIDC provider URL for EKS"
  type        = string
  default     = null
}

variable "infra_oidc_thumbprint" {
  description = "OIDC provider thumbprint"
  type        = string
  default     = null
}

variable "infra_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the cluster (if created externally)"
  type        = string
  default     = null
}
