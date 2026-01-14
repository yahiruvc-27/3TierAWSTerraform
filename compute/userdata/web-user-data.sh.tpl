#!/bin/bash
# ============================================================
# Web Tier EC2 User Data Script (Idempotent)
# This script is safe to re-run 
# ============================================================

set -euxo pipefail

# === 1. Update and install required packages ===

# dnf is idempotent: re-running will not reinstall packages
dnf update -y
dnf install -y nginx git awscli

# === 2. Define variables used === 

# NOTE: MUST REPLACE S3_BUCKET IP_BACKEND -> real values
S3_BUCKET="${s3_bucket}"
BACKEND_HOST="${backend_host}"

# Do not modidy
WEBROOT="/var/www/mini-amazon"
NGINX_CONFIG_PATH="/etc/nginx/conf.d"

# === 3. Ensure base directories exist ===

mkdir -p /var/www

# 4. Clone or update frontend / WEB GitHub repository (IDEMPOTENT)

if [ ! -d "$${WEBROOT}/.git" ]; then # if there is no local repo clone
  echo "Cloning frontend repository..."
  git clone https://github.com/yahiruvc-27/mini-amazon-frontend.git "$${WEBROOT}" # clone to the desired path $${WEBROOT}
else # just update or pull
  echo "Frontend repository already exists. Pulling latest changes..."
  cd "$${WEBROOT}"
  git pull
fi


# 5. Config file for nginx -> get backend endpoint 

NGINX_SOURCE_CONF="$${WEBROOT}/nginx/mini-amazon.conf" # NGINX config location from Git clone
NGINX_TARGET_CONF="$${NGINX_CONFIG_PATH}/mini-amazon.conf" # NGINX config DESIRED destination (move)

# Replace backend placeholder to the IP only if it still exists

# IF "BACKEND_PLACEHOLDER" IN "$${NGINX_SOURCE_CONF}" -> repace placehoder for Backend IP
if grep -q "BACKEND_PLACEHOLDER" "$${NGINX_SOURCE_CONF}"; then
    # sed = "search and replace |this|for that|"
    # -i -> save the file after the replace
    # s ->start, g -> global -> all the appearances
  sed -i "s|BACKEND_PLACEHOLDER|$${BACKEND_HOST}|g" "$${NGINX_SOURCE_CONF}"
fi

# Copy nginx config only if not already in destination folder
# IF FILE X not exist then
if [ ! -f "$${NGINX_TARGET_CONF}" ]; then
  echo "Installing nginx configuration..."
  cp "$${NGINX_SOURCE_CONF}" "$${NGINX_TARGET_CONF}"
fi

# Remove default nginx config, just to be safe
rm -f /etc/nginx/conf.d/default.conf


# === 6. Write availability zone metadata ===

# Request  token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Fetch availability zone
AZ=$(curl -H "X-aws-ec2-metadata-token: $${TOKEN}" \
  -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Write the $${AZ} to a file (overwrite)
echo "$${AZ}" > "$${WEBROOT}/az.txt"
chmod 644 "$${WEBROOT}/az.txt"

# === 7 Sync product images from S3 ===

# what is sync all images from S3
# download image if not exist (in EC2 dir), delete (from EC2 dir) if they are no longer in s3
mkdir -p "$${WEBROOT}/images"
aws s3 sync "s3://$${S3_BUCKET}" "$${WEBROOT}/images" --delete


# === 8. Fix ownership /permissions for nginx ===
# there is an NGINX user -> the service must own the files

chown -R nginx:nginx "$${WEBROOT}"
chmod -R 755 "$${WEBROOT}"

# === 9. Enable and start nginx ===

systemctl daemon-reload
systemctl enable --now nginx

# Oheck if NGINX is working
systemctl is-active nginx || systemctl status nginx -l --no-pager
