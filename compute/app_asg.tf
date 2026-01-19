# This .tf file creates the ASG HA for APP tier

# 1. TG, Health check, Protocol : Port
# 2. ALB, Type, SG, ALB Nodes (subnets)
# 3. ALB, Listener (Port / Protocol) -> forward 
# 4. ASG, # of instances, TG, subnets, LaunchTemplate
# 5. ASG ScalingPolicy -> CPU % Util

# Create a TG to register APP EC2 instances
resource "aws_lb_target_group" "app_tg" {
  name     = "${data.terraform_remote_state.networking.outputs.project_name}-app-tg"
  port     = var.backend_l_port
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.networking.outputs.vpc_id

  # create intervals and paths for health check
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Internal ALB for private app tier
resource "aws_lb" "app_alb" {
  name               = "${data.terraform_remote_state.networking.outputs.project_name}-app-alb"
  internal           = true
  load_balancer_type = "application"

  security_groups = [
    data.terraform_remote_state.security.outputs.internal_alb_sg_id
  ]
  # Subnets for Internal ALB nodes -> app private subnets
  # If the name of the subet has "-app" use it
  # Options  private-a-web, private-b-web, private-a-app, private-b-app 

  subnets = [
    for key, id in data.terraform_remote_state.networking.outputs.private_subnet_ids :
    id if length(regexall(".*-app", key)) > 0
  ]
}

# What is the ALB going to listen to: HTTP:5000 -> forward -> APP target gp"
resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = var.backend_l_port # beware of backed listening port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
# Cretae ASG = Internal ALB + APP TG
resource "aws_autoscaling_group" "app_asg" {
  name = "${data.terraform_remote_state.networking.outputs.project_name}-app-asg"

  # Number of desired instances 
  min_size         = 1
  desired_capacity = 2
  max_size         = 3
  # use app Subnets
  vpc_zone_identifier = [
    for key, id in data.terraform_remote_state.networking.outputs.private_subnet_ids :
    id if length(regexall(".*-app", key)) > 0
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 80

  # Use APP Launch Template 
  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.app_tg.arn
  ]

  tag {
    key                 = "Tier"
    value               = "app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${data.terraform_remote_state.networking.outputs.project_name}-app"
    propagate_at_launch = true
  }
}

# Create ASG -> TargetTrackingPolicy for APP ASG
resource "aws_autoscaling_policy" "app_cpu_scaling" {
  name                   = "${data.terraform_remote_state.networking.outputs.project_name}-app-cpu-scaling"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    # Target CPU usage %
    target_value = 50.0
  }
}

