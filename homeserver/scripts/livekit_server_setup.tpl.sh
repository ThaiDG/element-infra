#!/bin/sh
# This script will write all of your configurations to /opt/livekit.
# It'll also install LiveKit as a systemd service that will run at startup
# LiveKit will be started automatically at machine startup.

# Interpolating by Terraform template_file data
REDIS_ENDPOINT="${redis_endpoint}"
REDIS_PORT="${redis_port}"
ROOT_DOMAIN="${root_domain}"
SYNAPSE_DNS="${synapse_dns}"
AWS_REGION="${region}"

# Constants
WORK_DIR="/opt/livekit"
S3_BUCKET_NAME="767828741221-certbot"
S3_DIR="/s3_mounted"
CERT_SRC_DIR="$S3_DIR/certs/letsencrypt/live/$ROOT_DOMAIN"
CERT_DEST_DIR="$WORK_DIR/certs"

# Install AWS CLI if not already installed
apt-get update && \
apt-get install -y \
  unzip \
  curl \
  s3fs

if ! command -v aws >/dev/null 2>&1; then
  echo "⚙️ AWS CLI not found — installing..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
else
  echo "✅ AWS CLI is already installed!"
fi

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

ZEROSSL_APIKEY=$(fetch_ssm_param "/zerossl/apikey")
LIVEKIT_APIKEY=$(fetch_ssm_param "/livekit/apikey")
LIVEKIT_APISECRET=$(fetch_ssm_param "/livekit/apisecret")

# create directories for LiveKit
mkdir -p /usr/local/bin
# Create prometheus volume directory
mkdir -p $WORK_DIR/prometheus

# ─────────────────────── Configure and Mount S3FS ───────────────────────

# Create the media_store mount point under app directory
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

# Reload the systemd
systemctl daemon-reload

# Mount all filesystems (including our new s3fs entry)
mount -a

# Verify the mount succeeded
if ! mountpoint -q $S3_DIR; then
  echo "❌ ERROR: s3fs mount failed for bucket $S3_BUCKET_NAME"
  exit 1
else
  echo "✅ s3fs mounted $S3_BUCKET_NAME -> $S3_DIR"
fi

# ──────────────────────── Copy and secure certs ─────────────────────────

