# Optional Load Balancer Controller bootstrap

This prepares automation for the next deployment; it has not been exercised on a
live cluster. It does not install External Secrets or Argo CD yet. Existing manual
installation remains supported. Do not combine manual/eksctl and Terraform ownership
of the same role or Helm service account without an explicit migration.

## Ownership and versions

- Terraform creates a dedicated IAM policy and IRSA role only when enabled.
- The script installs the controller after the cluster and permissions exist.
- Helm owns the service account, RBAC, deployment, and webhook resources.
- Chart/controller are pinned to `3.6.0`; the matching upstream IAM policy is
  committed at `policies/aws-load-balancer-controller-v3.6.0.json`.
- The role trust checks both the exact service-account subject and STS audience.
- Two replicas are configured. The Service mutator webhook is disabled to preserve
  existing Service behavior; configure desired load-balancer ownership explicitly.

Sources: [official chart](https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller),
[versioned IAM policy](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.6.0/docs/install/iam_policy.json),
[installation requirements](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/).
Before a later deployment, review this pinned release's Kubernetes compatibility
and release notes rather than silently upgrading it. Helm upgrades do not handle
all CRD updates automatically; this script refuses a different existing chart version.

## Prepare and apply Terraform

Defaults remain disabled; dev/prod tfvars are unchanged. To enable for the next
deployment, add to the intended environment's tfvars:

```hcl
infra_enable_load_balancer_controller = true
# Existing EKS/IRSA flags must also be true.
```

Initialize the correct backend, review the environment's plan, then apply through
the normal approved infrastructure pipeline. The change adds no Helm/Kubernetes
provider and no dependency from EKS back to this role, avoiding an EKS/IAM cycle.
If similarly named AWS resources already exist, inspect ownership and import or
migrate them before apply. Do not overwrite an eksctl-managed role.

After apply, export the dedicated output (not the Terraform state):

```bash
terraform output -json load_balancer_bootstrap > bootstrap.json
```

Transfer this non-secret configuration and the repository to the installation
host. Keep the JSON local; it contains environment identifiers. Its output is
absent when the feature is disabled. Disabling it after adoption removes the
managed IAM resources, so uninstall the controller first if intentionally revoking
its permissions.

## Prerequisites and execution

Use a jump server or Jenkins agent that can reach the private EKS endpoint.
Required tools are AWS CLI, kubectl, Helm 3, jq, and Bash. The installation identity
needs AWS `sts:GetCallerIdentity`, `eks:DescribeCluster`, `iam:GetRole`, plus
Kubernetes cluster-admin permissions. AWS permissions alone do not grant Kubernetes
access. Workers need spare capacity, image pull connectivity, and access to STS
and the controller's AWS APIs. The host needs access to the Helm repository.
Check public/private subnet discovery tags and routing for the intended ALB.

```bash
# Read-only AWS/Kubernetes checks; uses a temporary local kubeconfig.
./scripts/bootstrap-load-balancer.sh bootstrap.json --check

# Explicitly install, or reconcile the same pinned Helm release.
./scripts/bootstrap-load-balancer.sh bootstrap.json
```

Preflight verifies the account, ACTIVE cluster, VPC, IRSA trust, Ready workers,
Kubernetes privileges, and installation ownership. It does not prove spare capacity,
subnet routing, policy effectiveness, or future ALB functionality. Wait operations
have timeouts; inspect logs/events after a failed installation before retrying.
Existing releases must use the same chart version and expected service-account
role. Fresh manual resources cause a stop instead of automatic adoption.

## Verification and teardown

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml
kubectl logs deployment/aws-load-balancer-controller -n kube-system --tail=100
```

On the next live deployment, verify that an intended Ingress reconciles to an ALB,
targets become healthy, and logs contain no IRSA/AccessDenied errors. A completed
rollout alone does not establish those functional checks.

For teardown, disable workload auto-sync, remove Ingresses and LoadBalancer
Services, and wait for AWS load balancers to disappear while their controllers
and IAM permissions remain available. Then:

```bash
helm uninstall aws-load-balancer-controller -n kube-system
```

Destroy the infrastructure afterward. Inspect any retained CRDs, security groups,
and load balancers rather than assuming Helm/Terraform owns everything. The script
does not create a load balancer or change the Argo CD service to LoadBalancer.

## Local checks without a cluster

```bash
terraform fmt -check -recursive
# Use a separate checkout and backend-free init for credential-free validation.
terraform init -backend=false -input=false
terraform validate
bash -n scripts/bootstrap-load-balancer.sh
helm template aws-load-balancer-controller aws-load-balancer-controller \
  --repo https://aws.github.io/eks-charts --version 3.6.0 \
  --namespace kube-system --values addons/load-balancer-controller-values.yaml \
  --set clusterName=validation-cluster --set region=us-east-1 \
  --set vpcId=vpc-0123456789abcdef0
```

Rendering requires chart download access but does not contact Kubernetes. These
checks do not replace the live authentication, scheduling, and ALB tests above.
