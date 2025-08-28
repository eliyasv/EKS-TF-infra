###################################
# Root - variables.tf
# Description: Input variables for root module
###################################

# -----------------------------
# Global Config
# -----------------------------
variable "infra_environment" {
  description = "Deployment environment name (e.g., dev, prod)"
  type        = string
}

variable "infra_region" {
  description = "AWS region to deploy infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "infra_project_name" {
  description = "Name of the project"
  type        = string
  default     = "project-ignite"
}

variable "infra_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "infra_tags" {
  description = "Global tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "project-ignite"
    ManagedBy = "terraform"
    Owner     = "devops"
  }
}

# -----------------------------
# VPC Module Inputs
# -----------------------------
variable "infra_vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "infra_public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "infra_private_subnet_cidrs" {
  description = "List of private subnet CIDRs"
  type        = list(string)
}

variable "infra_subnet_azs" {
  description = "List of availability zones to spread subnets across"
  type        = list(string)
}

# -----------------------------
# IAM Module Inputs
# -----------------------------
variable "infra_enable_control_plane_iam" {
  description = "Whether to create IAM role for EKS control plane"
  type        = bool
  default     = true
}

variable "infra_enable_node_iam_roles" {
  description = "Whether to create IAM roles for EKS node groups"
  type        = bool
  default     = true
}

# -----------------------------
# EKS Module Inputs
# -----------------------------
variable "infra_enable_eks" {
  description = "Whether to create EKS cluster"
  type        = bool
  default     = true
}

variable "infra_cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "infra_enable_private_access" {
  description = "Enable private API access to EKS control plane endpoint"
  type        = bool
  default     = true
}

variable "infra_enable_public_access" {
  description = "Enable public API access to EKS control plane endpoint"
  type        = bool
  default     = false
}

# -----------------------------
# On-Demand Node Group
# -----------------------------
variable "infra_enable_ondemand_nodes" {
  description = "Whether to create on-demand node group"
  type        = bool
  default     = true
}

variable "infra_ondemand_instance_types" {
  description = "List of EC2 instance types for on-demand node group"
  type        = list(string)
}

variable "infra_ondemand_desired_capacity" {
  description = "Desired number of nodes for on-demand group"
  type        = number
}

variable "infra_ondemand_min_capacity" {
  description = "Minimum number of nodes for on-demand group"
  type        = number
}

variable "infra_ondemand_max_capacity" {
  description = "Maximum number of nodes for on-demand group"
  type        = number
}

# -----------------------------
# Spot Node Group
# -----------------------------
variable "infra_enable_spot_nodes" {
  description = "Whether to create spot node group"
  type        = bool
  default     = true
}

variable "infra_spot_instance_types" {
  description = "List of EC2 instance types for spot node group"
  type        = list(string)
}

variable "infra_spot_desired_capacity" {
  description = "Desired number of nodes for spot group"
  type        = number
}

variable "infra_spot_min_capacity" {
  description = "Minimum number of nodes for spot group"
  type        = number
}

variable "infra_spot_max_capacity" {
  description = "Maximum number of nodes for spot group"
  type        = number
}

# -----------------------------
# EKS Add-ons
# -----------------------------
variable "infra_eks_addons" {
  description = "List of EKS managed addons (vpc-cni, CoreDNS, etc.)"
  type = list(object({
    name    = string
    version = string
  }))
}
