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
LIVEKIT_DNS="${livekit_dns}"
LIVEKIT_TURN_DNS="${livekit_turn_dns}"
MAS_DNS="${mas_dns}"

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

fetch_ssm_param() {
  local param_name="$1"
  aws ssm get-parameter \
    --name "$param_name" \
    --with-decryption \
    --region "$AWS_REGION" \
    --query 'Parameter.Value' \
    --output text
}

SMTP_USER=$(fetch_ssm_param "/smtp/user")
SMTP_PASS=$(fetch_ssm_param "/smtp/pass")
POSTGRES_USER=$(fetch_ssm_param "/synapse/postgres/user")
POSTGRES_PASSWORD=$(fetch_ssm_param "/synapse/postgres/password")
SYNAPSE_DB=$(fetch_ssm_param "/synapse/postgres/db")
RECAPTCHA_PUBLIC_KEY=$(fetch_ssm_param "/synapse/reCAPTCHA/public_key")
RECAPTCHA_PRIVATE_KEY=$(fetch_ssm_param "/synapse/reCAPTCHA/private_key")
LIVEKIT_URL=$(fetch_ssm_param "/synapse/livekit/url")
LIVEKIT_KEY=$(fetch_ssm_param "/synapse/livekit/key")
LIVEKIT_SECRET=$(fetch_ssm_param "/synapse/livekit/secret")
COTURN_SECRET=$(fetch_ssm_param "/coturn/secret")
MAS_CLIENT_ID=$(fetch_ssm_param "/mas/client/id")
MAS_CLIENT_SECRET=$(fetch_ssm_param "/mas/client/secret")
MAS_MATRIX_SECRET=$(fetch_ssm_param "/mas/matrix/secret")

# Create app directory and switch to it
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create docker-compose.yaml
cat <<'EOF' > docker-compose.yaml
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

x-verbose-logging: &verbose-logging
  driver: "json-file"
  options:
    max-size: "50m"
    max-file: "5"

