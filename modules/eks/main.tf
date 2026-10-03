# ------------------------
# modules/eks/main.tf
# ------------------------

# Create the EKS Cluster

resource "aws_eks_cluster" "ignite_cluster" {
  # Count condition - creates the cluster only if enabled by variable
  count = var.infra_enable_eks ? 1 : 0

  # Name of the EKS cluster (comes from variable, which is fed from dev/env)
  name = var.infra_cluster_name

  # IAM role used by the EKS control plane to call other AWS services
  role_arn = var.control_plane_iam_role_arn

  # Kubernetes version to run for this cluster
  version = var.infra_cluster_version

  # Networking configuration for the cluster
  vpc_config {
    subnet_ids              = var.private_subnet_ids          # subnets from different AZs recomended
    endpoint_private_access = var.infra_enable_private_access # private  endpoint
    endpoint_public_access  = var.infra_enable_public_access  # public  endpoint
    security_group_ids      = [var.eks_security_group_id]
  }

  # Tags for better resource management
  tags = merge(var.infra_tags, {
    Name = var.infra_cluster_name
    Env  = var.infra_environment
  })

  #lifecycle {
  #  prevent_destroy = true
  #}

  # Ensure IAM policies for the cluster are attached before creation
  # Dependencies on IAM roles are provided implicitly via module inputs (role ARNs)
}

# Worker Launch Template: On-Demand Instances
resource "aws_launch_template" "ignite_ondemand_nodes" {
  count       = var.infra_enable_ondemand_nodes ? 1 : 0
  name_prefix = "${var.infra_cluster_name}-ondemand-"
  description = "Launch template for ${var.infra_cluster_name} on-demand workers"

  # Pods that use the node role need two network hops to reach IMDSv2 credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Custom launch templates own root disk settings; preserve the EKS Linux default size.
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = false
      iops                  = 3000
      throughput            = 125
      volume_size           = 20
      volume_type           = "gp3"
    }
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_cluster_name}-ondemand-launch-template"
  })
}

# Node Group: On-Demand Instances
resource "aws_eks_node_group" "ignite_ondemand_nodes" {
  count           = var.infra_enable_ondemand_nodes ? 1 : 0
  cluster_name    = aws_eks_cluster.ignite_cluster[0].name
  node_group_name = "${var.infra_cluster_name}-ondemand"

  # IAM role for worker nodes (allows them to talk to other AWS services)
  node_role_arn = var.node_group_iam_role_arn

  # Place node instances in private subnets (best practice for security)
  subnet_ids = var.private_subnet_ids

  # Scaling configuration: desired, min & max node count
  scaling_config {
    desired_size = var.infra_ondemand_desired_capacity
    min_size     = var.infra_ondemand_min_capacity
    max_size     = var.infra_ondemand_max_capacity
  }

  # Instance types for on-demand nodes
  instance_types = var.infra_ondemand_instance_types
  capacity_type  = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.ignite_ondemand_nodes[0].id
    version = aws_launch_template.ignite_ondemand_nodes[0].latest_version
  }

  # Node label to identify workload scheduling preference
  labels = {
    type = "ondemand"
  }

  # Rolling update strategy (one node at a time can be unavailable)
  update_config {
    max_unavailable = 1
  }

  # Tags for resource classification
  tags = merge(var.infra_tags, {
    Name                                                  = "${var.infra_cluster_name}-ondemand"
    "k8s.io/cluster-autoscaler/enabled"                   = "true"
    "k8s.io/cluster-autoscaler/${var.infra_cluster_name}" = "owned"
  })

  # Ensure IAM policies for worker functionality are attached first
  depends_on = [
    aws_eks_cluster.ignite_cluster
  ]
}

# Worker Launch Template: Spot Instances
resource "aws_launch_template" "ignite_spot_nodes" {
  count       = var.infra_enable_spot_nodes ? 1 : 0
  name_prefix = "${var.infra_cluster_name}-spot-"
  description = "Launch template for ${var.infra_cluster_name} spot workers"

  # Pods that use the node role need two network hops to reach IMDSv2 credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Preserve the existing 50 GiB Spot root disk in the custom launch template.
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      encrypted             = false
      iops                  = 3000
      throughput            = 125
      volume_size           = 50
      volume_type           = "gp3"
    }
  }

  tags = merge(var.infra_tags, {
    Name = "${var.infra_cluster_name}-spot-launch-template"
  })
}

# Node Group: Spot Instances

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

  # Spot instances types
  instance_types = var.infra_spot_instance_types
  capacity_type  = "SPOT"

  launch_template {
    id      = aws_launch_template.ignite_spot_nodes[0].id
    version = aws_launch_template.ignite_spot_nodes[0].latest_version
  }

  labels = {
    type = "spot"
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(var.infra_tags, {
    Name                                                  = "${var.infra_cluster_name}-spot"
    "k8s.io/cluster-autoscaler/enabled"                   = "true"
    "k8s.io/cluster-autoscaler/${var.infra_cluster_name}" = "owned"
  })

  depends_on = [
    aws_eks_cluster.ignite_cluster
  ]
}

# EKS Addons

resource "aws_eks_addon" "ignite_addons" {
  # Iterate over addon definitions passed by vars
  for_each = var.infra_eks_addons != null ? {
    for addon in var.infra_eks_addons : addon.name => addon
  } : {}
  cluster_name  = try(aws_eks_cluster.ignite_cluster[0].name, null)
  addon_name    = each.value.name
  addon_version = data.aws_eks_addon_version.ignite_addons[each.key].version


  # Wait until node groups are ready before installing addons
  depends_on = [
    aws_eks_node_group.ignite_ondemand_nodes,
    aws_eks_node_group.ignite_spot_nodes
  ]
}

# -----------------------------
# IRSA Identity (OIDC)
# -----------------------------

data "tls_certificate" "oidc_thumbprint" {
  count = var.infra_enable_eks ? 1 : 0
  url   = aws_eks_cluster.ignite_cluster[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "ignite_eks_oidc_provider" {
  count = var.infra_enable_eks ? 1 : 0

  url             = aws_eks_cluster.ignite_cluster[0].identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint[0].certificates[0].sha1_fingerprint]

  tags = merge(var.infra_tags, {
    Name = "${var.infra_cluster_name}-oidc-provider"
  })
}
