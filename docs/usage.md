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

Before Terraform destroy, follow the companion app's
[ordered teardown runbook](https://github.com/eliyasv/EKS-TF-3tier-app/blob/main/docs/teardown.md).
Disable Argo CD sync and delete project Ingress/LoadBalancer Services while EKS
and their controllers still run. Check Classic (`aws elb`) as well as ALB/NLB
(`aws elbv2`) resources. Delete workload PVCs while EBS CSI runs, and remove
manually created eksctl resources, jump instance, dedicated security groups
and EIPs. Run destroy from outside the cluster VPC. Remaining manual load
balancers/interfaces/groups can block subnet, gateway or VPC deletion.

Keep the S3 state bucket and DynamoDB lock table when destroying temporary dev infrastructure. Removing the backend resources makes future cleanup and rebuilds harder.

```bash
cp environments/dev/backend.tf ./backend.tf
terraform init -reconfigure
terraform plan -destroy -var-file=environments/dev/dev.tfvars -out=destroy-dev.tfplan
# Review the destroy plan before applying:
terraform apply destroy-dev.tfplan
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

You can use [optional Terraform access management](ecr-and-access.md) instead
of the manual commands below. Defaults keep manual ownership; import any
existing entries/policy associations before enabling Terraform management.

Enable API access entries:

```bash
aws eks update-cluster-config \
  --region us-east-1 \
  --name ignite-cluster-dev \
  --access-config authenticationMode=API_AND_CONFIG_MAP
```

Before creating access entries, wait for the access update itself. Substitute
the update ID returned above and repeat the first command until status is
`Successful`; waiting only for `cluster-active` can return too early.

```bash
aws eks describe-update --region us-east-1 --name ignite-cluster-dev \
  --update-id "<UPDATE_ID>" --query 'update.{Status:status,Errors:errors}'
aws eks describe-cluster --region us-east-1 --name ignite-cluster-dev \
  --query 'cluster.accessConfig'
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
