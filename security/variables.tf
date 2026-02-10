variable "aws_region" {
  description = "aws region"
  type        = string
}

variable "database_password_parameter_name" {
  description = "SSM Parameter name for DB password"
  type        = string
}
