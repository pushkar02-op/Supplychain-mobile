import json
import urllib.request
from datetime import datetime

url = f"http://127.0.0.1:8000/v1/orders/?warehouse_id=1&order_date={datetime.now().strftime('%Y-%m-%d')}"
headers = {}  # No auth for this local trace based on current DB

try:
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
        data = response.read()
        parsed = json.loads(data)
        print("ORDERS_RAW_RESPONSE:")
        print(json.dumps(parsed, indent=2))

        # Analyze nulls
        nulls = set()
        for item in parsed:
            for k, v in item.items():
                if v is None:
                    nulls.add(k)
        print("\nNULL_FIELDS_FOUND:")
        for n in nulls:
            print("-", n)
except Exception as e:
    print("Error:", e)
