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
