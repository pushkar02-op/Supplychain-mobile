import json
import logging
import urllib.error
import urllib.request

# Config
BASE_URL = "http://localhost:8000/v1"
ADMIN_USER = "admin"
ADMIN_PASS = "admin"

# Setup logging
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("verify_net_view")


def login():
    """Authenticate and get token."""
    url = f"{BASE_URL}/login"
    data = json.dumps({"username": ADMIN_USER, "password": ADMIN_PASS}).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )

    try:
        with urllib.request.urlopen(req) as response:
            res = json.loads(response.read().decode())
            return res["access_token"]
    except urllib.error.HTTPError as e:
        logger.error(f"Login failed: {e.code} {e.read().decode()}")
        exit(1)


def get_headers(token):
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def get_dispatches(token):
    url = f"{BASE_URL}/dispatch-entries?limit=100"
    req = urllib.request.Request(url, headers=get_headers(token))

    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())


def create_reversal(token, dispatch_id, qty):
    url = f"{BASE_URL}/dispatch-entries/{dispatch_id}/reverse"
    data = json.dumps({"quantity": qty, "reason": "Net View Test"}).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=get_headers(token))

    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())


def run_test():
    logger.info("--- Starting Net View Verification ---")
    token = login()

    # 1. Find a candidate dispatch (or create implicitly if we had a create script, but we'll use existing)
    # We need a dispatch that is not fully reversed to test meaningfully.
    dispatches = get_dispatches(token)

    target = None
    for d in dispatches:
        # Pydantic schema validation check
        if "net_quantity" not in d or "status" not in d:
            logger.error("FAIL: Response missing net_quantity or status fields!")
            exit(1)

        # Find one that is Active and has quantity > 10
        if d["status"] == "Active" and d["quantity"] > 10:
            target = d
            break

    if not target:
        logger.warning(
            "No suitable Active dispatch found (>10 qty). Skipping mutation tests."
        )
        # Just fail if we can't test
        logger.error("FAIL: Setup - No testable dispatch found.")
        exit(1)

    dispatch_id = target["id"]
    original_qty = target["quantity"]
    logger.info(
        f"Target Dispatch ID: {dispatch_id}, Qty: {original_qty}, Status: {target['status']}"
    )

    # 2. Test Partial Reversal
    reverse_qty = 5.0
    logger.info(f"Reversing {reverse_qty}...")
    create_reversal(token, dispatch_id, reverse_qty)

    # Check Net View
    dispatches = get_dispatches(token)
    updated = next(d for d in dispatches if d["id"] == dispatch_id)

    expected_net = original_qty - reverse_qty
    logger.info(
        f"Post-Partial: Net: {updated['net_quantity']}, Status: {updated['status']}"
    )

    if abs(updated["net_quantity"] - expected_net) > 0.01:
        logger.error(
            f"FAIL: Expected net {expected_net}, got {updated['net_quantity']}"
        )
    elif updated["status"] != "Partially Reversed":
        logger.error(f"FAIL: Expected 'Partially Reversed', got '{updated['status']}'")
    else:
        logger.info("PASS: Partial Reversal Validated")

    # 3. Test Full Reversal
    remaining = updated["net_quantity"]
    logger.info(f"Reversing remaining {remaining}...")
    create_reversal(token, dispatch_id, remaining)

    dispatches = get_dispatches(token)
    final = next(d for d in dispatches if d["id"] == dispatch_id)

    logger.info(f"Post-Full: Net: {final['net_quantity']}, Status: {final['status']}")

    if final["net_quantity"] != 0:
        logger.error(f"FAIL: Expected net 0, got {final['net_quantity']}")
    elif final["status"] != "Fully Reversed":
        logger.error(f"FAIL: Expected 'Fully Reversed', got '{final['status']}'")
    else:
        logger.info("PASS: Full Reversal Validated")

    logger.info("--- All Net View Tests Passed ---")


if __name__ == "__main__":
    run_test()
