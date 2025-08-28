#!/bin/bash
set -e

# Interpolating by Terraform template_file data
AWS_ACCOUNT_ID="${aws_account_id}"
AWS_REGION="${aws_region}"
MAS_DNS="${mas_dns}"
SYNAPSE_DNS="${synapse_dns}"
POSTGRES_DNS="${postgres_dns}"

# Define constants
APP_DIR="/app"
MAS_VOLUME="/app/mas"
PROMETHEUS_VOLUME="/app/prometheus"

# Update and upgrade the system
apt-get update && apt-get upgrade -y

# Set up UFW rules
ufw allow 22/tcp
ufw allow 5000/tcp
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

# Create app directory and switch to it
mkdir -p "$APP_DIR"
cd "$APP_DIR"

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

MAS_POSTGRES_USER=$(fetch_ssm_param "/mas/postgres/user")
MAS_POSTGRES_PASSWORD=$(fetch_ssm_param "/mas/postgres/password")
MAS_POSTGRES_DATABASE=$(fetch_ssm_param "/mas/postgres/database")
# Signing secrets
MAS_ENCRYPTION=$(fetch_ssm_param "/mas/encryption")
MAS_RSA_KID=$(fetch_ssm_param "/mas/rsa/kid")
MAS_RSA_SECRET=$(fetch_ssm_param "/mas/rsa/secret")
MAS_PRIME256V1_KID=$(fetch_ssm_param "/mas/prime256v1/kid")
MAS_PRIME256V1_SECRET=$(fetch_ssm_param "/mas/prime256v1/secret")
MAS_SECP384R1_KID=$(fetch_ssm_param "/mas/secp384r1/kid")
MAS_SECP384R1_SECRET=$(fetch_ssm_param "/mas/secp384r1/secret")
MAS_SECP256K1_KID=$(fetch_ssm_param "/mas/secp256k1/kid")
MAS_SECP256K1_SECRET=$(fetch_ssm_param "/mas/secp256k1/secret")
# Client secrets
MAS_CLIENT_ID=$(fetch_ssm_param "/mas/client/id")
MAS_CLIENT_SECRET=$(fetch_ssm_param "/mas/client/secret")
MAS_MATRIX_SECRET=$(fetch_ssm_param "/mas/matrix/secret")
RECAPTCHA_PUBLIC_KEY=$(fetch_ssm_param "/synapse/reCAPTCHA/public_key")
RECAPTCHA_PRIVATE_KEY=$(fetch_ssm_param "/synapse/reCAPTCHA/private_key")

# Create docker-compose.yaml
cat <<EOF > docker-compose.yaml
services:
  mas:
    image: ghcr.io/element-hq/matrix-authentication-service:latest
    container_name: mas
    restart: always
    environment:
      - MAS_CONFIG=/app/config/config.yaml
    ports:
      - "8080:8080"
      - "8081:8081"
    volumes:
      - $MAS_VOLUME:/app/assets
      - $MAS_VOLUME/config.yaml:/app/config/config.yaml:ro

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: always
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yaml:/etc/prometheus/prometheus.yaml
EOF

# Create MAS volume directory
mkdir -p $MAS_VOLUME/assets

# Create MAS config file
cat <<EOF > $MAS_VOLUME/config.yaml
http:
  listeners:
    - name: web
      # List of resources to serve
      resources:
        # Serves the .well-known/openid-configuration document
        - name: discovery
        # Serves the human-facing pages, such as the login page
        - name: human
        # Serves the OAuth 2.0/OIDC endpoints
        - name: oauth
        # Serves the Matrix C-S API compatibility endpoints
        - name: compat
        # Serve the GraphQL API used by the frontend,
        # and optionally the GraphQL playground
        - name: graphql
          playground: true
        # Serve the given folder on the /assets/ path
        - name: assets
          path: /app/assets/
      binds:
        - host: localhost
          port: 8080
      proxy_protocol: false
    - name: internal
      resources:
        - name: health
      binds:
        - host: localhost
          port: 8081
      proxy_protocol: false
    - name: prometheus
      resources:
        - name: prometheus
      binds:
        - host: localhost
          port: 8000
      proxy_protocol: false
  trusted_proxies:
    - 192.168.0.0/16
    - 172.16.0.0/12
    - 10.0.0.0/10
    - 127.0.0.1/8
    - fd00::/8
    - ::1/128
  public_base: https://$MAS_DNS/
  issuer: https://$MAS_DNS/
database:
  host: $POSTGRES_DNS
  port: 5432
  username: $MAS_POSTGRES_USER
  password: $MAS_POSTGRES_PASSWORD
  database: $MAS_POSTGRES_DATABASE
  max_connections: 10
  min_connections: 0
  connect_timeout: 30
  idle_timeout: 600
  max_lifetime: 1800
secrets:
  # Encryption secret (used for encrypting cookies and database fields)
  # This must be a 32-byte long hex-encoded key
  encryption: $MAS_ENCRYPTION

  # Signing keys
  keys:
    # RSA
    - kid: $MAS_RSA_KID
      key: $MAS_RSA_SECRET
    # ECDSA with the P-256 (prime256v1) curve
    - kid: $MAS_PRIME256V1_KID
      key: $MAS_PRIME256V1_SECRET
    # ECDSA with the P-384 (secp384r1) curve
    - kid: $MAS_SECP384R1_KID
      key: $MAS_SECP384R1_SECRET
    # ECDSA with the K-256 (secp256k1) curve
    - kid: $MAS_SECP256K1_KID
      key: $MAS_SECP256K1_SECRET
passwords:
  enabled: true
  schemes:
  - version: 1
    algorithm: bcrypt
    unicode_normalization: true
  - version: 2
    algorithm: argon2id
  minimum_complexity: 3
