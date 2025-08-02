import json
import os
import boto3

s3 = boto3.client('s3')

def geojsonProxyFn(event, context):
    """Return latest GeoJSON object from S3."""
    bucket = os.environ.get("GEOJSON_BUCKET")
    key = os.environ.get("GEOJSON_KEY", "latest.geojson")
    if not bucket:
        return {"statusCode": 500, "body": json.dumps({"error": "GEOJSON_BUCKET not set"})}

    obj = s3.get_object(Bucket=bucket, Key=key)
    data = obj["Body"].read().decode("utf-8")
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": data,
    }
