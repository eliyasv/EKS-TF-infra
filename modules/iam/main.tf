# ------------------------
# modules/iam/main.tf
# ------------------------

# EKS Control Plane IAM Role (essential for tying the EKS-managed Kubernetes API/control plane to AWS resources, safely delegating infrastructure tasks to EKS.)
resource "aws_iam_role" "ignite_eks_cluster_role" {
  count              = var.infra_create_eks_cluster_role ? 1 : 0
  name               = "${var.infra_cluster_name}-eks-cluster-role"
 
  # This trust policy allows the EKS control plane to assume the role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.infra_cluster_name}-eks-cluster-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

# Attach AWS-managed EKS policy to the EKS control plane role
resource "aws_iam_role_policy_attachment" "ignite_eks_cluster_policy" {
  count      = var.infra_create_eks_cluster_role && var.infra_use_managed_policies ? 1 : 0
  role       = aws_iam_role.ignite_eks_cluster_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Attach any user-provided control plane custom policies when managed policies are disabled
resource "aws_iam_role_policy_attachment" "ignite_eks_cluster_custom" {
  for_each = toset(var.infra_create_eks_cluster_role && !var.infra_use_managed_policies ? var.infra_control_plane_custom_policy_arns : [])
  role     = aws_iam_role.ignite_eks_cluster_role[0].name
  policy_arn = each.value
}

# Nodegroup IAM Role (for EKS worker nodes)
resource "aws_iam_role" "ignite_eks_nodegroup_role" {
  count              = var.infra_create_eks_nodegroup_role ? 1 : 0
  name               = "${var.infra_cluster_name}-eks-nodegroup-role"

# Allows EC2 service to assume this role for the worker nodes
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.infra_cluster_name}-eks-nodegroup-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

# Attach necessary policies to worker node IAM role

# AmazonEKSWorkerNodePolicy - Essential permissions for EKS nodes
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_worker_policy" {
  count      = var.infra_create_eks_nodegroup_role && var.infra_use_managed_policies ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#  AmazonEKS_CNI_Policy - Required for VPC networking from within pods
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_cni_policy" {
  count      = var.infra_create_eks_nodegroup_role && var.infra_use_managed_policies ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# AmazonEC2ContainerRegistryReadOnly - Allows pulling container images from Amazon ECR
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_registry_policy" {
  count      = var.infra_create_eks_nodegroup_role && var.infra_use_managed_policies ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# AmazonEBSCSIDriverPolicy - Needed for dynamic provisioning of EBS volumes
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_ebs_policy" {
  count      = var.infra_create_eks_nodegroup_role && var.infra_use_managed_policies ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Attach any user-provided nodegroup custom policies when managed policies are disabled
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_custom" {
  for_each = toset(var.infra_create_eks_nodegroup_role && !var.infra_use_managed_policies ? var.infra_nodegroup_custom_policy_arns : [])
  role     = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = each.value
}

# IRSA role: create a role assumable by the EKS OIDC provider for a specific service account
resource "aws_iam_role" "ignite_irsa_role" {
  count = var.infra_enable_irsa && var.infra_oidc_provider_arn != null ? 1 : 0

  name = var.infra_irsa_role_name != "" ? var.infra_irsa_role_name : "${var.infra_cluster_name}-irsa-role"

  assume_role_policy = try(data.aws_iam_policy_document.eks_oidc_assume_role_policy[0].json, jsonencode({} ))

  tags = {
    Name        = var.infra_irsa_role_name != "" ? var.infra_irsa_role_name : "${var.infra_cluster_name}-irsa-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

# Attach policies to the IRSA role
resource "aws_iam_role_policy_attachment" "ignite_irsa_policy_attachments" {
  for_each = toset(var.infra_enable_irsa ? var.infra_irsa_policy_arns : [])
  role     = aws_iam_role.ignite_irsa_role[0].name
  policy_arn = each.value
}

