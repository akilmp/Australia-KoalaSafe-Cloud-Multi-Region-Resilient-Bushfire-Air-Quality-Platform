import json
import os
import urllib.request

EXPO_URL = "https://exp.host/--/api/v2/push/send"
EXPO_TOKEN = os.environ.get("EXPO_TOKEN")

def lambda_handler(event, context):
    detail = event.get('detail', {})
    message = {
        'to': detail.get('device_token'),
        'title': 'Bushfire Alert',
        'body': f"Fire intersected fence {detail.get('fence_id')}",
        'data': detail,
    }
    data = json.dumps(message).encode('utf-8')
    headers = {'Content-Type': 'application/json'}
    if EXPO_TOKEN:
        headers['Authorization'] = f'Bearer {EXPO_TOKEN}'
    request = urllib.request.Request(EXPO_URL, data=data, headers=headers)
    with urllib.request.urlopen(request) as resp:
        resp.read()
    return {'status': 'sent'}
