variable "project_name" {

  description = "Prefix for resource naming"
  type        = string
}

variable "vpc_cidr" {

  description = "VPC CIDR selection"
  type        = string
}

variable "public_subnets" {

  description = "Public subnet data"
  type = map(object({
    cidr = string
    az   = string
    name = string
  }))
}

variable "private_subnets" {

  description = "Private subnets data"
  type = map(object({
    cidr = string
    az   = string
    name = string
  }))
}

variable "database-subnets" {

  description = "Database subnets data"
  type = map(object({
    cidr = string
    az   = string
    name = string
  }))
}

variable "s3_bucket_name" {
  description = "S3 bucket product images name"
  type        = string
}