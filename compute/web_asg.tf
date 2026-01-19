# Create a TG to register WEB EC2 instances
resource "aws_lb_target_group" "web_tg" {
  name     = "${data.terraform_remote_state.networking.outputs.project_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.networking.outputs.vpc_id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Public ALB for private WEB tier, the system's public door
resource "aws_lb" "web_alb" {
  name               = "${data.terraform_remote_state.networking.outputs.project_name}-web-alb"
  internal           = false
  load_balancer_type = "application"

  # Subnets for the Public ALB nodes -> public
  security_groups = [
    data.terraform_remote_state.security.outputs.public_alb_sg_id
  ]
  # Use all Public facing subnets 
  subnets = values(
    data.terraform_remote_state.networking.outputs.public_subnet_ids
  )
}

# What is the ALB going to listen to = HTTP:80 -> forward -> WEB target gp 
resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Cretae ASG = Public ALB + WEB TG
resource "aws_autoscaling_group" "web_asg" {
  name = "${data.terraform_remote_state.networking.outputs.project_name}-web-asg"

  # Number of desired instances 
  min_size         = 1
  desired_capacity = 2
  max_size         = 3

  # use all the "web" subnets
  vpc_zone_identifier = [
    for key, id in data.terraform_remote_state.networking.outputs.private_subnet_ids :
    id if length(regexall(".*-web", key)) > 0
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 80

  # select what LT its gong to use = what instance is the ASG going to use
  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }

  # Attach to designated TG
  target_group_arns = [
    aws_lb_target_group.web_tg.arn
  ]

  tag {
    key                 = "Tier"
    value               = "web"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${data.terraform_remote_state.networking.outputs.project_name}-web"
    propagate_at_launch = true
  }
}

# Create ASG, TargetTrackingPolicy for APP ASG
resource "aws_autoscaling_policy" "web_cpu_scaling" {
  name                   = "${data.terraform_remote_state.networking.outputs.project_name}-web-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    # Target CPU usage %
    target_value = 50.0
  }
}
