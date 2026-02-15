#Allows federated access by the EKS cluster's OIDC provider, limited to a specific Kubernetes service account.
data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {
  count = var.infra_oidc_url != null && var.infra_oidc_thumbprint != null ? 1 : 0
  
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ignite_eks_oidc_provider[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.infra_oidc_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:aws-test"]  # Change namespace/serviceaccount as needed
    }
  }
}
