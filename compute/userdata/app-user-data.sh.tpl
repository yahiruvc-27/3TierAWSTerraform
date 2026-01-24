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
# === 2. Variables (Terraform passes values here) ===
# ------------------------------------------------------------
APP_DIR="/home/ec2-user/mini-amazon-app"
ENV_FILE="/etc/mini-amazon.env"
SCHEMA_FILE="$${APP_DIR}/schema.sql"

SERVICE_SRC="$${APP_DIR}/mini-amazon.service"
SERVICE_DST="/etc/systemd/system/mini-amazon.service"

# get SSM parameter 
db_pass=$(aws ssm get-parameter --name "${db_pass_param_name}" --with-decryption --query "Parameter.Value" --output text --region us-east-1)

# DB Variables
RDS_ENDPOINT="${rds_endpoint}"
DB_USER="${db_user}"
DB_PASS="$${db_pass}"
DB_NAME="store"

# Region and email source

AWS_REGION=us-east-1
SES_SOURCE=yahiruvc@gmail.com # modify with validated SES AWS source

# ------------------------------------------------------------
# === 3. Clone APP code from Git Hub ===
# ------------------------------------------------------------
# If we dont have a git in the folder $${APP_DIR}

if [ ! -d "$${APP_DIR}/.git" ]; then # Clone the GitHub repo
  echo "[INFO] Cloning backend repository..."
  sudo -u ec2-user git clone \
    https://github.com/yahiruvc-27/mini-amazon-backend.git "$${APP_DIR}"
else # We have .git -> we must have an old verison of the repo
  echo "[INFO] Repository exists, pulling latest changes..."
  sudo -u ec2-user git -C "$${APP_DIR}" pull
fi

# ------------------------------------------------------------
# === 4. Install Python dependencies from requirements.txt ===
# ------------------------------------------------------------
# The service runs with ec2-user as owner, if you modify the guinicorn flask service, 
# beware that u must select the user here as owner

sudo pip3 install -r "$${APP_DIR}/requirements.txt"

# ------------------------------------------------------------
# === 5. Wait for database to be reachable and operational ===
# ------------------------------------------------------------

echo "[INFO] Waiting for database to become available..."

for i in {1..30}; do
  # attempt connection
  if mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
      -e "SELECT 1;" >/dev/null 2>&1; then
    echo "[INFO] Database is reachable and operational"
    break # If its ready, no need to wait
  fi
  echo "[INFO] Database not ready yet... retrying"
  sleep 10
done

# ------------------------------------------------------------
# 6. Schema initialization lock for a distibuted APP tier
# ------------------------------------------------------------
echo "[INFO] Attempting schema initialization lock..."

# === Create LOCK to avoid race conditions ========

# LOCK_RESULT = 1 -> I got the lock 
# LOCK_RESULT = 0 -> Someone else has it, wait for x seconds

LOCK_RESULT=$(mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
  -N -s -e "SELECT GET_LOCK('mini_amazon_schema_init', 60);")

if [ "$${LOCK_RESULT}" != "1" ]; then

  echo "[INFO] Another instance is initializing schema. Skipping."

else
  echo "Attempting to start DB Schema"
  # Set up a cleanup method in case of this script failure
  cleanup() {

    echo "[INFO] Releasing schema lock..."
    mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
      -e "SELECT RELEASE_LOCK('mini_amazon_schema_init');" || true

  }
  trap cleanup EXIT # Trap .... EXIT -> do ... on exit

  # === validate DB schema file existance ===
  if [ ! -f "$${SCHEMA_FILE}" ]; then
    echo "[ERROR] Schema file not found (missing in Git Hub): $${SCHEMA_FILE}"
    exit 1 # exit code 1
  fi

  # === Create DB schema if needed ===

  echo "[INFO] Checking if Databse schema exists..."
  if ! mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
      -e "USE $${DB_NAME}" >/dev/null 2>&1; then

    echo "[INFO] Databse Schema not initialized,  runing schema.sql..."
    # If it doesnt exist create it
    mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" < "$${SCHEMA_FILE}"

  else
    echo "[INFO] Database Sschema already exists. Skipping initialization."
  fi
fi

# ------------------------------------------------------------
# === 7. Create environment file ===
# ------------------------------------------------------------
echo "[INFO] Writing environment variables..."
cat <<EOF > "$${ENV_FILE}"
RDS_ENDPOINT=$${RDS_ENDPOINT}
DB_USER=$${DB_USER}
DB_PASS=$${db_pass}
DB_NAME=$${DB_NAME}
AWS_REGION=$${AWS_REGION}
SES_SOURCE=$${SES_SOURCE}
EOF

# ------------------------------------------------------------
# 8. Ensure correct ownership APP files (GitHUb)
# ------------------------------------------------------------
chown -R ec2-user:ec2-user "$${APP_DIR}"

# ------------------------------------------------------------
# 9. Install systemd service file (COPY to needed path)
# ------------------------------------------------------------

if [ ! -f "$${SERVICE_DST}" ]; then
  echo "Installing guinicorn systemd service file..."
  cp "$${SERVICE_SRC}" "$${SERVICE_DST}"
fi

# ------------------------------------------------------------
# 10. Replace env file (env variables) for service
# ------------------------------------------------------------

if ! grep -q "^EnvironmentFile=$${ENV_FILE}" "$${SERVICE_DST}"; then
  sed -i "/^\[Service\]/a EnvironmentFile=$${ENV_FILE}" "$${SERVICE_DST}"
fi

# ------------------------------------------------------------
# 11. Reload systemd and start service
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