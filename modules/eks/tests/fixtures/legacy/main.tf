terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

# Seed the cluster address with an explicit legacy access configuration.
# This fixture runs exclusively with the test's mocked AWS provider.
resource "aws_eks_cluster" "ignite_cluster" {
  count    = 1
  name     = "access-test"
  role_arn = "arn:aws:iam::495599741234:role/test-cluster"
  version  = "1.36"
  access_config {
    authentication_mode                         = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }
  vpc_config {
    subnet_ids              = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = ["sg-0123456789abcdef0"]
  }
}

output "cluster_id" {
  value = aws_eks_cluster.ignite_cluster[0].id
}
