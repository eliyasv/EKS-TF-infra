# Passed from root/environment inputs to the cluster's optional access_config.
# API_AND_CONFIG_MAP enables access entries alongside existing aws-auth mappings.
variable "infra_eks_authentication_mode" {
  description = "Optional authentication mode; null leaves the access configuration unmanaged."
  type        = string
  default     = null

  validation {
    condition     = var.infra_eks_authentication_mode == null ? true : contains(["CONFIG_MAP", "API_AND_CONFIG_MAP", "API"], var.infra_eks_authentication_mode)
    error_message = "Authentication mode must be null, CONFIG_MAP, API_AND_CONFIG_MAP, or API."
  }
}

# Explicit Kubernetes grants for existing IAM roles/users; this creates no IAM roles.
# Empty defaults add no grants. Each stable map key identifies one managed entry.
variable "infra_eks_access_entries" {
  description = "STANDARD access entries with one explicitly selected EKS policy and scope per principal."
  type = map(object({
    principal_arn = string
    policy_arn    = string
    scope_type    = optional(string, "cluster")
    namespaces    = optional(set(string), [])
  }))
  default = {}

  # Access entries only work when cluster authentication supports the EKS API.
  validation {
    condition     = length(var.infra_eks_access_entries) == 0 || contains(["API_AND_CONFIG_MAP", "API"], coalesce(var.infra_eks_authentication_mode, "CONFIG_MAP"))
    error_message = "Access entries require an explicit API_AND_CONFIG_MAP or API authentication mode."
  }

  # Require permanent IAM principals rather than temporary assumed-role sessions.
  validation {
    condition = alltrue([
      for entry in values(var.infra_eks_access_entries) :
      can(regex("^arn:aws(-[a-z]+)*:iam::[0-9]{12}:(role|user)/.+$", entry.principal_arn)) &&
      can(regex("^arn:aws(-[a-z]+)*:eks::aws:cluster-access-policy/[A-Za-z0-9]+$", entry.policy_arn))
    ])
    error_message = "Use an IAM role/user ARN (not an STS session ARN) and an EKS cluster-access-policy ARN."
  }

  # Namespace-scoped grants need target namespaces; cluster grants cover all.
  validation {
    condition = alltrue([
      for entry in values(var.infra_eks_access_entries) :
      (entry.scope_type == "cluster" && length(entry.namespaces) == 0) ||
      (entry.scope_type == "namespace" && length(entry.namespaces) > 0 && alltrue([for namespace in entry.namespaces : trimspace(namespace) != ""]))
    ])
    error_message = "Cluster scope must have no namespaces; namespace scope must supply at least one nonempty namespace."
  }

  # EKS permits only one access entry per principal on a cluster.
  validation {
    condition     = length(distinct([for entry in values(var.infra_eks_access_entries) : entry.principal_arn])) == length(var.infra_eks_access_entries)
    error_message = "Each IAM principal must appear only once in the access-entry map."
  }
}

# Register the principal with EKS after the cluster exists.
# Disabling EKS suppresses both entries and their policy associations.
resource "aws_eks_access_entry" "application" {
  for_each = var.infra_enable_eks ? var.infra_eks_access_entries : {}

  cluster_name  = aws_eks_cluster.ignite_cluster[0].name
  principal_arn = each.value.principal_arn
  type          = "STANDARD"
  tags          = var.infra_tags
}

# Attach the selected Kubernetes permissions (for example, admin or read-only).
# These policies do not grant AWS CLI permissions or network access to the API.
resource "aws_eks_access_policy_association" "application" {
  for_each = var.infra_enable_eks ? var.infra_eks_access_entries : {}

  cluster_name  = aws_eks_access_entry.application[each.key].cluster_name
  principal_arn = aws_eks_access_entry.application[each.key].principal_arn
  policy_arn    = each.value.policy_arn

  # Limit the policy to named namespaces when requested; otherwise use cluster scope.
  access_scope {
    type       = each.value.scope_type
    namespaces = each.value.scope_type == "namespace" ? each.value.namespaces : null
  }
}

# Expose the principals managed here for inspection by callers of the module.
output "access_entry_principal_arns" {
  description = "Terraform-managed access principals keyed by configured entry name."
  value       = { for name, entry in aws_eks_access_entry.application : name => entry.principal_arn }
}
