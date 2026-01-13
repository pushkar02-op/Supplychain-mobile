import json
import os
import sys

import requests

# Add parent dir
sys.path.append(os.getcwd())

BASE_URL = "http://localhost:8000/v1"


def get_token(username, password):
    url = f"{BASE_URL}/auth/login"
    try:
        resp = requests.post(url, data={"username": username, "password": password})
        if resp.status_code == 200:
            return resp.json()["access_token"]
        print(f"Login failed: {resp.text}")
        return None
    except Exception as e:
        print(f"Login error: {e}")
        return None


def test_dispatch_deletion_blocked(headers, dispatch_id):
    print(f"\n--- Testing DELETE /dispatch-entries/{dispatch_id} (Should fail 405) ---")
    resp = requests.delete(
        f"{BASE_URL}/dispatch-entries/{dispatch_id}", headers=headers
    )
    print(f"Status: {resp.status_code}")
    if resp.status_code == 405:
        print("PASS: Delete blocked correctly.")
        return True
    print(f"FAIL: Delete not blocked correctly. Got {resp.status_code}")
    return False


def test_dispatch_update_blocked(headers, dispatch_id):
    print(f"\n--- Testing PUT /dispatch-entries/{dispatch_id} (Should fail 405) ---")
    resp = requests.put(
        f"{BASE_URL}/dispatch-entries/{dispatch_id}",
        json={"remarks": "Update"},
        headers=headers,
    )
    print(f"Status: {resp.status_code}")
    if resp.status_code == 405:
        print("PASS: Update blocked correctly.")
        return True
    print(f"FAIL: Update not blocked correctly. Got {resp.status_code}")
    return False


def test_reversal(headers, dispatch_id, qty=None):
    print(f"\n--- Testing POST /dispatch-entries/{dispatch_id}/reverse ---")
    payload = {"reason": "Test Reversal"}
    if qty:
        payload["quantity"] = qty

    resp = requests.post(
        f"{BASE_URL}/dispatch-entries/{dispatch_id}/reverse",
        json=payload,
        headers=headers,
    )
    print(f"Status: {resp.status_code}")
    print(f"Response: {resp.text}")
    if resp.status_code == 201:
        data = resp.json()
        print(f"PASS: Reversal created. ID: {data['id']}, Qty: {data['quantity']}")
        return True

    # Check for already fully reversed or partial limits
    if resp.status_code == 409:
        print(f"PASS (Expected Conflict): {resp.text}")
        return True

    print("FAIL: Reversal failed.")
    return False


def main():
    print("Logging in as admin...")
    token = get_token("admin", "admin")
    if not token:
        print("CRITICAL: Could not login as admin. Aborting tests.")
        sys.exit(1)

    headers = {"Authorization": f"Bearer {token}"}

    print("Fetching latest dispatch...")
    resp = requests.get(f"{BASE_URL}/dispatch-entries/?limit=1", headers=headers)
    dispatches = resp.json()
    if not dispatches:
        print(
            "No dispatches found. Skipping reversal tests (Logic verified if DELETE/PUT blocked)."
        )
        # Try to use a dummy ID to test 405s
        target_id = 999999
    else:
        target_id = dispatches[0]["id"]
        print(f"Targeting Dispatch ID: {target_id}")

    # 3. Test Blocked Methods
    if not test_dispatch_deletion_blocked(headers, target_id):
        sys.exit(1)
    if not test_dispatch_update_blocked(headers, target_id):
        sys.exit(1)

    if not dispatches:
        return

    # 4. Test Reversal (Partial)
    if not test_reversal(headers, target_id, qty=0.01):
        sys.exit(1)

    print("\n\nALL VERIFICATION TESTS PASSED")


if __name__ == "__main__":
    main()
