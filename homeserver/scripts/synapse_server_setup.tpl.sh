#!/bin/bash
set -e

# Interpolating by Terraform template_file data
SYNAPSE_DNS="${synapse_dns}"
COTURN_TCP_DNS="${coturn_tcp_dns}"
COTURN_UDP_DNS="${coturn_udp_dns}"
ELEMENT_DNS="${element_dns}"
SYGNAL_DNS="${sygnal_dns}"
AWS_ACCOUNT_ID="${aws_account_id}"
AWS_REGION="${aws_region}"
POSTGRES_DNS="${postgres_dns}"

# Define constants
APP_DIR="/app"
POSTGRES_DB="postgres"  # Default Postgres database name for initial setup

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
  curl

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

# Create app directory and switch to it
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create docker-compose.yaml
cat <<'EOF' > docker-compose.yaml
services:
  synapse:
    image: $${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/element/synapse-server:latest
    container_name: synapse
    restart: always
    # depends_on:
    #   - postgres
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

  # postgres:
  #   image: postgres:14
  #   restart: always
  #   volumes:
  #     - ./postgres/data:/var/lib/postgresql/data
  #     - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
  #   environment:
  #     - POSTGRES_USER=$${POSTGRES_USER}
  #     - POSTGRES_PASSWORD=$${POSTGRES_PASSWORD}
  #     - POSTGRES_DB=$${POSTGRES_DB}
  #   ports:
  #     - "127.0.0.1:5432:5432"
  #   healthcheck:
  #     test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${SYNAPSE_DB}"]
  #     interval: 10s
  #     timeout: 5s
  #     retries: 3
EOF

# Create .env file
cat <<EOF > .env
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
SYNAPSE_DB=$SYNAPSE_DB
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
AWS_REGION=$AWS_REGION
LIVEKIT_URL=wss://$LIVEKIT_URL
LIVEKIT_KEY=$LIVEKIT_KEY
LIVEKIT_SECRET=$LIVEKIT_SECRET
SYNAPSE_DNS=$SYNAPSE_DNS
EOF

# Create synapse and postgres folders
mkdir -p synapse/{config,data}
mkdir -p postgres/data
touch postgres/init.sql

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
    x_forwarded: true
    resources:
      - names: [client]
        compress: false
  - port: 8448
    tls: false
    type: http
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
report_stats_endpoint: synapse-usage-exporter:5000/report-usage-stats/push
macaroon_secret_key: $MACAROON_SECRET
form_secret: $FORM_SECRET
signing_key_path: "/data/$SYNAPSE_DNS.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"
suppress_key_server_warning: true

# Custom configurations

# Increase the maximum upload size
max_upload_size: 100M

# Enable TURN server
turn_uris:
  - "turn:$COTURN_UDP_DNS:3478?transport=udp"
  - "turn:$COTURN_TCP_DNS:3478?transport=tcp"
  - "turns:$COTURN_TCP_DNS:5349?transport=tcp"
turn_username: "admin"
turn_password: "Admin123"
turn_user_lifetime: 86400
turn_allow_guests: true

public_baseurl: "https://$SYNAPSE_DNS"
default_identity_server: "https://vector.im"
web_client_location: "https://$ELEMENT_DNS"

# Push notifications to Sygnal
push:
  enabled: true
  gateway_url: "https://$SYGNAL_DNS/_matrix/push/v1/notify"

# Registration settings
enable_registration: true

# Enable CAPTCHA verification
enable_registration_captcha: true
recaptcha_public_key: "$RECAPTCHA_PUBLIC_KEY"
recaptcha_private_key: "$RECAPTCHA_PRIVATE_KEY"
recaptcha_siteverify_api: "https://www.google.com/recaptcha/api/siteverify"

# Enable email verification
disable_msisdn_registration: true
# User required an email address to register and password reset
registrations_require_3pid:
  - email
# Allows people to change their email address
enable_3pid_changes: true
email:
  smtp_host: "smtp.gmail.com"
  smtp_port: 587
  smtp_user: "$SMTP_USER"
  smtp_pass: "$SMTP_PASS"
  force_tls: false
  require_transport_security: true
  enable_tls: true
  tlsname: smtp.gmail.com
  app_name: "TAP Media Chat"
  notif_from: "%(app)s <noreply@$SYNAPSE_DNS>"
  enable_notifs: true
  notif_for_new_users: false
  subjects:
    password_reset: '[%(app)s] Password reset'
    email_validation: '[%(app)s] Validate your email'

# Allows searching of all users in directory
user_directory:
  enabled: true
  search_all_users: true
  prefer_local_users: true
  exclude_remote_users: false
  show_locked_users: true

# Enable Google OAuth
# oidc_providers:
#   - idp_id: google
#     idp_name: Google
#     idp_brand: "google"  # optional: styling hint for clients
#     issuer: "https://accounts.google.com/"
#     client_id: "<Google OAuth client ID>"
#     client_secret: "<Google OAuth client secret>"
#     scopes:
#       - "openid"
#       - "profile"
#       - "email"
#     allow_existing_users: true
#     user_mapping_provider:
#       config:
#         localpart_template: "{{ user.given_name|lower }}"
#         display_name_template: "{{ user.name }}"
#         email_template: "{{ user.email }}" # needs "email" in scopes above

# Enable features
experimental_features:
#  msc3861:
#     enabled: true
#     issuer: "https://accounts.google.com"
#     client_id: "<Google OAuth client ID>"
#     client_auth_method: client_secret_basic
#     client_secret: "<Google OAuth client secret>"
#     admin_token: $REGISTRATION_SECRET

# Enable LiveKit for Element Call
  msc2967_enabled: true
  msc3266_enabled: true
  msc4222_enabled: true
  msc4140_enabled: true

max_event_delay_duration: 24h
rc_message:
  per_second: 0.5
  burst_count: 30
rc_delayed_event_mgmt:
  per_second: 1
  burst_count: 20

# Add well-known client content
serve_server_wellknown: true
extra_well_known_client_content:
  org.matrix.msc4143.rtc_foci:
    - type: "livekit"
      livekit_service_url: "https://$SYNAPSE_DNS"
    - type: "nextgen_new_foci_type"
      props_for_nextgen_foci: "val"


# vim:ft=yaml
EOF

# Start services
echo "Starting Synapse and Postgres services..."
docker compose up --wait --force-recreate

echo "Synapse server setup completed successfully."
