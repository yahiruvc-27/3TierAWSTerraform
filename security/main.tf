data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "../networking/terraform.tfstate"
  }
}

data "aws_s3_bucket" "s3_products_bucket" {
  # Manually created s3 bucket to reference here
  bucket = var.s3_bucket_name
}


resource "aws_security_group" "bastion_sg" {

  name        = "${data.terraform_remote_state.networking.outputs.project_name}-bastion-sg"
  description = "SG to create EC2 Bastion"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-bastion-sg"
  }
}

resource "aws_security_group" "public_alb_sg" {

  name        = "${data.terraform_remote_state.networking.outputs.project_name}-public-alb-sg"
  description = "SG for public facing ALB"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-public-alb-sg"
  }
}

resource "aws_security_group" "internal_alb_sg" {

  name        = "${data.terraform_remote_state.networking.outputs.project_name}-internal-alb-sg"
  description = "SG for internal ALB"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-internal-alb-sg"
  }
}

resource "aws_security_group" "web_sg" {

  name        = "${data.terraform_remote_state.networking.outputs.project_name}-web-sg"
  description = "SG for WEB EC2 tier"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-web-sg"
  }
}
resource "aws_security_group" "app_sg" {

  name        = "${data.terraform_remote_state.networking.outputs.project_name}-app-sg"
  description = "SG for APP EC2 tier"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-app-sg"
  }
}
resource "aws_security_group" "database_sg" {

  name        = "${data.terraform_remote_state.networking.outputs.project_name}-database-sg"
  description = "SG for DB RDS tier"
  vpc_id      = data.terraform_remote_state.networking.outputs.vpc_id

  tags = {
    Name = "${data.terraform_remote_state.networking.outputs.project_name}-database-sg"
  }
}

# === Rules for Bastion SG ===
resource "aws_security_group_rule" "ssh_ingress_bastion" {
  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"

  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_sg.id
}