account:
  # Whether users are allowed to change their email addresses.
  #
  # Defaults to true.
  email_change_allowed: true

  # Whether users are allowed to change their display names
  #
  # Defaults to true.
  # This should be in sync with the policy in the homeserver configuration.
  displayname_change_allowed: true

  # Whether to enable self-service password registration
  #
  # Defaults to false.
  # This has no effect if password login is disabled.
  password_registration_enabled: false

  # Whether users are allowed to change their passwords
  #
  # Defaults to true.
  # This has no effect if password login is disabled.
  password_change_allowed: true

  # Whether email-based password recovery is enabled
  #
  # Defaults to false.
  # This has no effect if password login is disabled.
  password_recovery_enabled: false

  # Whether users are allowed to delete their own account
  #
  # Defaults to true.
  account_deactivation_allowed: true

  # Whether users can log in with their email address.
  #
  # Defaults to false.
  # This has no effect if password login is disabled.
  login_with_email_allowed: false

  # Whether registration tokens are required for password registrations.
  #
  # Defaults to false.
  #
  # When enabled, users must provide a valid registration token during password
  # registration. This has no effect if password registration is disabled.
  registration_token_required: false
matrix:
  kind: synapse
  homeserver: $SYNAPSE_DNS
  secret: $MAS_MATRIX_SECRET
  endpoint: https://$SYNAPSE_DNS
clients:
  - client_id: $MAS_CLIENT_ID
    client_auth_method: client_secret_basic
    client_secret: "$MAS_CLIENT_SECRET"
policy:
  # Path to the WASM module
  wasm_module: /usr/local/share/mas-cli/policy.wasm

  # Entrypoint to use when evaluating client registrations
  client_registration_entrypoint: client_registration/violation

  # Entrypoint to use when evaluating user registrations
  register_entrypoint: register/violation

  # Entrypoint to use when evaluating authorization grants
  authorization_grant_entrypoint: authorization_grant/violation

  # Entrypoint to use when changing password
  password_entrypoint: password/violation

  # Entrypoint to use when adding an email address
  email_entrypoint: email/violation

  # This data is being passed to the policy
  data:
    # Users which are allowed to ask for admin access. If possible, use the
    # can_request_admin flag on users instead.
    admin_users:
      - thaidg

    # Client IDs which are allowed to ask for admin access with a
    # client_credentials grant
    admin_clients:
      - $MAS_CLIENT_ID

    # Dynamic Client Registration
    client_registration:
      # don't require URIs to be on the same host. default: false
      allow_host_mismatch: false
      # allow non-SSL and localhost URIs. default: false
      allow_insecure_uris: false
      # don't require clients to provide a client_uri. default: false
      allow_missing_client_uri: false

    # Restrictions on user registration
    registration:
      # If specified, the username (localpart) *must* match one of the allowed
      # usernames. If unspecified, all usernames are allowed.
      allowed_usernames:
        # Regular expressions that match allowed usernames
        regexes: ["^[a-z]+$"]
      # If specified, the username (localpart) *must not* match one of the
      # banned usernames. If unspecified, all usernames are allowed.
      banned_usernames:
        # Exact usernames that are banned
        literals: ["admin", "root"]
        # Substrings that match banned usernames
        substrings: ["admin", "root"]
        # Regular expressions that match banned usernames
        regexes: ["^admin$", "^root$"]
        # Prefixes that match banned usernames
        prefixes: ["admin-", "root-"]
        # Suffixes that match banned usernames
        suffixes: ["-admin", "-root"]

    # Restrict what email addresses can be added to a user
    # emails:
      # If specified, the email address *must* match one of the allowed addresses.
      # If unspecified, all email addresses are allowed.
      # allowed_addresses:
      #   # Exact emails that are allowed
      #   literals: ["alice@example.com", "bob@example.com"]
      #   # Regular expressions that match allowed emails
      #   regexes: ["@example\\.com$"]
      #   # Suffixes that match allowed emails
      #   suffixes: ["@example.com"]

      # If specified, the email address *must not* match one of the banned addresses.
      # If unspecified, all email addresses are allowed.
      # banned_addresses:
      #   # Exact emails that are banned
      #   literals: ["alice@evil.corp", "bob@evil.corp"]
      #   # Emails that contains those substrings are banned
      #   substrings: ["evil"]
      #   # Regular expressions that match banned emails
      #   regexes: ["@evil\\.corp$"]
      #   # Suffixes that match banned emails
      #   suffixes: ["@evil.corp"]
      #   # Prefixes that match banned emails
      #   prefixes: ["alice@"]

    requester:
      # List of IP addresses and CIDRs that are not allowed to register
      banned_ips:
        - 192.168.0.1
        - 192.168.1.0/24
        - fe80::/64
telemetry:
  tracing:
    # The default: don't export traces
    exporter: none
  metrics:
    # Export metrics by exposing a Prometheus endpoint
    # This requires mounting the prometheus resource to an HTTP listener
    exporter: prometheus
captcha:
    # Which service to use for CAPTCHA protection. Set to null (or ~) to disable CAPTCHA protection
    # Use Google reCAPTCHA v2
    service: recaptcha_v2
    site_key: "$RECAPTCHA_PUBLIC_KEY"
    secret_key: "$RECAPTCHA_PRIVATE_KEY"
EOF

# Create prometheus volume directory
mkdir -p $PROMETHEUS_VOLUME

# Create Prometheus job definition
cat <<EOF > $PROMETHEUS_VOLUME/prometheus.yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'mas'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['mas:8000']
EOF

# Start services
echo "Starting MAS and related services..."
docker compose up --wait --force-recreate
# Sync the config
# Runs the authentication service
docker exec -it mas mas-cli server --config=$MAS_VOLUME/config.yaml

echo "MAS server setup completed successfully."

