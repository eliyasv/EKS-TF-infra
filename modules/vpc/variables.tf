
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
variable "infra_subnets" {
  type = map(object({
    az           = string
    public_cidr  = string
    private_cidr = string
  }))
}

variable "infra_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "infra_bastion_cidr" {
  description = "CIDR block for bastion host access (optional)."
  type        = string
  default     = null
}

variable "infra_bastion_sg_id" {
  description = "Security Group ID of bastion host (optional, preferred)."
  type        = string
  default     = null
}
