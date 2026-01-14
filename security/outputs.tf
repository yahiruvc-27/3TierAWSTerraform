output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "public_alb_sg_id" {
  value = aws_security_group.public_alb_sg.id
}

output "web_sg_id" {
  value = aws_security_group.web_sg.id
}

output "internal_alb_sg_id" {
  value = aws_security_group.internal_alb_sg.id
}

output "app_sg_id" {
  value = aws_security_group.app_sg.id
}

output "database_sg_id" {
  value = aws_security_group.database_sg.id
}

output "web_instance_profile_name" {
  value = aws_iam_instance_profile.web_profile.name
}
output "app_instance_profile_name" {
  value = aws_iam_instance_profile.app_profile.name
}

output "s3_bucket_name" {
  value = data.terraform_remote_state.networking.outputs.s3_bucket_name

}

output "db_password_parameter_name" {
  value = var.database_password_parameter_name

}