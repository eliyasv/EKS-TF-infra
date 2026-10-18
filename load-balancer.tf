# Optional AWS permissions only. Helm installation happens after the cluster is ready.
variable "infra_enable_load_balancer_controller" {
  description = "Create the dedicated Load Balancer Controller IAM policy and IRSA role."
  type        = bool
  default     = false

  validation {
    condition     = !var.infra_enable_load_balancer_controller || (var.infra_enable_eks && var.infra_enable_irsa)
    error_message = "Load Balancer Controller permissions require EKS and IRSA to be enabled."
  }
}

resource "aws_iam_policy" "load_balancer_controller" {
  count       = var.infra_enable_load_balancer_controller ? 1 : 0
  name        = "${var.infra_cluster_name}-load-balancer-controller"
  description = "Official AWS Load Balancer Controller v3.6.0 policy"
  # Vendored from the matching upstream release; review policy and chart together.
  policy = file("${path.module}/policies/aws-load-balancer-controller-v3.6.0.json")
  tags   = var.infra_tags
}

resource "aws_iam_role" "load_balancer_controller" {
  count = var.infra_enable_load_balancer_controller ? 1 : 0
  name  = "${var.infra_cluster_name}-load-balancer-controller-irsa"
  tags  = var.infra_tags

  # Only this cluster's kube-system controller service account can assume the role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(module.eks.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  count      = var.infra_enable_load_balancer_controller ? 1 : 0
  role       = aws_iam_role.load_balancer_controller[0].name
  policy_arn = aws_iam_policy.load_balancer_controller[0].arn
}

# Export only the bootstrap inputs, rather than copying Terraform state to a host.
# The attachment dependency prevents outputs being ready before permissions attach.
output "load_balancer_bootstrap" {
  value = var.infra_enable_load_balancer_controller ? {
    account_id   = data.aws_caller_identity.current.account_id
    region       = var.infra_region
    cluster_name = var.infra_cluster_name
    vpc_id       = module.vpc.vpc_id
    role_arn     = aws_iam_role.load_balancer_controller[0].arn
  } : null
  depends_on = [aws_iam_role_policy_attachment.load_balancer_controller]
}
