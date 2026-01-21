# Highly Available 3-Tier AWS Architecture (Terraform)

This project is my personal, production-inspired 3-tier cloud architecture built on AWS using Terraform.

I focuse on architecture good practices: infrastructure design, scalability, fault tolerance, and operational thinking rather than application code alone.

VERSION 1.0 MVP

## Architecture Overview

Web Tier
- Public ALB + Auto Scaling Group (ASG)
- NGINX serving frontend content

App Tier
- Internal ALB + Auto Scaling Group (ASG)
- Flask REST API (Gunicorn)

Data Base Tier
- Amazon RDS (MySQL, Multi-AZ ready)
- Private DB subnets (no IGW or NAT access)

Shared Infrastructure
- VPC with public and private (web, app & DB) subnets
- NAT Gateway

- Security Groups with least-privilege rules
- IAM Roles & Instance Profiles for EC2

-S3 Gateway Endpoint (private S3 access)
-SSM Parameter Store (SecureString secrets)

## Terraform Structure

terraform/
├── networking/   # VPC, subnets, routes, endpoints
├── security/     # Security Groups, IAM roles
├── database/     # RDS, subnet groups
├── compute/      # EC2, ASG, ALB, Launch Templates

## System Diagram

[![Full Architecture](docs/architecture/full-architecture.png)](docs/architecture/full-architecture.pdf)


## How to Run This Project

### Prerequisites

AWS Account (access key + secret access key on aws config)
Terraform
AWS CLI configured
SSH key (optional, for SSH/debug Linux instances) -> comming soom SSM Session manager

### Step-by-Step Deployment

1. networking terraform (init, plan, apply)
2. security terraform (init, plan, apply)
3. database terraform (init, plan, apply)
4. compute terraform (init, plan, apply)

Each layer consumes outputs from the previous one via terraform_remote_state

## Important Design Decisions
- RDS start-up (schema, db, table creation)
- Security (IAM policies / Roles ... )
- EC2 User Data
- IaC (big learning moments, debugg and reading documentation)

## Future work

Security
- Use HTTPS ACM (Register a domain name)
- Use SSM session manager (delete SSH, key pairs and bastion host)

Functionality
- Log Inn (Account creation and auth for the user)
- Add SQS (Buffer for requests)
- Add analytics (sales)


