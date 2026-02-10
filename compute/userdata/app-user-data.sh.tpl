#!/bin/bash
# ============================================================
# User Data Script - APP Tier (Mini Amazon Backend)
# Idempotent -> Terraform 
# ============================================================
set -euxo pipefail  # Better debugging (print commands, exit on error)
echo "[INFO] Starting APP tier user data..."

# ------------------------------------------------------------
# === 1. Update and install packages ===
# ------------------------------------------------------------
dnf update -y
dnf install -y python3-pip git mariadb105 

# ------------------------------------------------------------
# === 2. Create linux  users
# ------------------------------------------------------------

# User to run app
if ! id appuser &>/dev/null; then
  useradd --system --no-create-home --shell /sbin/nologin appuser
fi

# Ops user (SSM user)
if ! id ops &>/dev/null; then
  useradd --create-home --shell /bin/bash ops
fi

# ------------------------------------------------------------
# === 3. Variables (Terraform passes values here) ===
# ------------------------------------------------------------

APP_DIR="/opt/mini-amazon-app"
ENV_DIR="/etc/mini-amazon"
ENV_FILE="$${ENV_DIR}/app.env"
SCHEMA_FILE="$${APP_DIR}/schema.sql"

SERVICE_DST="/etc/systemd/system/mini-amazon.service"

# DB Variables
RDS_ENDPOINT="${rds_endpoint}"
DB_USER="${db_user}"
DB_NAME="store"

# Region and email source
AWS_REGION=us-east-1
SES_SOURCE=example@gmail.com # modify with validated SES AWS source

# get SSM parameter 
# get and decript db_pass_param_name
DB_PASS=$(aws ssm get-parameter \
  --name "${db_pass_param_name}" \
  --with-decryption \
  --query "Parameter.Value"\
  --output text \
  --region $${AWS_REGION})

# ------------------------------------------------------------
# === 4. Clone APP code from Git Hub ===
# ------------------------------------------------------------

mkdir -p $${APP_DIR}

if [ ! -d "$${APP_DIR}/.git" ]; then # Clone the GitHub repo
  echo "[INFO] Cloning backend repository..."
  git clone https://github.com/yahiruvc-27/mini-amazon-backend.git "$${APP_DIR}"

else # We have .git -> we must have an old verison of the repo
  echo "[INFO] Repository exists, pulling latest changes..."
  git -C "$${APP_DIR}" pull
fi

# ------------------------------------------------------------
# === 5. Install Python dependencies from requirements.txt ===
# ------------------------------------------------------------

pip3 install -r "$${APP_DIR}/requirements.txt"

# ------------------------------------------------------------
# === 6. Wait for database to be reachable and operational ===
# ------------------------------------------------------------

echo "[INFO] Waiting / checking database to become available..."

for i in {1..30}; do
  # attempt connection
  if mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
      -e "SELECT 1;" >/dev/null 2>&1; then
  
    echo "[INFO] Database is reachable and operational"
    break
  fi
  echo "[INFO] Database not ready yet... retrying"
  sleep 10
done

# ------------------------------------------------------------
# 7. Schema initialization lock for a distibuted APP tier
# ------------------------------------------------------------
echo "[INFO] Attempting schema initialization lock..."

# === Create LOCK to avoid race conditions ========

# LOCK_RESULT = 1 -> I got the lock 
# LOCK_RESULT = 0 -> Someone else has it, wait for x seconds

LOCK_RESULT=$(mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
  -N -s -e "SELECT GET_LOCK('mini_amazon_schema_init', 60);")

if [ "$${LOCK_RESULT}" = "1" ]; then

  echo "Attempting to start DB Schema"

  # Set up a cleanup method in case of this script failure
  cleanup() {

    echo "[INFO] Releasing schema lock..."
    mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
      -e "SELECT RELEASE_LOCK('mini_amazon_schema_init');" || true

  }
  trap cleanup EXIT # Trap .... EXIT -> do ... on exit

  # Create DB schema if needed ===

  if ! mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" \
      -e "USE $${DB_NAME}" >/dev/null 2>&1; then

    # Cretae schema -> run schema.sql
    mysql -h "$${RDS_ENDPOINT}" -u "$${DB_USER}" -p"$${DB_PASS}" < "$${SCHEMA_FILE}"
    echo "[INFO] Databse Schema Created"
  fi 
else
  echo "[INFO] Another instance is initializing schema. Skipping."
fi

# ------------------------------------------------------------
# === 8. Create environment file ===
# ------------------------------------------------------------

mkdir -p "$${ENV_DIR}"

echo "[INFO] Writing environment vars to: $${ENV_FILE}"

cat <<EOF > "$${ENV_FILE}"
RDS_ENDPOINT=$${RDS_ENDPOINT}
DB_USER=$${DB_USER}
DB_PASS=$${DB_PASS}
DB_NAME=$${DB_NAME}
AWS_REGION=$${AWS_REGION}
SES_SOURCE=$${SES_SOURCE}
EOF

# Fix permisisons
chmod 640 "$${ENV_FILE}"
chown root:root "$${ENV_FILE}"

# ------------------------------------------------------------
# 9. Ensure correct ownership APP files (GitHUb) cloned -> to appuser
# ------------------------------------------------------------
chown -R appuser:appuser "$${APP_DIR}"
chmod -R 750 "$${APP_DIR}"

# ------------------------------------------------------------
# 10. Install systemd service file 
# ------------------------------------------------------------

cat <<EOF > "$${SERVICE_DST}"
[Unit]
Description=Mini Amazon Backend Flask App (gunicorn)
After=network.target

[Service]
User=appuser
Group=appuser
WorkingDirectory=$${APP_DIR}
EnvironmentFile=$${ENV_FILE}
ExecStart=/usr/local/bin/gunicorn --workers 2 --bind 0.0.0.0:5000 app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# 11. Configure sudoers file for  ops user
# ------------------------------------------------------------
cat <<EOF > /etc/sudoers.d/ops-mini-amazon
# Ops:  incident-response for Mini Amazon app
User_Alias OPS = ops

Cmnd_Alias MINI_AMAZON_SVC = \
  /bin/systemctl status mini-amazon, \
  /bin/systemctl restart mini-amazon, \
  /bin/systemctl stop mini-amazon, \
  /bin/journalctl -u mini-amazon

OPS ALL=(root) NOPASSWD: MINI_AMAZON_SVC
EOF

chmod 440 /etc/sudoers.d/ops-mini-amazon

# ------------------------------------------------------------
# 12. Reload systemd and start service
# ------------------------------------------------------------

systemctl daemon-reload
systemctl enable --now mini-amazon

# Check if service is running
systemctl is-active --quiet mini-amazon && echo "[SUCCESS] Service running"