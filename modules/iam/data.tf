#Allows federated access by the EKS cluster's OIDC provider, limited to a specific Kubernetes service account.
# NOTE: This data source is unconditional. The condition block is dynamic to handle null OIDC URL.
# The actual resource-level condition is applied via count in the role resource.
data "aws_iam_policy_document" "eks_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.infra_oidc_provider_arn]
    }
  }

  # Only add the OIDC subject condition if URL is provided
  dynamic "statement" {
    for_each = var.infra_oidc_url != null ? [1] : []
    content {
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
}
