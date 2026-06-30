###################################
# Root - infra/providers.tf
###################################

terraform {
  # Pinned Terraform CLI version to ensure stability
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Pinned AWS provider to major version 5
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.infra_region
}
