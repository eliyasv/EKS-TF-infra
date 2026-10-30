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

External Secrets and optional logging/Load Balancer roles use IRSA. The managed
EBS CSI add-on now receives a dedicated role when EKS and IRSA are enabled and
the add-on is configured. CNI still uses node permissions; Cluster Autoscaler
and Pod Identity are separate follow-up work.

### EBS CSI dedicated identity

The EKS module creates `${infra_cluster_name}-ebs-csi-irsa`, trusts only its
cluster OIDC provider with subject `system:serviceaccount:kube-system:ebs-csi-controller-sa`
and audience `sts.amazonaws.com`, and attaches `AmazonEBSCSIDriverPolicy`.
Only `aws-ebs-csi-driver` receives the role through `service_account_role_arn`.
Other add-on identities and pinned versions are unchanged. The dependency order is:

```text
Core IAM -> cluster -> OIDC provider -> EBS role -> policy attachment -> add-on
```

The role lives inside the EKS module so it does not depend on the whole module
that also needs it. The add-on waits for policy attachment; this is operation
ordering, not a guarantee of IAM propagation or a live storage test.

Root defaults remove the node's EBS policy only when this dedicated identity is
enabled. The IAM module's standalone default remains compatible with legacy callers.
No EBS role is created if EKS, IRSA or the configured add-on is absent; the legacy
node attachment remains available in those paths. CNI, worker and ECR policies
are unaffected. This migration retains the existing EBS policy rather than also
changing to V2 or a custom policy. Review driver/policy compatibility and custom
KMS permissions separately before the next deployment.

#### Fresh deployment (the current destroyed-cluster situation)

1. Leave `infra_enable_eks = true`, `infra_enable_irsa = true` and the pinned
   EBS add-on in the intended environment. No additional role flag is needed.
2. Leave `infra_ebs_csi_node_role_fallback` at its default `false`.
3. Initialize the correct backend and review the full environment plan. Expect
   the dedicated role/attachment and EBS add-on association, with no node EBS
   attachment. Current worker IMDSv2 settings remain unchanged.
4. Apply only when intentionally rebuilding. Verify the live role and volume
   operations below before describing this migration as live-tested.

#### Existing-cluster migration (if used later)

1. Record the add-on's current identity/ownership. Do not overwrite a manually
   managed IRSA or Pod Identity association without a migration plan/import.
2. Set `infra_ebs_csi_node_role_fallback = true` in the environment tfvars for
   the first apply. This creates the controller role while retaining node EBS
   permissions; it does not move other workloads to IRSA.
3. Review the plan, apply and verify credential identity and disposable storage.
   Ensure replacement controller pods use the configured identity; inspect
   add-on status/service account and restart the controller deliberately if needed.
4. Remove the fallback override or set it to `false`, review the attachment
   removal, apply and repeat the storage checks. Do not disable all node managed
   policies to remove just EBS permissions.

#### Live verification (pending)

Backend-free validation and six mocked configuration scenarios were checked for
each of dev/prod: fresh identity, migration fallback, IRSA disabled, EKS disabled,
EBS add-on absent and null add-ons. Resulting states were inspected for exact
trust conditions, add-on association, worker EBS policy gating and preservation
of other worker policies. Dependency-graph generation also completed without a
cycle. These checks used temporary files, not repository test folders or AWS resources.
They do not establish future regional version availability or live storage success.

```bash
terraform output -raw ebs_csi_irsa_role_arn
aws eks describe-addon --region us-east-1 --cluster-name ignite-cluster-dev \
  --addon-name aws-ebs-csi-driver \
  --query 'addon.{Status:status,Role:serviceAccountRoleArn,Issues:health.issues}'
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o yaml
kubectl rollout status deployment/ebs-csi-controller -n kube-system --timeout=300s
kubectl logs deployment/ebs-csi-controller -n kube-system -c ebs-plugin --tail=100
```

Run from the initialized environment checkout / a host with private API access
as appropriate. Verify the returned role matches the output and no web-identity
or AccessDenied errors remain. Use a disposable PVC plus consumer pod with the
app's `ebs-csi` StorageClass; WaitForFirstConsumer means the PVC alone may stay
Pending. Verify provisioning, mounting, write/read, then delete the test pod/PVC
and verify the intended EBS cleanup. Do not use or delete MongoDB's actual claims.
Check relevant CloudTrail EBS operations for the dedicated assumed-role identity;
a healthy deployment alone does not prove which credentials it used.

Keep the IMDS hop limit at 2 until all remaining metadata dependencies are reviewed.
IRSA changes EBS CSI's AWS credentials; it does not block pods from node metadata
or guarantee the driver never uses metadata for non-credential information.
Role-assumption credentials require STS connectivity as well as AWS API access.
For rollback, restore node EBS permissions before deliberately disabling IRSA;
do not change the global IRSA flag casually because other controllers use it.

References: [AWS EBS CSI identity guidance](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html),
[AWS provider 5.100 add-on arguments](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/website/docs/r/eks_addon.html.markdown).

Other controller identities to review include:

- AWS Load Balancer Controller
- External Secrets Operator
- Cluster Autoscaler

### Worker Instance Metadata

Worker launch templates require IMDSv2 and set the response hop limit to `2`.
This historically restored the EBS controller's node-role credential path. The
dedicated identity above supersedes that credential dependency when enabled;
metadata reachability remains available for other dependencies and is not tightened here.

Existing managed node groups created without these launch templates must be replaced to adopt the metadata settings. This project applies that change during the next fresh lab rebuild rather than modifying the current node groups in place.

After deployment, verify the settings on running workers:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:eks:cluster-name,Values=ignite-cluster-dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,HttpTokens:MetadataOptions.HttpTokens,HopLimit:MetadataOptions.HttpPutResponseHopLimit}' \
  --output table
```

Each worker should report `required` for `HttpTokens` and `2` for `HopLimit`.
