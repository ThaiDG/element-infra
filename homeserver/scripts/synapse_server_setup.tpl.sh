#!/bin/bash
set -e

# Interpolating by Terraform template_file data
SYNAPSE_DNS="${synapse_dns}"
COTURN_TCP_DNS="${coturn_tcp_dns}"
COTURN_UDP_DNS="${coturn_udp_dns}"
TAPYOUSH_DNS="${tapyoush_dns}"
SYGNAL_DNS="${sygnal_dns}"
AWS_ACCOUNT_ID="${aws_account_id}"
AWS_REGION="${aws_region}"
POSTGRES_DNS="${postgres_dns}"
SYNAPSE_VERSION="${synapse_version}"
S3_BUCKET_NAME="${s3_bucket_name}"

# Define constants
APP_DIR="/app"
POSTGRES_DB="postgres"  # Default Postgres database name for initial setup
MAX_BODY_SIZE="500M"

# Update and upgrade the system
apt-get update && apt-get upgrade -y

# Set up UFW rules
ufw allow 22/tcp
ufw allow http
ufw allow 8448
ufw allow 9090  # Prometheus port
# Enable UFW
ufw --force enable

# Install Docker
apt-get install -y \
  docker.io \
  unzip \
  curl \
  s3fs

# Install AWS CLI if not already installed
if ! command -v aws >/dev/null 2>&1; then
  echo "⚙️ AWS CLI not found — installing..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
else
  echo "✅ AWS CLI is already installed!"
fi

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install the docker compose verison 2
# Define version - fetch latest dynamically
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f4)
    
# Define plugin path
DOCKER_CONFIG=/root/.docker
PLUGIN_DIR="$DOCKER_CONFIG/cli-plugins"

# Create plugin directory
mkdir -p "$PLUGIN_DIR"

# Download Compose v2 binary
echo "Downloading Docker Compose v2..."
curl -SL "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-linux-x86_64" -o "$PLUGIN_DIR/docker-compose"

# Make it executable
chmod +x "$PLUGIN_DIR/docker-compose"

# Verify installation
echo "Verifying Docker Compose installation..."
docker compose version

