# ------------------------
# modules/iam/main.tf
# ------------------------
resource "aws_iam_role" "ignite_eks_cluster_role" {
  count              = var.infra_create_eks_cluster_role ? 1 : 0
  name               = "${var.infra_environment}-${var.infra_project_name}-eks-cluster-role"
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
    Name        = "${var.infra_environment}-${var.infra_project_name}-eks-cluster-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

resource "aws_iam_role_policy_attachment" "ignite_eks_cluster_policy" {
  count      = var.infra_create_eks_cluster_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_cluster_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "ignite_eks_nodegroup_role" {
  count              = var.infra_create_eks_nodegroup_role ? 1 : 0
  name               = "${var.infra_environment}-${var.infra_project_name}-eks-nodegroup-role"
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
    Name        = "${var.infra_environment}-${var.infra_project_name}-eks-nodegroup-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

resource "aws_iam_role_policy_attachment" "ignite_nodegroup_worker_policy" {
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ignite_nodegroup_cni_policy" {
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ignite_nodegroup_registry_policy" {
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ignite_nodegroup_ebs_policy" {
  count      = var.infra_create_eks_nodegroup_role ? 1 : 0
  role       = aws_iam_role.ignite_eks_nodegroup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# OIDC
resource "aws_iam_openid_connect_provider" "ignite_eks_oidc_provider" {
  url             = var.infra_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.infra_oidc_thumbprint]

  tags = {
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}


# IRSA IAM Role (example usage for a specific sa in default namespace)
resource "aws_iam_role" "ignite_eks_irsa_role" {
  name = "${var.infra_environment}-${var.infra_project_name}-eks-irsa-role"

  assume_role_policy = data.aws_iam_policy_document.eks_oidc_assume_role_policy.json

  tags = {
    Name        = "${var.infra_environment}-${var.infra_project_name}-irsa-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}
resource "aws_iam_policy" "ignite-eks-oidc-policy" {
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

resource "aws_iam_role_policy_attachment" "ignite-oidc-policy-attach" {
  role       = aws_iam_role.ignite_eks_irsa_role.name
  policy_arn = aws_iam_policy.ignite-eks-oidc-policy.arn
}