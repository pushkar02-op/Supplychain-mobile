import sys
import uuid
import json
import urllib.request
import urllib.error

API_URL = "http://localhost:8000"


def request(method, endpoint, data=None):
    url = f"{API_URL}{endpoint}"
    if data:
        json_data = json.dumps(data).encode("utf-8")
    else:
        json_data = None

    req = urllib.request.Request(url, data=json_data, method=method)
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req) as resp:
            status = resp.status
            body = resp.read().decode("utf-8")
            try:
                json_body = json.loads(body)
            except:
                json_body = body
            return status, json_body
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            json_body = json.loads(body)
        except:
            json_body = body
        return e.code, json_body


def run_test():
    username = f"refresh_tester_{uuid.uuid4().hex[:8]}"
    password = "password123"

    print(f"1. Registering user: {username}")
    status, data = request(
        "POST",
        "/register",
        {"username": username, "password": password, "full_name": "Refresh Tester"},
    )
    if status != 200:
        print(f"Registration failed: {data}")
        return False
    if "refresh_token" not in data:
        print("FAIL: refresh_token missing in register response")
        return False
    print("PASS: Got refresh token on register")

    print("2. Logging in")
    status, data = request(
        "POST", "/login", {"username": username, "password": password}
    )
    if status != 200:
        print(f"Login failed: {data}")
        return False

    refresh_token = data.get("refresh_token")
    access_token = data.get("access_token")

    if not refresh_token:
        print("FAIL: refresh_token missing in login response")
        return False
    print(f"PASS: Got refresh token on login: {refresh_token[:10]}...")

    print("3. Refreshing token")
    status, data = request("POST", "/refresh", {"refresh_token": refresh_token})
    if status != 200:
        print(f"Refresh failed: {data}")
        return False

    new_refresh = data.get("refresh_token")
    new_access = data.get("access_token")

    if not new_refresh or not new_access:
        print("FAIL: Missing tokens in refresh response")
        return False
    if new_refresh == refresh_token:
        print("FAIL: Refresh token was not rotated (same token returned)")
        return False
    print("PASS: Successfully refreshed and rotated token")

    print("4. Attempting reuse of old refresh token (Security Check)")
    status, data = request("POST", "/refresh", {"refresh_token": refresh_token})
    if status == 401:
        print("PASS: Old token reuse blocked (401)")
    else:
        print(f"FAIL: Reuse allowed or wrong status code: {status}")
        return False

    print("5. Attempting invalid token")
    status, data = request("POST", "/refresh", {"refresh_token": "invalid_token_blob"})
    if status == 401:
        print("PASS: Invalid token blocked (401)")
    else:
        print(f"FAIL: Invalid token allowed: {status}")
        return False

    print("SUCCESS: All refresh token checks passed.")
    return True


if __name__ == "__main__":
    try:
        if run_test():
            sys.exit(0)
        else:
            sys.exit(1)
    except Exception as e:
        print(f"Test crashed: {e}")
        sys.exit(1)
