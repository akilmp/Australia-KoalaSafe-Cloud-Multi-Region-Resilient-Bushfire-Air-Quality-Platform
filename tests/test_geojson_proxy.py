import os
import sys
import json
import io
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from api import geojson_proxy


def test_geojson_proxy_no_bucket(monkeypatch=None):
    os.environ.pop("GEOJSON_BUCKET", None)
    response = geojson_proxy.geojsonProxyFn({}, None)
    assert response["statusCode"] == 500
    body = json.loads(response["body"])
    assert body["error"] == "GEOJSON_BUCKET not set"


def test_geojson_proxy_success(monkeypatch=None):
    os.environ["GEOJSON_BUCKET"] = "my-bucket"
    os.environ["GEOJSON_KEY"] = "data.geojson"
    sample = {"type": "FeatureCollection"}
    mock_body = io.BytesIO(json.dumps(sample).encode("utf-8"))
    with patch.object(geojson_proxy.s3, "get_object", return_value={"Body": mock_body}) as mock_get:
        response = geojson_proxy.geojsonProxyFn({}, None)
    mock_get.assert_called_once_with(Bucket="my-bucket", Key="data.geojson")
    assert response["statusCode"] == 200
    assert json.loads(response["body"]) == sample
