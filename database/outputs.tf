output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.rds_instance.endpoint
}

output "db_username" {
  description = "RDS Usarname"
  value       = aws_db_instance.rds_instance.username
}

output "ssm_db_password_name" {
  description = "SSM Parameter name for the RDS PW"
  value       = aws_ssm_parameter.db_password.name
}
