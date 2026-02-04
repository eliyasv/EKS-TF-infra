## EKS Infrastructure with Terraform

This repository provisions a production-ready Amazon EKS cluster using Terraform following Infrastructure-as-Code (IaC), DevOps, and AWS best practices.

It is designed to be modular, scalable, cost-aware, and environment-agnostic (dev, prod).
The cluster on desired capacity runs 3 worker nodes:
2 on-demand for baseline stability and 1 spot node for cost-optimized workloads.
It can autoscale between 2 and 8 nodes depending on demand.

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
### High-Level Architecture

What this project creates:

* Multi-AZ VPC with public and private subnets
* Private EKS control plane (no public API exposure)
* Managed EKS node groups:
* On-Demand nodes for baseline workloads
* Spot nodes for cost-optimized workloads
* IAM Roles for Service Accounts (IRSA) via OIDC
* Managed EKS add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI)
* Remote Terraform state with locking
* CI/CD-ready pipeline using Jenkins

Traffic flow:

Internet → ALB (Ingress) → Kubernetes Services → Pods

### Features

*  Separate environments (`dev`, `prod`)
*  Modular Terraform structure (`vpc`, `iam`, `eks`)
*  Multi-AZ for high availability
*  Public/private subnets with NAT Gateway
*  Spot and On-Demand node groups for cost optimization
*  Secure EKS cluster (private API access)
*  OIDC/IRSA enabled for Kubernetes IAM
*  Configurable EKS add-ons
*  CI/CD ready with Jenkins pipeline for safe plan/apply/destroy
*  Remote S3 backend with state locking via DynamoDB for Terraform state management

---

### Prerequisites

* Terraform CLI
* AWS IAM user with appropriate permissions
* S3 bucket + DynamoDB table for remote state storing
* Jenkins server configured with docker, terraform  plugins and credentials (for all relevant CI/CD jobs.) 

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
infra_env               = "dev"
infra_region            = "us-east-1"
infra_vpc_cidr          = "10.10.0.0/16"
infra_cluster_name      = "dev-project-ignite-cluster"
infra_enable_eks        = true
infra_eks_version       = "1.30"
...
```

---

### Per-Environment Terraform Workflow (Locally)


You can deploy or manage infrastructure for each environment (`dev`, `prod`, etc.) independently using their own backend and variable files.

> 📌 All commands should be run from the project root (`EKS-TF-infra/`)

### Steps for `dev` Environment

---

```bash

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

### 🛠️ CI/CD with Jenkins

This project includes a `Jenkinsfile` for automating:

* Terraform plan/apply/destroy
* Environment selection (`dev`, `prod`)
* Safe apply/destroy with approval gates


---

### Configuring Ingress 

An Ingress is a Kubernetes API object that manages external access to services within a cluster, typically over HTTP and HTTPS.
With Ingress, you can use one entry point (like a single door) and let rules decide which app the request should go to.

Ingress doesn’t handle traffic itself; it needs an Ingress Controller.

* Access the eks by a jumpserver (created in side the vpc )


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

### Modules Overview

| Module | Description                                                    |
| ------ | -------------------------------------------------------------- |
| `vpc/` | Creates VPC, public/private subnets, route tables, NAT gateway, internet gateway, elastic IP, security group|
| `iam/` | Creates IAM roles and attach policies for EKS control plane, node groups, OIDC IRSA|
| `eks/` | Creates EKS cluster, node groups (spot/on-demand), add-ons |

---

### 
