import urllib.request
import urllib.error
import urllib.parse
import json
import time
import sys

BASE_URL = "http://localhost:8000/v1"


def log(msg):
    print(msg)
    with open("verify_phase4a.log", "a") as f:
        f.write(msg + "\n")


def make_request(method, endpoint, data=None, token=None, idempotency_key=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if idempotency_key:
        headers["Idempotency-Key"] = idempotency_key

    body = json.dumps(data).encode("utf-8") if data else None
    req = urllib.request.Request(
        f"{BASE_URL}{endpoint}", data=body, headers=headers, method=method
    )

    try:
        with urllib.request.urlopen(req) as resp:
            return resp.getcode(), json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body_str = e.read().decode("utf-8")
        try:
            body_json = json.loads(body_str)
        except:
            body_json = body_str
        return e.code, body_json


def get_token():
    # Login
    login_payload = {"username": "idem_tester", "password": "Password123!"}
    code, resp = make_request("POST", "/login", login_payload)
    if code != 200:
        # Register if fails
        try:
            make_request(
                "POST",
                "/register",
                {
                    "username": "idem_tester",
                    "email": "idem@test.com",
                    "password": "Password123!",
                    "full_name": "Idem Tester",
                    "role": "admin",
                },
            )
            code2, resp2 = make_request("POST", "/login", login_payload)
            return resp2["access_token"]
        except:
            raise Exception("Login failed")
    return resp["access_token"]


def run_verification():
    log("=" * 60)
    log("Phase 4A Verification (Fractional Quantities)")
    log("=" * 60)

    try:
        token = get_token()
        log(f"[SETUP] Token acquired")

        # Create test item
        item_name = f"FractionalItem_{int(time.time())}"
        code, item = make_request("POST", "/item/", {"name": item_name}, token)
        if code not in [200, 201]:
            log(f"[FATAL] Failed to create item: {code} {item}")
            return
        item_id = item["id"]
        log(f"[SETUP] Created Item ID: {item_id}")

        # Test 1: Fractional Stock Entry (10.5)
        log("\nSCENARIO 1: Fractional Stock Entry (10.5)")
        key1 = f"frac-key-{int(time.time())}"
        payload = {
            "item_id": item_id,
            "quantity": 10.5,
            "unit": "kg",
            "received_date": "2025-12-24",
            "price_per_unit": 10.0,
            "total_cost": 105.0,
        }
        code1, resp1 = make_request(
            "POST", "/stock-entry/", payload, token, idempotency_key=key1
        )
        log(f"HTTP Code: {code1}")
        log(f"Response: {resp1}")

        if code1 in [200, 201]:
            log("RESULT: PASS (Accepted fractional quantity)")
        else:
            log(f"RESULT: FAIL (Rejected fractional: {resp1})")

        # Verify Batch Quantity via Rejection (since we strictly can't read DB directly purely via API usually, but wait, API returns Batch?)
        # Getting stock entry returns simple object.
        # Attempt to reject 0.5.

        log("\nSCENARIO 2: Rejection of 0.5")
        batch_id = resp1.get("batch_id")
        if not batch_id:
            log("SKIP: No batch_id from Scen 1")
        else:
            key2 = f"rej-key-{int(time.time())}"
            rej_payload = {
                "batch_id": batch_id,
                "quantity": 0.5,  # RejectionEntryCreate takes quantity: float? Check schema later.
                "reason": "Test fraction",
                "rejection_date": "2025-12-24",
            }
            code2, resp2 = make_request(
                "POST", "/rejection-entries/", rej_payload, token, idempotency_key=key2
            )
            log(f"HTTP Code: {code2}")
            log(f"Response: {resp2}")
            if code2 in [200, 201]:
                log("RESULT: PASS (Rejected 0.5)")
            else:
                log(f"RESULT: FAIL (Failed to reject 0.5: {resp2})")

    except Exception as e:
        log(f"EXCEPTION: {e}")
        import traceback

        traceback.print_exc()


if __name__ == "__main__":
    run_verification()
