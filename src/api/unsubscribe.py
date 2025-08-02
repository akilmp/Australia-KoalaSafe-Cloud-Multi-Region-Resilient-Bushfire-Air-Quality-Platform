import json
import os
import boto3
from botocore.exceptions import ClientError


dynamodb = boto3.resource('dynamodb')


def unsubscribeFn(event, context):
    """Remove alert subscription belonging to the authenticated user."""
    table = dynamodb.Table(os.environ['ALERTS_TABLE'])
    user_id = event['requestContext']['authorizer']['claims']['sub']
    alert_id = event['pathParameters']['id']
    try:
        table.delete_item(
            Key={'id': alert_id},
            ConditionExpression='user_id = :u',
            ExpressionAttributeValues={':u': user_id}
        )
    except ClientError as exc:
        if exc.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return {'statusCode': 404, 'body': json.dumps({'error': 'alert not found'})}
        raise
    return {'statusCode': 204, 'body': ''}
