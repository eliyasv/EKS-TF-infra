## EKS Infrastructure with Terraform

Production-style Kubernetes infrastructure on AWS using Terraform, designed to be modular, reproducible, and environment-agnostic.

This project demonstrates Infrastructure as Code, Kubernetes platform provisioning, and cloud networking design aligned with DevOps best practices.

---
### What This Project Demonstrates

* Infrastructure as Code using Terraform
* Kubernetes platform provisioning on AWS
* Cloud networking design (VPC/subnets/routing)
* IAM role configuration for managed services
* Reusable infrastructure modules
* Cluster scalability design (scalable from 3–8 nodes)

### Features

*  Separate environments (`dev`, `prod`)
*  Modular Terraform structure (`vpc`, `iam`, `eks`)
*  Multi-AZ Subnet distribution
*  Public/private subnet architecture
*  Single NAT Gateway (Cost-optimized for Dev; upgrade to Multi-NAT for Prod)
*  Spot and On-Demand node groups for cost optimization
*  Secure EKS cluster (private API access)
*  OIDC Provider & IRSA enabled (Consolidated within EKS module)
*  Configurable EKS add-ons
*  CI/CD ready with Jenkins pipeline for safe plan/apply/destroy
*  Remote S3 backend with state locking via DynamoDB

---

### Architecture Overview

      ┌─────────────────────────────────────────────────────────────────────────────┐
      │                              AWS CLOUD (us-east-1)                          │
      │                                                                             │
      │  ┌───────────────────────────────────────────────────────────────────────┐  │
      │  │                         VPC (10.x.0.0/16)                             │  │
      │  │                                                                       │  │
      │  │  ┌──────────────────┐         ┌────────────────────────────────────┐  │  │
      │  │  │  Public Subnets  │         │       Private Subnets              │  │  │
      │  │  │  (3 AZs)         │         │         (3 AZs)                    │  │  │
      │  │  │                  │         │                                    │  │  │
      │  │  │  ┌────────────┐  │         │  ┌──────────────────────────────┐  │  │  │
      │  │  │  │ Internet   │  │         │  │      EKS Cluster             │  │  │  │
      │  │  │  │  Gateway   │  │         │  │  ┌──────────────────────┐    │  │  │  │
      │  │  │  └─────┬──────┘  │         │  │  │   Control Plane      │    │  │  │  │
      │  │  │        │         │         │  │  │   (Private API)      │    │  │  │  │
      │  │  │  ┌─────▼──────┐  │         │  │  └──────────┬───────────┘    │  │  │  │
      │  │  │  │ NAT Gateway│  │         │  │             │                │  │  │  │
      │  │  │  └────────────┘  │         │  │  ┌──────────▼───────────┐    │  │  │  │
      │  │  │                  │         │  │  │   Node Groups        │    │  │  │  │
      │  │  │  ┌────────────┐  │         │  │  │  • On-Demand         │    │  │  │  │
      │  │  │  │ Route Table│  │         │  │  │  • Spot              │    │  │  │  │
      │  │  │  └────────────┘  │         │  │  └──────────────────────┘    │  │  │  │
      │  │  └──────────────────┘         └────────────────────────────────────┘  │  |
      │  └───────────────────────────────────────────────────────────────────────┘  │
      │                                                                             │
      │  ┌──────────────────────────┐  ┌────────────────────────────────────────┐   │
      │  │      IAM Roles           │  │         State Backend                  │   │
      │  │  • Control Plane         │  │  • S3 (terraform.tfstate)              │   │
      │  │  • Node Groups           │  │  • DynamoDB (state locking)            │   │
      │  │  • OIDC/IRSA             │  │                                        │   │
      │  └──────────────────────────┘  └────────────────────────────────────────┘   │
      └─────────────────────────────────────────────────────────────────────────────┘
                          ^                                  ^
                          │                                  │
               ┌──────────┴──────────┐             ┌─────────┴─────────┐
               │   Jenkins Pipeline  │             │  Jumpserver       │
               │   (Plan→Apply)      │             │   (kubectl)       │
               └──────────┬──────────┘             └─────────┬─────────┘
                          │                                    │
                          └────────────┬───────────────────────┘
                                       │
                               ┌───────▼───────┐
                               │ Git Repository│
                               │ (Terraform)   │
                               └───────────────┘


