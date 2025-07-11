
# modules/iam/outputs.tf

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = try(aws_iam_openid_connect_provider.ignite_eks_oidc_provider[0].arn, null)
}

output "control_plane_iam_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  value       = try(aws_iam_role.ignite_eks_cluster_role[0].arn, null)
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN for EKS node groups"
  value       = try(aws_iam_role.ignite_eks_nodegroup_role[0].arn, null)
}
