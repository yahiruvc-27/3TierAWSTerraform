output "ssm_log_group_name" {
  description = "Logs group name in CW for SSM sessions"
  value       = aws_cloudwatch_log_group.ssm_session_logs.name
}

output "ssm_bucket_id" {
  description = "The name of the bucket"
  value       = aws_s3_bucket.s3_ssm_archive.id
}

output "ssm_bucket_arn" {
  description = "The ARN of the bucket for IAM policies"
  value       = aws_s3_bucket.s3_ssm_archive.arn
}

output "ssm_log_write_policy" {
  description = "IAM policy JSON to enable log permissions to S3 and CloudWatch (in EC2 Instance Profile)"
  value       = data.aws_iam_policy_document.ssm_log_write.json
}

output "ssm_logging_policy_arn" {
  description = "IAM policy ARN to enable log permissions to S3 and CloudWatch (in EC2 Instance Profile)"
  value       = aws_iam_policy.ssm_logging_policy.arn
}