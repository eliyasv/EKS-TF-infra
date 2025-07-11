## 🚀 EKS Infrastructure with Terraform

This repository provisions an **Amazon EKS cluster** designed for scalability, reusability, and DevOps automation best practices. (WIP)

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
├── Jenkinsfile
├── main.tf
├── modules
│   ├── eks
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── iam
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── outputs.tf
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
* ✅ Remote S3 backend with state locking via DynamoDB

---

### 🔧 Prerequisites

* Terraform CLI ≥ `1.9.3`
* AWS credentials with appropriate IAM permissions
* S3 bucket + DynamoDB table for remote state storing
* Jenkins agent (for CI/CD)

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
infra_eks_version       = "1.32"
...
```

---

### 🚀 Usage

```bash
# Initialize Terraform
terraform init

# Plan for dev
terraform plan -var-file=environments/dev.tfvars

# Apply for dev
terraform apply -var-file=environments/dev.tfvars

# Destroy dev
terraform destroy -var-file=environments/dev.tfvars
```

---

### 🛠️ CI/CD with Jenkins

This project includes a `Jenkinsfile` for automating:

* Terraform plan/apply/destroy
* Environment selection (`dev`, `prod`)
* Safe apply/destroy with approval gates

Set up Jenkins with:

* GitHub integration
* AWS credentials via environment or credentials plugin
* Terraform CLI installed

---

### 🧱 Modules Overview

| Module | Description                                                    |
| ------ | -------------------------------------------------------------- |
| `vpc/` | Creates VPC, public/private subnets, route tables, NAT gateway |
| `iam/` | IAM roles for EKS control plane, node groups, and IRSA         |
| `eks/` | EKS cluster, node groups (spot/on-demand), OIDC, add-ons       |

---

### 📦 Outputs

After `apply`, Terraform will output:

* EKS Cluster Name
* EKS Endpoint
* Node Group info
* VPC & Subnet IDs

---
