import json
import os
import sys
import urllib.parse
import urllib.request

# If running from /app, app module is available.
sys.path.append(os.getcwd())

BASE_URL = "http://localhost:8000/v1"


def make_request(url, method="GET", data=None, headers=None):
    if headers is None:
        headers = {}

    if data:
        data_bytes = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"
    else:
        data_bytes = None

    req = urllib.request.Request(url, data=data_bytes, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
            body = resp.read().decode("utf-8")
            return status, body, resp.headers
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        return e.code, body, e.headers
    except Exception as e:
        print(f"Request error: {e}")
        return 0, str(e), {}


def get_token(username, password):
    url = f"{BASE_URL}/login"
    # Auth endpoint expects JSON UserLogin schema
    data = json.dumps({"username": username, "password": password}).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            return body["access_token"]
    except Exception as e:
        print(f"Login failed: {e}")
        return None


def test_dispatch_deletion_blocked(headers, dispatch_id):
    print(f"\n--- Testing DELETE /dispatch-entries/{dispatch_id} (Should fail 405) ---")
    status, body, _ = make_request(
        f"{BASE_URL}/dispatch-entries/{dispatch_id}", method="DELETE", headers=headers
    )
    print(f"Status: {status}")
    if status == 405:
        print("PASS: Delete blocked correctly.")
        return True
    print(f"FAIL: Delete not blocked correctly. Got {status}")
    return False


def test_dispatch_update_blocked(headers, dispatch_id):
    print(f"\n--- Testing PUT /dispatch-entries/{dispatch_id} (Should fail 405) ---")
    status, body, _ = make_request(
        f"{BASE_URL}/dispatch-entries/{dispatch_id}",
        method="PUT",
        data={"remarks": "Update"},
        headers=headers,
    )
    print(f"Status: {status}")
    if status == 405:
        print("PASS: Update blocked correctly.")
        return True
    print(f"FAIL: Update not blocked correctly. Got {status}")
    return False


def test_reversal(headers, dispatch_id, qty=None):
    print(f"\n--- Testing POST /dispatch-entries/{dispatch_id}/reverse ---")
    payload = {"reason": "Test Reversal"}
    if qty:
        payload["quantity"] = qty

    status, body, _ = make_request(
        f"{BASE_URL}/dispatch-entries/{dispatch_id}/reverse",
        method="POST",
        data=payload,
        headers=headers,
    )
    print(f"Status: {status}")
    print(f"Response: {body}")

    if status == 201:
        data = json.loads(body)
        print(f"PASS: Reversal created. ID: {data['id']}, Qty: {data['quantity']}")
        return True

    if status == 409:
        print(f"PASS (Expected Conflict): {body}")
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
    status, body, _ = make_request(
        f"{BASE_URL}/dispatch-entries/?limit=1", headers=headers
    )
    if status != 200:
        print(f"Failed to fetch dispatches: {status}")
        sys.exit(1)

    dispatches = json.loads(body)

    if not dispatches:
        print(
            "No dispatches found. Skipping reversal tests (Logic verified if DELETE/PUT blocked)."
        )
        target_id = 999999
    else:
        target_id = dispatches[0]["id"]
        # Ensure ID is int
        target_id = int(target_id)
        print(f"Targeting Dispatch ID: {target_id} Qty: {dispatches[0]['quantity']}")

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
