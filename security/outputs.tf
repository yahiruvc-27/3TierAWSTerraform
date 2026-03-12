output "bastion_sg_id" {
  description = "SG ID for Bastion Host EC2"
  value       = aws_security_group.bastion_sg.id
}

output "public_alb_sg_id" {
  description = "SG ID for public facing / ingres ALB"
  value       = aws_security_group.public_alb_sg.id
}

output "web_sg_id" {
  description = "SG ID for WEB Tier EC2"
  value       = aws_security_group.web_sg.id
}

output "internal_alb_sg_id" {
  description = "SG ID for internal backend ALB"
  value       = aws_security_group.internal_alb_sg.id
}

output "app_sg_id" {
  description = "SG ID for APP Tier EC2"
  value       = aws_security_group.app_sg.id
}

output "database_sg_id" {
  description = "SG ID for DB RDS"
  value       = aws_security_group.database_sg.id
}

output "web_instance_profile_name" {
  description = "Web instance profile name / web service role"
  value       = aws_iam_instance_profile.web_profile.name
}

output "app_instance_profile_name" {
  description = "App instance profile name / web service role"
  value       = aws_iam_instance_profile.app_profile.name
}

output "products_bucket_name" {
  description = "S3 products Bucket name, storage for product images"
  value       = data.terraform_remote_state.networking.outputs.products_bucket_name
}

output "db_password_parameter_name" {
  description = "SSM parameter name for RDS password"
  value       = var.database_password_parameter_name
}