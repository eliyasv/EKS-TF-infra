#Allows federated access by the EKS cluster's OIDC provider, limited to a specific Kubernetes service account.
# NOTE: This data source is unconditional. The condition is applied at the resource level.
# Using count here causes issues with unknown values during terraform plan when OIDC values come from other resources.
data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {
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
