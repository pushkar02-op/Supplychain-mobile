import json
import urllib.request

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
            return e.code, json.loads(body_str)
        except:
            return e.code, body_str


def get_token():
    payload = {"username": "idem_tester", "password": "Password123!"}
    code, resp = make_request("POST", "/login", payload)
    if code != 200:
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
        code2, resp2 = make_request("POST", "/login", payload)
        return resp2["access_token"]
    return resp["access_token"]


def run():
    try:
        token = get_token()
        print(f"Token: {token[:10]}...")

        # Create Item
        code, item = make_request("POST", "/item/", {"name": "TestItemDebug"}, token)
        if code not in [200, 201]:
            print(f"Item Create Fail: {code} {item}")
            return
        item_id = item["id"]

        # Create Stock Entry
        payload = {
            "item_id": item_id,
            "quantity": 10.5,
            "unit": "kg",
            "received_date": "2025-12-24",
            "price_per_unit": 10.0,
            "total_cost": 105.0,
        }
        code2, resp2 = make_request(
            "POST", "/stock-entry/", payload, token, idempotency_key="debug-test-key"
        )
        print(f"Stock Entry Code: {code2}")
        print(json.dumps(resp2, indent=2))

    except Exception as e:
        print(e)


if __name__ == "__main__":
    run()
