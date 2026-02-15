###################################
# Root - main.tf
# Description: Composes the infrastructure using VPC, IAM, and EKS modules
###################################

# -----------------------------
# VPC Module
# -----------------------------
module "vpc" {
  source = "./modules/vpc"

  infra_environment          = var.infra_environment
  infra_project_name         = var.infra_project_name
  infra_cluster_name         = var.infra_cluster_name
  infra_vpc_cidr             = var.infra_vpc_cidr
  infra_public_subnet_cidrs  = var.infra_public_subnet_cidrs
  infra_private_subnet_cidrs = var.infra_private_subnet_cidrs
  infra_subnet_azs           = var.infra_subnet_azs
  infra_tags                 = var.infra_tags
}

# IAM pre: control-plane + nodegroup roles only (no OIDC/IRSA)
module "iam_pre" {
  source = "./modules/iam"

  infra_environment               = var.infra_environment
  infra_project_name              = var.infra_project_name
  infra_cluster_name              = var.infra_cluster_name

  infra_create_eks_cluster_role   = var.infra_enable_control_plane_iam
  infra_create_eks_nodegroup_role = var.infra_enable_node_iam_roles

  # Leave OIDC inputs null so OIDC/IRSA resources are skipped in this pass
  infra_oidc_url        = null
  infra_oidc_thumbprint = null
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

  infra_enable_eks         = var.infra_enable_eks
  infra_enable_private_access = var.infra_enable_private_access
  infra_enable_public_access = var.infra_enable_public_access

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  control_plane_iam_role_arn = module.iam_pre.control_plane_iam_role_arn
  node_group_iam_role_arn    = module.iam_pre.node_group_iam_role_arn

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

# Conditionally create IAM IRSA module only when both EKS and IRSA are enabled
module "iam_irsa" {
  count = var.infra_enable_eks && var.infra_enable_irsa ? 1 : 0
  source = "./modules/iam"

  infra_environment  = var.infra_environment
  infra_project_name = var.infra_project_name
  infra_cluster_name = var.infra_cluster_name

  # Do not recreate roles; this pass only does OIDC/IRSA
  infra_create_eks_cluster_role   = false
  infra_create_eks_nodegroup_role = false

  infra_oidc_url        = module.eks.oidc_issuer_url
  infra_oidc_thumbprint = data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint

  # Make sure IRSA runs after cluster
  depends_on = [module.eks]
}