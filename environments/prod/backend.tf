###################################
# Terraform Prod Backend Configuration
# Stores state in S3 and currently locks via DynamoDB
# DynamoDB-based locking is deprecated; native S3 locking with
# `use_lockfile = true` is recommended for future implementation.
###################################

terraform {
  backend "s3" {
    bucket         = "project-ignite-tfstate" # S3 bucket for state files
    key            = "prod/terraform.tfstate" # Path to the prod state file
    region         = "us-east-1"              # Region for S3 and DynamoDB
    dynamodb_table = "project-ignite-locks"   # Current legacy locking method (deprecated)
    encrypt        = true                     # Enable encryption at rest
  }
}
