
# ------------------------
# modules/eks/variables.tf
# ------------------------

variable "infra_environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "infra_project_name" {
  description = "Project name prefix"
  type        = string
}

variable "infra_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "infra_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "infra_cluster_version" {
  description = "Kubernetes version for the cluster"
  type        = string
}

variable "infra_enable_eks" {
  description = "Whether to create the EKS cluster"
  type        = bool
  default     = true
}

variable "infra_enable_private_api" {
  description = "Enable private API access"
  type        = bool
  default     = true
}

variable "infra_enable_public_api" {
  description = "Enable public API access"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "control_plane_iam_role_arn" {
  description = "IAM role ARN for EKS control plane"
  type        = string
}

variable "node_group_iam_role_arn" {
  description = "IAM role ARN for EKS node group"
  type        = string
}

variable "infra_enable_ondemand_nodes" {
  description = "Enable on-demand node group"
  type        = bool
  default     = true
}

variable "infra_ondemand_instance_types" {
  description = "Instance types for on-demand nodes"
  type        = list(string)
}

variable "infra_ondemand_desired_capacity" {
  description = "Desired capacity for on-demand node group"
  type        = number
}

variable "infra_ondemand_min_capacity" {
  description = "Minimum capacity for on-demand node group"
  type        = number
}

variable "infra_ondemand_max_capacity" {
  description = "Maximum capacity for on-demand node group"
  type        = number
}

variable "infra_enable_spot_nodes" {
  description = "Enable spot node group"
  type        = bool
  default     = true
}

variable "infra_spot_instance_types" {
  description = "Instance types for spot nodes"
  type        = list(string)
}

variable "infra_spot_desired_capacity" {
  description = "Desired capacity for spot node group"
  type        = number
}

variable "infra_spot_min_capacity" {
  description = "Minimum capacity for spot node group"
  type        = number
}

variable "infra_spot_max_capacity" {
  description = "Maximum capacity for spot node group"
  type        = number
}

variable "infra_eks_addons" {
  description = "List of EKS add-ons"
  type = list(object({
    name    = string
    version = string
  }))
}
