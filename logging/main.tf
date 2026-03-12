# import Networking module outputs
data "terraform_remote_state" "networking" {
  backend = "local"

  config = {
    path = "../networking/terraform.tfstate"
  }
}
# create local acess to required elements
locals {
  environment         = data.terraform_remote_state.networking.outputs.environment
  project_name        = data.terraform_remote_state.networking.outputs.project_name
  ssm_log_bucket_name = data.terraform_remote_state.networking.outputs.ssm_log_bucket_name
}

# Create a CW gorup -> be ready to log streams from SSM Sessions
resource "aws_cloudwatch_log_group" "ssm_session_logs" {
  name = "/${local.project_name}/${local.environment}/ssm/session-logs"

  retention_in_days = var.cw_retention_days # Set retention period = to compliance requirements

  tags = {
    Project     = local.project_name
    Environment = local.environment
  }
}

# Create S3 for log retention
resource "aws_s3_bucket" "s3_ssm_archive" {

  bucket = local.ssm_log_bucket_name

  tags = {
    Project     = local.project_name
    Environment = local.environment
  }
}

# Enable bucket versioning
resource "aws_s3_bucket_versioning" "s3_ssm_versioning" {
  bucket = aws_s3_bucket.s3_ssm_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "s3_block" {

  bucket = aws_s3_bucket.s3_ssm_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Apply S3 (server side) encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_block_encryption" {

  bucket = aws_s3_bucket.s3_ssm_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create Life cycle rule -> expire old logs (cost optimization)
resource "aws_s3_bucket_lifecycle_configuration" "archive_lifecycle" {
  bucket = aws_s3_bucket.s3_ssm_archive.id

  rule {
    id     = "delete-old-ssm-logs"
    status = "Enabled"

    filter {
      prefix = "" # "" means apply to all objects in the bucket
    }

    expiration {
      days = var.s3_retention_days
    }
  }
}

# Allow to write on this audit log bucket
# & Write logs to CW
data "aws_iam_policy_document" "ssm_log_write" {
  # ------------------------------------------------------------
  # 1. S3 put – SSM log storage logging encrypted
  # ------------------------------------------------------------
  statement {

    effect = "Allow"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.s3_ssm_archive.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256"]
    }

  }

  statement {

    effect = "Allow"

    actions = [
      "s3:GetEncryptionConfiguration"
    ]

    resources = [
      aws_s3_bucket.s3_ssm_archive.arn
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

    resources = [
    "${aws_cloudwatch_log_group.ssm_session_logs.arn}:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetEncryptionConfiguration"]
    resources = ["*"]
  }
}

# Create IAM policy for EC2 instances
# Enable S3 audit logs for SSM sessions
# To be attached in ../security module -> Instance profile
resource "aws_iam_policy" "ssm_logging_policy" {
  name        = "${local.project_name}-${local.environment}-ssm-logging-policy"
  description = "Allows EC2 to write SSM session logs to S3 and CloudWatch"
  policy      = data.aws_iam_policy_document.ssm_log_write.json
}