services:
  synapse:
    image: $${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/element/synapse-server:$${SYNAPSE_VERSION}
    container_name: synapse
    restart: always
    logging: *verbose-logging
    volumes:
      - ./synapse/data:/data
      - ./synapse/config:/config
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8008/_matrix/client/versions || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  synapse-usage-exporter:
    image: $${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/element/synapse-usage-exporter:latest
    container_name: synapse-usage-exporter
    logging: *default-logging
    restart: always
    ports:
      - "5000:5000"
    tmpfs:
      - /tmp/prometheus
    environment:
      - APP_LOG_LEVEL=DEBUG
      - PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    logging: *default-logging
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml

  nginx:
    image: nginx:latest
    container_name: nginx
    logging: *default-logging
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      synapse:
        condition: service_healthy
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
SYNAPSE_DNS=$SYNAPSE_DNS
EOF

# Create synapse and postgres folders
mkdir -p synapse/{config,data}
mkdir -p postgres/data
touch postgres/init.sql
# Create prometheus volume directory
mkdir -p prometheus
# Create nginx directory
mkdir -p nginx

# Create init SQL content
cat <<EOF > postgres/init.sql
CREATE DATABASE $SYNAPSE_DB
ENCODING 'UTF8'
LC_COLLATE='C'
LC_CTYPE='C'
TEMPLATE template0
OWNER $POSTGRES_USER;
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
  # - "turn:$COTURN_UDP_DNS:3478?transport=udp"
  # - "turn:$COTURN_TCP_DNS:3478?transport=tcp"
  - "turns:$LIVEKIT_TURN_DNS:5349?transport=tcp"
turn_shared_secret: "$COTURN_SECRET"
turn_user_lifetime: 86400
turn_allow_guests: false

public_baseurl: "https://$SYNAPSE_DNS"
# default_identity_server: "https://$MAS_DNS"
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
experimental_features:
  # Enable LiveKit for Element Call
  msc2967_enabled: true
  msc3266_enabled: true
  msc4222_enabled: true
  msc4140_enabled: true
  # # The below configuration is used for Matrix Authentication Service
  # msc4108_enabled: true
  # msc3861:
  #   enabled: true

  #   # Synapse will call {issuer}/.well-known/openid-configuration to get the OIDC configuration
  #   issuer: https://$MAS_DNS/

  #   # Matches the client_id in the auth service config
  #   client_id: $MAS_CLIENT_ID

  #   # Matches the client_auth_method in the auth service config
  #   client_auth_method: client_secret_basic

  #   # Matches the client_secret in the auth service config
  #   client_secret: "$MAS_CLIENT_SECRET"

  #   # Matches the matrix.secret in the auth service config
  #   admin_token: "$MAS_MATRIX_SECRET"

  #   # URL to advertise to clients where users can self-manage their account
  #   # Defaults to the URL advertised by MAS, e.g. https://{public_mas_domain}/account/
  #   account_management_url: "https://$MAS_DNS/account/"

  #   # URL which Synapse will use to introspect access tokens
  #   # Defaults to the URL advertised by MAS, e.g. https://{public_mas_domain}/oauth2/introspect
  #   # This is useful to override if Synapse has a way to call the auth service's
  #   # introspection endpoint directly, skipping intermediate reverse proxies
  #   introspection_endpoint: "https://$MAS_DNS/oauth2/introspect"

# The maximum allowed duration by which sent events can be delayed, as
# per MSC4140.
max_event_delay_duration: 24h

rc_message:
  # This needs to match at least e2ee key sharing frequency plus a bit of headroom
  # Note key sharing events are bursty
  per_second: 0.5
  burst_count: 30
  # This needs to match at least the heart-beat frequency plus a bit of headroom
  # Currently the heart-beat is every 5 seconds which translates into a rate of 0.2s
rc_delayed_event_mgmt:
  per_second: 1
  burst_count: 20

# Add well-known client content
serve_server_wellknown: true
extra_well_known_client_content:
  org.matrix.msc4143.rtc_foci:
    - type: "livekit"
      livekit_service_url: "https://$LIVEKIT_DNS"
    - type: "nextgen_new_foci_type"
      props_for_nextgen_foci: "val"
  # org.matrix.msc2965.authentication:
  #   - issuer: "https://$MAS_DNS"
  #     account: "https://$MAS_DNS"


# vim:ft=yaml
EOF

# Create Nginx configuration for Matrix routing
cat <<EOF > nginx/nginx.conf
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log  notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    # Add resolver for Docker DNS
    resolver 127.0.0.11 valid=30s;
    
    # Set maximum upload size to match Synapse configuration
    client_max_body_size $MAX_BODY_SIZE;
    
    # Define upstream servers with health checks
    upstream synapse_client {
        server synapse:8008 max_fails=3 fail_timeout=30s;
    }
    
    upstream synapse_federation {
        server synapse:8448 max_fails=3 fail_timeout=30s;
    }
    
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ''      close;
    }

    server {
        listen       80;
        server_name  $SYNAPSE_DNS;

        # Health check endpoint for ALB
        location /health {
            proxy_pass http://synapse_client/health;
            proxy_set_header X-Forwarded-For \$remote_addr;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Host \$host;
            proxy_http_version 1.1;
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        # Matrix Federation API - route federation requests to port 8448
        location /_matrix/federation {
            proxy_pass http://synapse_federation;
            proxy_set_header X-Forwarded-For \$remote_addr;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Host \$host;
            proxy_http_version 1.1;
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Matrix Client API - all other /_matrix requests go to port 8008
        location /_matrix {
            proxy_pass http://synapse_client;
            proxy_set_header X-Forwarded-For \$remote_addr;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Host \$host;
            
            # Synapse responses may be chunked, which is an HTTP/1.1 feature.
            proxy_http_version 1.1;
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Synapse admin endpoints
        location /_synapse {
            proxy_pass http://synapse_client;
            proxy_set_header X-Forwarded-For \$remote_addr;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Host \$host;
            proxy_http_version 1.1;
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # Well-known endpoints (served by Synapse via homeserver.yaml)
        location /.well-known {
            proxy_pass http://synapse_client;
            proxy_set_header X-Forwarded-For \$remote_addr;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Host \$host;
            proxy_http_version 1.1;
            proxy_connect_timeout 5s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }
    }
}
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
