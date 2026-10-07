# Optional Terraform ownership of ECR and EKS access

Both features are opt-in. Existing dev/prod tfvars are unchanged:
`infra_ecr_repository_names` defaults to `[]`,
`infra_eks_authentication_mode` defaults to `null`, and
`infra_eks_access_entries` defaults to `{}`. These defaults add no repositories
or access grants, and omit the cluster access configuration block. No live AWS
apply or import is performed by merging this change.

## ECR ownership

To enable creation/management, add this to the owning environment's tfvars:

```hcl
infra_ecr_repository_names = ["frontend", "backend"]
```

The names match current Jenkins and deployment image paths. Repository URLs
are available through `application_ecr_repository_urls`. Repositories are
account/region resources, not cluster resources: do not manage the same names
in both dev and prod states. If images should survive repeated dev destroys,
keep repositories manually managed or move ownership into a separate durable
registry state instead of the temporary cluster state.

Check for retained repositories before applying:

```bash
aws ecr describe-repositories --region us-east-1 \
  --repository-names frontend backend
```

If a repository exists, add its name to tfvars and import it into the correct
initialized backend/state before any apply. Run from the infra repository root:

```bash
cp environments/dev/backend.tf ./backend.tf
terraform init -reconfigure
terraform import -var-file=environments/dev/dev.tfvars \
  'aws_ecr_repository.application["frontend"]' frontend
terraform import -var-file=environments/dev/dev.tfvars \
  'aws_ecr_repository.application["backend"]' backend
terraform plan -var-file=environments/dev/dev.tfvars
```

Import only repositories that actually exist. If one name is absent, Terraform
creates that repository after plan approval; never delete a retained repository
just to make creation succeed. Encryption/scanning blocks are not introduced,
but MUTABLE tag behavior and configured tags are declared. Review any difference
from retained repository settings before applying, especially replacement.
Existing images are not rebuilt, retagged, or modified by import.

`force_delete = false` prevents deleting a repository while it contains images.
It is not a retention policy: empty managed repositories can be destroyed, and
full ones will block destroy until deliberately handled. Removing a name from
the input set plans its destruction; defaults are not a way to detach ownership
once a repository is in state. Preserve ownership configuration or explicitly
migrate state if retaining the repository.

## EKS access ownership

Use API_AND_CONFIG_MAP when adding access entries to a ConfigMap-based cluster,
so existing ConfigMap mappings remain usable. IAM principals must already exist.
Use the base IAM role/user ARN, not an STS assumed-role session ARN. For example,
replace the account/role below with your actual administering role:

```hcl
infra_eks_authentication_mode = "API_AND_CONFIG_MAP"
infra_eks_access_entries = {
  jump_admin = {
    principal_arn = "arn:aws:iam::123456789012:role/admin-access"
    policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    scope_type    = "cluster"
  }
  app_reader = {
    principal_arn = "arn:aws:iam::123456789012:role/app-reader"
    policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
    scope_type    = "namespace"
    namespaces    = ["mern-app"]
  }
}
```

These are examples, not enabled defaults. Grant cluster admin only to intended
administrators. This first implementation supports one access policy per
principal; namespace scope requires explicit namespaces. STANDARD entries and
associations are gated by `infra_enable_eks`. They depend on the EKS resource,
not vice versa, so they introduce no EKS/IAM cycle. Existing node-role mappings,
IRSA roles and private endpoint settings are unchanged.

The bootstrap cluster-creator admin setting matches EKS's true default on
new clusters. A narrowly scoped lifecycle ignore preserves this creation-only
setting on existing clusters, including a previously configured false value;
changing it can otherwise replace a cluster with AWS provider 5.x.
Enabling the access API is one-way; you cannot return to a mode that removes it.
If a cluster already uses API-only authentication, set `API` rather than trying
to revert it to API_AND_CONFIG_MAP. Keep the configured mode after adoption.
Adding access entries can take precedence over matching aws-auth mappings, so
review grants against existing access before enabling them.

For an existing cluster, inspect entries and associations first. Enabling API
access may also create an entry for the original cluster creator:

```bash
aws eks describe-cluster --region us-east-1 --name ignite-cluster-dev \
  --query 'cluster.accessConfig'
aws eks list-access-entries --region us-east-1 --cluster-name ignite-cluster-dev
aws eks list-associated-access-policies --region us-east-1 \
  --cluster-name ignite-cluster-dev \
  --principal-arn 'arn:aws:iam::123456789012:role/admin-access'
```

If the intended entry/association exists, configure the matching map entry and
import it before applying (substitute the actual ARN everywhere):

```bash
terraform import -var-file=environments/dev/dev.tfvars \
  'module.eks.aws_eks_access_entry.application["jump_admin"]' \
  'ignite-cluster-dev:arn:aws:iam::123456789012:role/admin-access'
terraform import -var-file=environments/dev/dev.tfvars \
  'module.eks.aws_eks_access_policy_association.application["jump_admin"]' \
  'ignite-cluster-dev#arn:aws:iam::123456789012:role/admin-access#arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy'
```

Do not import entries from the previously destroyed cluster. For a fresh cluster,
configure the desired mode/principals and review the new-resource plan. Changing
an entry's IAM principal recreates that entry; removing a map key revokes the
managed grant. Ensure another administration path exists before revoking your
own access. EKS policies grant Kubernetes access, not AWS CLI permissions; the
pipeline still needs AWS IAM permissions for the ECR/EKS management operations.

## Verification

With defaults, a plan against existing state should contain no ECR/access
resource changes and no cluster replacement attributable to this feature.
There may be unrelated drift; review the full plan. Stop if a retained ECR
repository or existing cluster is unexpectedly replaced. Only apply after
imports/configuration match the intended ownership and permissions.

Backend-free tests use mocked providers and do not contact AWS:

```bash
terraform init -backend=false -input=false
terraform validate
terraform test -var-file=environments/dev/dev.tfvars
terraform -chdir=modules/eks init -backend=false -input=false
terraform -chdir=modules/eks test
```

Run in a separate checkout or temporary directory to avoid altering the active
backend initialization. Live no-change verification requires the correct AWS
credentials and remote state; mocked tests do not replace that review.

References: [ECR imports](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/ecr_repository),
[EKS access entry imports](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/eks_access_entry),
[policy association imports](https://registry.terraform.io/providers/hashicorp/aws/5.100.0/docs/resources/eks_access_policy_association),
and [AWS authentication modes](https://docs.aws.amazon.com/eks/latest/userguide/grant-k8s-access.html).
