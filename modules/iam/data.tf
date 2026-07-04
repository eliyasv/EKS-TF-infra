#Allows federated access by the EKS cluster's OIDC provider, limited to a specific Kubernetes service account.
# NOTE: count is safe here because it only depends on var.infra_enable_irsa (a simple boolean)
# not on resource attributes from other modules.
data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {
  count = var.infra_enable_irsa ? 1 : 0

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
