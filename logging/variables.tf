variable "cw_retention_days" {
  description = "Number of days for SSM log retention in CloudWatch"
  type        = number
  default     = 7
}

variable "s3_retention_days" {
  description = "Number of days for SSM log retention in S3"
  type        = number
  default     = 30
}