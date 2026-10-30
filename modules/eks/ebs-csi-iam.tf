# Keep the role within this module: cluster -> OIDC -> role -> add-on.
# It must not depend on the add-on or on a whole IAM module waiting for EKS.
variable "infra_enable_ebs_csi_irsa" {
  description = "Give the managed EBS CSI add-on a dedicated IRSA identity. Root follows infra_enable_irsa; no resources are created if EKS or the add-on is absent."
  type        = bool
  default     = true
}

locals {
  enable_ebs_csi_irsa = var.infra_enable_eks && var.infra_enable_ebs_csi_irsa && contains(
    var.infra_eks_addons == null ? [] : [for addon in var.infra_eks_addons : addon.name],
    "aws-ebs-csi-driver"
  )
}

resource "aws_iam_role" "ebs_csi" {
  count = local.enable_ebs_csi_irsa ? 1 : 0
  name  = "${var.infra_cluster_name}-ebs-csi-irsa"
  tags  = var.infra_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.ignite_eks_oidc_provider[0].arn }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.ignite_cluster[0].identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(aws_eks_cluster.ignite_cluster[0].identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = local.enable_ebs_csi_irsa ? 1 : 0
  role  = aws_iam_role.ebs_csi[0].name
  # Preserve the existing policy behavior; V2/KMS policy changes need separate review.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

output "ebs_csi_irsa_role_arn" {
  description = "Dedicated managed EBS CSI role; null when disabled or the add-on is absent."
  value       = try(aws_iam_role.ebs_csi[0].arn, null)
  depends_on  = [aws_iam_role_policy_attachment.ebs_csi]
}
