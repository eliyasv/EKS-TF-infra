# CI/CD

Jenkins is the active CI/CD path for this project. A GitHub Actions workflow also exists, but it is secondary/reference unless you decide to enable it as part of your main process.

## Jenkins

The root `Jenkinsfile` automates Terraform operations for the selected environment.

### Parameters

- `ENVIRONMENT`: `dev` or `prod`
- `ACTION`: `plan`, `apply`, or `destroy`

### Jenkins Stages

- `Checkout`: clones the configured Git branch.
- `Prepare Backend`: copies `environments/${ENVIRONMENT}/backend.tf` to the repository root.
- `Terraform Init`: runs `terraform init -reconfigure`.
- `Terraform Format`: runs `terraform fmt -recursive`.
- `Terraform Validate`: runs `terraform validate`.
- `Terraform Plan Full`: creates a full environment plan and stores it as `tfplan-${ENVIRONMENT}-full`.
- `Terraform Apply Full`: asks for manual approval, then applies the saved plan.
- `Terraform Destroy`: asks for manual approval, then destroys the selected environment.

### Apply Review

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

### Branching Note

The Jenkinsfile has a configured Git branch. If you deploy from `dev`, make sure Jenkins checks out `dev` or make the branch a Jenkins parameter.

## GitHub Actions

The repository includes `.github/workflows/terraform.yml`.

Current behavior:

- Runs validation on pushes and pull requests to `main`.
- Supports manual `workflow_dispatch` for `dev` or `prod`.
- Supports manual actions: `plan`, `apply`, and `destroy`.
- Uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` GitHub secrets.
- Creates targeted plans for `module.iam_core`, `module.eks`, and `module.iam_irsa`.
- Applies the downloaded plan artifacts in order when manually dispatched with `apply`.

Because Jenkins is your current CI path, treat this workflow as optional until you intentionally adopt it. If you do adopt GitHub Actions later, prefer OIDC-based AWS role assumption instead of long-lived AWS access keys.

## Improvement Ideas

- Use `terraform fmt -check -recursive` in CI to fail on formatting drift.
- Add `tflint`, `checkov`, or `tfsec` before `terraform plan`.
- Save plan artifacts as Jenkins build artifacts.
- Use environment-specific deploy roles with least privilege.
- Add policy checks to block accidental production destroy/replacement.
- Run builds on isolated agents with pinned Terraform and scanner versions.
