import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from ingest_lambda.handlers import (
    normalize_nsw_rfs,
    normalize_nasa_firms,
    normalize_nsw_epn,
)


def test_normalize_nsw_rfs():
    sample = {
        "features": [
            {
                "properties": {"id": "1", "updated": "2024-04-22T10:00:00Z"},
                "geometry": {"coordinates": [150.0, -33.0]},
            }
        ]
    }
    result = normalize_nsw_rfs(sample)
    assert result == [
        {
            "source": "nsw_rfs",
            "id": "1",
            "latitude": -33.0,
            "longitude": 150.0,
            "timestamp": "2024-04-22T10:00:00Z",
            "raw": {"id": "1", "updated": "2024-04-22T10:00:00Z"},
        }
    ]


def test_normalize_nasa_firms():
    sample = {
        "features": [
            {
                "properties": {"fid": "abc", "acq_date": "2024-04-22", "acq_time": "0830"},
                "geometry": {"coordinates": [151.0, -32.0]},
            }
        ]
    }
    result = normalize_nasa_firms(sample)
    assert result == [
        {
            "source": "nasa_firms",
            "id": "abc",
            "latitude": -32.0,
            "longitude": 151.0,
            "timestamp": "2024-04-22T0830Z",
            "raw": {"fid": "abc", "acq_date": "2024-04-22", "acq_time": "0830"},
        }
    ]


def test_normalize_nsw_epn():
    sample = {
        "records": [
            {
                "Site": "Sydney",
                "Latitude": -33.86,
                "Longitude": 151.2,
                "Date": "2024-04-22T00:00:00Z",
            }
        ]
    }
    result = normalize_nsw_epn(sample)
    assert result == [
        {
            "source": "nsw_epn",
            "id": "Sydney",
            "latitude": -33.86,
            "longitude": 151.2,
            "timestamp": "2024-04-22T00:00:00Z",
            "raw": {
                "Site": "Sydney",
                "Latitude": -33.86,
                "Longitude": 151.2,
                "Date": "2024-04-22T00:00:00Z",
            },
        }
    ]
