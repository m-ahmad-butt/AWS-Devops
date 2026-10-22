#!/bin/bash
set -euxo pipefail

# AL2023 typically includes AWS CLI v2; install httpd for the site
dnf install -y httpd
command -v aws >/dev/null || dnf install -y awscli-2
command -v curl >/dev/null || dnf install -y curl

BUCKET="cv-23l-3059"
PREFIX="site"
export BUCKET PREFIX WEB_ROOT=/var/www/html

install -d -m 0755 /opt/cv
cat > /opt/cv/sync-cv.sh << 'SYNC'
#!/bin/bash
set -euo pipefail

BUCKET="${BUCKET:-cv-23l-3059}"
PREFIX="${PREFIX:-site}"
WEB_ROOT="${WEB_ROOT:-/var/www/html}"
LOG_FILE="/var/log/cv-sync.log"
TOKEN_URL="http://169.254.169.254/latest/api/token"
META_URL="http://169.254.169.254/latest/meta-data/instance-id"

status="ok"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

token="$(curl -s -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" "$TOKEN_URL")"
instance_id="$(curl -s -H "X-aws-ec2-metadata-token: $token" "$META_URL")"

if ! aws s3 sync "s3://${BUCKET}/${PREFIX}/" "${WEB_ROOT}/" --exact-timestamps; then
  status="fail"
fi

if [[ -f "${WEB_ROOT}/index.html" ]]; then
  sed -i "s/{{HOSTED_ON}}/EC2 ${instance_id}/g" "${WEB_ROOT}/index.html"
fi

echo "${ts} status=${status} instance=${instance_id}" >> "$LOG_FILE"

if [[ "$status" != "ok" ]]; then
  exit 1
fi
SYNC
chmod 0755 /opt/cv/sync-cv.sh

# systemd service + timer (every 5 minutes)
cat > /etc/systemd/system/cv-sync.service << 'EOF'
[Unit]
Description=Sync CV site from S3
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
Environment=BUCKET=cv-23l-3059
Environment=PREFIX=site
Environment=WEB_ROOT=/var/www/html
ExecStart=/opt/cv/sync-cv.sh
EOF

cat > /etc/systemd/system/cv-sync.timer << 'EOF'
[Unit]
Description=Run CV S3 sync every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=cv-sync.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now httpd
systemctl enable --now cv-sync.timer
/opt/cv/sync-cv.sh || true
