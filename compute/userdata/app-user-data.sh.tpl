#!/bin/bash
# ============================================================
# User Data Script - APP Tier (Mini Amazon Backend)
# Idempotent -> Terraform 
# ============================================================
set -euxo pipefail  # Better debugging (print commands, exit on error)
echo "[INFO] Starting APP tier bootstrap..."

# ------------------------------------------------------------
# === 1. Update and install packages ===
# ------------------------------------------------------------
dnf update -y
dnf install -y python3-pip git mariadb105 

# ------------------------------------------------------------
# === 2. Variables (Terraform injects values here) ===
# ------------------------------------------------------------
APP_DIR="/home/ec2-user/mini-amazon-app"
ENV_FILE="/etc/mini-amazon.env"

SERVICE_SRC="$${APP_DIR}/mini-amazon.service"
SERVICE_DST="/etc/systemd/system/mini-amazon.service"

# $${var} = Parameters passed by terraform 
# DB Variables
RDS_ENDPOINT="${rds_endpoint}"
DB_USER="${db_user}"
DB_PASS="${db_pass}"
DB_NAME="store"

# Region and email source
AWS_REGION=us-east-1
SES_SOURCE=yahiruvc@gmail.com

# ------------------------------------------------------------
# === 3. Clone APP code from Git Hub ===
# ------------------------------------------------------------
if [ ! -d "$${APP_DIR}/.git" ]; then
  echo "[INFO] Cloning backend repository..."
  sudo -u ec2-user git clone \
    https://github.com/yahiruvc-27/mini-amazon-backend.git "$${APP_DIR}"
else
  echo "[INFO] Repository exists, pulling latest changes..."
  sudo -u ec2-user git -C "$${APP_DIR}" pull
fi

# ------------------------------------------------------------
# === 4. Install Python dependencies from requirements.txt ===
# ------------------------------------------------------------
pip3 install -r "$${APP_DIR}/requirements.txt"

#sudo -u ec2-user pip3 install --user -r "$${APP_DIR}/requirements.txt"

# ------------------------------------------------------------
# === 5. Create environment file ===
# ------------------------------------------------------------
echo "[INFO] Writing environment variables..."
cat <<EOF > "$${ENV_FILE}"
RDS_ENDPOINT=$${RDS_ENDPOINT}
DB_USER=$${DB_USER}
DB_PASS=$${DB_PASS}
DB_NAME=$${DB_NAME}
AWS_REGION=$${AWS_REGION}
SES_SOURCE=$${SES_SOURCE}
EOF
# fix permissions


# ------------------------------------------------------------
# 6. Ensure correct ownership APP files (GitHUb)
# ------------------------------------------------------------
chown -R ec2-user:ec2-user "$${APP_DIR}"

# ------------------------------------------------------------
# 7. Install systemd service file (COPY to needed path)
# ------------------------------------------------------------
#cp /home/ec2-user/mini-amazon-app/mini-amazon.service /etc/systemd/system/mini-amazon.service

if [ ! -f "$${SERVICE_DST}" ]; then
  echo "Installing systemd service file..."
  cp "$${SERVICE_SRC}" "$${SERVICE_DST}"
fi

# ------------------------------------------------------------
# 8. Ensure EnvironmentFile is in rigth path
# ------------------------------------------------------------
if ! grep -q "^EnvironmentFile=$${ENV_FILE}" "$${SERVICE_DST}"; then
  sed -i "/^\[Service\]/a EnvironmentFile=$${ENV_FILE}" "$${SERVICE_DST}"
fi

# ------------------------------------------------------------
# 9. Reload systemd and start service
# ------------------------------------------------------------
systemctl daemon-reload
systemctl enable --now mini-amazon

# Check if service is running, sanity check

if systemctl is-active --quiet mini-amazon; then
  echo "[SUCCESS] mini-amazon service is running"
else
  echo "[WARN] mini-amazon service failed to start"
  systemctl status mini-amazon -l --no-pager
fi