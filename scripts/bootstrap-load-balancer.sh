#!/usr/bin/env bash
# Run from a host that can reach the private EKS API. Nothing runs during Terraform apply.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
[[ $# -ge 1 && $# -le 2 ]] || die "Usage: $0 bootstrap.json [--check]"
config=$1
mode=${2:-install}
[[ "$mode" == install || "$mode" == --check ]] || die "Unknown option: $mode"
for command in aws kubectl helm jq; do
  command -v "$command" >/dev/null || die "Required tool missing: $command"
done
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
chart_version=3.6.0
release=aws-load-balancer-controller

# Read the dedicated Terraform output JSON, never the full state or secret values.
account=$(jq -er '.account_id | select(test("^[0-9]{12}$"))' "$config")
region=$(jq -er '.region | select(length > 0)' "$config")
cluster=$(jq -er '.cluster_name | select(length > 0)' "$config")
vpc=$(jq -er '.vpc_id | select(startswith("vpc-"))' "$config")
role=$(jq -er '.role_arn | select(length > 0)' "$config")
[[ "$role" == "arn:aws:iam::${account}:role/"* ]] || die "IRSA role must belong to the expected AWS account"
actual_account=$(aws sts get-caller-identity --region "$region" --query Account --output text)
[[ "$actual_account" == "$account" ]] || die "AWS account differs from bootstrap configuration"
details=$(aws eks describe-cluster --region "$region" --name "$cluster" --output json)
[[ $(jq -r '.cluster.status' <<< "$details") == ACTIVE ]] || die "EKS cluster is not ACTIVE"
[[ $(jq -r '.cluster.resourcesVpcConfig.vpcId' <<< "$details") == "$vpc" ]] || die "Cluster VPC differs from configuration"
role_name=${role##*/}
role_details=$(aws iam get-role --role-name "$role_name" --output json)
issuer=$(jq -r '.cluster.identity.oidc.issuer | sub("^https://"; "")' <<< "$details")
jq -e --arg issuer "$issuer" --arg account "$account" '
  any(.Role.AssumeRolePolicyDocument.Statement[];
    .Effect == "Allow" and .Action == "sts:AssumeRoleWithWebIdentity" and
    .Principal.Federated == ("arn:aws:iam::" + $account + ":oidc-provider/" + $issuer) and
    .Condition.StringEquals[($issuer + ":sub")] == "system:serviceaccount:kube-system:aws-load-balancer-controller" and
    .Condition.StringEquals[($issuer + ":aud")] == "sts.amazonaws.com")
' <<< "$role_details" >/dev/null || die "IRSA trust does not match this cluster/service account"

# Use a temporary kubeconfig to avoid changing the user's current context.
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
export KUBECONFIG="$work_dir/kubeconfig"
aws eks update-kubeconfig --region "$region" --name "$cluster" --kubeconfig "$KUBECONFIG" >/dev/null
kubectl --request-timeout=20s get nodes -o json > "$work_dir/nodes.json"
jq -e 'any(.items[]; any(.status.conditions[]; .type == "Ready" and .status == "True"))' "$work_dir/nodes.json" >/dev/null || die "No Ready workers"
# Check broad installation privileges; chart CRDs/RBAC/webhooks need cluster access.
[[ $(kubectl auth can-i '*' '*' --all-namespaces) == yes ]] || die "Run bootstrap with cluster-admin Kubernetes permissions"
helm list -n kube-system -o json > "$work_dir/releases.json"
existing_chart=$(jq -r --arg name "$release" '.[] | select(.name == $name) | .chart' "$work_dir/releases.json")
if [[ -n "$existing_chart" ]]; then
  [[ "$existing_chart" == "aws-load-balancer-controller-$chart_version" ]] || die "Existing chart differs; review upgrade/CRD changes separately"
else
  # Refuse to adopt an installation owned by eksctl/manual manifests/another release.
  for object in deployment serviceaccount; do
    existing=$(kubectl get "$object" "$release" -n kube-system --ignore-not-found -o name)
    [[ -z "$existing" ]] || die "Existing $object without this Helm release; resolve ownership first"
  done
fi
if [[ -n "$existing_chart" ]]; then
  existing_role=$(kubectl get serviceaccount "$release" -n kube-system -o json | jq -r '.metadata.annotations["eks.amazonaws.com/role-arn"] // ""')
  [[ "$existing_role" == "$role" ]] || die "Existing service account uses a different IAM role"
fi
echo "Preflight passed: account=$account cluster=$cluster region=$region chart=$chart_version"
[[ "$mode" != --check ]] || exit 0

# Pin chart and controller; explicit region/VPC avoid reliance on node metadata.
helm upgrade --install "$release" aws-load-balancer-controller \
  --repo https://aws.github.io/eks-charts \
  --version "$chart_version" --namespace kube-system \
  --values "$repo_dir/addons/load-balancer-controller-values.yaml" \
  --set-string "clusterName=$cluster" \
  --set-string "region=$region" --set-string "vpcId=$vpc" \
  --set-string "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$role" \
  --wait --timeout 5m
kubectl rollout status deployment/"$release" -n kube-system --timeout=300s
echo "Controller rollout complete. Verify IRSA and ALB reconciliation on the live cluster."
