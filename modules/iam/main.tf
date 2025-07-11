# ------------------------
# modules/iam/main.tf
# ------------------------
resource "aws_iam_role" "ignite_eks_cluster_role" {
  count              = var.infra_create_eks_cluster_role ? 1 : 0
  name               = "${var.infra_environment}-${var.infra_project_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.infra_eks_assume_role_policy.json

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
  assume_role_policy = data.aws_iam_policy_document.infra_ec2_assume_role_policy.json

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

resource "aws_iam_openid_connect_provider" "ignite_eks_oidc_provider" {
  count           = var.infra_enable_irsa ? 1 : 0
  url             = var.infra_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.infra_oidc_thumbprint]

  tags = {
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

resource "aws_iam_role" "ignite_irsa_role" {
  count              = var.infra_enable_irsa ? 1 : 0
  name               = "${var.infra_environment}-${var.infra_project_name}-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.infra_irsa_assume_policy.json

  tags = {
    Name        = "${var.infra_environment}-${var.infra_project_name}-irsa-role"
    Environment = var.infra_environment
    Project     = var.infra_project_name
  }
}

resource "aws_iam_policy" "ignite_irsa_policy" {
  count  = var.infra_enable_irsa ? 1 : 0
  name   = "${var.infra_environment}-${var.infra_project_name}-irsa-policy"
  policy = var.infra_irsa_policy_json
}

resource "aws_iam_role_policy_attachment" "ignite_irsa_policy_attach" {
  count      = var.infra_enable_irsa ? 1 : 0
  role       = aws_iam_role.ignite_irsa_role[0].name
  policy_arn = aws_iam_policy.ignite_irsa_policy[0].arn
}
