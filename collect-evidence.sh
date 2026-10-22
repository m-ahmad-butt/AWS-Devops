#!/usr/bin/env bash
set -u

# Prevent Git Bash on Windows from rewriting /aws/... into a filesystem path
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <bucket-name> <ec2-address> <lambda-address>"
  exit 1
fi

BUCKET="$1"
EC2_ADDR="$2"
LAMBDA_ADDR="$3"
OUT="evidence.txt"
ROLL="23l-3059"
EC2_ROLE="cv-ec2-role-${ROLL}"
LAMBDA_ROLE="cv-lambda-role-${ROLL}"
FUNC="cv-func-${ROLL}"
REGION="${AWS_DEFAULT_REGION:-ap-south-1}"

: > "$OUT"

section() {
  local name="$1"
  shift
  {
    echo "== ${name} =="
    if ! "$@" 2>&1; then
      echo "(command failed; continuing)"
    fi
    echo
  } >> "$OUT"
}

section "caller" aws sts get-caller-identity

section "public-access" aws s3api get-public-access-block --bucket "$BUCKET"

section "versioning" aws s3api get-bucket-versioning --bucket "$BUCKET"

section "objects" aws s3 ls "s3://${BUCKET}/site/" --recursive

section "ec2-policy" aws iam get-role-policy --role-name "$EC2_ROLE" --policy-name cv-ec2-s3-policy

{
  echo "== lambda-policy =="
  if ! aws iam list-attached-role-policies --role-name "$LAMBDA_ROLE" 2>&1; then
    echo "(list-attached-role-policies failed; continuing)"
  fi
  if ! aws iam get-role-policy --role-name "$LAMBDA_ROLE" --policy-name cv-lambda-s3-policy 2>&1; then
    echo "(get-role-policy failed; continuing)"
  fi
  echo
} >> "$OUT"

SG_ID="$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=cv-sg-${ROLL}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
if [[ -n "${SG_ID}" && "${SG_ID}" != "None" ]]; then
  section "security-group" aws ec2 describe-security-groups --group-ids "$SG_ID"
else
  {
    echo "== security-group =="
    echo "(could not resolve security group; continuing)"
    echo
  } >> "$OUT"
fi

section "instance" aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=cv-ec2-${ROLL}" "Name=instance-state-name,Values=running,pending,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,Type:InstanceType,PublicIp:PublicIpAddress,IMDSv2:MetadataOptions.HttpTokens,Profile:IamInstanceProfile.Arn}' \
  --output json

{
  echo "== endpoints =="
  # Git Bash + Windows curl.exe: discard body to NUL (not /dev/null)
  discard="NUL"
  case "$(uname -s 2>/dev/null)" in
    Linux*|Darwin*) discard="/dev/null" ;;
  esac
  for label_url in "ec2|http://${EC2_ADDR}/" "ec2-css|http://${EC2_ADDR}/style.css" "ec2-pdf|http://${EC2_ADDR}/cv.pdf" \
                   "lambda|${LAMBDA_ADDR}" "lambda-css|${LAMBDA_ADDR%/}/style.css" "lambda-pdf|${LAMBDA_ADDR%/}/cv.pdf" \
                   "s3|https://${BUCKET}.s3.${REGION}.amazonaws.com/site/index.html"; do
    label="${label_url%%|*}"
    url="${label_url#*|}"
    echo "-- ${label}: ${url}"
    line="$(curl -sS -o "$discard" -w "status=%{http_code} content_type=%{content_type}" "$url" 2>/dev/null || true)"
    if [[ -z "$line" || "$line" == *"status=000"* ]]; then
      echo "(curl failed)"
    else
      echo "$line"
    fi
  done
  echo
} >> "$OUT"

section "lambda-logs" aws logs tail "/aws/lambda/${FUNC}" --since 1h --format short

section "log-retention" aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/${FUNC}" \
  --query 'logGroups[].{name:logGroupName,retention:retentionInDays}' \
  --output json

echo "DONE"
