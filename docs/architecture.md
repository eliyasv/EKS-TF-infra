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

The companion app requires MongoDB on on-demand workers and backend/frontend on
Spot workers. These are required scheduling rules, not fallback preferences.
MongoDB also requires separate hosts and three eligible AZs; subnet configuration
alone does not prove the workers are placed correctly.

Optional root resources add ECR ownership and EKS access grants; defaults leave
them unmanaged. Logging IAM/log-group resources are in `logging.tf`. Prepared
Load Balancer Controller IAM and a separate post-cluster Helm script are described
in [the bootstrap guide](load-balancer-bootstrap.md); their live validation is pending.
External Secrets and Argo CD installation remain separate bootstrap steps.

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

## Design decisions and tradeoffs

The goal is to learn the complete EKS deployment lifecycle with a small application.
These decisions explain the checked-in design and its consequences. They are not
a claim that EKS is necessary for a Todo application's traffic, or that alternatives
were benchmarked. The earlier deployment was tested and destroyed; later optional
automation has its own validation boundary.

| Decision | Rationale | Tradeoff and when to reconsider |
|---|---|---|
| Modular Terraform with separate dev/prod state keys | Reuse network, IAM and cluster definitions while separating environment ownership. | Shared modules can affect both environments. Review each environment's plan; prod tfvars alone do not supply a production application overlay. |
| Separate core IAM from workload IRSA | EKS needs its core roles first; workload roles need EKS's OIDC issuer. Keeping the dependency direction explicit avoids the previous EKS/IAM cycle. | IAM creation is not controller installation or proof of IAM propagation. Verify actual workload AWS calls after bootstrap. |
| Private workers and private EKS API, administered through SSM | Keep worker/API access inside the network and use the jump host for administration without requiring an SSH key. | The jump host needs network connectivity, an AWS identity and Kubernetes authorization. It is manually provisioned. Tighten the current fallback security-group rule before claiming least-privilege network access. |
| Public and private subnets in three AZs | Supply public load-balancer placement and private worker capacity across zones. | Three subnet AZs do not guarantee worker or pod distribution. Verify actual placement; database storage remains AZ-bound. |
| One NAT Gateway | Reduce the number of always-present network resources in the learning environment. | Private subnets share an egress dependency, including across AZs. Evaluate per-AZ NAT or appropriate endpoints for stricter availability needs. No measured cost-saving percentage is claimed. |
| On-Demand database capacity and required Spot application placement | Keep database membership on stable compute while practicing interruptible application capacity. Dev starts with three On-Demand workers and one Spot worker. | Application pods cannot fall back to spare On-Demand capacity. One Spot worker is a shared failure domain for multiple replicas; the Spot maximum of five does not install a node autoscaler. |
| IRSA for AWS-integrated controllers | Give External Secrets and Fluent Bit separate AWS identities instead of embedding AWS access keys in manifests. The prepared Load Balancer Controller role follows that pattern too. | Trust subjects, OIDC providers and policies need lifecycle management. Node roles still carry CNI/EBS permissions; dedicated identities and Pod Identity migration are separate hardening work. |
| Optional ECR ownership, with retained registries kept separate by default | Preserve images across temporary cluster destruction and avoid accidental adoption of existing repositories. | Terraform cannot automatically adopt a retained name. Import once into the intended owning state if enabling management; a populated managed repository can block destroy. |
| Separate AWS provisioning from Kubernetes controller bootstrap | Terraform creates the platform/permissions; the explicit pinned Helm script runs after the API is reachable. This avoids requiring a Kubernetes provider during initial cluster creation. | Installation remains a second operation. The Load Balancer bootstrap has local validation only, and External Secrets/Argo CD installation is still separate. |

### Alternatives and evidence boundaries

A single VM, managed container platform, or managed database would change the
operational responsibilities and learning scope. They are alternatives to evaluate,
not experimentally rejected options. Likewise, adding workers, per-AZ NAT or
On-Demand application fallback changes the baseline footprint and failure behavior.

Historical deployment evidence supports successful provisioning and operation; it
does not establish uptime, cost savings, interruption recovery time or load capacity.
For changes to this design, record the intended benefit, the workload/cost baseline,
and the test needed to verify it. Use [security notes](security.md),
[ECR/access adoption](ecr-and-access.md) and
[bootstrap ownership](load-balancer-bootstrap.md) for the current implementation limits.

The companion application's decisions cover database placement, GitOps, probes,
storage, secrets and observability in its
[Kubernetes resource guide](https://github.com/eliyasv/EKS-TF-3tier-app/blob/main/docs/k8s-resources.md#design-decisions-and-tradeoffs).
