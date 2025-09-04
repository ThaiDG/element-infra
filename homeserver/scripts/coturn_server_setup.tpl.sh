#!/bin/bash
set -e

# Interpolation of variables from Terraform
TCP_NLB_DNS="${tcp_nlb_dns}"
UDP_NLB_DNS="${udp_nlb_dns}"
AWS_REGION="${region}"
DOMAIN="${root_domain}"

# Constants
S3_BUCKET_NAME="767828741221-certbot"
S3_DIR="/s3_mounted"
CERT_SRC_DIR="$S3_DIR/certs/letsencrypt/live/$DOMAIN"
CERT_DEST_DIR="/etc/coturn/certs"
CONFIG_FILE="/etc/turnserver.conf"
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Update and upgrade the system
apt-get update && apt-get upgrade -y

# 1. Install Coturn and NFS client
apt-get update && apt-get install -y coturn docker.io unzip curl s3fs

# Install AWS CLI if not already installed
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
COTURN_SECRET=$(aws ssm get-parameter \
  --name "/coturn/secret" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

# 2. Enable Coturn service
sed -i 's/^#TURNSERVER_ENABLED=1$/TURNSERVER_ENABLED=1/' /etc/default/coturn

# 3. ─── Configure and Mount S3FS ────────────────────────────────────────────

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
# ──────────────────────────────────────────────────────────────────────────

# 4. Copy and secure certs
# Ensure destination directory exists
mkdir -p "$CERT_DEST_DIR"
# Copy latest symlinked certificate files
echo "🔍 Copying certificates from $CERT_SRC_DIR to $CERT_DEST_DIR"
cp "$CERT_SRC_DIR/fullchain.pem" "$CERT_DEST_DIR/fullchain.pem"
cp "$CERT_SRC_DIR/privkey.pem" "$CERT_DEST_DIR/privkey.pem"
# Set ownership and strict permissions
chown turnserver:turnserver "$CERT_DEST_DIR"/*.pem
chmod 400 "$CERT_DEST_DIR"/*.pem
echo "✅ Certificates copied and secured."

# 5. Write Coturn config
tee "$CONFIG_FILE" > /dev/null <<EOF
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
min-port=49152
max-port=65535
fingerprint
use-auth-secret
static-auth-secret=$COTURN_SECRET
prometheus
realm=$DOMAIN
no-tcp-relay
# consider whether you want to limit the quota of relayed streams per user (or total) to avoid risk of DoS.
user-quota=12 # 4 streams per video call, so 12 streams = 3 simultaneous relayed calls per user.
total-quota=1200
stale-nonce
cert=$CERT_DEST_DIR/fullchain.pem
pkey=$CERT_DEST_DIR/privkey.pem
no-stdout-log
syslog
simple-log
# don't let the relay ever try to connect to private IP address ranges within your network (if any)
# given the turn server is likely behind your firewall, remember to include any privileged public IPs too.
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=172.16.0.0-172.31.255.255

# recommended additional local peers to block, to mitigate external access to internal services.
# https://www.rtcsec.com/article/slack-webrtc-turn-compromise-and-bug-bounty/#how-to-fix-an-open-turn-relay-to-address-this-vulnerability
no-multicast-peers
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.0.2.0-192.0.2.255
denied-peer-ip=192.88.99.0-192.88.99.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=198.51.100.0-198.51.100.255
denied-peer-ip=203.0.113.0-203.0.113.255
denied-peer-ip=240.0.0.0-255.255.255.255
allowed-peer-ip=$PRIVATE_IP
cli-ip=127.0.0.1
cli-port=5766
cli-password=qwerty
no-rfc5780
no-stun-backward-compatibility
response-origin-only-with-rfc5780
external-ip=$TCP_NLB_DNS/$UDP_NLB_DNS
relay-ip=$PRIVATE_IP
EOF

# 6. Restart Coturn
systemctl restart coturn

# 7. Confirm it's running
journalctl -u coturn -n 20 --no-pager

# Setup for Prometheus monitoring
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


# Define constants
APP_DIR="/app"

# Create app directory and switch to it
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create docker-compose.yaml
cat <<'EOF' > docker-compose.yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml
EOF

# Create prometheus volume directory
mkdir -p prometheus

# Create Prometheus job definition
cat <<EOF > prometheus/prometheus.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'coturn'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['localhost:9641']
EOF

# Start services
echo "Starting Synapse and Postgres services..."
docker compose up --wait --force-recreate

echo "CoTURN server setup completed successfully."