### Terraform Module Overview
      ┌─────────────────────┬───────────────────────────────────────────────────────┐
      │      MODULE         │              WHAT IT BUILDS                           │
      ├─────────────────────┼───────────────────────────────────────────────────────┤
      │                     │                                                       │
      │   modules/vpc/      │  Networking Foundation                                │
      │                     │  • VPC (Virtual Private Cloud)                        │
      │                     │  • Public Subnets (3 AZs)                             │
      │                     │  • Private Subnets (3 AZs)                            │
      │                     │  • Internet Gateway                                   │
      │                     │  • NAT Gateway + Elastic IP                           │
      │                     │  • Route Tables (public + private)                    │
      │                     │  • Security Groups                                    │
      │                     │                                                       │
      ├─────────────────────┼───────────────────────────────────────────────────────┤
      │                     │                                                       │
      │   modules/iam/      │  Core Identity & Access Management                    │
      │                     │  • EKS Control Plane IAM Role                         │
      │                     │  • EKS Node Group IAM Role                            │
      │                     │  • Required Managed Policy Attachments                │
      │                     │                                                       │
      ├─────────────────────┼───────────────────────────────────────────────────────┤
      │                     │                                                       │
      │   modules/eks/      │  Kubernetes Platform (Consolidated)                   │
      │                     │  • EKS Cluster (Control Plane)                        │
      │                     │  • Managed Node Groups (On-Demand & Spot)             │
      │                     │  • OIDC Identity Provider & IRSA Support              │
      │                     │  • EKS Add-ons & Identity-Aware Security              │
      │                     │                                                       │
      └─────────────────────┴───────────────────────────────────────────────────────┘

---

### Prerequisites

* Terraform CLI
* AWS IAM user with appropriate permissions
* S3 bucket + DynamoDB table for remote state storing
* CI/CD environment with Terraform and AWS credentials.

---

### CI Pipeline (Jenkins)

Infrastructure provisioning is automated using a Jenkins pipeline.
The pipeline supports environment-based deployments and safe infrastructure changes.

Pipeline parameters:

* `ENVIRONMENT`: `dev` or `prod`
* `ACTION`: `plan`, `apply`, or `destroy`

Pipeline stages and what they do:

* `Checkout`
  * Clone the repository from the configured branch.
* `Prepare Backend`
  * Copy `environments/${params.ENVIRONMENT}/backend.tf` into the repo root.
  * Ensures Terraform initializes with the correct S3/DynamoDB remote state backend for the selected environment.
* `Terraform Init`
  * Run `terraform init -reconfigure` to initialize providers, modules, and backend state.
* `Terraform Format`
  * Run `terraform fmt -recursive` to normalize HCL formatting across the repository.
* `Terraform Validate`
  * Run `terraform validate` to check syntax, providers, modules, and input requirements.
* `Terraform Plan IAM Core`
  * Create a targeted plan for `module.iam_core`.
  * Verifies IAM role and policy changes before provisioning the cluster.
* `Terraform Plan EKS`
  * Create a targeted plan for `module.eks`.
  * Verifies cluster and nodegroup changes after the IAM core stage.
* `Terraform Plan IRSA`
  * Create a targeted plan for `module.iam_irsa`.
  * Verifies IRSA/OIDC-related IAM role changes after EKS has created the OIDC provider.
* `Terraform Apply IAM Core`
  * Manual approval step, then apply the IAM core plan.
* `Terraform Apply EKS`
  * Manual approval step, then apply the EKS plan.
* `Terraform Apply IRSA`
  * Manual approval step, then apply the IRSA plan.
* `Terraform Destroy`
  * Manual approval step, then destroy the selected environment.

This stage sequence is intentional: IAM core resources are created first, the EKS cluster is provisioned second, and IRSA-related IAM resources are provisioned last once the OIDC provider exists.

CI job split example (recommended for IAM/IRSA ordering):

- Job 1 (IAM core): create IAM roles and attach policies

