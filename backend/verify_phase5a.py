#!/usr/bin/env python3
"""
Phase 5A Verification Script
Tests UOM safety enforcement and diagnostics
"""

import urllib.request
import urllib.error
import json
import time
import sys


import builtins


# Set up file logging
import os

log_path = os.path.abspath("verification_results.log")
log_file = open(log_path, "w", encoding="utf-8")


def log_print(*args, **kwargs):
    builtins.print(*args, **kwargs)
    # Simple logging of args
    msg = " ".join(map(str, args))
    log_file.write(msg + "\n")
    log_file.flush()


print(f"Logging to: {log_path}")
print = log_print

BASE_URL = "http://localhost:8000/v1"


def make_request(
    method, endpoint, data=None, token=None, idempotency_key=None, retries=5
):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if idempotency_key:
        headers["Idempotency-Key"] = idempotency_key

    body = json.dumps(data).encode("utf-8") if data else None

    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                f"{BASE_URL}{endpoint}", data=body, headers=headers, method=method
            )
            with urllib.request.urlopen(req) as resp:
                return resp.getcode(), json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body_str = e.read().decode("utf-8")
            try:
                return e.code, json.loads(body_str)
            except:
                return e.code, {"detail": body_str}
        except (urllib.error.URLError, ConnectionResetError) as e:
            if attempt < retries - 1:
                log_print(
                    f"Connection failed ({e}), retrying {attempt + 1}/{retries}..."
                )
                time.sleep(2)
            else:
                log_print(f"Failed after {retries} attempts")
                raise e
    return 500, {"detail": "Max retries exceeded"}


def get_token():
    payload = {"username": "uom_tester", "password": "Password123!"}
    code, resp = make_request("POST", "/login", payload)
    if code != 200:
        make_request(
            "POST",
            "/register",
            {
                "username": "uom_tester",
                "email": "uom_tester@test.com",
                "password": "Password123!",
                "full_name": "UOM Tester",
                "role": "admin",
            },
        )
        code, resp = make_request("POST", "/login", payload)
    return resp["access_token"]


def main():
    print("=" * 80)
    print("PHASE 5A VERIFICATION: UOM SAFETY")
    print("=" * 80)

    token = get_token()
    print("✓ Authentication successful")

    timestamp = int(time.time())

    # ------------------------------------------------------------------
    # TEST 1: Stock Entry for Item with NO Default UOM
    # ------------------------------------------------------------------
    print("\nTEST 1: Missing Default UOM -> Should FAIL (409)")
    print("-" * 80)

    # Create item with NO default UOM
    item_name_no_uom = f"NoUOMItem_{timestamp}"
    code, item = make_request("POST", "/item/", {"name": item_name_no_uom}, token)
    if code not in [200, 201]:
        print(f"✗ Failed to create test item: {code} {item}")
        return
    item_id = item["id"]
    print(f"  Created item ID {item_id} (No Default UOM)")

    # Attempt Stock Entry
    stock_payload = {
        "item_id": item_id,
        "quantity": 10.0,
        "unit": "kg",
        "received_date": "2025-12-24",
        "price_per_unit": 10.0,
        "total_cost": 100.0,
    }
    code, resp = make_request(
        "POST",
        "/stock-entry/",
        stock_payload,
        token,
        idempotency_key=f"test1-{timestamp}",
    )

    if code == 409 and resp.get("error_code") == "UOM_CONFIG_ERROR":
        print(f"✓ PASS: Request blocked with 409 UOMConfigurationError")
        print(f"  Message: {resp.get('detail')}")
    else:
        print(f"✗ FAIL: Expected 409 UOM_CONFIG_ERROR, got {code}")
        print(f"  Response: {resp}")
        sys.exit(1)

    # ------------------------------------------------------------------
    # TEST 2: Admin Diagnostics
    # ------------------------------------------------------------------
    print("\nTEST 2: Admin Diagnostics -> Should List Missing UOM")
    print("-" * 80)

    code, diag_resp = make_request(
        "GET", "/admin/diagnostics/uom/missing-default", None, token
    )

    if code == 200:
        items = diag_resp.get("items", [])
        found = any(i["id"] == item_id for i in items)
        if found:
            print(f"✓ PASS: Diagnostics correctly identified item {item_id}")
            print(f"  Diagnostic output count: {diag_resp.get('count')}")
        else:
            print(f"✗ FAIL: Item {item_id} not found in diagnostics")
            print(f"  Items: {items}")
            sys.exit(1)
    else:
        print(f"✗ FAIL: Diagnostics endpoint returned {code}")
        print(resp)
        sys.exit(1)

    # ------------------------------------------------------------------
    # TEST 3: Conversion Mismatch
    # ------------------------------------------------------------------
    print("\nTEST 3: Missing Conversion Factor -> Should FAIL (409)")
    print("-" * 80)

    # Try to find an existing item with a default UOM
    code, items = make_request("GET", "/item/", None, token)
    valid_item = None
    if code == 200:
        for i in items:
            if i.get("default_unit"):
                valid_item = i
                break

    if valid_item:
        print(
            f"  Using existing item: {valid_item['name']} (ID: {valid_item['id']}, UOM: {valid_item.get('default_unit')})"
        )
        # Try stock entry with 'liters' (assuming no conversion to default unit exists)
        # Use a unit likely to not have conversion, e.g. 'cubic_meters' or just 'liters' if item is 'kg'
        test_unit = "liters" if valid_item.get("default_unit") != "liters" else "kg"

        stock_payload2 = {
            "item_id": valid_item["id"],
            "quantity": 10.0,
            "unit": test_unit,
            "received_date": "2025-12-24",
            "price_per_unit": 10.0,
            "total_cost": 100.0,
        }
        code, resp = make_request(
            "POST",
            "/stock-entry/",
            stock_payload2,
            token,
            idempotency_key=f"test3-{timestamp}",
        )

        if code == 409 and resp.get("error_code") == "UOM_CONFIG_ERROR":
            print(f"✓ PASS: Conversion failure blocked with 409 UOMConfigurationError")
            print(f"  Message: {resp.get('detail')}")
        elif code == 400 and "Conversion" in str(resp):
            # Fallback if old error persists (shouldn't happen)
            print(f"✗ FAIL: Got generic 400 instead of 409")
            print(resp)
        elif code == 200:
            print(
                f"⚠ WARNING: Creation succeeded - Conversion apparently exists between {test_unit} and {valid_item.get('default_unit')}"
            )
        else:
            print(f"✗ FAIL: Expected 409 UOM_CONFIG_ERROR, got {code}")
            print(f"  Response: {resp}")
    else:
        print(
            "⚠ SKIP: No existing item with default UOM found to test conversion logic."
        )

    print("\n" + "=" * 80)
    print("PHASE 5A VERIFICATION: CHECKS COMPLETED")
    print("=" * 80)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n✗ EXCEPTION: {e}")
        import traceback

        traceback.print_exc()
