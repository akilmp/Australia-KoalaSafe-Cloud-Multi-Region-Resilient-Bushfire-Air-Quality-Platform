import json
import os
import uuid
import boto3

dynamodb = boto3.resource('dynamodb')


def subscribeFn(event, context):
    """Store alert subscription for the authenticated user."""
    table = dynamodb.Table(os.environ['ALERTS_TABLE'])
    user_id = event['requestContext']['authorizer']['claims']['sub']
    body = json.loads(event.get('body') or '{}')
    alert_id = str(uuid.uuid4())
    item = {
        'id': alert_id,
        'user_id': user_id,
        'params': body
    }
    table.put_item(Item=item)
    return {
        'statusCode': 201,
        'body': json.dumps({'id': alert_id})
    }
