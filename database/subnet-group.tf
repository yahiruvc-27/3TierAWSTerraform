resource "aws_db_subnet_group" "db_subnets" {
  name       = "db-subnet-group"
  subnet_ids = values(data.terraform_remote_state.networking.outputs.database_subnet_ids)

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-db-subnet-group"
  }
}
