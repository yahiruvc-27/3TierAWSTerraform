# Networking Root Module

**Purpose:** 
Use Terrform to provision only the esential networking infrastructure for the project.

## Resources Created
- VPC
- Public subnets (Publuic ALB, Bastion Host)
- Private subnets (Web, App, DB)
- Internet Gateway
- NAT Gateway
- Route tables and associations
- VPC Gateway Endpoint for S3 (private access) [*Must have an existing S3]

## Design Characteristics
- Private subnets for Web App (EC2), and DB (RDS) tiers
- NAT Gateway used  for outbound Linux package download
- S3 accessed via Gateway Endpoint (with IAM policy attached), associated to Private RT

## Inputs
Must fill these variable values
See "terraform.tfvars.example"
and rename or cp to "terraform.tfvars"

Please check "providers.tf" -> aws region

## Outputs
- VPC ID
- Subnet IDs (grouped by tier)
- Project name (resource naming)
- S3 bucket name

## Apply Order
This is the first terraform root module
Must apply **first**.

Go to /security/ after this root module

```bash
terraform init
terrafrom plan
terraform apply
```