resource "aws_security_group_rule" "ssh_egress_bastion_web" {
  description = "Allow ssh into WEB tier EC2 form Bastion EC2"
  type        = "egress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"

  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "ssh_egress_bastion_app" {
  description = "Allow ssh into APP tier EC2 from Bastion EC2"
  type        = "egress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"

  security_group_id        = aws_security_group.bastion_sg.id
  source_security_group_id = aws_security_group.app_sg.id
}

# === Rules for public ALB ===
# INBOUND
resource "aws_security_group_rule" "inbound_http_public_alb" {
  description = "Allow all http from everywhere"

  type      = "ingress"
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.public_alb_sg.id
}

resource "aws_security_group_rule" "inbound_https_public_alb" {
  description = "Allow all https from everywhere"

  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.public_alb_sg.id
}

resource "aws_security_group_rule" "egress_http_alb_web" {
  description = "Allow outbound http from public ALB to WEB SG"
  type        = "egress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"

  security_group_id        = aws_security_group.public_alb_sg.id
  source_security_group_id = aws_security_group.web_sg.id
}

# === WEB EC2 SG ===

# INBOUND
resource "aws_security_group_rule" "ingress_http_alb_web" {

  description = "Allow inbound http from public ALB to WEB SG"
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"

  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.public_alb_sg.id
}

resource "aws_security_group_rule" "ingress_https_alb_web" {

  description = "Allow ingress https from public ALB to WEB SG"
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"

  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.public_alb_sg.id
}

resource "aws_security_group_rule" "ssh_ingress_bastion_web" {

  description = "Allow ssh into WEB tier EC2 form Bastion EC2"
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"

  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

# OUTBOUND
resource "aws_security_group_rule" "egress_http_web_internalalb" {
  description = "Allow API rest calls HTTP to internal ALB"
  type        = "egress"
  from_port   = "5000"
  to_port     = "5000"
  protocol    = "tcp"

  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.internal_alb_sg.id

}

# For testing only -> PROD end to end must be comented
# Folllow least principle priviledge
# API calls must arrive to proxu ALB iternal
resource "aws_security_group_rule" "egress_http_web_app" {

  description = "Allow API rest calls HTTP to APP tier"
  type        = "egress"
  from_port   = "5000"
  to_port     = "5000"
  protocol    = "tcp"

  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.app_sg.id
}

resource "aws_security_group_rule" "egress_package_download_web" {
  description       = "Download packages"
  type              = "egress"
  from_port         = 80
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
}

# === ALB internal SG ===

# INBOUND
resource "aws_security_group_rule" "ingress_http_web_internalalb" {

  description = "Allow inbound http from public WEB to internal ALB SG"
  type        = "ingress"
  from_port   = 5000
  to_port     = 5000
  protocol    = "tcp"

  security_group_id        = aws_security_group.internal_alb_sg.id
  source_security_group_id = aws_security_group.web_sg.id
}

# OUTBOUND
resource "aws_security_group_rule" "egress_http_internalalb_app" {

  description = "Allow API rest calls HTTP APP tier"
  type        = "egress"
  from_port   = "5000"
  to_port     = "5000"
  protocol    = "tcp"

  security_group_id        = aws_security_group.internal_alb_sg.id
  source_security_group_id = aws_security_group.app_sg.id

}

# === APP EC2 SG ===

# INBOUND
resource "aws_security_group_rule" "ingress_http_internalalb_APP" {

  description = "Allow inbound http from internal ALB to APP tier"
  type        = "ingress"
  from_port   = 5000
  to_port     = 5000
  protocol    = "tcp"

  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.internal_alb_sg.id
}

resource "aws_security_group_rule" "ssh_ingress_bastion_app" {

  description = "Allow ssh into APP tier EC2 form Bastion EC2"
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"

  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

# For testing only -> PROD end to end must be comented
# Folllow least principle priviledge
# API calls must arrive to proxu ALB iternal
resource "aws_security_group_rule" "ingress_http_web_app" {

  description = "Allow API rest calls HTTP to APP tierfrom WEB tier"
  type        = "ingress"
  from_port   = "5000"
  to_port     = "5000"
  protocol    = "tcp"

  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.web_sg.id
}

# OUTBOUND
resource "aws_security_group_rule" "egress_package_download_app" {

  description       = "Download packages"
  type              = "egress"
  from_port         = 80
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_sg.id
}

resource "aws_security_group_rule" "egress_SQL_app_database" {

  description = "SQL communication with RDS"
  type        = "egress"
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"

  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.database_sg.id
}

# === RDS SG ===

# INBOUND
resource "aws_security_group_rule" "ingress_app_rds" {

  description = "SQL communication with app / backed"
  type        = "ingress"
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"

  security_group_id        = aws_security_group.database_sg.id
  source_security_group_id = aws_security_group.app_sg.id
}

# -------------------------------------------------------
# ============ CREATE IAM ROLES FOR EC2 =================
# -------------------------------------------------------

# Create a trsut policy to allow EC2 instances to assume the IAM Service Role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create an empty role for WEB tier
resource "aws_iam_role" "web_role" {

  name               = "${data.terraform_remote_state.networking.outputs.project_name}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json # Allow EC2 service to assume role
}

# Create an empty role for APP tier
resource "aws_iam_role" "app_role" {

  name               = "${data.terraform_remote_state.networking.outputs.project_name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json # Allow EC2 service to assume role
}

# Create the policy for web role, least priviledge principle 
data "aws_iam_policy_document" "web_policy_data" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      data.aws_s3_bucket.s3_products_bucket.arn,
      "${data.aws_s3_bucket.s3_products_bucket.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

# Create the policy for web role, least priviledge principle 
# data "aws_iam_policy_document" "app_policy_data" {
#   statement {
#     effect = "Allow"

#     actions = [
#     	"ses:SendEmail",
#     	"ses:SendRawEmail"
#     ]

#     resources = ["*"]
#   }

#   statement {
#     effect = "Allow"

#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents"
#     ]

#     resources = ["*"]
#   }
# }

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "app_policy_data" {

  # ------------------------------------------------------------
  # 1. SES – app sends emails
  # ------------------------------------------------------------
  statement {
    effect = "Allow"

    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------------------
  # 2. CloudWatch Logs – app logging
  # ------------------------------------------------------------
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------------------
  # 3. SSM Parameter Store – read DB password
  # ------------------------------------------------------------
  statement {
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.database_password_parameter_name}"
    ]
  }

  # ------------------------------------------------------------
  # 4. KMS – decrypt SecureString parameter
  # ------------------------------------------------------------
  statement {
    effect = "Allow"

    actions = [
      "kms:Decrypt"
    ]

    resources = ["*"]
  }
}


# Create the WEB policy resource with the previus data (aws_iam_policy_document)
resource "aws_iam_policy" "web_policy" {
  name   = "${data.terraform_remote_state.networking.outputs.project_name}-web-role-policy"
  policy = data.aws_iam_policy_document.web_policy_data.json
}

# Create the APP policy resource with the previus data (aws_iam_policy_document)
resource "aws_iam_policy" "app_policy" {
  name   = "${data.terraform_remote_state.networking.outputs.project_name}-app-role-policy"
  policy = data.aws_iam_policy_document.app_policy_data.json
}

# Attach the policy to the web role
resource "aws_iam_role_policy_attachment" "web_attach_policy" {
  role       = aws_iam_role.web_role.name
  policy_arn = aws_iam_policy.web_policy.arn
}

# Attach the policy to the app role
resource "aws_iam_role_policy_attachment" "app_attach_policy" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# Create WEB instance profile
resource "aws_iam_instance_profile" "web_profile" {
  name = "${data.terraform_remote_state.networking.outputs.project_name}-web-profile"
  role = aws_iam_role.web_role.name
}

# Create WEB instance profile
resource "aws_iam_instance_profile" "app_profile" {
  name = "${data.terraform_remote_state.networking.outputs.project_name}-app-profile"
  role = aws_iam_role.app_role.name
}
