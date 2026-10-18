# IAM module: actual inputs and permissions

This module can create EKS control-plane/node roles or one IRSA role. The root
calls it as iam_core and iam_irsa (External Secrets). Logging and optional Load
Balancer roles are separate root resources; they are not further instances of this module.

## Managed versus custom policies

Module-level inputs include infra_use_managed_policies,
infra_control_plane_custom_policy_arns and infra_nodegroup_custom_policy_arns.
The current root main.tf passes infra_use_managed_policies = true and does not
expose those custom-policy inputs through root variables. Setting them in root
tfvars alone does not switch the module: root wiring must also be changed.

AWS-managed policies are the current learning configuration, not a claim that
every role has the minimum possible permissions. Custom policies need tested
per-action resource/condition scoping. The previous simplified ECR/EBS snippets
were removed: GetAuthorizationToken cannot be repository-scoped, and a single
resource-tag condition is not a complete EBS CSI policy for all API calls.

Current node attachments include AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy,
AmazonEC2ContainerRegistryReadOnly and AmazonEBSCSIDriverPolicy. Separate workload
identities for CNI/EBS are future hardening work, not implemented by these attachments.

## IRSA role

infra_enable_irsa controls role creation. The stable map infra_irsa_policy_arns
selects attachments; subject and cluster OIDC URL/provider identify the trusted
Kubernetes identity. The root External Secrets subject is
system:serviceaccount:external-secrets:external-secrets.

The reusable trust currently restricts sub, but does not explicitly add an aud
condition. The prepared root Load Balancer trust includes both. Review this
hardening difference before claiming identical trust restrictions for all roles.

## Dependencies and outputs

Policy attachment dependencies establish Terraform operation ordering. They do
not independently measure AWS IAM eventual-consistency propagation. The output
named iam_policies_propagated is a constant with dependencies, not an AWS probe
or propagation wait. Service readiness must be verified at deployment time.

See [security notes](../../docs/security.md) for worker metadata, access and
least-privilege follow-ups. Do not migrate roles or revoke grants without a
reviewed plan and a remaining administration path.
