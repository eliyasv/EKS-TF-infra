# Environment Metadata
infra_environment  = "dev"
infra_region       = "us-east-1"
infra_project_name = "project-ignite"
infra_cluster_name = "ignite-cluster-dev"

# VPC Configuration
infra_vpc_cidr             = "10.100.0.0/16"
infra_public_subnet_cidrs  = ["10.100.0.0/20", "10.100.16.0/20", "10.100.32.0/20"]
infra_private_subnet_cidrs = ["10.100.128.0/20", "10.100.144.0/20", "10.100.160.0/20"]
infra_subnet_azs           = ["us-east-1a", "us-east-1b", "us-east-1c"]

# EKS Cluster Configuration
infra_enable_eks          = true
infra_cluster_version     = "1.32"
infra_enable_private_api  = true
infra_enable_public_api   = false

# Node Group Configuration (On-Demand)
infra_enable_ondemand_nodes     = true
infra_ondemand_instance_types   = ["t3a.medium"]
infra_ondemand_desired_capacity = 2
infra_ondemand_min_capacity     = 1
infra_ondemand_max_capacity     = 3

# Node Group Configuration (Spot)
infra_enable_spot_nodes     = true
infra_spot_instance_types   = ["t3a.large", "m5.large"]
infra_spot_desired_capacity = 1
infra_spot_min_capacity     = 1
infra_spot_max_capacity     = 5

# IAM Role Flags
infra_enable_control_plane_iam = true
infra_enable_node_iam_roles    = true
infra_enable_irsa              = true

# EKS Add-ons
infra_eks_addons = [
  {
    name    = "vpc-cni"
    version = "v1.19.2-eksbuild.1"
  },
  {
    name    = "coredns"
    version = "v1.11.4-eksbuild.1"
  },
  {
    name    = "kube-proxy"
    version = "v1.31.3-eksbuild.2"
  },
  {
    name    = "aws-ebs-csi-driver"
    version = "v1.38.1-eksbuild.1"
  }
]
