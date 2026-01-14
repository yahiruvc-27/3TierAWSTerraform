# Mini Amazon – AWS 3-Tier Architecture (Terraform)

This is my personal learning project that provisions a highly available (2 AZ), auto-scaling 3-tier architecture on AWS using Terraform.

VERSION 1.0 MVP

## Architecture
- VPC with public and private subnets (Multi-AZ)
- Web Tier (Nginx) (Private subnets) – Auto Scaling Group behind public ALB
- App Tier (Flask / Gunicorn) (Private subnets)– Auto Scaling Group behind internal ALB
- RDS MySQL (Private subnets)
- S3 (Private, Product images) + VPC Gateway Endpoint
- IAM roles with least privilege
- Secrets stored in SSM Parameter Store

## Folder Structure

terraform/
├── networking/   # VPC, subnets, routes, endpoints
├── security/     # Security Groups, IAM roles
├── database/     # RDS, subnet groups
├── compute/      # EC2, ASG, ALB, Launch Templates

## Deployment Order

1. networking
2. security
3. database
4. compute

## Key Features
- No hardcoded IPs
- No secrets in code
- Self-healing infrastructure
- Designed for future HTTPS & CI/CD
