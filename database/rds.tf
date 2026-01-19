# === Import local remote backends  ===
# VPC, Subnets ...
data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "../networking/terraform.tfstate"
  }
}

# SG & Instance Profiles
data "terraform_remote_state" "security" {
  backend = "local"

  config = {
    path = "../security/terraform.tfstate"
  }
}

# === 3. Create RDS Instance ===
resource "aws_db_instance" "rds_instance" {
  identifier = var.database_name # The name of the DB

  engine         = "mysql"
  engine_version = "8.0.43"

  instance_class = "db.t4g.micro"

  allocated_storage = 20 # Disk size of RDS instance
  storage_type      = "gp2" # Tune for desired  performance

  db_name  = var.database_name
  username = var.db_username
  password = aws_ssm_parameter.db_password.value

  db_subnet_group_name = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [data.terraform_remote_state.security.outputs.database_sg_id]

  publicly_accessible = false
  multi_az            = false # Create a standby sycronus instance for HA (no read replica)

  backup_retention_period = 0 # For how may days we mantain a backup
  skip_final_snapshot     = true # Create a snapshot (copy of last RDS instance state) before termination
  deletion_protection     = false # Avoid mistakes -> a must for PRO env 

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-mysql-rds"
  }
}

