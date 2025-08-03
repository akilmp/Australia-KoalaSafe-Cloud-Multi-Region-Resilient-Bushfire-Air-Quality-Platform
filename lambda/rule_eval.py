import json
import boto3
from opentelemetry.instrumentation.aws_lambda import AwsLambdaInstrumentor

AwsLambdaInstrumentor().instrument()

eventbridge = boto3.client('events')

def lambda_handler(event, context):
    entries = []
    for record in event.get('Records', []):
        if record.get('eventName') not in ('INSERT', 'MODIFY'):
            continue
        new_image = record['dynamodb'].get('NewImage', {})
        intersects = new_image.get('intersects', {}).get('BOOL', False)
        if not intersects:
            continue
        region = new_image.get('region', {}).get('S', 'unknown')
        fence_id = new_image.get('fence_id', {}).get('S', '')
        entries.append({
            'Source': 'koalasafe.rule_eval',
            'DetailType': 'FenceIntersection',
            'Detail': json.dumps({'fence_id': fence_id, 'region': region}),
        })
    if entries:
        eventbridge.put_events(Entries=entries)
    return {'events_published': len(entries)}
