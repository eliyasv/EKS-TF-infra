# ------------------------
# modules/eks/main.tf
# ------------------------

# Create the EKS Cluster

resource "aws_eks_cluster" "ignite_cluster" {
  # Count condition - creates the cluster only if enabled by variable
  count    = var.infra_enable_eks ? 1 : 0

  # Name of the EKS cluster (comes from variable, which is fed from dev/env)
  name     = var.infra_cluster_name

  # IAM role used by the EKS control plane to call other AWS services
  role_arn = var.control_plane_iam_role_arn

  # Kubernetes version to run for this cluster
  version  = var.infra_cluster_version

  # Networking configuration for the cluster
  vpc_config {
    subnet_ids              = var.private_subnet_ids # subnets from different AZs recomended
    endpoint_private_access = var.infra_enable_private_access # private  endpoint
    endpoint_public_access  = var.infra_enable_public_access  # public  endpoint
  }

  # Cluster access configuration
  access_config {
    authentication_mode                         = "API"  # Enables IAM authentication
    bootstrap_cluster_creator_admin_permissions = true   # Grants admin permissions to creator
  }

  # Tags for better resource management
  tags = merge(var.infra_tags, {
    Name = var.infra_cluster_name
    Env  = var.infra_environment
  })

  # Ensure IAM policies for the cluster are attached before creation
  depends_on = [aws_iam_role_policy_attachment.ignite_eks_cluster_policy]
}

# Node Group: On-Demand Instances
resource "aws_eks_node_group" "ignite_ondemand_nodes" {
  count           = var.infra_enable_ondemand_nodes ? 1 : 0
  cluster_name    = aws_eks_cluster.ignite_cluster[0].name 
  node_group_name = "${var.infra_cluster_name}-ondemand"

  # IAM role for worker nodes (allows them to talk to other AWS services)
  node_role_arn = var.node_group_iam_role_arn

  # Place node instances in private subnets (best practice for security)
  subnet_ids    = var.private_subnet_ids

  # Scaling configuration: desired, min & max node count
  scaling_config {
    desired_size = var.infra_ondemand_desired_capacity
    min_size     = var.infra_ondemand_min_capacity
    max_size     = var.infra_ondemand_max_capacity
  }

  # Instance types for on-demand nodes
  instance_types = var.infra_ondemand_instance_types
  capacity_type  = "ON_DEMAND"

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
    Name = "${var.infra_cluster_name}-ondemand"
  })

  # Ensure IAM policies for worker functionality are attached first
  depends_on = [
    aws_iam_role_policy_attachment.ignite_nodegroup_worker_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_cni_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_registry_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_ebs_policy,
  ]
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

  labels = {
    type = "spot"
  }

  update_config {
    max_unavailable = 1
  }

  # Node disk size (GB)
  disk_size = 50

  tags = merge(var.infra_tags, {
    Name = "${var.infra_cluster_name}-spot"
  })

  depends_on = [
    aws_iam_role_policy_attachment.ignite_nodegroup_worker_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_cni_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_registry_policy,
    aws_iam_role_policy_attachment.ignite_nodegroup_ebs_policy,
  ]
}

# EKS Addons

resource "aws_eks_addon" "ignite_addons" {
  # Iterate over addon definitions passed by vars (list of { name, version })
  for_each = var.infra_eks_addons != null ? { for addon in var.infra_eks_addons : addon.name => addon } : {}

  cluster_name  = try(aws_eks_cluster.ignite_cluster[0].name, null)
  addon_name    = each.value.name
  addon_version = each.value.version

  # Wait until node groups are ready before installing addons
  depends_on    = [
    aws_eks_node_group.ignite_ondemand_nodes,
    aws_eks_node_group.ignite_spot_nodes
  ]
}
