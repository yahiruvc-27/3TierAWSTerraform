data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "../networking/terraform.tfstate"
  }
}

data "terraform_remote_state" "logging" {
  backend = "local"

  config = {
    path = "../logging/terraform.tfstate"
  }
}

data "aws_s3_bucket" "s3_products_bucket" {
  # Manually created s3 bucket to reference here
  bucket = data.terraform_remote_state.networking.outputs.products_bucket_name
}

locals {
  # From networking module
  environment  = data.terraform_remote_state.networking.outputs.environment
  project_name = data.terraform_remote_state.networking.outputs.project_name

  # From logging module
  ssm_log_group_name = data.terraform_remote_state.logging.outputs.ssm_log_group_name
  ssm_log_policy_arn = data.terraform_remote_state.logging.outputs.ssm_logging_policy_arn

  # SSM Logs S3 bucket
  ssm_bucket_id  = data.terraform_remote_state.logging.outputs.ssm_bucket_id
  ssm_bucket_arn = data.terraform_remote_state.logging.outputs.ssm_bucket_arn
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

# Add SSH INGRESS FROM BASTION (Dont forget to ADD KEY PAIR)
# resource "aws_security_group_rule" "ssh_ingress_bastion_web" {

#   description = "Allow ssh into WEB tier EC2 form Bastion EC2"
#   type        = "ingress"
#   from_port   = 22
#   to_port     = 22
#   protocol    = "tcp"

#   security_group_id        = aws_security_group.web_sg.id
#   source_security_group_id = aws_security_group.bastion_sg.id
# }

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
# API calls must arrive to  ALB internal
# resource "aws_security_group_rule" "egress_http_web_app" {

#   description = "Allow API rest calls HTTP to APP tier"
#   type        = "egress"
#   from_port   = "5000"
#   to_port     = "5000"
#   protocol    = "tcp"

#   security_group_id        = aws_security_group.web_sg.id
#   source_security_group_id = aws_security_group.app_sg.id
# }

resource "aws_security_group_rule" "egress_package_download_web" {
  description       = "Download packages"
  type              = "egress"
  from_port         = 80
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "egress_https_web" {

  description = "Outbound HTTPS"
  type        = "egress"

  from_port         = 443
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
# Add SSH INGRESS FROM BASTION (Dont forget to ADD KEY PAIR)
# resource "aws_security_group_rule" "ssh_ingress_bastion_app" {

#   description = "Allow ssh into APP tier EC2 form Bastion EC2"
#   type        = "ingress"
#   from_port   = 22
#   to_port     = 22
#   protocol    = "tcp"

#   security_group_id        = aws_security_group.app_sg.id
#   source_security_group_id = aws_security_group.bastion_sg.id
# }

# For testing only -> PROD end to end must be comented
# Folllow least principle priviledge
# API calls must arrive to proxy ALB iternal
# resource "aws_security_group_rule" "ingress_http_web_app" {

#   description = "Allow API rest calls HTTP to APP tierfrom WEB tier"
#   type        = "ingress"
#   from_port   = "5000"
#   to_port     = "5000"
#   protocol    = "tcp"

#   security_group_id        = aws_security_group.app_sg.id
#   source_security_group_id = aws_security_group.web_sg.id
# }

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

resource "aws_security_group_rule" "egress_https_app" {

  description = "Outbound HTTPS"
  type        = "egress"

  from_port         = 443
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

# 1.- Create aws_iam_policy_document [Trust Policy] (who can assume this role)
# 2.- Create aws_iam_role (role itself)
# 3.- Create aws_iam_policy_document (IAM Policy, content)
# 4.- Create aws_iam_policy (IAM Policy) -> document to policy
# 5.- Create aws_iam_role_policy_attachment -> Give the policy to the role

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
  # ------------------------------------------------------------
  # 1. S3 methods Get/ list Bcukets – obtain product images
  # ------------------------------------------------------------
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
  # ------------------------------------------------------------
  # 2. CloudWatch Logs – app logging
  # ------------------------------------------------------------
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------------------
  # 4. S3 methods Get/ list Bcukets – obtain product images
  # ------------------------------------------------------------
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
    ]

    resources = [
      local.ssm_bucket_arn,
      "${local.ssm_bucket_arn}/*"
    ]
  }
}


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
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    resources = ["*"] # later work to secure and send the logs to CW (not implemented rigth now)
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

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketLocation"
    ]

    resources = [
      local.ssm_bucket_arn,
      "${local.ssm_bucket_arn}/*"
    ]
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

# Attach the custom policy to the web role
resource "aws_iam_role_policy_attachment" "web_attach_policy" {
  role       = aws_iam_role.web_role.name
  policy_arn = aws_iam_policy.web_policy.arn
}

# Attach the custom policy to the app role
resource "aws_iam_role_policy_attachment" "app_attach_policy" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# Attach the SSM Logging Policy to the WEB role
resource "aws_iam_role_policy_attachment" "web_ssm_logging_attach" {
  role       = aws_iam_role.web_role.name
  policy_arn = local.ssm_log_policy_arn
}

