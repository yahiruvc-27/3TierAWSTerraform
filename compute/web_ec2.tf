# === 1. get lates Linux AWS AMI DYNAMICALLY ====
# tf will search for latest version (region safe)
data "aws_ami" "ami_amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Reference the bucket with product images
data "aws_s3_bucket" "s3_products_bucket" {
  # Manually created s3 bucket to reference here
  bucket = data.terraform_remote_state.security.outputs.s3_bucket_name
}

# 2.- Create and configure instance WEB tier
# uncoment this block of code to create a single WEB tier instance
# resource "aws_instance" "web_ec2" {
#   ami           = data.aws_ami.ami_amazon_linux_2023.id
#   instance_type = var.web_instance_size

#   subnet_id = data.terraform_remote_state.networking.outputs.private_subnet_ids["private-a-web"]
#   #subnet_id = data.terraform_remote_state.networking.outputs.public_subnet_ids["public_a"]


#   vpc_security_group_ids = [
#     data.terraform_remote_state.security.outputs.web_sg_id
#   ]

#   associate_public_ip_address = false

#   key_name = var.web_key_pair_name

#   iam_instance_profile = data.terraform_remote_state.security.outputs.web_instance_profile_name

#   #user_data = file("${path.module}/userdata/web.sh")

#   user_data = templatefile("${path.module}/userdata/web-user-data.sh.tpl", {
#     s3_bucket  = data.aws_s3_bucket.s3_products_bucket.bucket
#     #ip_backend = aws_instance.app_ec2.private_ip
#     ip_backend = aws_lb.app_alb.dns_name

#   })

#   root_block_device {
#     volume_size = 8
#     volume_type = "gp2"
#   }

#   tags = {
#     Name = "${var.project_name}-web-ec2"
#     Tier = "web"
#   }
# }

# === 2. CREATE Lunch Template WEB Tier ===
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = data.aws_ami.ami_amazon_linux_2023.id
  instance_type = var.web_instance_size # Instance class and size

  # Associate EC2 Instance Key Pair
  key_name = var.web_key_pair_name

  # Attach a SG
  vpc_security_group_ids = [
    data.terraform_remote_state.security.outputs.web_sg_id
  ]

  # Attch IAM Service Role to the EC2  
  iam_instance_profile {
    name = data.terraform_remote_state.security.outputs.web_instance_profile_name
  }
  # Encode and pass parameters to the WEB User data 
  user_data = base64encode(
    templatefile("${path.module}/userdata/web-user-data.sh.tpl", {
      s3_bucket    = data.aws_s3_bucket.s3_products_bucket.bucket
      backend_host = aws_lb.app_alb.dns_name
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
      Name = "${var.project_name}-web"
      Tier = "web"
    }
  }
}

