#!/usr/bin/env python3
"""
Phase 3 Idempotency Verification Script (Clean Environment)
"""

import urllib.request
import urllib.error
import urllib.parse
import json
import time

BASE_URL = "http://localhost:8000/v1"


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
    # Register (ignore errors if exists)
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
    except:
        pass

    # Login
    login_payload = {"username": "idem_tester", "password": "Password123!"}
    code, resp = make_request("POST", "/login", login_payload)
    if code != 200:
        raise Exception(f"Login failed: {code} {resp}")
    return resp["access_token"]


def run_verification():
    with open("verification.log", "w") as f:
        # Redirect print to file AND stdout
        original_print = print

        def log(*args, **kwargs):
            original_print(*args, **kwargs)
            print(*args, file=f, **kwargs)

        log("=" * 60)
        log("Phase 3 Idempotency Verification (Clean Environment)")
        log("=" * 60)

        token = get_token()
        log(f"[SETUP] Token acquired")

        # Create test item
        item_name = f"VerifyItem_{int(time.time())}"
        code, item = make_request("POST", "/item/", {"name": item_name}, token)
        if code not in [200, 201]:
            log(f"[FATAL] Failed to create item: {code} {item}")
            return
        item_id = item["id"]
        log(f"[SETUP] Created Item ID: {item_id}")

        payload = {
            "item_id": item_id,
            "quantity": 100,
            "unit": "kg",
            "received_date": "2025-12-24",
            "price_per_unit": 10.0,
            "total_cost": 1000.0,
        }
        key1 = f"idem-key-{int(time.time())}-1"
        key2 = f"idem-key-{int(time.time())}-2"

        results = []

        # SCENARIO 1: Missing Idempotency Key
        log("\n" + "=" * 60)
        log("SCENARIO 1: Missing Idempotency Key")
        log("=" * 60)
        code1, resp1 = make_request(
            "POST", "/stock-entry/", payload, token, idempotency_key=None
        )
        log(f"HTTP Code: {code1}")
        log(f"Response: {resp1}")
        s1_pass = code1 == 400
        log(f"RESULT: {'PASS' if s1_pass else 'FAIL'} (Expected 400, Got {code1})")
        results.append(("Missing Key", 400, code1, s1_pass))

        # SCENARIO 2: Happy Path (New Key K1)
        log("\n" + "=" * 60)
        log(f"SCENARIO 2: Happy Path (Key: {key1})")
        log("=" * 60)
        code2, resp2 = make_request(
            "POST", "/stock-entry/", payload, token, idempotency_key=key1
        )
        log(f"HTTP Code: {code2}")
        log(f"Response: {resp2}")
        entry_id = resp2.get("id") if isinstance(resp2, dict) else None
        s2_pass = code2 in [200, 201] and entry_id is not None
        log(f"StockEntry ID: {entry_id}")
        log(f"RESULT: {'PASS' if s2_pass else 'FAIL'}")
        results.append(("Happy Path", "201/200", code2, s2_pass))

        # SCENARIO 3: Replay (Same Key K1, Same Payload)
        log("\n" + "=" * 60)
        log(f"SCENARIO 3: Replay (Key: {key1})")
        log("=" * 60)
        code3, resp3 = make_request(
            "POST", "/stock-entry/", payload, token, idempotency_key=key1
        )
        log(f"HTTP Code: {code3}")
        log(f"Response: {resp3}")
        replay_id = resp3.get("id") if isinstance(resp3, dict) else None
        log(f"Returned ID: {replay_id}")
        s3_pass = code3 in [200, 201] and replay_id == entry_id
        log(f"IDs Match: {replay_id == entry_id}")
        log(f"RESULT: {'PASS' if s3_pass else 'FAIL'}")
        results.append(("Replay", "Same ID", f"{code3}, ID={replay_id}", s3_pass))

        # SCENARIO 4: Conflict (Same Key K1, Different Payload)
        log("\n" + "=" * 60)
        log(f"SCENARIO 4: Conflict (Key: {key1}, qty=999)")
        log("=" * 60)
        payload_diff = payload.copy()
        payload_diff["quantity"] = 999
        payload_diff["total_cost"] = 9990.0
        code4, resp4 = make_request(
            "POST", "/stock-entry/", payload_diff, token, idempotency_key=key1
        )
        log(f"HTTP Code: {code4}")
        log(f"Response: {resp4}")
        s4_pass = code4 == 409
        log(f"RESULT: {'PASS' if s4_pass else 'FAIL'} (Expected 409, Got {code4})")
        results.append(("Conflict", 409, code4, s4_pass))

        # SCENARIO 5: Legitimate Repeat (New Key K2, Same Payload)
        log("\n" + "=" * 60)
        log(f"SCENARIO 5: Legitimate Repeat (Key: {key2})")
        log("=" * 60)
        code5, resp5 = make_request(
            "POST", "/stock-entry/", payload, token, idempotency_key=key2
        )
        log(f"HTTP Code: {code5}")
        log(f"Response: {resp5}")
        new_entry_id = resp5.get("id") if isinstance(resp5, dict) else None
        log(f"New StockEntry ID: {new_entry_id}")
        s5_pass = (
            code5 in [200, 201]
            and new_entry_id is not None
            and new_entry_id != entry_id
        )
        log(f"IDs Differ: {new_entry_id != entry_id}")
        log(f"RESULT: {'PASS' if s5_pass else 'FAIL'}")
        results.append(
            ("Legit Repeat", "New ID", f"{code5}, ID={new_entry_id}", s5_pass)
        )

        # Summary
        log("\n" + "=" * 60)
        log("SUMMARY")
        log("=" * 60)
        all_pass = all(r[3] for r in results)
        for scenario, expected, actual, passed in results:
            log(
                f"{scenario}: Expected={expected}, Actual={actual}, {'PASS' if passed else 'FAIL'}"
            )

        log("\n" + "=" * 60)
        if all_pass:
            log("FINAL VERDICT: **VERIFIED — Phase 3 correct**")
        else:
            log("FINAL VERDICT: **FAILED — Phase 3 broken**")
        log("=" * 60)


if __name__ == "__main__":
    run_verification()