# Attach the SSM Logging Policy to the APP role
resource "aws_iam_role_policy_attachment" "app_ssm_logging_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = local.ssm_log_policy_arn
}

# -------------------------------------------------------
# ============ Enable SSM Session manager ============
# -------------------------------------------------------
# 1. AWS Managed Policy ARN AmazonSSMManagedInstanceCore 
locals {
  ssm_managed_policy = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 2. Attach SSM policy to the WEB role
resource "aws_iam_role_policy_attachment" "web_ssm_attach" {
  role       = aws_iam_role.web_role.name
  policy_arn = local.ssm_managed_policy
}

# 3. Attach SSM policy to the APP role
resource "aws_iam_role_policy_attachment" "app_ssm_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = local.ssm_managed_policy
}
# === End Enable SSM Session manager =====

# -------------------------------------------------------
# ============ CREATE Instance Profiles FOR EC2 =================
# -------------------------------------------------------

# Use a Role and turn it into Instance profile 

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

# -------------------------------------------------------
# ============ Create IAM AppOpsEngineerRole Role  ============
# -------------------------------------------------------
# Creatinng AppOpsEngineerRole 

# 1.- Create Trust Policy (who can assume this role)
# 2.- Create aws_iam_role (role itself)
# 3.- Create aws_ssm_document (SSM restriction -> ops user)
# 4.- Create aws_iam_role_policy (IAM Policy) -> what can this role do 


# Policy to allow User "AppOps" to assume this role
data "aws_iam_policy_document" "AppOps_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/AppOps"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

# Create an empty role for AppOpsEngineerRole
resource "aws_iam_role" "AppOpsEngineerRole" {

  name               = "AppOpsEngineerRole"
  assume_role_policy = data.aws_iam_policy_document.AppOps_assume_role_policy.json # Allow User X to assume role

  tags = {
    Project = data.terraform_remote_state.networking.outputs.project_name
    Role    = "AppOpsEngineerRole"
  }
}

# -------------------------------------------------------
# ============ Create SSM_document   ============
#    (force ops linux user, logging and security)
# -------------------------------------------------------

resource "aws_ssm_document" "session_manager_doc_appops" {
  name            = "SSM-AppOpsConfig"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "App Ops restricted session test"
    sessionType   = "Standard_Stream"
    inputs = {
      runAsEnabled     = true
      runAsDefaultUser = "ops"
      shellProfile = {
        linux = "exec /bin/bash"
      }
      # CloudWatch Logging
      cloudWatchLogGroupName      = local.ssm_log_group_name
      cloudWatchEncryptionEnabled = false # True for real enterprise env

      # S3 Logging (Aded for longer Audit retention)
      s3BucketName        = local.ssm_bucket_id
      s3KeyPrefix         = "session-logs"
      s3EncryptionEnabled = true

      idleSessionTimeout = "10" # Kill unactive Sessions
    }
  })
}

# Create the Policy for  AppOps role -> what actions can the role perform
data "aws_iam_policy_document" "AppOps_ssm_policy" {
  # ------------------------------------------------------------
  # 1. SSM – Use custoum document only
  # ------------------------------------------------------------

  statement {
    sid    = "AllowCustomSSMDocument"
    effect = "Allow"

    actions = [
      "ssm:StartSession",
      "ssm:GetDocument"
    ]

    resources = [
      aws_ssm_document.session_manager_doc_appops.arn
    ]
  }
  # ------------------------------------------------------------
  # 2. SSM – Only allow access to EC2 target instances
  # ------------------------------------------------------------

  statement {
    sid    = "AllowTaggedInstancesOnly"
    effect = "Allow"

    actions = [
      "ssm:StartSession"
    ]

    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/SSMAccess"
      values   = ["app-ops"]
    }
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Environment"
      values   = [local.environment]
    }
  }
  # ------------------------------------------------------------
  # 3. SSM – Deny workarrounds
  # ------------------------------------------------------------

  statement {
    sid    = "DenyDefaultSSMDocuments"
    effect = "Deny"

    actions = [
      "ssm:StartSession"
    ]

    resources = [
      "arn:aws:ssm:*:*:document/AWS-StartInteractiveCommand",
      "arn:aws:ssm:*:*:document/AWS-StartPortForwardingSession",
      "arn:aws:ssm:*:*:document/AWS-StartSSHSession"
    ]
  }

  # ------------------------------------------------------------
  # 4. SSM – SSM Utils, discover and manage session
  # ------------------------------------------------------------

  statement {
    sid    = "SSMUtilities"
    effect = "Allow"

    actions = [
      "ssm:DescribeInstanceInformation",
      "ssm:GetConnectionStatus",
      "ssm:TerminateSession",
      "ssm:DescribeSessions",
      "ec2:DescribeInstances"
    ]

    resources = ["*"]
  }
}

# Attach IAM policy for the App Ops role 
resource "aws_iam_role_policy" "AppOps_ssm_enforcement" {
  name = "SSMDocumentEnforcement"
  role = aws_iam_role.AppOpsEngineerRole.id

  policy = data.aws_iam_policy_document.AppOps_ssm_policy.json
}
