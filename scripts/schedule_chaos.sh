#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <cluster-name> <service-name>" >&2
  echo "Environment variables: REGION, ACCOUNT_ID, AUTOMATION_ROLE_ARN" >&2
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

CLUSTER="$1"
SERVICE="$2"
REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:?ACCOUNT_ID env var required}"
ROLE_ARN="${AUTOMATION_ROLE_ARN:?AUTOMATION_ROLE_ARN env var required}"
DOC_NAME="ECSChaosExperiment"
DOC_FILE="$(dirname "$0")/ecs_chaos_automation.yaml"

printf 'Publishing automation document %s...\n' "$DOC_NAME"
aws ssm delete-document --name "$DOC_NAME" --region "$REGION" >/dev/null 2>&1 || true
aws ssm create-document \
  --name "$DOC_NAME" \
  --document-type Automation \
  --content file://"$DOC_FILE" \
  --region "$REGION" >/dev/null

printf 'Scheduling weekly chaos experiment...\n'
aws events put-rule \
  --name "${DOC_NAME}Weekly" \
  --schedule-expression 'cron(0 3 ? * MON-FRI *)' \
  --region "$REGION" >/dev/null

aws events put-targets \
  --rule "${DOC_NAME}Weekly" \
  --targets "Id"="1","Arn"="arn:aws:ssm:${REGION}:${ACCOUNT_ID}:automation-definition/${DOC_NAME}","RoleArn"="${ROLE_ARN}","Input"="{\"ClusterName\":\"${CLUSTER}\",\"ServiceName\":\"${SERVICE}\"}" \
  --region "$REGION" >/dev/null

printf 'Chaos schedule created.\n'
