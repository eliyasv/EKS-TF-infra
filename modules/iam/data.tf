#Allows federated access by the EKS cluster's OIDC provider, limited to a specific Kubernetes service account.
data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {
  count = var.infra_enable_irsa && var.infra_oidc_provider_arn != null && var.infra_oidc_url != null ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.infra_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.infra_oidc_url, "https://", "")}:sub"
      values   = [var.infra_irsa_subject]
    }
  }
}
