# Security Root Module

**Purpose:** 
IAM + Security Groups + Instance Profiles
This module defines SG, Instance profiles (EC2) and IAM Policies.

## Resources Created
- Security Groups for:
  - Bastion Host
  - Public ALB
  - Web Tier
  - Internal ALB
  - App Tier
  - Database
- IAM Roles and Instance Profiles:
  - Web EC2 Role
  - App EC2 Role
- IAM Policies:
  - (WEB) CW Logs, S3 read only
  - (App) Send emails, CW Logs, SSM Parameter get

## Design Decisions
- Least-privilege IAM policies
- No secrets on plain text

## Outputs
- Security Group IDs
- IAM (WEB & APP)Instance Profile names
- S3 bucket name
- SSM parameter name for DB password

## Apply Order
Must be applied **after networking**.
Go to /database/ afterwards

```bash
terraform init
terrafrom plan
terraform apply

