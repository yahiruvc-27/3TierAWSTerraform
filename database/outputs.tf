output "db_endpoint" {
  value = aws_db_instance.rds_instance.endpoint
}

output "db_username" {
  value = aws_db_instance.rds_instance.username
}

output "ssm_db_password_name" {
  value = aws_ssm_parameter.db_password.name
}
