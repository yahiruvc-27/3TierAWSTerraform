# Mini Amazon – AWS 3-Tier Architecture (Terraform)

This is my personal learning project that provisions a highly available (2 AZ), auto-scaling 3-tier architecture on AWS using Terraform.

My focus is on cloud (system design, debugging and eperimentation), IaC (terraform), service integration, HA, security and at the end user experience (this is not a software developer project, its a Cloud and Infra project)

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
- ASG HA infrastructure
- Created, tested and validated first by hand -> AWS Console
- Turned into IaC lerning (big learning moments, debugg and documentation reading)

## Future work

Security
- Use HTTPS ACM (Register a domain name)
- Use SSM session manager (delete SSH, key pairs and bastion host)

Functionality
- Add analytics (sales)
- Log Inn (Account creation and auth for the user)
- Add SQS (Buffer for requests)


