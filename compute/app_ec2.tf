
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
# DRDS MYSQL, Endpoint & Credentials 
data "terraform_remote_state" "database" {
  backend = "local"

  config = {
    path = "../database/terraform.tfstate"
  }
}

# Inport the SSM Parameter name for DB PW
data "aws_ssm_parameter" "db_password" {
  name            = data.terraform_remote_state.security.outputs.db_password_parameter_name
  with_decryption = true
}


# === 2.- Create and configure instance APP tier====
# UNCOMMENT THIS BLOCKblock  to create a single APP tier instance
# resource "aws_instance" "app_ec2" {
#   ami           = data.aws_ami.ami_amazon_linux_2023.id
#   instance_type = var.app_instance_size

#   #subnet_id = aws_subnet.private_sb["private-a-app"].id
#   subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids["private-a-app"]


#   vpc_security_group_ids = [
#     data.terraform_remote_state.security.outputs.app_sg_id
#   ]

#   associate_public_ip_address = false

#   key_name = var.app_key_pair_name

#   #iam_instance_profile = aws_iam_instance_profile.app_profile.name
#   iam_instance_profile = data.terraform_remote_state.security.outputs.app_instance_profile_name

#   #user_data = file("${path.module}/userdata/app-user-data.sh")
#   user_data = templatefile("${path.module}/userdata/app-user-data.sh.tpl", {
#     #rds_endpoint = data.terraform_remote_state.database.outputs.db_endpoint
#     # This searches for a colon followed by digits at the end of the string and removes them
#     rds_endpoint = replace(data.terraform_remote_state.database.outputs.db_endpoint, "/:[0-9]+$/", "")
#     db_user      = data.terraform_remote_state.database.outputs.db_username
#     db_pass      = data.aws_ssm_parameter.db_password.value
#   })

#   root_block_device {
#     volume_size = 8
#     volume_type = "gp2"
#   }

#   tags = {
#     Name = "${var.project_name}-app-ec2"
#     Tier = "app"
#   }
# }

# === 2. CREATE Lunch Template APP Tier ===
resource "aws_launch_template" "app_launch_template" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ami.ami_amazon_linux_2023.id # AMI
  instance_type = var.app_instance_size                 # Instance class and size

  # Associate EC2 Instance Key Pair
  key_name = var.app_key_pair_name

  # Attach a SG
  vpc_security_group_ids = [
    data.terraform_remote_state.security.outputs.app_sg_id
  ]

  # Attch IAM Service Role to the EC2  
  iam_instance_profile {
    name = data.terraform_remote_state.security.outputs.app_instance_profile_name
  }
  # Encode and pass parameters to the APP User data 
  user_data = base64encode(
    templatefile("${path.module}/userdata/app-user-data.sh.tpl", {
      rds_endpoint = replace(data.terraform_remote_state.database.outputs.db_endpoint,
      "/:[0-9]+$/", "") # Remove port ....:3306 -> dont need it
      db_user = data.terraform_remote_state.database.outputs.db_username
      db_pass = data.aws_ssm_parameter.db_password.value
    })
  )

  # Indicate EBS root volume
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true # What happens when the instance is deleted, False = take snapshot
    }
  }
  # Tag the instance
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-app"
      Tier = "app"
    }
  }
}

