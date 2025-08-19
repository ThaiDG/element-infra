#!/bin/bash
set -e

# Interpolating by Terraform template_file data
AWS_ACCOUNT_ID="${aws_account_id}"
AWS_REGION="${aws_region}"
LOG_LEVEL="${log_level}"

# Define constants
APP_DIR="/app"

# Update and upgrade the system
apt-get update && apt-get upgrade -y

# Set up UFW rules
ufw allow 22/tcp
ufw allow http
ufw allow 5000
ufw allow 9090  # Prometheus port
# Enable UFW
ufw --force enable

# Install necessary packages
apt-get install -y \
  docker.io \
  curl \
  unzip

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
# APNs credentials
BUNDLE_ID=$(aws ssm get-parameter \
  --name "/sygnal/apns/bundle_id" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

APNS_CERT=$(aws ssm get-parameter \
  --name "/sygnal/apns/apns_cert" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

VOIP_CERT=$(aws ssm get-parameter \
  --name "/sygnal/apns/voip_cert" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

# FCM/GCM credentials
PROJECT_ID=$(aws ssm get-parameter \
  --name "/sygnal/gcm/project-id" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

FIREBASE_ADMINSDK_JSON=$(aws ssm get-parameter \
  --name "/sygnal/gcm/$PROJECT_ID-firebase-adminsdk" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

PACKAGE_NAME=$(aws ssm get-parameter \
  --name "/sygnal/gcm/package-name" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text
)

# Create app directory and switch to it
mkdir -p "$APP_DIR"
cd "$APP_DIR"

# Create sygnal volume directory
mkdir -p sygnal
# Create prometheus volume directory
mkdir -p prometheus

# Create docker-compose.yaml
cat <<EOF > docker-compose.yaml
services:
  sygnal:
    image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/element/sygnal-service:latest
    restart: always
    container_name: sygnal
    ports:
      - "5000:5000"  # Host port 5000 to container port 5000
    environment:
      - SYGNAL_CONF=/sygnal/sygnal.yaml
    volumes:
      - ./sygnal:/sygnal
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml
EOF

cat <<EOF > sygnal/$PROJECT_ID-firebase-adminsdk.json
$FIREBASE_ADMINSDK_JSON
EOF

cat <<EOF > sygnal/apns_cert.pem
$APNS_CERT
EOF

cat <<EOF > sygnal/voip_cert.pem
$VOIP_CERT
EOF

cat <<EOF > sygnal/sygnal.yaml
## Logging #
#
log:
  setup:
    version: 1
    formatters:
      normal:
        format: "%(asctime)s [%(process)d] %(levelname)-5s %(name)s %(message)s"
    handlers:
      # This handler prints to Standard Error
      #
      stderr:
        class: "logging.StreamHandler"
        formatter: "normal"
        stream: "ext://sys.stderr"

      # This handler prints to Standard Output.
      #
      stdout:
        class: "logging.StreamHandler"
        formatter: "normal"
        stream: "ext://sys.stdout"

      # This handler demonstrates logging to a text file on the filesystem.
      # You can use logrotate(8) to perform log rotation.
      #
      file:
        class: "logging.handlers.WatchedFileHandler"
        formatter: "normal"
        filename: "./sygnal.log"
    loggers:
      # sygnal.access contains the access logging lines.
      # Comment out this section if you don't want to give access logging
      # any special treatment.
      #
      sygnal.access:
        propagate: false
        handlers: ["stdout"]
        level: "INFO"

      # sygnal contains log lines from Sygnal itself.
      # You can comment out this section to fall back to the root logger.
      #
      sygnal:
        propagate: false
        handlers: ["stderr", "stdout"]
        level: "$LOG_LEVEL"

    root:
      # Specify the handler(s) to send log messages to.
      handlers: ["stderr", "stdout"]
      level: "$LOG_LEVEL"

    disable_existing_loggers: false

  access:
    x_forwarded_for: true

## HTTP Server (Matrix Push Gateway API) #
#
http:
  # Listens on all IPv4 interfaces:
  bind_addresses: ['0.0.0.0']

  # Specify the port number to listen on.
  port: 5000

## Metrics #
#
metrics:
  prometheus:
    enabled: false
    # Specify an address for the Prometheus HTTP Server to listen on.
    address: '0.0.0.0'
    port: 8000

## Pushkins/Apps #
#
apps:
  # This is an example APNs push configuration
  #
  # APNs with cert file
  $BUNDLE_ID:
    type: apns
    certfile: /sygnal/apns_cert.pem
    platform: production

  $BUNDLE_ID.voip:
    type: apns
    certfile: /sygnal/voip_cert.pem
    topic: $BUNDLE_ID
    platform: production

  # This is an example GCM/FCM push configuration.
  #
  $PACKAGE_NAME:
    type: gcm
    api_version: v1
    project_id: $PROJECT_ID
    service_account_file: /sygnal/$PROJECT_ID-firebase-adminsdk.json
    max_connections: 20
    inflight_request_limit: 512
EOF

# Create Prometheus job definition
cat <<EOF > prometheus/prometheus.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'sygnal'
    static_configs:
      - targets: ['sygnal:8000']
EOF

# Start the Sygnal service
echo "Starting Sygnal service..."
docker compose up --wait --force-recreate

echo "Sygnal service setup complete!"
