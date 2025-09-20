#!/bin/bash
set -e

# Interpolating by Terraform template_file data
AWS_REGION="${aws_region}"
AWS_ACCOUNT_ID="${aws_account_id}"
S3_BUCKET_NAME="${s3_bucket_name}"
TAPYOUSH_DNS="${tapyoush_dns}"
SYDENT_DNS="${sydent_dns}"
SYNAPSE_DNS="${synapse_dns}"

# Define constants
APP_DIR="/app"
MAX_BODY_SIZE="100M"
SYDENT_VERSION="latest"

# Update and upgrade the system
apt-get update && apt-get upgrade -y

# Set up UFW rules
ufw allow 22/tcp
ufw allow http
ufw allow 9090  # Prometheus port
# Enable UFW
ufw --force enable

# Install Docker and required packages
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

# Install Docker Compose v2
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f4)
DOCKER_CONFIG=/root/.docker
PLUGIN_DIR="$DOCKER_CONFIG/cli-plugins"
mkdir -p "$PLUGIN_DIR"
curl -SL "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-linux-x86_64" -o "$PLUGIN_DIR/docker-compose"
chmod +x "$PLUGIN_DIR/docker-compose"

# Create symlink for systemd compatibility
ln -sf "$PLUGIN_DIR/docker-compose" /usr/local/bin/docker-compose
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

TWILIO_ACCOUNT_SID=$(fetch_ssm_param "/sydent/twilio/account_sid")
TWILIO_AUTH_TOKEN=$(fetch_ssm_param "/sydent/twilio/auth_token")
TWILIO_FROM_NUMBER=$(fetch_ssm_param "/sydent/twilio/from_number")
SIGNING_KEY=$(fetch_ssm_param "/sydent/signing")

# Create app directory and switch to it
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# ─── Configure and Mount S3FS ────────────────────────────────────────────

# Create the data mount point under app directory
S3_DIR="$APP_DIR/sydent_storage/data"
mkdir -p $S3_DIR

# Ensure permissions allow the container (or any user) to access it
chown root:root $S3_DIR
chmod 755 $S3_DIR

# Append an fstab entry so the bucket auto-mounts on reboot
echo "s3fs#$S3_BUCKET_NAME $S3_DIR fuse \
  _netdev,allow_other,use_path_request_style,\
url=https://s3.$AWS_REGION.amazonaws.com,iam_role=auto,nonempty,\
mp_umask=0000 0 0" \
  >> /etc/fstab

# Mount all filesystems (including our new s3fs entry)
mount -a

# Verify the mount succeeded
if ! mountpoint -q $S3_DIR; then
  echo "❌ ERROR: s3fs mount failed for bucket $S3_BUCKET_NAME"
  exit 1
else
  echo "✅ s3fs mounted $S3_BUCKET_NAME -> $S3_DIR"
fi
# ──────────────────────────────────────────────────────────────────────────

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
  sydent:
    image: $${AWS_ACCOUNT_ID}.dkr.ecr.$${AWS_REGION}.amazonaws.com/element/sydent-server:$${SYDENT_VERSION}
    container_name: sydent
    logging: *verbose-logging
    restart: always
    volumes:
      - ./sydent/data/sydent.conf:/data/sydent.conf
      - $${S3_MOUNT_POINT}:/data
    healthcheck:
      test: ["CMD-SHELL", "python3 -c 'import urllib.request; urllib.request.urlopen(\"http://localhost:8090/_matrix/identity/v2\")'"]
      interval: 30s
      timeout: 10s
      retries: 5

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
      - sydent

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    logging: *default-logging
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml
    depends_on:
      - sydent
EOF

# Create .env file
cat <<EOF > .env
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID
AWS_REGION=$AWS_REGION
SYDENT_VERSION=$SYDENT_VERSION
S3_MOUNT_POINT=$S3_DIR
EOF

# Create directories
mkdir -p sydent/data
mkdir -p prometheus
mkdir -p nginx

# Create Sydent config
cat > sydent/data/sydent.conf << EOL
[general]
server.name = $SYDENT_DNS
log.path =
log.level = INFO
pidfile.path = /data/sydent.pid
terms.path =
address_lookup_limit = 10000
templates.path = res
brand.default = yoush
enable_v1_associations = true
delete_tokens_on_bind = true
ip.blacklist =
ip.whitelist =
homeserver_allow_list =
enable_v1_access = true

[db]
db.file = /data/sydent.db

[http]
clientapi.http.bind_address = ::
clientapi.http.port = 8090
internalapi.http.bind_address = ::
internalapi.http.port = 
replication.https.certfile = 
replication.https.cacert = 
replication.https.bind_address = ::
replication.https.port = 4434
obey_x_forwarded_for = True
federation.verifycerts = True
client_http_base = https://$SYDENT_DNS

[email]
# Email support is disabled - only SMS verification is supported
email.from = noreply@$SYDENT_DNS
email.subject = Your Validation Token
email.invite.subject = %(sender_display_name)s has invited you to chat
email.invite.subject_space = %(sender_display_name)s has invited you to a space
email.smtphost = 
email.smtpport = 587
email.smtpusername = 
email.smtppassword = 
email.hostname = 
email.tlsmode = 0
email.default_web_client_location = https://$TAPYOUSH_DNS
email.third_party_invite_username_obfuscate_characters = 3
email.third_party_invite_domain_obfuscate_characters = 3

[sms]
provider = twilio
twilio.account_sid = $TWILIO_ACCOUNT_SID
twilio.auth_token = $TWILIO_AUTH_TOKEN
twilio.from_number = $TWILIO_FROM_NUMBER

bodyTemplate = Your Yoush verification code is {token}

originators.1 = alpha:Yoush
originators.44 = alpha:Yoush
originators.84 = alpha:Yoush
originators.default = alpha:Yoush

msisdn.ratelimit.burst = 5
msisdn.ratelimit.rate_hz = 0.000277
country.ratelimit.burst = 50
country.ratelimit.rate_hz = 0.0166

[crypto]
ed25519.signingkey = $SIGNING_KEY


EOL

# Create Prometheus job definition
cat <<EOF > prometheus/prometheus.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'sydent'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['sydent:9090']
EOF

# Create Nginx configuration
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
    
    # Set maximum upload size
    client_max_body_size $MAX_BODY_SIZE;
    
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ''      close;
    }

    server {
        listen       80;
        server_name  $SYDENT_DNS;

        # Health check endpoint for ALB
        location /health {
            access_log off;
            proxy_pass http://sydent:8090/_matrix/identity/v2;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Matrix Identity API endpoints
        location /_matrix/identity {
            proxy_pass http://sydent:8090;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;

            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
        }

        # Prometheus metrics endpoint
        location /metrics {
            proxy_pass http://sydent:9090;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

# Create systemd service for docker-compose
cat <<EOF > /etc/systemd/system/sydent-docker.service
[Unit]
Description=Sydent Identity Server Container
After=docker.service
Requires=docker.service

[Service]
Restart=always
WorkingDirectory=/app
# Shutdown container (if running) when unit is started
ExecStartPre=/usr/local/bin/docker-compose down
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose down

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable sydent-docker
systemctl start sydent-docker

echo "Sydent server setup completed successfully."