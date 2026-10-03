data "aws_eks_addon_version" "ignite_addons" {
  for_each = var.infra_eks_addons != null ? {
    for addon in var.infra_eks_addons : addon.name => addon
  } : {}

  addon_name         = each.value.name
  kubernetes_version = aws_eks_cluster.ignite_cluster[0].version
  most_recent        = each.value.most_recent
}