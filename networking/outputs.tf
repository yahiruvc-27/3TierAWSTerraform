output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main-vpc.id
}

output "public_subnet_ids" {
  description = "A map of public subnet IDs keyed by their configuration name"
  value       = { for name, subnet in aws_subnet.public_sb : name => subnet.id }
}

output "private_subnet_ids" {
  description = "A map of web subnet IDs keyed by their configuration name"
  value       = { for name, subnet in aws_subnet.private_sb : name => subnet.id }
}

output "database_subnet_ids" {
  description = "A map of app subnet IDs keyed by their configuration name"
  value       = { for name, subnet in aws_subnet.database_sb : name => subnet.id }
}

output "project_name" {
  description = "Project name variable propagation between modules"
  value       = var.project_name
}

output "products_bucket_name" {
  description = "S3 Products bucket name"
  value       = var.products_bucket_name
}

output "environment" {
  description = "Naming for env of deployment"
  value       = var.environment
}

output "ssm_log_bucket_name" {
  description = "S3 SSM log bucket name"
  value       = local.ssm_log_bucket_name
}