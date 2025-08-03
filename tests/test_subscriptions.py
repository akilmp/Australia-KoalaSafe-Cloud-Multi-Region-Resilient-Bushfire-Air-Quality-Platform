import os
import sys
import json
from unittest.mock import MagicMock, patch
from botocore.exceptions import ClientError

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from api import subscribe, unsubscribe


def test_subscribe_stores_alert(monkeypatch=None):
    os.environ["ALERTS_TABLE"] = "alerts"
    event = {
        "requestContext": {"authorizer": {"claims": {"sub": "user1"}}},
        "body": json.dumps({"type": "fire", "fence_id": "f1"}),
    }
    mock_table = MagicMock()
    with patch.object(subscribe.dynamodb, "Table", return_value=mock_table):
        response = subscribe.subscribeFn(event, None)
    mock_table.put_item.assert_called_once_with(
        Item={
            "user_id": "user1",
            "fence_id": "f1",
            "params": {"type": "fire", "fence_id": "f1"},
        }
    )
    assert response["statusCode"] == 201
    assert json.loads(response["body"]) == {"fence_id": "f1"}


def test_unsubscribe_deletes_alert(monkeypatch=None):
    os.environ["ALERTS_TABLE"] = "alerts"
    event = {
        "requestContext": {"authorizer": {"claims": {"sub": "user1"}}},
        "pathParameters": {"fence_id": "f1"},
    }
    mock_table = MagicMock()
    with patch.object(unsubscribe.dynamodb, "Table", return_value=mock_table):
        response = unsubscribe.unsubscribeFn(event, None)
    mock_table.delete_item.assert_called_once_with(
        Key={"user_id": "user1", "fence_id": "f1"},
        ConditionExpression="attribute_exists(fence_id)",
    )
    assert response["statusCode"] == 204


def test_unsubscribe_not_found(monkeypatch=None):
    os.environ["ALERTS_TABLE"] = "alerts"
    event = {
        "requestContext": {"authorizer": {"claims": {"sub": "user1"}}},
        "pathParameters": {"fence_id": "f1"},
    }
    mock_table = MagicMock()
    error_response = {"Error": {"Code": "ConditionalCheckFailedException"}}
    mock_table.delete_item.side_effect = ClientError(error_response, "DeleteItem")
    with patch.object(unsubscribe.dynamodb, "Table", return_value=mock_table):
        response = unsubscribe.unsubscribeFn(event, None)
    assert response["statusCode"] == 404
    body = json.loads(response["body"])
    assert body["error"] == "alert not found"
