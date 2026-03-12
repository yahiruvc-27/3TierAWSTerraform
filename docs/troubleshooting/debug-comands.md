## EC2

**See the ec2-userdata log**

```bash
sudo cat /var/log/cloud-init-output.log
```

**Verify instance Role**

```bash
aws sts get-caller-identity
```
### Web Tier (NGINX + Reverse Proxy)

**Service Status**

```bash
sudo systemctl status nginx
sudo journalctl -u nginx --no-pager
```

**Listening port**

```bash
sudo ss -lntp
```

**NGINX -> Backend product list**

```bash
curl -s http://127.0.0.1/api/products
```

**Test purchase**

```bash
curl -X POST http://127.0.0.1/api/purchase \
  -H "Content-Type: application/json" \
  -d '{
    "buyer_name": "Yahir",
    "buyer_email": "yahiruvc@example.com",
    "items": [
      {"product_id": 1, "quantity": 2},
      {"product_id": 3, "quantity": 1}
    ]
  }'
```

### APP Tier

**Status and listening port**

```bash
sudo systemctl status mini-amazon
sudo ss -lntp
```

**Test API locally (from APP tier)**
Flask rest API test (guinicorn)

```bash
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/products

```

**App Logs**

```bash
sudo journalctl -u mini-amazon --no-pager
```


## Test DB

**Set DB connection variables**

```bash
RDS_ENDPOINT="<rds_endpoint>"
DB_USER="<username>"
DB_PASS="<password>"
```

**Verify DB recheability -> all products**

```bash
Select ALL table "products" from store db
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "SELECT * FROM store.products;"
```

**Update product stock (write test)**

```bash
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "USE store; UPDATE products SET stock = 10 WHERE product_id=1; SELECT ROW_COUNT() AS Affected_Rows; SELECT stock FROM products WHERE product_id=1;"
```

**Update product price**

```bash
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "USE store; UPDATE products SET price = 9.99 WHERE product_id=1; SELECT ROW_COUNT() AS Affected_rows; SELECT price FROM products WHERE product_id=1;
```

**Modify the image key → pointer to S3 bucket image**

```bash
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "USE store; UPDATE products SET image_key='red-mug.jpeg' WHERE product_id=1;"
```

## SSM Session start

**Check IAM caller identity (check if assume role worked)**

```bash
aws sts get-caller-identity
```

**Assume a role on CLI**

```bash
aws sts assume-role `
  --profile <CLIProfile> `
  --role-arn arn:aws:iam::<AccountID>:role/AppOpsEngineerRole `
  --role-session-name <SessionName> `
  --serial-number arn:aws:iam::<AccountID>:mfa/<RoleName> `
  --token-code <MFACode>
  ```

**Start SSM Session to EC2**

```bash 
aws ssm start-session --target <InstanceID> --document-name <DocumentName>

Custom Document name = SSM-AppOpsConfig
```