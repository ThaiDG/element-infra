#!/bin/bash
set -e

AWS_REGION="${region}"
DOMAIN="${domain}"
S3_BUCKET_NAME="767828741221-certbot"
S3_DIR="/s3_mounted"

# ------------------------------
# 1. Install dependencies
# ------------------------------
echo "📦 Installing Certbot, NFS, and AWS CLI..."

apt-get update
apt-get install -y \
    software-properties-common \
    certbot \
    python3-certbot-dns-route53 \
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

# ─── Configure and Mount S3FS ────────────────────────────────────────────

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

# ------------------------------
# 2. Request cert via Route53 plugin
# ------------------------------
echo "🔍 Checking for existing certificate for $DOMAIN..."
CERT_PATH="$S3_DIR/certs/letsencrypt/live/$DOMAIN/fullchain.pem"

if [ -f "$CERT_PATH" ]; then
  echo "✅ Certificate already exists for $DOMAIN. Skipping registration."
else
  echo "▶️ Certificate not found — registering new certificate."

  # Define EAB credentials and retry logic
  echo "🔐 Fetching EAB credentials from SSM..."

  EAB_KID=$(aws ssm get-parameter \
    --name "/zerossl/eab_kid" \
    --with-decryption \
    --region "$AWS_REGION" \
    --query 'Parameter.Value' \
    --output text)

  EAB_HMAC_KEY=$(aws ssm get-parameter \
    --name "/zerossl/eab_hmac_key" \
    --with-decryption \
    --region "$AWS_REGION" \
    --query 'Parameter.Value' \
    --output text)

  if [ -z "$EAB_KID" ] || [ -z "$EAB_HMAC_KEY" ]; then
    echo "❌ Failed to retrieve EAB credentials from SSM."
    exit 1
  fi

  MAX_RETRIES=5
  RETRY_DELAY=60
  COUNT=0

  until certbot certonly \
    --dns-route53 \
    --server https://acme.zerossl.com/v2/DV90 \
    --eab-kid "$EAB_KID" \
    --eab-hmac-key "$EAB_HMAC_KEY" \
    -d "*.$DOMAIN" \
    --agree-tos \
    --non-interactive \
    --email thaidg@tapofthink.com \
    --config-dir "$S3_DIR/certs/letsencrypt" \
    -v; do

    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
      echo "❌ Certbot failed after $MAX_RETRIES attempts."
      exit 1
    fi

    echo "🔁 Retry #$COUNT after $RETRY_DELAY seconds..."
    sleep $RETRY_DELAY
  done

  echo "✅ Certificate successfully obtained."
fi

# ------------------------------
# 3. Setup renewal timer
# ------------------------------
echo "⏰ Setting up Certbot renewal timer..."

cat <<EOF > /usr/local/bin/check-and-renew-cert.sh
#!/bin/bash

CERT_PATH="$CERT_PATH"
THRESHOLD_SECS=$((24 * 3600 * 3))  # 3 days

echo "🔎 Checking certificate at $CERT_PATH..."

if [ ! -f "$CERT_PATH" ]; then
  echo "❌ Certificate not found at $CERT_PATH"
  exit 1
fi

if openssl x509 -checkend $THRESHOLD_SECS -noout -in "$CERT_PATH"; then
  echo "✅ Certificate is still valid for more than 3 days."
else
  echo "⏳ Certificate expires soon — renewing..."
  certbot renew \
    --dns-route53 \
    --config-dir "$S3_DIR/certs/letsencrypt" \
    --quiet
fi
EOF

chmod +x /usr/local/bin/check-and-renew-cert.sh

cat <<EOF > /etc/systemd/system/certbot-renew.service
[Unit]
Description=Renew ZeroSSL Certificates via Certbot if expiring soon

[Service]
ExecStart=/usr/local/bin/check-and-renew-cert.sh
EOF

cat <<EOF > /etc/systemd/system/certbot-renew.timer
[Unit]
Description=Run Certbot every day

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable certbot-renew.timer
systemctl start certbot-renew.timer
