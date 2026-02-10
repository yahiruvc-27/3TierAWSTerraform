# Failure 01 — S3 Gateway Endpoint Policy Broke EC2 Bootstrapping

ERROR: user data script failure, impossible to dowload linux packages when I attached a S3 GW Endpoint

## Context
I provisioned a S3 GW, attached it to privet RT with a security IAM policy only allowing traffic to product bucket. imporving security and optimized cost by reducing data traffic to the NAT GW.

Remember
- Private EC2 instances (Web & App tiers) install packages via user data.
- No public IPs. No direct internet access.
- Outbound S3 access for the region is routed through S3 Gateway Endpoint.

### Erorrs and Impact

1.- EC2 instances bootstrap failed during user data execution
2.- dnf/yum package installs failed -> Services (NGINX, Gunicorn) never started
3.- ASG continuously replaced instances due to failed health checks

### Root Cause

The S3 GW Endpoint IAM policy  too restrictive -> blocking traffic to linux packages repositories hosted on AWS owned buckets (S3)

It allowed: Access to the bucket holding product images, native to this project

It blocked: AWS-owned S3 buckets used by Amazon, the ones containing Linux packages repositories

Result: OS-level package installation failed even though S3 access “seems fine" for my app bucket -> but does not consider other buckets taht need to be accessed.

### Evidence

View APP Tier user data script logs

```bash
sudo cat /var/log/cloud-init-output.log
``` 

![s3-endpoint-failed-install-packages.png](/docs/failures/s3-endpoint-failed-install-packages.png) 

## Fix

Expanded the S3 Gateway Endpoint policy to allow access to: Required AWS Linux repository S3 buckets (see /networking/vpc.tf -> s3_endpoint_policy)

Result: Package installation, safe execution of user data and fixed ASG healtchecks (stable ASG capacity) 

### Validation

After the fix, run from a private EC2 instance (web tier in this case):

dnf install -y nginx
systemctl status nginx

Sucessfull package instalation, therefore ec2 user data had a clean execution

## Key Learning

S3 GW Endpoint are attached at the RT level -> they impact traffic going to all S3 not just my bucket
Endpoint policies must consider all VPC traffic for that RT, not just the explicit S3 thats being reached