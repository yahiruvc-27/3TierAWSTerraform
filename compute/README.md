# Compute Root Module

Create EC2 instances -> use User Data to have an APP ready and running

## Resources Created
- Launch Templates
- Auto Scaling Groups:
  - Web Tier
  - App Tier
- Application Load Balancers:
  - Public ALB (Web)
  - Internal ALB (App)
- Target Groups and Listeners
- User Data scripts

NOTES: The ec2.tf files can create a single instance of every tier for testing purpuses
Switch between sincgle instance / ASG multi AZ by commenting aws_launch_template & aws_launch_template

## Design Characteristics
- User data templated with Terraform (terrafrom passes parameters to user data script)
- App tier retrieves DB password from SSM
- Web tier retrieves products from S3 via VPC endpoint
- Auto Scaling Groups (2 Azs) for High Avaliability

## Dependencies
Requires outputs from:
- networking
- security
- database

## Apply Order
Applied **last**, after DB is initialized.

```bash
terraform initCharacteristics
terraform plan
terrafrom apply
