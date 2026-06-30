# ------------------------
# modules/eks/outputs.tf
# ------------------------

output "ignite_cluster_id" {
  value       = try(aws_eks_cluster.ignite_cluster[0].id, null)
  description = "ID of the EKS cluster"
}

output "ignite_cluster_name" {
  description = "EKS cluster name"
  value       = try(aws_eks_cluster.ignite_cluster[0].name, null)
}

output "ignite_cluster_version" {
  value       = try(aws_eks_cluster.ignite_cluster[0].version, null)
  description = "Kubernetes version"
}

output "ignite_cluster_endpoint" {
  value       = try(aws_eks_cluster.ignite_cluster[0].endpoint, null)
  description = "EKS cluster endpoint"
}

output "ignite_nodegroup_ondemand_name" {
  value       = try(aws_eks_node_group.ignite_ondemand_nodes[0].node_group_name, null)
  description = "Name of the on-demand node group"
}

output "ignite_nodegroup_spot_name" {
  value       = try(aws_eks_node_group.ignite_spot_nodes[0].node_group_name, null)
  description = "Name of the spot node group"
}

output "oidc_issuer_url" {
  description = "OIDC Issuer URL"
  value       = try(aws_eks_cluster.ignite_cluster[0].identity[0].oidc[0].issuer, null)
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN created for the cluster"
  value       = try(aws_iam_openid_connect_provider.ignite_eks_oidc_provider[0].arn, null)
}

output "oidc_thumbprint" {
  description = "OIDC provider TLS thumbprint (SHA1)"
  value       = try(data.tls_certificate.oidc_thumbprint[0].certificates[0].sha1_fingerprint, null)
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS"
  value       = var.private_subnet_ids
}