# Ensure destination directory exists
mkdir -p "$CERT_DEST_DIR"
# Copy latest symlinked certificate files
echo "🔍 Copying certificates from $CERT_SRC_DIR to $CERT_DEST_DIR"
cp "$CERT_SRC_DIR/fullchain.pem" "$CERT_DEST_DIR/fullchain.pem"
cp "$CERT_SRC_DIR/privkey.pem" "$CERT_DEST_DIR/privkey.pem"
# Set ownership and strict permissions
chown root:root "$CERT_DEST_DIR"/*.pem
chmod 400 "$CERT_DEST_DIR"/*.pem
echo "✅ Certificates copied and secured."
# ────────────────────────────────────────────────────────────────────────

# Docker & Docker Compose will need to be installed on the machine
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
# Define version - fetch latest dynamically
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f4)
curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod 755 /usr/local/bin/docker-compose

sudo systemctl enable docker

# livekit config
cat << EOF > $WORK_DIR/livekit.yaml
port: 7880
bind_addresses:
    - "0.0.0.0"
rtc:
    tcp_port: 7881
    port_range_start: 50000
    port_range_end: 60000
    use_external_ip: false
room:
    auto_create: false
logging:
    level: info
redis:
    address: $REDIS_ENDPOINT:$REDIS_PORT
    db: 0
    tls:
      enabled: true
turn:
    enabled: true
    udp_port: 3478
    tls_port: 5349
    external_tls: false
    domain: livekit-turn.$ROOT_DOMAIN
    cert_file: $CERT_DEST_DIR/fullchain.pem
    key_file: $CERT_DEST_DIR/privkey.pem
keys:
    $LIVEKIT_APIKEY: $LIVEKIT_APISECRET
prometheus:
    port: 6789


EOF

# docker compose
cat << EOF > $WORK_DIR/docker-compose.yaml
# This docker-compose requires host networking, which is only available on Linux
# This compose will not function correctly on Mac or Windows
services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit
    command: --config /etc/livekit.yaml
    restart: unless-stopped
    volumes:
      - $WORK_DIR/livekit.yaml:/etc/livekit.yaml
      - $CERT_DEST_DIR:$CERT_DEST_DIR:ro
  jwt-auth:
    image: ghcr.io/element-hq/lk-jwt-service:latest
    container_name: jwt-auth
    restart: always
    environment:
      - LK_JWT_PORT=8080
      - LIVEKIT_URL=https://livekit.$ROOT_DOMAIN/livekit/sfu
      - LIVEKIT_KEY=$LIVEKIT_APIKEY
      - LIVEKIT_SECRET=$LIVEKIT_APISECRET
      - LIVEKIT_FULL_ACCESS_HOMESERVERS=$SYNAPSE_DNS
  nginx:
    image: nginx:latest
    container_name: nginx
    restart: always
    ports:
      - "80:80"
      - "5349:5349"
    volumes:
      - $WORK_DIR/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - livekit
      - jwt-auth
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - $WORK_DIR/prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml


EOF

# Create Nginx config
cat <<EOF > $WORK_DIR/nginx.conf
# user and worker setup
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log  notice;
pid        /var/run/nginx.pid;

# required events block
events {
    worker_connections  1024;
    use epoll;                # on Linux, epoll is recommended
}

http {
    # Add resolver for DNS resolution within Docker network
    resolver 127.0.0.11 valid=30s;
    
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ''      close;
    }

    server {
        listen       80;  
        server_name  livekit.$ROOT_DOMAIN;

        location /livekit/jwt/ {
            proxy_set_header Host               \$host;
            proxy_set_header X-Real-IP          \$remote_addr;
            proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  \$scheme;
            
            proxy_pass http://jwt-auth:8080/;
        }

        location /sfu/get {
            proxy_set_header Host               \$host;
            proxy_set_header X-Real-IP          \$remote_addr;
            proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  \$scheme;

            proxy_pass http://jwt-auth:8080/sfu/get;
        }

        location /healthz {
            proxy_set_header Host               \$host;
            proxy_set_header X-Real-IP          \$remote_addr;
            proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  \$scheme;
            proxy_set_header X-Forwarded-Host   \$host;

            proxy_pass http://jwt-auth:8080/healthz;
        }

        location /livekit/sfu/ {
            proxy_set_header Host               \$host;
            proxy_set_header X-Real-IP          \$remote_addr;
            proxy_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto  \$scheme;

            proxy_set_header Upgrade            \$http_upgrade;
            proxy_set_header Connection         \$connection_upgrade;
            proxy_buffering off;
            
            proxy_pass http://livekit:7880/;
        }
    }
}
stream {
    # Add resolver for DNS resolution in stream context
    resolver 127.0.0.11 valid=30s;
    
    map \$ssl_preread_server_name \$turn_upstream {
        livekit-turn.$ROOT_DOMAIN     livekit:5349;
        default                       livekit:7880;
    }

    server {
        listen        5349;
        proxy_pass    \$turn_upstream;
        ssl_preread   on;  # peek at SNI, don't decrypt
    }
}


EOF

# Create Prometheus job definition
cat <<EOF > $WORK_DIR/prometheus/prometheus.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'livekit'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['livekit:6789']


EOF

# systemd file
cat << EOF > /etc/systemd/system/livekit-docker.service
[Unit]
Description=LiveKit Server Container
After=docker.service
Requires=docker.service

[Service]
LimitNOFILE=500000
Restart=always
WorkingDirectory=/opt/livekit
# Shutdown container (if running) when unit is started
ExecStartPre=/usr/local/bin/docker-compose -f docker-compose.yaml down
ExecStart=/usr/local/bin/docker-compose -f docker-compose.yaml up
ExecStop=/usr/local/bin/docker-compose -f docker-compose.yaml down

[Install]
WantedBy=multi-user.target


EOF

systemctl enable livekit-docker
systemctl start livekit-docker
