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
  count      = var.infra_create_eks_cluster_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_cluster_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
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
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#  AmazonEKS_CNI_Policy - Required for VPC networking from within pods
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_cni_policy" {
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# AmazonEC2ContainerRegistryReadOnly - Allows pulling container images from Amazon ECR
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_registry_policy" {
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# AmazonEBSCSIDriverPolicy - Needed for dynamic provisioning of EBS volumes
resource "aws_iam_role_policy_attachment" "ignite_nodegroup_ebs_policy" {
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# OpenID Connect Provider (oidc) for EKS (required for IRSA)
# Only create if both URL and thumbprint are provided
resource "aws_iam_openid_connect_provider" "ignite_eks_oidc_provider" {
  count = var.infra_oidc_url != null && var.infra_oidc_thumbprint != null ? 1 : 0
  
  url             = var.infra_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.infra_oidc_thumbprint]

  tags = {
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}


# IRSA IAM Role (example for enabling IAM roles for Kubernetes service accounts (IRSA))
resource "aws_iam_role" "ignite_eks_irsa_role" {
  count = var.infra_oidc_url != null && var.infra_oidc_thumbprint != null ? 1 : 0
  name = "${var.infra_cluster_name}-eks-irsa-role"

  # Trust policy should reference the EKS OIDC provider and restrict to the correct service account
  assume_role_policy = data.aws_iam_policy_document.eks_oidc_assume_role_policy[0].json

  tags = {
    Name        = "${var.infra_cluster_name}-irsa-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

resource "aws_iam_policy" "ignite-eks-oidc-policy" {
  count = var.infra_oidc_url != null && var.infra_oidc_thumbprint != null ? 1 : 0
  name = "test-policy"

  policy = jsonencode({
    Statement = [{
      Action = [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation",
        "*"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
    Version = "2012-10-17"
  })
}
# The "*" above will allow all actions and resourses (not safe for production - least privilege recommended)
# Attach the custom IAM Policy to IRSA Role
resource "aws_iam_role_policy_attachment" "ignite-oidc-policy-attach" {
  count      = var.infra_oidc_url != null && var.infra_oidc_thumbprint != null ? 1 : 0
  role       = aws_iam_role.ignite_eks_irsa_role[0].name
  policy_arn = aws_iam_policy.ignite-eks-oidc-policy[0].arn
}
