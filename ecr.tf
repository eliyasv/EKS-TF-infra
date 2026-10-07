variable "infra_ecr_repository_names" {
  description = "ECR repositories owned by this environment's state. Import existing repositories before apply; leave empty to preserve manual ownership."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for name in var.infra_ecr_repository_names :
      length(name) >= 2 && length(name) <= 256 && can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)*$", name))
    ])
    error_message = "Repository names must be 2-256 characters and use valid lowercase ECR path components."
  }
}

resource "aws_ecr_repository" "application" {
  for_each = var.infra_ecr_repository_names

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = false
  tags                 = var.infra_tags
}

output "application_ecr_repository_urls" {
  description = "Repository URLs keyed by name; empty when ECR is managed separately."
  value       = { for name, repository in aws_ecr_repository.application : name => repository.repository_url }
}
