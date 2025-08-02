import os
import sys
import json
import importlib
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")

rule_eval = importlib.import_module("lambda.rule_eval")


def test_rule_eval_publishes_events():
    mock_eventbridge = MagicMock()
    rule_eval.eventbridge = mock_eventbridge
    event = {
        "Records": [
            {
                "eventName": "INSERT",
                "dynamodb": {
                    "NewImage": {
                        "intersects": {"BOOL": True},
                        "region": {"S": "r1"},
                        "fence_id": {"S": "f1"},
                    }
                },
            },
            {
                "eventName": "REMOVE",
                "dynamodb": {
                    "NewImage": {"intersects": {"BOOL": True}},
                },
            },
            {
                "eventName": "MODIFY",
                "dynamodb": {
                    "NewImage": {"intersects": {"BOOL": False}},
                },
            },
        ]
    }
    result = rule_eval.lambda_handler(event, None)
    mock_eventbridge.put_events.assert_called_once()
    entries = mock_eventbridge.put_events.call_args[1]["Entries"]
    assert entries == [
        {
            "Source": "koalasafe.rule_eval",
            "DetailType": "FenceIntersection",
            "Detail": json.dumps({"fence_id": "f1", "region": "r1"}),
        }
    ]
    assert result == {"events_published": 1}


def test_rule_eval_no_events():
    mock_eventbridge = MagicMock()
    rule_eval.eventbridge = mock_eventbridge
    result = rule_eval.lambda_handler({"Records": []}, None)
    mock_eventbridge.put_events.assert_not_called()
    assert result == {"events_published": 0}
