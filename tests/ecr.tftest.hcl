# Mock providers let these tests inspect plans without AWS credentials or resources.
# Run explicitly with: terraform test -var-file=environments/dev/dev.tfvars
mock_provider "aws" {}
mock_provider "tls" {}

variables {
  # Keep this test focused on repositories, independently of cluster creation.
  infra_enable_eks = false
}

# Empty defaults must leave existing, manually managed repositories outside state.
run "manual_ecr_ownership_by_default" {
  command = plan
  assert {
    condition     = length(aws_ecr_repository.application) == 0
    error_message = "Default inputs must not create or adopt ECR repositories."
  }
}

# Opting in must retain the repository names used by Jenkins and Kubernetes.
run "explicit_repository_names_preserve_image_paths" {
  command = plan
  variables {
    infra_ecr_repository_names = ["frontend", "backend"]
  }
  assert {
    condition     = aws_ecr_repository.application["frontend"].name == "frontend" && aws_ecr_repository.application["backend"].name == "backend"
    error_message = "Repository names must match the existing Jenkins/manifest paths."
  }
  assert {
    condition     = alltrue([for repository in aws_ecr_repository.application : !repository.force_delete && repository.image_tag_mutability == "MUTABLE"])
    error_message = "Keep existing tag behavior and prohibit forced image deletion."
  }
}
