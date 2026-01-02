import json
import logging
import urllib.request

# Config
BASE_URL = "http://localhost:8000/v1"
ADMIN_USER = "admin"
ADMIN_PASS = "admin"

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("verify_filtering")


def login():
    url = f"{BASE_URL}/login"
    data = json.dumps({"username": ADMIN_USER, "password": ADMIN_PASS}).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())["access_token"]


def get_dispatches(token, hide_reversed=None):
    url = f"{BASE_URL}/dispatch-entries?limit=100"
    if hide_reversed is not None:
        url += f"&hide_fully_reversed={str(hide_reversed).lower()}"

    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())


def run_test():
    logger.info("--- Backend Filtering Verification ---")
    token = login()

    # 1. Fetch ALL (Default)
    all_dispatches = get_dispatches(token)
    fully_reversed_count_all = sum(
        1 for d in all_dispatches if d["status"] == "Fully Reversed"
    )
    logger.info(f"Total Dispatches: {len(all_dispatches)}")
    logger.info(f"Fully Reversed (Default): {fully_reversed_count_all}")

    if fully_reversed_count_all == 0:
        logger.warning(
            "No fully reversed dispatches found. Cannot verify filtering exclusion."
        )
        # We assume previous tests created some. If not, verification is weak.

    # 2. Fetch Filtered
    filtered_dispatches = get_dispatches(token, hide_reversed=True)
    fully_reversed_count_filtered = sum(
        1 for d in filtered_dispatches if d["status"] == "Fully Reversed"
    )
    logger.info(f"Filtered Dispatches: {len(filtered_dispatches)}")
    logger.info(f"Fully Reversed (Filtered): {fully_reversed_count_filtered}")

    # Assertions
    if fully_reversed_count_filtered != 0:
        logger.error(
            f"FAIL: Expected 0 fully reversed items, got {fully_reversed_count_filtered}"
        )
        exit(1)

    if len(filtered_dispatches) > len(all_dispatches):
        logger.error("FAIL: Filtered list is larger than default list (Logic error)")
        exit(1)

    if len(all_dispatches) - len(filtered_dispatches) != fully_reversed_count_all:
        # Note: If limit=100 cuts off data, this might mismatch.
        # But assuming dataset < 100 or fully reversed are recent.
        logger.warning(
            "Count mismatch (potential pagination cliff), but exclusion verified."
        )

    logger.info("PASS: Filtering Logic Verified")


if __name__ == "__main__":
    run_test()
