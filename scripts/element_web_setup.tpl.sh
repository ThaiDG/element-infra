#!/bin/bash
set -e

# Interpolating by Terraform template_file data
SYNAPSE_DNS="${synapse_dns}"
ELEMENT_DNS="${element_dns}"
AWS_ACCOUNT_ID="${aws_account_id}"
AWS_REGION="${aws_region}"

# Define constants
APP_DIR="/app"

# Update and upgrade the system
apt-get update && apt-get upgrade -y

# Set up UFW rules
ufw allow 22/tcp
ufw allow http
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
            - ./element/config.$ELEMENT_DNS.json:/app/config.$ELEMENT_DNS.json
            - ./element/data:/app/data
EOL

# Step 3: Create folders for element
echo "Creating folders for element..."
mkdir -p element/{config,data}

# Step 4: Create config.json
# Must investigate to create our own identity server instead of using vector.im
echo "Creating config.json..."
cat <<EOL > element/config.$ELEMENT_DNS.json
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
    "permalink_prefix": "https://$ELEMENT_DNS",
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

# Step 5: Start Element web
echo "Starting Element web..."
docker compose up --wait --force-recreate

echo "Setup complete!"
