## EC2

**See the ec2-userdata log**
sudo cat /var/log/cloud-init-output.log

**Verify instance Role**
aws sts get-caller-identity 

### Web Tier (NGINX + Reverse Proxy)

**Service Status**
sudo systemctl status nginx
sudo journalctl -u nginx --no-pager

**Listening port**
sudo ss -lntp

*NGINX -> Backend product list*
curl -s http://127.0.0.1/api/products

**Test purchase**
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

### APP Tier

**Status and listening port**
sudo systemctl status mini-amazon
sudo ss -lntp

**Test API locally (from APP tier)**
Flask rest API test (guinicorn)
curl http://127.0.0.1:5000/
curl http://127.0.0.1:5000/products

**App Logs**
sudo journalctl -u mini-amazon --no-pager

## Test DB

**Set DB connection variables**
RDS_ENDPOINT="<rds_endpoint>"
DB_USER="<username>"
DB_PASS="<password>"

**Verify DB recheability -> all products**
Select ALL table "products" from store db
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "SELECT * FROM store.products;"

**Update product stock (write test)**
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "USE store; UPDATE products SET stock = 10 WHERE product_id=1; SELECT ROW_COUNT() AS Affected_Rows; SELECT stock FROM products WHERE product_id=1;"

**Update product price**
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "USE store; UPDATE products SET price = 9.99 WHERE product_id=1; SELECT ROW_COUNT() AS Affected_rows; SELECT price FROM products WHERE product_id=1;"

**Modify the image key → pointer to S3 bucket image**
mysql -h $RDS_ENDPOINT -u $DB_USER -p$DB_PASS -e "USE store; UPDATE products SET image_key='red-mug.jpeg' WHERE product_id=1;"