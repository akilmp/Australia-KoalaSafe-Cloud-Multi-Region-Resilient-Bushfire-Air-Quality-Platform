import json
import os
import tempfile

import boto3
import fiona
from shapely.geometry import shape, mapping
from shapely.ops import unary_union


def collect_firehose_geometries(s3_client, bucket: str, prefix: str):
    """Load GeoJSON features from Firehose-delivered objects."""
    geometries = []
    resp = s3_client.list_objects_v2(Bucket=bucket, Prefix=prefix)
    for obj in resp.get("Contents", []):
        body = s3_client.get_object(Bucket=bucket, Key=obj["Key"])['Body'].read()
        data = json.loads(body)
        for feature in data.get("features", []):
            geometries.append(shape(feature["geometry"]))
    return geometries


def main():
    firehose_bucket = os.environ.get("FIREHOSE_BUCKET")
    firehose_prefix = os.environ.get("FIREHOSE_PREFIX", "")
    output_bucket = os.environ.get("OUTPUT_BUCKET")
    output_key = os.environ.get("OUTPUT_KEY", "fire_perimeters.geojson")

    if not firehose_bucket or not output_bucket:
        raise RuntimeError("FIREHOSE_BUCKET and OUTPUT_BUCKET must be set")

    s3 = boto3.client("s3")

    geometries = collect_firehose_geometries(s3, firehose_bucket, firehose_prefix)
    if not geometries:
        print("No fire perimeter features found")
        return

    union_geom = unary_union(geometries)

    schema = {"geometry": union_geom.geom_type, "properties": {}}

    with tempfile.NamedTemporaryFile(suffix=".geojson", delete=False) as tmp:
        with fiona.open(tmp.name, "w", driver="GeoJSON", schema=schema) as dst:
            dst.write({"geometry": mapping(union_geom), "properties": {}})
        s3.upload_file(tmp.name, output_bucket, output_key)
        print(f"Uploaded merged perimeters to s3://{output_bucket}/{output_key}")


if __name__ == "__main__":
    main()