```bash
# from repo root
cp environments/prod/backend.tf ./backend.tf
terraform init -reconfigure
terraform apply -var-file=environments/prod/prod.tfvars -target=module.iam_core -auto-approve
```

- Job 2 (EKS): create the EKS cluster (depends on IAM core)

```bash
cp environments/prod/backend.tf ./backend.tf
terraform init -reconfigure
terraform apply -var-file=environments/prod/prod.tfvars -target=module.eks -auto-approve
```

- Job 3 (IRSA & addons): create IRSA roles that require the OIDC provider, then install addons

```bash
cp environments/prod/backend.tf ./backend.tf
terraform init -reconfigure
terraform apply -var-file=environments/prod/prod.tfvars -target=module.iam_irsa -auto-approve
# then optionally apply other modules or the full config
terraform apply -var-file=environments/prod/prod.tfvars -auto-approve
```

Notes: using `-target` for staged deployment; prefer separate workspaces or module-level orchestration for long-term maintainability.

### GitHub Actions workflow

A GitHub Actions workflow is also included in `.github/workflows/terraform.yml`.
This workflow mirrors the same staged deployment order as Jenkins and adds plan artifact reuse for the apply step.

Workflow jobs:

* `validate`
  * Runs on `push`, `pull_request`, and manual dispatch.
  * Checks out the repo, configures AWS credentials, initializes Terraform, runs `terraform fmt`, and validates the configuration.
* `plan`
  * Runs on manual dispatch when `action` is `plan`.
  * Creates targeted plans for `module.iam_core`, `module.eks`, and `module.iam_irsa`.
  * Uploads plan artifacts for later apply.
* `apply`
  * Runs on manual dispatch when `action` is `apply`.
  * Downloads previously generated plan artifacts and applies the plans in order.
* `destroy`
  * Runs on manual dispatch when `action` is `destroy`.
  * Destroys the selected environment.

You can include both Jenkins and GitHub Actions in the README as separate subsections under a shared CI/Automation heading. This is a good general option when a repo supports multiple CI platforms.

---

### Accessing the Cluster

```bash
#Get kubeconfig
aws eks update-kubeconfig --region us-east-1 --name ignite-cluster-dev
#Verify access
kubectl get nodes
# Deploy sample app
kubectl apply -f https://k8s.io/examples/application/deployment.yaml
```
---

### Folder Structure

```bash
❯ tree -aL 3
.
├── environments
│   ├── dev
│   │   ├── backend.tf
│   │   └── dev.tfvars
│   └── prod
│       ├── backend.tf
│       └── prod.tfvars
├── .gitignore
├── Jenkinsfile
├── main.tf
├── modules
│   ├── eks
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── iam
│   │   ├── data.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── outputs.tf
├── data.tf
├── providers.tf
├── README.md
└── variables.tf


```
---

---

### Remote Backend Configuration

Edit `backend.tf` to match your S3 and DynamoDB setup:

```hcl
terraform {
  backend "s3" {
    bucket         = "bucketname"
    key            = "path to terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "lock"
    encrypt        = true
  }
}
```

---

### Environment Variables

You can override values in `dev.tfvars` or `prod.tfvars`. Example:

```hcl
# environments/dev.tfvars
infra_environment       = "dev"
infra_region            = "us-east-1"
infra_vpc_cidr          = "10.10.0.0/16"
infra_cluster_name      = "dev-project-ignite-cluster"
infra_enable_eks        = true
infra_cluster_version       = "1.30"
...
```

---

### Per-Environment Terraform Workflow (Locally)

You can deploy or manage infrastructure for each environment (`dev`, `prod`, etc.) independently using their own backend and variable files.

> 📌 All commands should be run from the project root (`EKS-TF-infra/`)

### Steps for `dev` Environment Quick Start (local)

```bash

# Clone repo
git clone https://github.com/eliyasv/EKS-TF-infra.git
cd EKS-TF-infra
# Copy backend config
cp environments/dev/backend.tf ./backend.tf
# Initialize Terraform
terraform init
# Plan for dev(This creates an execution plan based on the dev environment variables.)
terraform plan -var-file=environments/dev/dev.tfvars -out=tfplan-dev
# Apply for dev
terraform apply tfplan-dev

```

