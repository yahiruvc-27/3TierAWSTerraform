resource "aws_ssm_parameter" "db_password" {
  name  = data.terraform_remote_state.security.outputs.db_password_parameter_name
  type  = "SecureString"
  value = random_password.db_password.result

  lifecycle {
    prevent_destroy = false
  }
}

resource "random_password" "db_password" {
  length  = 16
  special = true
  # Avoid apply errors by axcluding not authorized characters
  override_special = "!#$%&()*+,-.:;<=>?[]^_{|}~"
}