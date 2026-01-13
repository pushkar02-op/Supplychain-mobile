import json
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import date

BASE_URL = "http://localhost:8000/v1"


def get_token():
    # 1. Register (ignore error if exists)
    reg_data = {
        "username": "idem_test_user",
        "email": "idem_test@example.com",
        "password": "Password123!",
        "full_name": "Idempotency Tester",
        "role": "admin",
    }
    try:
        req = urllib.request.Request(
            f"{BASE_URL}/register",
            data=json.dumps(reg_data).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        urllib.request.urlopen(req)
    except urllib.error.HTTPError:
        pass

    # 2. Login
    login_data = {"username": "idem_test_user", "password": "Password123!"}
    # Using x-www-form-urlencoded
    data = urllib.parse.urlencode(login_data).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/login",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req) as response:
        res = json.loads(response.read().decode("utf-8"))
        return res["access_token"]


def make_request(method, endpoint, data, token, idempotency_key=None):
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {token}"}
    if idempotency_key:
        headers["Idempotency-Key"] = idempotency_key

    req = urllib.request.Request(
        f"{BASE_URL}{endpoint}",
        data=json.dumps(data).encode("utf-8") if data else None,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req) as response:
            return response.getcode(), json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        print(f"HTTP {e.code}: {body}")
        return e.code, body


def run_tests():
    token = get_token()
    print("Got token.")

    # Setup Item
    item_key = str(uuid.uuid4())[:8]
    item_data = {
        "name": f"IdemItem-{item_key}",
        "category": "Test",
        "cost_price": 10.0,
        "selling_price": 20.0,
        "default_unit": "kg",
    }
    status, item = make_request("POST", "/item/", item_data, token)
    if status not in [200, 201]:
        print("Failed to create item")
        sys.exit(1)
    item_id = item["id"]
    print(f"Created Item {item_id}")

    # SCENARIO 1: Missing Header
    print("\n--- SCENARIO 1: Missing Header ---")
    payload = {
        "item_id": item_id,
        "quantity": 10,
        "unit": "kg",
        "received_date": str(date.today()),
        "price_per_unit": 10.0,
        "total_cost": 100.0,
    }
    status, res = make_request("POST", "/stock-entry/", payload, token)
    if status == 400 and "header is required" in str(res):
        print("PASS: Missing header rejected (400).")
    else:
        print(f"FAIL: Expected 400, got {status}")

    # SCENARIO 2: First Request (Success)
    print("\n--- SCENARIO 2: First Request (Key A) ---")
    key_a = str(uuid.uuid4())
    status, res_a1 = make_request(
        "POST", "/stock-entry/", payload, token, idempotency_key=key_a
    )
    if status == 201:
        print(f"PASS: Created Stock Entry {res_a1['id']}")
    else:
        print(f"FAIL: Expected 201, got {status}")
        sys.exit(1)

    # SCENARIO 3: Replay Request (Same Key, Same Payload)
    print("\n--- SCENARIO 3: Replay Request (Key A) ---")
    status, res_a2 = make_request(
        "POST", "/stock-entry/", payload, token, idempotency_key=key_a
    )
    if status == 200:  # Assuming 200 for OK found, or 201 if just returned
        # Logic says "return get_stock_entry(...)". This usually returns the Pydantic model response.
        # Status code: The endpoint defaults to 201. If we return the object, FastAPI uses the default status code unless we change request.response.status_code.
        # But wait, we return the Object. FastAPI serializes it.
        # The status code will be 201 because it's set in decorator.
        # Let's check IDs.
        if res_a1["id"] == res_a2["id"]:
            print(f"PASS: Returned same ID {res_a1['id']}")
        else:
            print(f"FAIL: IDs mismatch. Original {res_a1['id']}, Replay {res_a2['id']}")
    else:
        # It might return 201 even on replay because the decorator forces it.
        if status == 201 and res_a1["id"] == res_a2["id"]:
            print(f"PASS: Returned same ID {res_a1['id']} (Status 201)")
        else:
            print(f"FAIL: Expected Success, got {status}")

    # SCENARIO 4: Conflict Request (Same Key, Diff Payload)
    print("\n--- SCENARIO 4: Conflict Request (Key A, Diff Payload) ---")
    payload_diff = payload.copy()
    payload_diff["quantity"] = 999
    status, res = make_request(
        "POST", "/stock-entry/", payload_diff, token, idempotency_key=key_a
    )
    if status == 409:
        print("PASS: Rejected conflict (409).")
    else:
        print(f"FAIL: Expected 409, got {status}")

    # SCENARIO 5: New Request (Key B)
    print("\n--- SCENARIO 5: New Request (Key B) ---")
    key_b = str(uuid.uuid4())
    status, res_b = make_request(
        "POST", "/stock-entry/", payload, token, idempotency_key=key_b
    )
    if status == 201:
        print(f"PASS: Created Stock Entry {res_b['id']}")
        if res_b["id"] != res_a1["id"]:
            print("PASS: ID is different from Key A.")
        else:
            print("FAIL: ID is same as Key A!")
    else:
        print(f"FAIL: Expected 201, got {status}")


if __name__ == "__main__":
    run_tests()