This Terraform configuration deploys a production-ready EKS cluster named ignite-cluster-dev in the us-east-1 region. It includes:

* An EKS cluster running Kubernetes version 1.30
* Node groups using both On-demand and Spot EC2 instances with autoscaling capability
* EKS managed addons: coredns, kube-proxy, vpc-cni, and aws-ebs-csi-driver
* AWS Identity and Access Management (IAM) roles and policies, including OpenID Connect (OIDC) provider for IAM Roles for Service Accounts (IRSA)
* Virtual Private Cloud (VPC) with public and private subnets across multiple Availability Zones
* NAT gateway and Internet Gateway for routing internet traffic
* Route tables for public and private subnet routing


```bash

# Destroy dev
terraform destroy -var-file=environments/dev/dev.tfvars

# Clean up
rm backend.tf
```
### Switching Between Environments (e.g. prod)

```bash

cp environments/prod/backend.tf ./backend.tf
terraform init -reconfigure
terraform plan -var-file=environments/prod/prod.tfvars -out=tfplan-prod
terraform apply tfplan-prod

```
---

### Configuring Ingress in the cluster

An Ingress is a Kubernetes API object that manages external access to services within a cluster, typically over HTTP and HTTPS.
With Ingress, you can use one entry point (like a single door) and let rules decide which app the request should go to.

Ingress doesn’t handle traffic itself; it needs an Ingress Controller.

* Access the eks by jumpserver (created inside the vpc with appropriate sg rules)


```bash

# IAM OIDC provider is already setup using terraform.

# Download IAM policy for the Load Balancer Controller
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

# Create an IAM policy called AWSLoadBalancerControllerIAMPolicy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# Create an IAM service account in Kubernetes with the policy attached (Replace the values for cluster name, region code, and account ID)
eksctl create iamserviceaccount \
    --cluster=<cluster-name> \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --region <aws-region-code> \
    --approve
```    

* Install AWS Load Balencer with helm (install helm if haven't already)

```bash

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
 
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=my-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --version 1.13.0

# helm install command automatically installs the custom resource definitions (CRDs) for the controller.
```
### Security Considerations
     
-  Private API endpoint (no public access)
-  IRSA enabled for pod-level IAM
-  State encryption at rest (S3)
-  State locking (DynamoDB)
-  Security group allows 0.0.0.0/0 on 443 (restrict in production)
-  IRSA policy uses wildcard permissions (apply least privilege in production)
-  Current setup uses a single NAT Gateway for cost-efficiency. Production requires one per AZ for High Availability.

Note: For production-grade deployments you should restrict API access to a bastion/jump host. Provide either `infra_bastion_sg_id` (preferred) or `infra_bastion_cidr` in your environment tfvars to lock the EKS SG down. Example in `environments/prod/prod.tfvars`:

```hcl
infra_bastion_sg_id = "sg-0123456789abcdef0"
# or
infra_bastion_cidr = "203.0.113.4/32"
```

High-availability NAT guidance (note: not implemented by default to reduce cost):

To make NAT Gateways highly available, create one NAT Gateway per AZ and allocate one EIP per NAT. A Terraform pattern is to `for_each` over your AZs/subnets, create `aws_eip` per AZ, `aws_nat_gateway` per AZ, and then create route tables for private subnets that point to the NAT in the same AZ. This avoids a single egress point failure.

Jenkins pipeline improvement suggestions:

- Add static checks before `terraform plan`: `tfsec`, `checkov`, and `tflint` to catch security and style issues early.
- Run `terraform fmt` and `terraform validate` (already present) and fail the build on format/validation errors.
- Run `terraform plan` in a detached workspace and store plan artifacts as build artifacts; require manual approval for `apply` (already present).
- Use ephemeral, isolated build agents (containerized) with pinned Terraform versions (use a docker image with TF and scanners preinstalled).
- Use a dedicated service account/assume-role per environment and limit its permissions to least privilege (e.g., separate deploy role for `plan` and `apply`).
- Add automated policy/remediation steps: post-plan checks to prevent destructive changes (e.g., deleting production resources).