# Logging in to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Fetching credentials from SSM
echo "🔐 Fetching credentials from SSM..."
SMTP_USER=$(aws ssm get-parameter \
  --name "/smtp/user" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

SMTP_PASS=$(aws ssm get-parameter \
  --name "/smtp/pass" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

POSTGRES_USER=$(aws ssm get-parameter \
  --name "/synapse/postgres/user" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

POSTGRES_PASSWORD=$(aws ssm get-parameter \
  --name "/synapse/postgres/password" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

SYNAPSE_DB=$(aws ssm get-parameter \
  --name "/synapse/postgres/db" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

RECAPTCHA_PUBLIC_KEY=$(aws ssm get-parameter \
  --name "/synapse/reCAPTCHA/public_key" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

RECAPTCHA_PRIVATE_KEY=$(aws ssm get-parameter \
  --name "/synapse/reCAPTCHA/private_key" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

LIVEKIT_URL=$(aws ssm get-parameter \
  --name "/synapse/livekit/url" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

LIVEKIT_KEY=$(aws ssm get-parameter \
  --name "/synapse/livekit/key" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

LIVEKIT_SECRET=$(aws ssm get-parameter \
  --name "/synapse/livekit/secret" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

COTURN_SECRET=$(aws ssm get-parameter \
  --name "/coturn/secret" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

# Create app directory and switch to it
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create docker-compose.yaml
cat <<'EOF' > docker-compose.yaml
services:
  synapse:
    image: $${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/element/synapse-server:$${SYNAPSE_VERSION}
    container_name: synapse
    restart: always
    volumes:
      - ./synapse/data:/data
      - ./synapse/config:/config
    ports:
      - "8448:8448"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8008/_matrix/client/versions || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  synapse-usage-exporter:
    image: $${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/element/synapse-usage-exporter:latest
    container_name: synapse-usage-exporter
    ports:
      - 5000:5000
    tmpfs:
      - /tmp/prometheus
    environment:
      - APP_LOG_LEVEL=DEBUG
      - PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus

  jwt-auth:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    container_name: jwt-auth
    restart: always
    ports:
      - "8070:8080"
    environment:
      - LK_JWT_PORT=8080
      - LIVEKIT_URL=$${LIVEKIT_URL}
      - LIVEKIT_KEY=$${LIVEKIT_KEY}
      - LIVEKIT_SECRET=$${LIVEKIT_SECRET}
      - LIVEKIT_FULL_ACCESS_HOMESERVERS=$${SYNAPSE_DNS}

  nginx:
    image: nginx:latest
    container_name: nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - synapse
      - jwt-auth

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml
EOF

# Create .env file
cat <<EOF > .env
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
SYNAPSE_DB=$SYNAPSE_DB
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
AWS_REGION=$AWS_REGION
SYNAPSE_VERSION=$SYNAPSE_VERSION
LIVEKIT_URL=wss://$LIVEKIT_URL
LIVEKIT_KEY=$LIVEKIT_KEY
LIVEKIT_SECRET=$LIVEKIT_SECRET
SYNAPSE_DNS=$SYNAPSE_DNS
EOF

# Create synapse and postgres folders
mkdir -p synapse/{config,data}
mkdir -p postgres/data
touch postgres/init.sql
# Create prometheus volume directory
mkdir -p prometheus

# Create init SQL content
cat <<EOF > postgres/init.sql
CREATE DATABASE $SYNAPSE_DB
ENCODING 'UTF8'
LC_COLLATE='C'
LC_CTYPE='C'
TEMPLATE template0
OWNER $POSTGRES_USER;
EOF

# Create nginx configuration
cat <<EOF > nginx.conf
worker_processes auto;
events {
    worker_connections 1024;
}
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    # Enable access and error logging
    access_log /var/log/nginx/access.log combined;
    error_log /var/log/nginx/error.log debug;

    server {
        listen 80;
        server_name $SYNAPSE_DNS;

        client_max_body_size $MAX_BODY_SIZE;

        # Synapse endpoints
        location ~ ^(/_matrix/|/.well-known/|/health) {
            proxy_pass http://synapse:8008;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # JWT Auth / SFU endpoints
        location = /sfu/get {
            proxy_pass http://jwt-auth:8080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
        }
        location = /healthz {
            proxy_pass http://jwt-auth:8080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
        }
    }
}
EOF

# Create Prometheus job definition
cat <<EOF > prometheus/prometheus.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'synapse'
    metrics_path: '/_synapse/metrics'
    static_configs:
      - targets: ['synapse:8000']
  - job_name: 'synapse-usage'
    static_configs:
      - targets: ['synapse-usage-exporter:5000']
EOF

# Generate synapse config (requires Docker)
docker run --rm \
  -v "$APP_DIR/synapse/data:/data" \
  -v "$APP_DIR/synapse/config:/config" \
  -e SYNAPSE_SERVER_NAME=$SYNAPSE_DNS \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse generate

CONFIG_FILE="$APP_DIR/synapse/data/homeserver.yaml"

# Extract secret values
REGISTRATION_SECRET=$(grep 'registration_shared_secret:' "$CONFIG_FILE" | sed 's/.*registration_shared_secret:[[:space:]]*//')
MACAROON_SECRET=$(grep 'macaroon_secret_key:' "$CONFIG_FILE" | sed 's/.*macaroon_secret_key:[[:space:]]*//')
FORM_SECRET=$(grep 'form_secret:' "$CONFIG_FILE" | sed 's/.*form_secret:[[:space:]]*//')

# Overwrite homeserver.yaml with complete config
cat <<EOF > "$CONFIG_FILE"
# Configuration file for Synapse.
#
# This is a YAML file: see [1] for a quick introduction. Note in particular
# that *indentation is important*: all the elements of a list or dictionary
# should have the same indentation.
#
# [1] https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html
#
# For more information on how to configure Synapse, including a complete accounting of
# each option, go to docs/usage/configuration/config_documentation.md or
# https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html
server_name: "$SYNAPSE_DNS"
pid_file: /data/homeserver.pid
listeners:
  - port: 8008
    tls: false
    type: http
    bind_addresses: ['0.0.0.0']
    x_forwarded: true
    resources:
      - names: [client]
        compress: false
  - port: 8448
    tls: false
    type: http
    bind_addresses: ['0.0.0.0']
    x_forwarded: true
    resources:
      - names: [federation]
        compress: false
  - port: 8000
    type: metrics
    bind_addresses: ['127.0.0.1']
database:
  name: psycopg2
  args:
    user: $POSTGRES_USER
    password: $POSTGRES_PASSWORD
    database: $SYNAPSE_DB
    host: $POSTGRES_DNS
log_config: "/data/$SYNAPSE_DNS.log.config"
registration_shared_secret: $REGISTRATION_SECRET
media_store_path: /data/media_store
report_stats: true
report_stats_endpoint: http://synapse-usage-exporter:5000/report-usage-stats/push
macaroon_secret_key: $MACAROON_SECRET
form_secret: $FORM_SECRET
signing_key_path: "/data/$SYNAPSE_DNS.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"
suppress_key_server_warning: true

# Custom configurations

# Increase the maximum upload size
max_upload_size: $MAX_BODY_SIZE

# Enable TURN server
turn_uris:
  - "turn:$COTURN_UDP_DNS:3478?transport=udp"
  - "turn:$COTURN_TCP_DNS:3478?transport=tcp"
  - "turns:$COTURN_TCP_DNS:5349?transport=tcp"
turn_shared_secret: "$COTURN_SECRET"
turn_user_lifetime: 86400
turn_allow_guests: false

public_baseurl: "https://$SYNAPSE_DNS"
default_identity_server: "https://vector.im"
web_client_location: "https://$TAPYOUSH_DNS"

# Push notifications to Sygnal
push:
  enabled: true

# Registration settings
enable_registration: true

# Enable CAPTCHA verification
enable_registration_captcha: true
recaptcha_public_key: "$RECAPTCHA_PUBLIC_KEY"
recaptcha_private_key: "$RECAPTCHA_PRIVATE_KEY"
recaptcha_siteverify_api: "https://www.google.com/recaptcha/api/siteverify"

# Enable email verification
disable_msisdn_registration: true
# Allows people to change their email address
enable_3pid_changes: true

# Allows searching of all users in directory
user_directory:
  enabled: true
  search_all_users: true
  prefer_local_users: true
  exclude_remote_users: false
  show_locked_users: true

# Enable features
# experimental_features:
# # Enable LiveKit for Element Call
#   msc2967_enabled: true
#   msc3266_enabled: true
#   msc4222_enabled: true
#   msc4140_enabled: true

# max_event_delay_duration: 24h
# rc_message:
#   per_second: 0.5
#   burst_count: 30
# rc_delayed_event_mgmt:
#   per_second: 1
#   burst_count: 20

# Add well-known client content
serve_server_wellknown: true
# extra_well_known_client_content:
#   org.matrix.msc4143.rtc_foci:
#     - type: "livekit"
#       livekit_service_url: "https://$SYNAPSE_DNS"
#     - type: "nextgen_new_foci_type"
#       props_for_nextgen_foci: "val"


# vim:ft=yaml
EOF

# ─── Configure and Mount S3FS ────────────────────────────────────────────

# Create the media_store mount point under app directory
mkdir -p $APP_DIR/synapse/data/media_store

# Ensure permissions allow the container (or any user) to access it
chown root:root $APP_DIR/synapse/data/media_store
chmod 755 $APP_DIR/synapse/data/media_store

# Append an fstab entry so the bucket auto-mounts on reboot
echo "s3fs#$S3_BUCKET_NAME $APP_DIR/synapse/data/media_store fuse \
  _netdev,allow_other,use_path_request_style,\
url=https://s3.$AWS_REGION.amazonaws.com,iam_role=auto,nonempty,\
mp_umask=0000 0 0" \
  >> /etc/fstab

# Mount all filesystems (including our new s3fs entry)
mount -a

# Verify the mount succeeded
if ! mountpoint -q $APP_DIR/synapse/data/media_store; then
  echo "❌ ERROR: s3fs mount failed for bucket $S3_BUCKET_NAME"
  exit 1
else
  echo "✅ s3fs mounted $S3_BUCKET_NAME -> $APP_DIR/synapse/data/media_store"
fi
# ──────────────────────────────────────────────────────────────────────────

# Start services
echo "Starting Synapse and related services..."
docker compose up --wait --force-recreate

echo "Synapse server setup completed successfully."
