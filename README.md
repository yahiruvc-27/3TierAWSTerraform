# Highly Available 3-Tier AWS Architecture (Terraform)

This project is my personal, production-inspired 3-tier cloud architecture built on AWS using Terraform.

I focuse on good practices: infrastructure design / plan(diagrams), scalability, fault tolerance, and operational thinking rather than application code alone.

This project intentionally documents my real failures (network policies, load balancing, and distributed start up issues) and engineering decisions used find the root cause and fix it

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

- S3 Gateway Endpoint (private S3 access)
- SSM Parameter Store (SecureString secrets)
- SSM Session manager and Linux users with a purpose and permisions

## Terraform Structure

terraform/
- networking/   # VPC, subnets, routes, endpoints
- security/     # Security Groups, IAM roles
- database/     # RDS, subnet groups
- compute/      # EC2, ASG, ALB, Launch Templates

## System Diagram
*Click to se diagram*

[![Full Architecture](docs/architecture/full-architecture.png)](docs/architecture/full-architecture.pdf)

[Load Products Flow](docs/architecture/load-products-flow.pdf)

[Purchase Products Flow](docs/architecture/purchase-flow.pdf)

## How to Run This Project

### Prerequisites

1. AWS Account (access key ID + secret access key on aws config)
2. Terraform
3. AWS CLI configured
4. SSH key (optional, for SSH/debug Linux instances) -> comming soom SSM Session manager
5. SES verified source
6. S3 bucket with 6 .jpeg images
- Create {bucket_name} bucket -> place {bucket_name} in networking/terraform.tfvars
- Enable bucket encryption: S3 managed keys  (SSE-S3)
- Block public access
- Upload the 6 .jpeg images names [red-mug, blue-shirt, notepad, headphones, bottle, backpack]

### Step-by-Step Deployment
Do -> terraform (init, plan, apply) in each of the modules in order
1. /networking/
2. /security/
3. /database/
4. /compute/

*Each root module consumes outputs from the previous one via terraform_remote_state

### Step-by-Step Destruction
Do terrafrom destroy in each of the modules in inverse order creation

1. /compute/
2. /database/
3. /security/
4. /networking/

## Important Design Decisions
- RDS start-up (schema, db, table creation) in a ASG enviroment
- Security (IAM policies / Roles, SSM Session Manager, SG, GW endpoint, IAM Policies... )
- EC2 User Data templates
- IaC (big learning moments, debugg and troubleshooting)

## Future work

Security
- Use HTTPS ACM (Register a domain name)
- Use SSM session manager (delete SSH, key pairs and bastion host)

Functionality
- Log Inn (Account creation and auth for the user)
- Add SQS (Decouple & Async order processing)


