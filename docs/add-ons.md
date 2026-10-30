# Cluster add-ons and post-cluster controllers

Terraform installs configured EKS managed add-ons. Kubernetes controllers below
need separate installation from a host that can reach the private API. Roles
alone do not install a controller. Record compatible versions before rebuilding;
the commands below do not assert current AWS version availability.

## EBS CSI managed add-on

When EKS, IRSA and the EBS add-on are configured, Terraform creates a dedicated
controller role and associates it with the add-on. Workers omit the legacy EBS
policy unless migration fallback is explicitly enabled. No manual service-account
annotation or separate installation is needed for this managed-add-on path.
Read [identity migration and verification](security.md#ebs-csi-dedicated-identity)
before applying to an existing cluster. Local tests are not proof of live volume
operations; validate those on the next deployment. Add-on versions are unchanged.

## AWS Load Balancer Controller

Use the [prepared Terraform and Helm bootstrap](load-balancer-bootstrap.md) for
the optional ownership path. Dev enables its IAM resources on next apply; the
script runs explicitly after Terraform and has not been live-verified.
It uses chart/controller 3.6.0 with its matching committed policy. It supplies
cluster, region, VPC and service-account annotation rather than relying on metadata.

A manual/eksctl installation is an alternative, not an additional step. Select a
matching chart/controller/policy release, track its role/service account/stack and
follow the [official installation guide](https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html).
Do not combine the old 2.11.0 policy/1.13.0 chart example with a new cluster or
existing Terraform-managed identity without a reviewed migration.

```bash
kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl logs deployment/aws-load-balancer-controller -n kube-system --tail=100
```

The ALB is created only after an intended Ingress is reconciled. Chart rollout
alone doesn't verify IAM, subnet routing or healthy AWS targets.

## Metrics Server

The current resource HPAs use Metrics Server, not Prometheus. Select a compatible
release from the [official project](https://github.com/kubernetes-sigs/metrics-server)
and set its full version tag explicitly before running:

```bash
: "${METRICS_SERVER_VERSION:?Set the reviewed version tag, including v}"
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"
kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=300s
kubectl top nodes
kubectl top pods -A
```

Do not treat a floating latest download as a reproducible pin. Check APIService,
logs and network/certificate configuration if resource metrics remain unavailable.

## External Secrets Operator

Terraform exposes external_secrets_irsa_role_arn. From the initialized environment
state, export that ARN to the private installation host. Select/record a chart
version whose CRDs serve external-secrets.io/v1, matching application manifests.
On a host with both state-output access and cluster access:

```bash
: "${EXTERNAL_SECRETS_CHART_VERSION:?Set a reviewed chart version}"
EXTERNAL_SECRETS_ROLE_ARN=$(terraform output -raw external_secrets_irsa_role_arn)
helm repo add external-secrets https://charts.external-secrets.io
helm repo update external-secrets
helm upgrade --install external-secrets external-secrets/external-secrets \
  --version "$EXTERNAL_SECRETS_CHART_VERSION" \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.create=true --set serviceAccount.name=external-secrets \
  --set-string "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${EXTERNAL_SECRETS_ROLE_ARN}" \
  --wait --timeout 5m
```

If the jump host cannot access Terraform state, supply the exported role ARN
instead; do not copy state files there. Verify the role is non-null before install.
Trust identity must match system:serviceaccount:external-secrets:external-secrets.
Inspect existing release ownership/version before upgrade; avoid unreviewed CRD
changes. Verify operator/webhook readiness and both required CRDs serve v1:

```bash
kubectl get deployments -n external-secrets
kubectl get crd externalsecrets.external-secrets.io secretstores.external-secrets.io \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.versions[*]}{.name}{" served="}{.served}{"\n"}{end}{end}'
```

Create remote secret values separately and bootstrap the app SecretStore and
ExternalSecrets before database deployment. See the companion
[redeployment guide](https://github.com/eliyasv/EKS-TF-3tier-app/blob/main/docs/redeployment.md).

## Cluster Autoscaler

This is a follow-up, not an installed component. It adds nodes for unschedulable
pods; HPA adds pod replicas. Managed node-group resources already declare
related tags, but actual underlying ASG discovery tags must be verified.

Before installation, choose a Kubernetes-compatible autoscaler release, define
its scoped IAM/service account and Kubernetes permissions, configure ASG discovery,
and decide how to avoid Terraform resetting autoscaler-controlled desired_size.
Do not use the old v1.30 image example for the currently configured 1.36 cluster.
Follow the [EKS guidance](https://docs.aws.amazon.com/eks/latest/best-practices/cas.html).
No installation manifest or deployment is supplied by this repo today.

## Argo CD and monitoring

Install Argo CD before its Application resources. Keep management Services private
and use SSM forwarding. The app repository's monitoring Application owns its pinned
chart; don't install the same stack independently with Helm. See the companion
[observability guide](https://github.com/eliyasv/EKS-TF-3tier-app/blob/main/docs/observability.md).
