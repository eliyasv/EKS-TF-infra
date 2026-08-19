# Security Notes

This is a learning project with production-style patterns. The current design is suitable for practicing end-to-end infrastructure and app deployment, but a real production setup should tighten several areas.

## Current Good Practices

- EKS API endpoint is private by default.
- Worker nodes run in private subnets.
- Terraform state is stored in S3 with encryption.
- IRSA is used for External Secrets Operator.
- MongoDB secrets are read from AWS Secrets Manager through a scoped IAM policy.
- Public and private subnets are tagged for Kubernetes load balancer discovery.

## Items To Tighten

### EKS API Access

If no bastion CIDR or security group is provided, the EKS API security group falls back to allowing HTTPS from `0.0.0.0/0`.

For production-style access, set one of these in the environment tfvars:

```hcl
infra_bastion_sg_id = "sg-0123456789abcdef0"
```

or:

```hcl
infra_bastion_cidr = "203.0.113.4/32"
```

### NAT Gateway High Availability

The default VPC module uses one NAT Gateway to reduce cost. For production HA, create one NAT Gateway per AZ and route each private subnet through the NAT Gateway in the same AZ.

### Terraform State Locking

This project currently uses DynamoDB-based S3 backend locking:

```hcl
dynamodb_table = "project-ignite-locks"
```

Newer Terraform versions recommend native S3 lockfiles:

```hcl
use_lockfile = true
```

Migrate both `dev` and `prod` backend files together if you change this.

### IAM

Managed AWS policies are used for easier learning and smoother EKS bring-up. For stricter production hardening:

- Replace broad managed policies with least-privilege custom policies.
- Use separate deploy roles per environment.
- Keep IRSA roles scoped to one service account and one namespace.
- Avoid long-lived static AWS keys in CI where role assumption is available.

### Add-on IAM

Some add-ons can use node role permissions, but production-style EKS normally gives controllers their own IRSA roles. Consider IRSA for:

- AWS Load Balancer Controller
- External Secrets Operator
- EBS CSI driver
- Cluster Autoscaler
