# Architecture

This repository builds the AWS infrastructure layer for the companion 3-tier MERN app.

## High-Level Design

```text
AWS us-east-1
|-- VPC
|   |-- Public subnets
|   |   |-- Internet Gateway
|   |   `-- NAT Gateway
|   `-- Private subnets
|       `-- EKS worker nodes
|-- EKS
|   |-- Private control plane endpoint
|   |-- On-demand managed node group
|   |-- Spot managed node group
|   |-- Managed add-ons
|   `-- OIDC provider
|-- IAM
|   |-- Control plane role
|   |-- Node group role
|   `-- IRSA role for External Secrets Operator
`-- Terraform State
    |-- S3 backend
    `-- DynamoDB lock table
```

## VPC

The `modules/vpc` module creates:

- VPC
- Public subnets across three AZs
- Private subnets across three AZs
- Internet Gateway
- Single NAT Gateway
- Public and private route tables
- EKS security group

Public subnets are tagged for internet-facing load balancers:

```hcl
"kubernetes.io/role/elb" = "1"
```

Private subnets are tagged for internal load balancers:

```hcl
"kubernetes.io/role/internal-elb" = "1"
```

## IAM

The `modules/iam` module can create:

- EKS control plane IAM role
- EKS node group IAM role
- Managed AWS policy attachments
- Reusable IRSA role for Kubernetes service accounts

The root module uses the IAM module twice:

- `iam_core` for EKS control plane and node group roles
- `iam_irsa` for External Secrets Operator

## EKS

The `modules/eks` module creates:

- EKS cluster
- On-demand managed node group
- Spot managed node group
- EKS managed add-ons
- OIDC provider used by IRSA

Node labels:

```hcl
type = "ondemand"
type = "spot"
```

The companion app uses these labels to keep MongoDB on stable on-demand nodes while allowing backend/frontend workloads to prefer either on-demand or spot.

## Environment Sizing

Dev is sized for the 3-member MongoDB replica set:

```hcl
infra_ondemand_desired_capacity = 3
infra_ondemand_min_capacity     = 3
infra_ondemand_max_capacity     = 3
```

Spot nodes are available for scalable application workloads:

```hcl
infra_spot_desired_capacity = 1
infra_spot_min_capacity     = 1
infra_spot_max_capacity     = 5
```

## Production-Style Notes

The project intentionally keeps some choices cost-conscious for learning:

- Single NAT Gateway instead of one NAT Gateway per AZ
- Broad EKS API fallback ingress if no bastion input is provided
- Managed policies for easier EKS bring-up

For a stricter production build, use one NAT Gateway per AZ, narrow IAM policies, and restrict EKS API access to a bastion or jump host security group.
