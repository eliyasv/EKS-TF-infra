# Cluster Add-ons

Terraform provisions the EKS cluster, node groups, OIDC provider, and configured EKS managed add-ons. Some Kubernetes controllers should be installed after the cluster exists.

Run these commands from a host that can reach the private EKS endpoint, such as a jump server or Jenkins host inside the VPC.

## AWS Load Balancer Controller

The companion app uses ALB annotations in `k8s/ingress.yaml`, so install AWS Load Balancer Controller before applying ingress resources.

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

eksctl create iamserviceaccount \
  --cluster=ignite-cluster-dev \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region us-east-1 \
  --approve

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=ignite-cluster-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --version 1.13.0
```

Verify:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

## Metrics Server

Metrics Server is required before applying the app repo's `k8s/hpa.yaml`.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl wait --for=condition=available deployment/metrics-server -n kube-system --timeout=300s
kubectl top nodes
kubectl top pods -A
```

## External Secrets Operator

This Terraform repo creates an IAM policy and IRSA role for External Secrets Operator to read the MERN app MongoDB secrets from AWS Secrets Manager.

Get the role ARN:

```bash
terraform output -raw external_secrets_irsa_role_arn
```

Install External Secrets Operator:

```bash
EXTERNAL_SECRETS_ROLE_ARN=$(terraform output -raw external_secrets_irsa_role_arn)

helm repo add external-secrets https://charts.external-secrets.io
helm repo update external-secrets

helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${EXTERNAL_SECRETS_ROLE_ARN}"
```

The IRSA trust policy is tied to:

```text
system:serviceaccount:external-secrets:external-secrets
```

If you install the operator with a different namespace or service account name, update `infra_irsa_subject` in `main.tf` before applying Terraform.

## Cluster Autoscaler

Cluster Autoscaler is optional but useful when HPA creates pods that cannot fit on the current worker nodes.

Before installing it, add autoscaler discovery tags to both EKS managed node groups:

```hcl
"k8s.io/cluster-autoscaler/enabled" = "true"
"k8s.io/cluster-autoscaler/${var.infra_cluster_name}" = "owned"
```

Then create an IAM policy and IRSA service account for `kube-system/cluster-autoscaler`, install the autoscaler manifest, and pin the image version to match the EKS cluster minor version.

For EKS `1.30`:

```bash
kubectl -n kube-system set image deployment/cluster-autoscaler \
  cluster-autoscaler=registry.k8s.io/autoscaling/cluster-autoscaler:v1.30.0
```

Confirm the deployment arg uses the cluster name:

```yaml
- --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/ignite-cluster-dev
```

Verify:

```bash
kubectl -n kube-system rollout status deployment/cluster-autoscaler
kubectl -n kube-system logs deployment/cluster-autoscaler
```
