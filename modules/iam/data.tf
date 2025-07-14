# Trust policy for EKS control plane
data "aws_iam_policy_document" "infra_eks_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# Trust policy for EC2 node groups (EKS workers)
data "aws_iam_policy_document" "infra_ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Trust policy for IRSA (IAM Role for Service Account)
data "aws_iam_policy_document" "infra_irsa_assume_policy" {
  count = var.infra_enable_irsa ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ignite_eks_oidc_provider[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.infra_oidc_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:*"]
    }
  }
}
