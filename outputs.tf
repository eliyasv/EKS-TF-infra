# -------------------------------
# Root - outputs.tf
# Description: Consolidated outputs from submodules
# -------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.infra_enable_eks ? module.eks.ignite_cluster_id : null
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = var.infra_enable_eks ? module.eks.ignite_cluster_endpoint : null
}

output "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = var.infra_enable_eks ? module.eks.ignite_cluster_version : null
}

output "eks_nodegroup_ondemand_name" {
  description = "Name of the on-demand node group"
  value       = var.infra_enable_ondemand_nodes ? module.eks.ignite_nodegroup_ondemand_name : null
}

output "eks_nodegroup_spot_name" {
  description = "Name of the spot node group"
  value       = var.infra_enable_spot_nodes ? module.eks.ignite_nodegroup_spot_name : null
}

output "eks_oidc_provider_url" {
  description = "OIDC issuer URL for IRSA"
  value       = var.infra_enable_irsa ? module.eks.oidc_issuer_url : null
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = var.infra_enable_irsa ? module.iam.oidc_provider_arn : null
}

output "eks_control_plane_role_arn" {
  description = "IAM Role ARN for EKS control plane"
  value       = var.infra_enable_control_plane_iam ? module.iam.control_plane_iam_role_arn : null
}

output "eks_node_group_role_arn" {
  description = "IAM Role ARN for EKS node group"
  value       = var.infra_enable_node_iam_roles ? module.iam.node_group_iam_role_arn : null
}
