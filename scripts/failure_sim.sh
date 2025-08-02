#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOT
Usage: $0 --alb-arn ARN --health-check-id ID --template-file FILE [--region REGION]

Simulates failure of the primary ALB by deleting it and waits for Route 53 fail-over.
After fail-over is detected, the ALB is restored using the provided CloudFormation template.

Required parameters:
  --alb-arn           ARN of the primary Application Load Balancer
  --health-check-id   ID of the Route 53 health check monitoring the ALB
  --template-file     CloudFormation template used to recreate the ALB
Optional parameters:
  --region            AWS region (default: us-east-1)
EOT
}

ALB_ARN=""
HEALTH_CHECK_ID=""
TEMPLATE_FILE=""
REGION="us-east-1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alb-arn) ALB_ARN="$2"; shift 2;;
    --health-check-id) HEALTH_CHECK_ID="$2"; shift 2;;
    --template-file) TEMPLATE_FILE="$2"; shift 2;;
    --region) REGION="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
 done

if [[ -z "$ALB_ARN" || -z "$HEALTH_CHECK_ID" || -z "$TEMPLATE_FILE" ]]; then
  usage
  exit 1
fi

echo "Disabling deletion protection for ALB..."
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn "$ALB_ARN" \
  --attributes Key=deletion_protection.enabled,Value=false \
  --region "$REGION"

echo "Deleting ALB $ALB_ARN..."
aws elbv2 delete-load-balancer \
  --load-balancer-arn "$ALB_ARN" \
  --region "$REGION"

echo "Waiting for Route 53 health check $HEALTH_CHECK_ID to report failure..."
while true; do
  STATUS=$(aws route53 get-health-check-status \
    --health-check-id "$HEALTH_CHECK_ID" \
    --query 'HealthCheckObservations[*].StatusReport.Status' \
    --output text)
  echo "Current health check statuses: $STATUS"
  if [[ "$STATUS" == *"Failure"* ]]; then
    echo "Fail-over detected."
    break
  fi
  sleep 30
 done

echo "Restoring ALB using template $TEMPLATE_FILE..."
aws cloudformation deploy \
  --stack-name primary-alb \
  --template-file "$TEMPLATE_FILE" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

NEW_ALB_ARN=$(aws cloudformation describe-stacks \
  --stack-name primary-alb \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerArn`].OutputValue' \
  --output text \
  --region "$REGION")

echo "Waiting for ALB $NEW_ALB_ARN to become active..."
aws elbv2 wait load-balancer-available \
  --load-balancer-arns "$NEW_ALB_ARN" \
  --region "$REGION"

echo "ALB restored. Failover test complete."
