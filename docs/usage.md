# Usage

Run Terraform from the repository root unless noted otherwise.

## Remote Backend

Each environment has its own backend config:

```text
environments/dev/backend.tf
environments/prod/backend.tf
```

Copy the selected backend file to the root before `terraform init`:

```bash
cp environments/dev/backend.tf ./backend.tf
terraform init -reconfigure
```

Example backend shape:

```hcl
terraform {
  backend "s3" {
    bucket         = "project-ignite-tfstate-YOUR-ID"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "project-ignite-locks"
    encrypt        = true
  }
}
```

This project currently uses DynamoDB-based state locking. Newer Terraform versions recommend native S3 lockfiles with `use_lockfile = true`; migrate both backend files together if you change this.

## Dev Workflow

```bash
cp environments/dev/backend.tf ./backend.tf
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan -var-file=environments/dev/dev.tfvars -out=tfplan-dev
terraform apply tfplan-dev
rm -f backend.tf tfplan-dev
```

## Prod Workflow

```bash
cp environments/prod/backend.tf ./backend.tf
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan -var-file=environments/prod/prod.tfvars -out=tfplan-prod
terraform apply tfplan-prod
rm -f backend.tf tfplan-prod
```

## Destroy Dev

Keep the S3 state bucket and DynamoDB lock table when destroying temporary dev infrastructure. Removing the backend resources makes future cleanup and rebuilds harder.

```bash
cp environments/dev/backend.tf ./backend.tf
terraform init -reconfigure
terraform destroy -var-file=environments/dev/dev.tfvars
rm -f backend.tf
```

After rebuilding EKS, recreate access entries for your console principal and jump/Jenkins role because access entries belong to the old cluster.

## Cluster Access

The cluster endpoint is private by default. Run `kubectl` from a jump server, Jenkins host, or another machine that can reach the VPC.

```bash
aws eks update-kubeconfig --region us-east-1 --name ignite-cluster-dev
aws sts get-caller-identity
kubectl get nodes
```

If `kubectl` tries to reach `http://localhost:8080`, kubeconfig is missing. Re-run `aws eks update-kubeconfig`.

If Kubernetes says the server asked the client to provide credentials, kubeconfig exists but the IAM principal is not authorized in EKS.

## EKS Access Entries

Enable API access entries:

```bash
aws eks update-cluster-config \
  --region us-east-1 \
  --name ignite-cluster-dev \
  --access-config authenticationMode=API_AND_CONFIG_MAP
```

Grant access to your IAM user or role:

```bash
aws eks create-access-entry \
  --region us-east-1 \
  --cluster-name ignite-cluster-dev \
  --principal-arn <YOUR_IAM_USER_OR_ROLE_ARN>

aws eks associate-access-policy \
  --region us-east-1 \
  --cluster-name ignite-cluster-dev \
  --principal-arn <YOUR_IAM_USER_OR_ROLE_ARN> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

For a jump server or Jenkins EC2 instance role, use the base IAM role ARN, not the STS assumed-role session ARN:

```bash
aws eks create-access-entry \
  --region us-east-1 \
  --cluster-name ignite-cluster-dev \
  --principal-arn arn:aws:iam::<AWS_ACCOUNT_ID>:role/Jenkinsrole

aws eks associate-access-policy \
  --region us-east-1 \
  --cluster-name ignite-cluster-dev \
  --principal-arn arn:aws:iam::<AWS_ACCOUNT_ID>:role/Jenkinsrole \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

For production, replace `AmazonEKSClusterAdminPolicy` with narrower policies.
