# Database Root Module

Create RDS MYSQL Instance 

## Resources Created
- RDS MySQL 8.0 (Single-AZ, Free Tier)
- DB subnet group (private subnets only)
- Database SG
- SSM SecureString parameter for DB password

## Design Characteristics
- Schema and connection parameters data sent throouhj outputs
- Password generated automatically and stored in SSM
- No public accessibility

## Manual Step (Intentional)
After applying this module, the database schema must be initialized manually
or via a controlled bootstrap process.

See `/schema/schema.sql`.

## Apply Order
Must be applied **after networking and security**.

```bash
terraform init
terraform plan
terraform apply
