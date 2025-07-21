# ------------------------
# modules/eks/main.tf
# ------------------------

resource "aws_eks_cluster" "ignite_cluster" {
  count    = var.infra_enable_eks ? 1 : 0

  name     = var.infra_cluster_name
  role_arn = var.control_plane_iam_role_arn
  version  = var.infra_cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = var.infra_enable_private_api
    endpoint_public_access  = var.infra_enable_public_api
  }

  access_config {
    authentication_mode                         = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = merge(var.infra_tags, {
    Name = var.infra_cluster_name
    Env  = var.infra_environment
  })
}


resource "aws_eks_addon" "ignite_addons" {
  for_each      = { for addon in var.infra_eks_addons : addon.name => addon }
  cluster_name  = aws_eks_cluster.ignite_cluster[0].name
  addon_name    = each.value.name
  addon_version = each.value.version

  depends_on = [aws_eks_cluster.ignite_cluster]
}

resource "aws_eks_node_group" "ignite_ondemand_nodes" {
  count           = var.infra_enable_ondemand_nodes ? 1 : 0
  cluster_name    = aws_eks_cluster.ignite_cluster[0].name
  node_group_name = "${var.infra_cluster_name}-ondemand"

  node_role_arn = var.node_group_iam_role_arn
  subnet_ids    = var.private_subnet_ids

  scaling_config {
    desired_size = var.infra_ondemand_desired_capacity
    min_size     = var.infra_ondemand_min_capacity
    max_size     = var.infra_ondemand_max_capacity
  }

  instance_types = var.infra_ondemand_instance_types
  capacity_type  = "ON_DEMAND"

  labels = {
    type = "ondemand"
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_cluster_name}-ondemand"
  })

  depends_on = [aws_eks_cluster.ignite_cluster]
}

resource "aws_eks_node_group" "ignite_spot_nodes" {
  count           = var.infra_enable_spot_nodes ? 1 : 0
  cluster_name    = aws_eks_cluster.ignite_cluster[0].name
  node_group_name = "${var.infra_cluster_name}-spot"

  node_role_arn = var.node_group_iam_role_arn
  subnet_ids    = var.private_subnet_ids

  scaling_config {
    desired_size = var.infra_spot_desired_capacity
    min_size     = var.infra_spot_min_capacity
    max_size     = var.infra_spot_max_capacity
  }

  instance_types = var.infra_spot_instance_types
  capacity_type  = "SPOT"

  labels = {
    type = "spot"
  }

  update_config {
    max_unavailable = 1
  }

  disk_size = 50

  tags = merge(var.infra_tags, {
    Name = "${var.infra_cluster_name}-spot"
  })

  depends_on = [aws_eks_cluster.ignite_cluster]
}
