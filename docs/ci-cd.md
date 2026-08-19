# CI/CD

The root `Jenkinsfile` automates Terraform operations for the selected environment.

## Parameters

- `ENVIRONMENT`: `dev` or `prod`
- `ACTION`: `plan`, `apply`, or `destroy`

## Jenkins Stages

- `Checkout`: clones the configured Git branch.
- `Prepare Backend`: copies `environments/${ENVIRONMENT}/backend.tf` to the repository root.
- `Terraform Init`: runs `terraform init -reconfigure`.
- `Terraform Format`: runs `terraform fmt -recursive`.
- `Terraform Validate`: runs `terraform validate`.
- `Terraform Plan Full`: creates a full environment plan and stores it as `tfplan-${ENVIRONMENT}-full`.
- `Terraform Apply Full`: asks for manual approval, then applies the saved plan.
- `Terraform Destroy`: asks for manual approval, then destroys the selected environment.

## Apply Review

Before approving apply, review the plan carefully. Do not approve a plan that unexpectedly says:

```text
module.eks.aws_eks_cluster.ignite_cluster[0] must be replaced
```

Also pause if the plan unexpectedly destroys:

- EKS cluster
- VPC
- Node groups
- IAM roles
- S3/DynamoDB backend resources

## Branching Note

The Jenkinsfile has a configured Git branch. If you deploy from `dev`, make sure Jenkins checks out `dev` or make the branch a Jenkins parameter.

## Improvement Ideas

- Use `terraform fmt -check -recursive` in CI to fail on formatting drift.
- Add `tflint`, `checkov`, or `tfsec` before `terraform plan`.
- Save plan artifacts as Jenkins build artifacts.
- Use environment-specific deploy roles with least privilege.
- Add policy checks to block accidental production destroy/replacement.
- Run builds on isolated agents with pinned Terraform and scanner versions.
