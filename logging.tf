locals {
  enable_cloudwatch_logs = var.infra_enable_cloudwatch_logs && var.infra_enable_eks && var.infra_enable_irsa
}

variable "infra_enable_cloudwatch_logs" {
  description = "Create the application log group and logging:fluent-bit IRSA role."
  type        = bool
  default     = false
}

resource "aws_cloudwatch_log_group" "application" {
  count             = local.enable_cloudwatch_logs ? 1 : 0
  name              = "/eks/${var.infra_cluster_name}/application"
  retention_in_days = 7
  tags              = var.infra_tags
}

resource "aws_iam_role" "fluent_bit" {
  count = local.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.infra_cluster_name}-fluent-bit-irsa"
  tags  = var.infra_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:logging:fluent-bit"
          "${replace(module.eks.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "fluent_bit" {
  count = local.enable_cloudwatch_logs ? 1 : 0
  name  = "application-log-write"
  role  = aws_iam_role.fluent_bit[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogStreams"]
        Resource = aws_cloudwatch_log_group.application[0].arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.application[0].arn}:log-stream:*"
      }
    ]
  })
}

output "fluent_bit_irsa_role_arn" {
  value      = try(aws_iam_role.fluent_bit[0].arn, null)
  depends_on = [aws_iam_role_policy.fluent_bit]
}

output "application_log_group_name" {
  value = try(aws_cloudwatch_log_group.application[0].name, null)
}
