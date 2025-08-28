## 🚀 EKS Infrastructure with Terraform

This repository provisions an **Amazon EKS cluster** designed for scalability, reusability, and DevOps automation best practices.

---

### 📁 Folder Structure

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

### 🧠 Features

* ✅ Modular Terraform structure (`vpc`, `iam`, `eks`)
* ✅ Public/private subnets with NAT Gateway
* ✅ Spot and On-Demand node groups
* ✅ Secure EKS cluster (private API access)
* ✅ OIDC/IRSA enabled for Kubernetes IAM
* ✅ Configurable EKS add-ons (`vpc-cni`, `CoreDNS`, `kube-proxy`, `EBS CSI`)
* ✅ Separate environments (`dev`, `prod`)
* ✅ GitHub + Jenkins CI ready 
* ✅ Remote S3 backend with state locking via DynamoDB for Terraform state management

---

### 🔧 Prerequisites

* Terraform CLI
* AWS credentials with appropriate IAM permissions
* S3 bucket + DynamoDB table for remote state storing
* Jenkins server configured with docker, terraform  plugins and credentials (for all relevant CI/CD jobs.) 

---

### 🌐 Remote Backend Configuration

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

### 🚨 Environment Variables

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

### ✅ Per-Environment Terraform Workflow (Locally)


You can deploy or manage infrastructure for each environment (`dev`, `prod`, etc.) independently using their own backend and variable files.

> 📌 All commands should be run from the project root (`EKS-TF-infra/`)

### 🔧 Steps for `dev` Environment

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
* Security Groups configured for public HTTP/HTTPS access


```bash

# Destroy dev
terraform destroy -var-file=environments/dev/dev.tfvars

# Clean up
rm backend.tf
```
### 🔁 Switching Between Environments (e.g. prod)

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

### 🧱 Modules Overview

| Module | Description                                                    |
| ------ | -------------------------------------------------------------- |
| `vpc/` | Creates VPC, public/private subnets, route tables, NAT gateway, internet gateway, elastic IP, security group|
| `iam/` | Creates IAM roles for EKS control plane, node groups, OIDC IRSA iam role |
| `eks/` | Creates EKS cluster, node groups (spot/on-demand), add-ons |

---

