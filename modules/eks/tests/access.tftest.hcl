mock_provider "aws" {
  mock_resource "aws_eks_cluster" {
    defaults = {
      identity = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/TEST" }] }]
      access_config = [{
        authentication_mode                         = "CONFIG_MAP"
        bootstrap_cluster_creator_admin_permissions = false
      }]
    }
  }
}
mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [{ sha1_fingerprint = "0123456789012345678901234567890123456789" }]
    }
  }
}

variables {
  infra_environment               = "test"
  infra_project_name              = "project-ignite"
  infra_cluster_name              = "access-test"
  infra_cluster_version           = "1.36"
  vpc_id                          = "vpc-0123456789abcdef0"
  private_subnet_ids              = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  public_subnet_ids               = []
  eks_security_group_id           = "sg-0123456789abcdef0"
  control_plane_iam_role_arn      = "arn:aws:iam::495599741234:role/test-cluster"
  node_group_iam_role_arn         = "arn:aws:iam::495599741234:role/test-node"
  infra_enable_ondemand_nodes     = false
  infra_ondemand_instance_types   = ["t3a.medium"]
  infra_ondemand_desired_capacity = 3
  infra_ondemand_min_capacity     = 3
  infra_ondemand_max_capacity     = 3
  infra_enable_spot_nodes         = false
  infra_spot_instance_types       = ["t3a.large"]
  infra_spot_desired_capacity     = 1
  infra_spot_min_capacity         = 1
  infra_spot_max_capacity         = 5
  infra_eks_addons                = []
}

run "manual_access_ownership_by_default" {
  command = plan
  assert {
    condition     = length(aws_eks_access_entry.application) == 0 && length(aws_eks_access_policy_association.application) == 0
    error_message = "Default inputs must preserve manual access ownership."
  }
}

run "explicit_api_access_and_namespace_scope" {
  command = plan
  variables {
    infra_eks_authentication_mode = "API_AND_CONFIG_MAP"
    infra_eks_access_entries = {
      reader = {
        principal_arn = "arn:aws:iam::495599741234:role/test-reader"
        policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
        scope_type    = "namespace"
        namespaces    = ["mern-app"]
      }
    }
  }
  assert {
    condition     = aws_eks_cluster.ignite_cluster[0].access_config[0].authentication_mode == "API_AND_CONFIG_MAP"
    error_message = "The configured mode must allow API entries while preserving ConfigMap authentication."
  }
  assert {
    condition     = aws_eks_access_entry.application["reader"].type == "STANDARD" && aws_eks_access_policy_association.application["reader"].access_scope[0].namespaces == toset(["mern-app"])
    error_message = "The reader must receive only the requested namespace scope."
  }
}

run "legacy_cluster_state" {
  command   = apply
  state_key = "legacy-adoption"
  module {
    source = "./tests/fixtures/legacy"
  }
  # Mock providers only: seed CONFIG_MAP state with creator-admin access disabled.
}

run "adopt_access_preserves_creator_setting" {
  command   = plan
  state_key = "legacy-adoption"
  variables {
    infra_eks_authentication_mode = "API_AND_CONFIG_MAP"
  }
  assert {
    condition     = !aws_eks_cluster.ignite_cluster[0].access_config[0].bootstrap_cluster_creator_admin_permissions
    error_message = "Adding API access must preserve the legacy creator setting instead of replacing the cluster."
  }
  assert {
    condition     = aws_eks_cluster.ignite_cluster[0].id == run.legacy_cluster_state.cluster_id
    error_message = "Access adoption must retain the existing cluster identity."
  }
}

run "eks_disabled_gates_access_resources" {
  command = plan
  variables {
    infra_enable_eks              = false
    infra_eks_authentication_mode = "API_AND_CONFIG_MAP"
    infra_eks_access_entries = {
      reader = {
        principal_arn = "arn:aws:iam::495599741234:role/test-reader"
        policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      }
    }
  }
  assert {
    condition     = length(aws_eks_access_entry.application) == 0 && length(aws_eks_access_policy_association.application) == 0
    error_message = "Disabled EKS must not create access entries or policy associations."
  }
}

run "reject_entries_without_api_mode" {
  command = plan
  variables {
    infra_eks_access_entries = {
      reader = {
        principal_arn = "arn:aws:iam::495599741234:role/test-reader"
        policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      }
    }
  }
  expect_failures = [var.infra_eks_access_entries]
}

run "reject_sts_session_principal" {
  command = plan
  variables {
    infra_eks_authentication_mode = "API_AND_CONFIG_MAP"
    infra_eks_access_entries = {
      reader = {
        principal_arn = "arn:aws:sts::495599741234:assumed-role/test-reader/session"
        policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      }
    }
  }
  expect_failures = [var.infra_eks_access_entries]
}
