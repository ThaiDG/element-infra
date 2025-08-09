#!/bin/bash
set -e

# Interpolation of variables from Terraform
NLB_DNS="${nlb_dns}"
EFS_ID="${efs_id}"
NFS_VERSION="${nfs_version}"
if [ -z "$NFS_VERSION" ]; then
  NFS_VERSION="4.1"
fi
AWS_REGION="${region}"
DOMAIN="${root_domain}"

# Constants
EFS_DIR="/mnt/certs"
CERT_SRC_DIR="$EFS_DIR/letsencrypt/live/$DOMAIN"
CERT_DEST_DIR="/etc/coturn/certs"
CONFIG_FILE="/etc/turnserver.conf"
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# 1. Install Coturn and NFS client
apt-get update && apt-get install -y coturn nfs-common docker.io

# 2. Enable Coturn service
sed -i 's/^#TURNSERVER_ENABLED=1$/TURNSERVER_ENABLED=1/' /etc/default/coturn

# 3. Mount EFS for certs
# Create EFS mount directory
mkdir -p "$EFS_DIR"
# Mount EFS
echo "🔗 Mounting EFS $EFS_ID to $EFS_DIR"
mount \
  -t nfs \
  -o nfsvers=$NFS_VERSION,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
  $EFS_ID.efs.$AWS_REGION.amazonaws.com:/ $EFS_DIR

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
verbose
fingerprint
lt-cred-mech
user=admin:Admin123
prometheus
realm=$DOMAIN
no-tcp-relay
cert=$CERT_DEST_DIR/fullchain.pem
pkey=$CERT_DEST_DIR/privkey.pem
no-stdout-log
syslog
simple-log
no-multicast-peers
cli-ip=127.0.0.1
cli-port=5766
cli-password=qwerty
no-rfc5780
no-stun-backward-compatibility
response-origin-only-with-rfc5780
external-ip=$NLB_DNS
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
