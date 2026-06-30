IAM Module - Least Privilege Guidance

This module creates IAM roles for the EKS control plane and EKS node groups. By default it attaches AWS-managed policies for compatibility. For production and security-conscious deployments you should replace managed policies with narrowly scoped custom policies.

How to use custom policies

- Set `infra_use_managed_policies = false` in your root `tfvars`.
- Provide ARNs for custom policies you manage in your account using the variables:
  - `infra_control_plane_custom_policy_arns` - list of ARNs to attach to control plane role
  - `infra_nodegroup_custom_policy_arns` - list of ARNs to attach to node group role

Why this approach

- AWS-managed policies are convenient but broad. Replacing them with custom policies scoped to specific ARNs (cluster resources, ECR repos, KMS keys, etc.) enforces least privilege.
- Recreating the exact behavior of AWS-managed EKS policies is complex. This module therefore lets you supply custom ARNs you control, so you can audit and version policies centrally.

Example minimal custom policy snippets

1) Example ECR read-only policy (attach to node group role)

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "arn:aws:ecr:${region}:${account_id}:repository/*"
    }
  ]
}

2) Example scoped permissions for EBS CSI driver (attach to node group role)

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:DeleteVolume",
        "ec2:DescribeVolumes",
        "ec2:DescribeInstances"
      ],
      "Resource": "*",
+      "Condition": {
+        "StringEquals": {
+          "ec2:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned"
+        }
+      }
+    }
+  ]
+}
+
+Notes and assumptions
+
+- The examples above are starting points — validate in a non-production environment before rolling out.
+- Some EKS operations require broad `Describe*` permissions against EC2 and other services; keep `Describe*` actions if needed since they are read-only.
+- It's recommended to manage custom policies centrally (single account) and reference their ARNs when calling this module.
+- If you need help producing a complete least-privilege set for your environment, I can help craft them based on your EKS addons and integrations.
