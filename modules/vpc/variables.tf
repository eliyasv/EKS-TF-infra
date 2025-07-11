
# ------------------------
# modules/vpc/variables.tf
# ------------------------

variable "infra_environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "infra_project_name" {
  description = "Project name prefix"
  type        = string
}

variable "infra_cluster_name" {
  description = "EKS cluster name for tagging"
  type        = string
}

variable "infra_vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "infra_subnet_azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "infra_public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
}

variable "infra_private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
}

variable "infra_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
