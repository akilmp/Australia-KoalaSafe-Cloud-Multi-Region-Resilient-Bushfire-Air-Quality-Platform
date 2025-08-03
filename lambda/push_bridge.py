import json
import os
import urllib.request

import boto3
from opentelemetry.instrumentation.aws_lambda import AwsLambdaInstrumentor

AwsLambdaInstrumentor().instrument()

EXPO_URL = "https://exp.host/--/api/v2/push/send"


def _get_token() -> str | None:
    token = os.environ.get("EXPO_TOKEN")
    if token:
        return token
    secret_arn = os.environ.get("EXPO_TOKEN_SECRET_ARN")
    if secret_arn:
        sm = boto3.client("secretsmanager")
        resp = sm.get_secret_value(SecretId=secret_arn)
        return resp.get("SecretString")
    return None


def lambda_handler(event, context):
    detail = event.get('detail', {})
    message = {
        'to': detail.get('device_token'),
        'title': 'Bushfire Alert',
        'body': f"Fire intersected fence {detail.get('fence_id')}",
        'data': detail,
    }
    data = json.dumps(message).encode('utf-8')
    headers = {'Content-Type': 'application/json'}
    token = _get_token()
    if token:
        headers['Authorization'] = f'Bearer {token}'
    request = urllib.request.Request(EXPO_URL, data=data, headers=headers)
    with urllib.request.urlopen(request) as resp:
        resp.read()
    return {'status': 'sent'}
