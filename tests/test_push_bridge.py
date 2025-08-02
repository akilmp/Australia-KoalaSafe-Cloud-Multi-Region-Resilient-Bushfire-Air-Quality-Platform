import os
import sys
import importlib
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

push_bridge = importlib.import_module("lambda.push_bridge")


def _mock_urlopen():
    mock = MagicMock()
    mock.__enter__.return_value.read.return_value = b""
    mock.__exit__.return_value = False
    return mock


def test_push_bridge_with_token():
    os.environ["EXPO_TOKEN"] = "token123"
    try:
        with patch("urllib.request.urlopen", return_value=_mock_urlopen()) as mock_open:
            event = {"detail": {"device_token": "d1", "fence_id": "f1"}}
            result = push_bridge.lambda_handler(event, None)
        request = mock_open.call_args[0][0]
        assert request.headers["Authorization"] == "Bearer token123"
        assert result == {"status": "sent"}
    finally:
        del os.environ["EXPO_TOKEN"]


def test_push_bridge_without_token():
    if "EXPO_TOKEN" in os.environ:
        del os.environ["EXPO_TOKEN"]
    if "EXPO_TOKEN_SECRET_ARN" in os.environ:
        del os.environ["EXPO_TOKEN_SECRET_ARN"]
    with patch("urllib.request.urlopen", return_value=_mock_urlopen()) as mock_open:
        event = {"detail": {"device_token": "d1", "fence_id": "f1"}}
        result = push_bridge.lambda_handler(event, None)
    request = mock_open.call_args[0][0]
    assert "Authorization" not in request.headers
    assert result == {"status": "sent"}


def test_push_bridge_with_secret():
    os.environ["EXPO_TOKEN_SECRET_ARN"] = "arn:expo"
    mock_client = MagicMock()
    mock_client.get_secret_value.return_value = {"SecretString": "secretXYZ"}
    try:
        with patch("boto3.client", return_value=mock_client):
            with patch("urllib.request.urlopen", return_value=_mock_urlopen()) as mock_open:
                event = {"detail": {"device_token": "d1", "fence_id": "f1"}}
                result = push_bridge.lambda_handler(event, None)
        request = mock_open.call_args[0][0]
        assert request.headers["Authorization"] == "Bearer secretXYZ"
        assert result == {"status": "sent"}
    finally:
        del os.environ["EXPO_TOKEN_SECRET_ARN"]
