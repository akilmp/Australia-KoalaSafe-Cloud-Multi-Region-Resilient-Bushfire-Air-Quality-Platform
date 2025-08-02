import os
import json
from typing import List, Dict, Any

import requests
import boto3

FIREHOSE_STREAM_NAME = os.environ.get("FIREHOSE_STREAM_NAME", "bushfire_raw")

firehose = boto3.client("firehose", region_name=os.environ.get("AWS_REGION", "us-east-1"))

NSW_RFS_URL = "https://www.rfs.nsw.gov.au/feeds/majorIncidents.json"
NASA_FIRMS_URL = (
    "https://firms.modaps.eosdis.nasa.gov/active_fire/c6/geojson/MODIS_C6_Australia_NewZealand_24h.geojson"
)
NSW_EPN_URL = "https://data.airquality.nsw.gov.au/api/Data/Hourly/Average"

def fetch_json(url: str) -> Dict[str, Any]:
    """Fetch JSON data from a URL."""
    resp = requests.get(url, timeout=10)
    resp.raise_for_status()
    return resp.json()

def normalize_nsw_rfs(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Normalize NSW RFS major incident feed."""
    features = data.get("features", [])
    normalized = []
    for feat in features:
        prop = feat.get("properties", {})
        geom = feat.get("geometry", {})
        coords = geom.get("coordinates", [None, None])
        normalized.append(
            {
                "source": "nsw_rfs",
                "id": prop.get("id") or prop.get("objectid"),
                "latitude": coords[1],
                "longitude": coords[0],
                "timestamp": prop.get("updated") or prop.get("pubdate"),
                "raw": prop,
            }
        )
    return normalized

def normalize_nasa_firms(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Normalize NASA FIRMS feed."""
    features = data.get("features", [])
    normalized = []
    for feat in features:
        prop = feat.get("properties", {})
        geom = feat.get("geometry", {})
        coords = geom.get("coordinates", [None, None])
        acq_date = prop.get("acq_date")
        acq_time = prop.get("acq_time")
        ts = None
        if acq_date and acq_time:
            ts = f"{acq_date}T{acq_time}Z"
        normalized.append(
            {
                "source": "nasa_firms",
                "id": prop.get("id") or prop.get("fid"),
                "latitude": coords[1],
                "longitude": coords[0],
                "timestamp": ts,
                "raw": prop,
            }
        )
    return normalized

def normalize_nsw_epn(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Normalize NSW Environmental Protection data feed."""
    records = data.get("records", []) or data.get("data", [])
    normalized = []
    for rec in records:
        normalized.append(
            {
                "source": "nsw_epn",
                "id": rec.get("Site") or rec.get("station"),
                "latitude": rec.get("Latitude") or rec.get("lat"),
                "longitude": rec.get("Longitude") or rec.get("lon"),
                "timestamp": rec.get("Date") or rec.get("timestamp"),
                "raw": rec,
            }
        )
    return normalized

def send_to_firehose(records: List[Dict[str, Any]]) -> int:
    """Send records to Kinesis Firehose."""
    if not records:
        return 0

    def chunk(lst: List[Dict[str, Any]], size: int):
        for i in range(0, len(lst), size):
            yield lst[i : i + size]

    sent = 0
    for batch in chunk(records, 500):
        response = firehose.put_record_batch(
            DeliveryStreamName=FIREHOSE_STREAM_NAME,
            Records=[{"Data": json.dumps(rec) + "\n"} for rec in batch],
        )
        failures = response.get("FailedPutCount", 0)
        sent += len(batch) - failures
    return sent

def handler(event, context):
    nsw_rfs_data = fetch_json(NSW_RFS_URL)
    nasa_firms_data = fetch_json(NASA_FIRMS_URL)
    nsw_epn_data = fetch_json(NSW_EPN_URL)

    records = (
        normalize_nsw_rfs(nsw_rfs_data)
        + normalize_nasa_firms(nasa_firms_data)
        + normalize_nsw_epn(nsw_epn_data)
    )

    send_to_firehose(records)
    return {"records": len(records)}
