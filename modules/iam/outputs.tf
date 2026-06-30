#----------------------
# modules/iam/outputs.tf
#-----------------------


output "control_plane_iam_role_arn" {
  description = "The ARN of the EKS control plane IAM role"
  value       = try(aws_iam_role.ignite_eks_cluster_role[0].arn, null)

  # Ensure policy is attached before the ARN is "ready" to prevent race condition
  depends_on = [
    aws_iam_role_policy_attachment.ignite_eks_cluster_policy
  ]
}

output "node_group_iam_role_arn" {
  description = "The ARN of the EKS node group IAM role"
  value       = try(aws_iam_role.ignite_eks_nodegroup_role[0].arn, null)

  # Wait for all node policies to be attached
  depends_on = [
    aws_iam_role_policy_attachment.ignite_nodegroup_worker_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_cni_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_registry_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_ebs_policy
  ]
}

# A "readiness" output that can be used to force dependencies
output "iam_policies_propagated" {
  description = "A boolean to indicate if all IAM policies are attached and ready"
  value       = true
  depends_on = [
    aws_iam_role_policy_attachment.ignite_eks_cluster_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_worker_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_cni_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_registry_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_ebs_policy
  ]
}

output "irsa_role_arn" {
  description = "ARN of the IRSA IAM role created by this module (if any)"
  value       = try(aws_iam_role.ignite_irsa_role[0].arn, null)
  depends_on = [
    aws_iam_role_policy_attachment.ignite_irsa_policy_attachments
  ]
}

