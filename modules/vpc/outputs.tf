# ------------------------
# module/vpc/outputs.tf
# ------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.infra_vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.infra_public_subnets : subnet.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for subnet in aws_subnet.infra_private_subnets : subnet.id]
}

output "eks_security_group_id" {
  description = "Security group ID for the EKS cluster"
  value       = aws_security_group.infra_eks_sg.id
}
