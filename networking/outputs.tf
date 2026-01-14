output "vpc_id" {
  value = aws_vpc.main-vpc.id
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

output "s3_bucket_name" {
  description = "S3 Products bucket name"
  value       = var.s3_bucket_name
}


