# ------------------------
# modules/iam/variables.tf
# ------------------------
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

variable "infra_irsa_policy_json" {
  description = "JSON IAM policy for IRSA role"
  type        = string
  default     = null
}
