###################################
# Root - main.tf
# Composes the infrastructure using VPC, IAM, and EKS modules
###################################

# Build a consistent `infra_subnets` map when individual subnet lists are provided
locals {
  infra_subnets = var.infra_subnets != null ? var.infra_subnets : {
    for idx, az in var.infra_subnet_azs : "subnet-${idx}" => {
      az           = az
      public_cidr  = var.infra_public_subnet_cidrs[idx]
      private_cidr = var.infra_private_subnet_cidrs[idx]
    }
  }
}

# -----------------------------
# VPC Module
# -----------------------------
module "vpc" {
  source = "./modules/vpc"

  infra_environment          = var.infra_environment
  infra_project_name         = var.infra_project_name
  infra_cluster_name         = var.infra_cluster_name
  infra_vpc_cidr             = var.infra_vpc_cidr
  infra_subnets              = local.infra_subnets
  infra_bastion_cidr         = var.infra_bastion_cidr
  infra_bastion_sg_id       = var.infra_bastion_sg_id
  infra_tags                 = var.infra_tags
}

# -----------------------------
# IAM Core Module (create core roles and attach policies)
# -----------------------------
module "iam_core" {
  source = "./modules/iam"

  infra_environment               = var.infra_environment
  infra_project_name              = var.infra_project_name
  infra_cluster_name              = var.infra_cluster_name

  infra_create_eks_cluster_role   = var.infra_enable_control_plane_iam
  infra_create_eks_nodegroup_role = var.infra_enable_node_iam_roles

  infra_use_managed_policies = true
}

# -----------------------------
# EKS Module
# -----------------------------
module "eks" {
  source = "./modules/eks"

  infra_environment  = var.infra_environment
  infra_project_name = var.infra_project_name

  infra_cluster_name    = var.infra_cluster_name
  infra_cluster_version = var.infra_cluster_version

  infra_enable_eks            = var.infra_enable_eks
  infra_enable_private_access = var.infra_enable_private_access
  infra_enable_public_access  = var.infra_enable_public_access

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  eks_security_group_id = module.vpc.eks_security_group_id

  # These values wait for IAM policy propagation (provided by iam_core)
  control_plane_iam_role_arn = module.iam_core.control_plane_iam_role_arn
  node_group_iam_role_arn    = module.iam_core.node_group_iam_role_arn

  infra_enable_ondemand_nodes     = var.infra_enable_ondemand_nodes
  infra_ondemand_instance_types   = var.infra_ondemand_instance_types
  infra_ondemand_desired_capacity = var.infra_ondemand_desired_capacity
  infra_ondemand_min_capacity     = var.infra_ondemand_min_capacity
  infra_ondemand_max_capacity     = var.infra_ondemand_max_capacity

  infra_enable_spot_nodes     = var.infra_enable_spot_nodes
  infra_spot_instance_types   = var.infra_spot_instance_types
  infra_spot_desired_capacity = var.infra_spot_desired_capacity
  infra_spot_min_capacity     = var.infra_spot_min_capacity
  infra_spot_max_capacity     = var.infra_spot_max_capacity
  infra_eks_addons            = var.infra_eks_addons

  infra_tags                  = var.infra_tags
}

# -----------------------------
# IAM IRSA Module (create IRSA roles after EKS and OIDC provider exist)
# -----------------------------
module "iam_irsa" {
  source = "./modules/iam"

  infra_environment  = var.infra_environment
  infra_project_name = var.infra_project_name
  infra_cluster_name = var.infra_cluster_name

  infra_create_eks_cluster_role   = false
  infra_create_eks_nodegroup_role = false
  infra_enable_irsa = true
  infra_irsa_role_name = "${var.infra_cluster_name}-irsa-role"
  infra_irsa_policy_arns = []

  # OIDC provider created by EKS module
  infra_oidc_provider_arn = module.eks.oidc_provider_arn
  infra_oidc_url          = module.eks.oidc_issuer_url

  depends_on = [module.eks]
}
