#!/bin/bash
set -e

# Interpolating by Terraform template_file data
SYNAPSE_DNS="${synapse_dns}"
TAPYOUSH_DNS="${tapyoush_dns}"
YOUSHTAP_DNS="${youshtap_dns}"
AWS_ACCOUNT_ID="${aws_account_id}"
AWS_REGION="${aws_region}"

# Define constants
APP_DIR="/app"

# Update and upgrade the system
apt-get update && apt-get upgrade -y

# Set up UFW rules
ufw allow 22/tcp
ufw allow http
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

# Step 1: Create the app folder
echo "Creating app folder..."
mkdir -p "$APP_DIR" && cd "$APP_DIR"

# Step 2: Create docker-compose.yaml
echo "Creating docker-compose.yaml..."
cat <<EOL > docker-compose.yaml
services:
  element:
    image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/element/element-web:latest
    container_name: element-web
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./element/config.$TAPYOUSH_DNS.json:/app/config.$TAPYOUSH_DNS.json
      - ./element/config.$YOUSHTAP_DNS.json:/app/config.$YOUSHTAP_DNS.json
      - ./element/data:/app/data

  blackbox:
    image: prom/blackbox-exporter:latest
    container_name: blackbox
    volumes:
      - ./prometheus/blackbox.yaml:/etc/blackbox_exporter/config.yaml
    command:
      - '--config.file=/etc/blackbox_exporter/config.yaml'

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    depends_on:
      - blackbox
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml
EOL

# Step 3: Create folders for element
echo "Creating folders for element..."
mkdir -p element/{config,data}
# Create prometheus volume directory
mkdir -p prometheus

# Step 4: Create config.json
# Must investigate to create our own identity server instead of using vector.im
echo "Creating config.$TAPYOUSH_DNS.json..."
cat <<EOL > element/config.$TAPYOUSH_DNS.json
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "https://$SYNAPSE_DNS",
      "server_name": "$SYNAPSE_DNS"
    },
    "m.identity_server": {
      "base_url": "https://vector.im"
    }
  },
  "permalink_prefix": "https://$TAPYOUSH_DNS",
  "default_country_code": "VN",
  "brand": "TAP Media Chat",
  "room_directory": {
    "servers": [
      "$SYNAPSE_DNS"
    ]
  },
  "show_labs_settings": true,
  "features": {
    "feature_pinning": "labs"
  },
  "default_theme": "light",
  "disable_guests": true
}
EOL

echo "Creating config.$YOUSHTAP_DNS.json..."
cat <<EOL > element/config.$YOUSHTAP_DNS.json
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "https://$SYNAPSE_DNS",
      "server_name": "$SYNAPSE_DNS"
    },
    "m.identity_server": {
      "base_url": "https://vector.im"
    }
  },
  "permalink_prefix": "https://$YOUSHTAP_DNS",
  "default_country_code": "VN",
  "brand": "TAP Media Chat",
  "room_directory": {
    "servers": [
      "$SYNAPSE_DNS"
    ]
  },
  "show_labs_settings": true,
  "features": {
    "feature_pinning": "labs"
  },
  "default_theme": "light",
  "disable_guests": true
}
EOL

# Blackbox exporter configuration
cat <<EOF > prometheus/blackbox.yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      method: GET
      valid_http_versions: ["HTTP/1.1", "HTTP/2"]
      valid_status_codes: [200, 301, 302]
      follow_redirects: true
EOF

# Create Prometheus job definition
cat <<EOF > prometheus/prometheus.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://$TAPYOUSH_DNS
        - https://$YOUSHTAP_DNS
        - https://$SYNAPSE_DNS
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115
EOF

# Step 5: Start Element web
echo "Starting Element web..."
docker compose up --wait --force-recreate

echo "Setup complete!"
