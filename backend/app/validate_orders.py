import json
import logging
import urllib.error
import urllib.request

from app.core.config import settings
from sqlalchemy import create_engine, text

API_URL = "http://localhost:8000/v1/orders/"
engine = create_engine(settings.DATABASE_URL)
logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
logger = logging.getLogger(__name__)


def run_test(name, payload):
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as response:
            logger.info("%s: %s SUCCESS", name, response.getcode())
            return True
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        logger.error("%s: %s FAIL %s", name, e.code, body)
        return False
    except Exception as e:
        logger.error("%s: ERR %s", name, e)
        return False


def check_db():
    logger.info("--- DB STATE ---")
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT id, mart_id, quantity_ordered FROM public.order WHERE item_id = 17 AND order_date = '2026-01-01' ORDER BY id DESC"
            )
        ).fetchall()
        for r in rows:
            logger.info("ID=%s MartID=%s", r.id, r.mart_id)


def main():
    base = {
        "item_id": 17,
        "order_date": "2026-01-01",
        "quantity_ordered": 65,
        "unit": "KG",
    }

    # 1. mart_id only (EXPECT FAIL 422)
    p1 = base.copy()
    p1["mart_id"] = 1
    run_test("TEST1(ID=1)", p1)

    # 2. Match (ID + Name) (EXPECT FAIL 422 - mart_id forbidden)
    p2 = base.copy()
    p2["mart_id"] = 1
    p2["mart_name"] = "KEOTA_CC_RRL"
    run_test("TEST2(Match)", p2)

    # 3. Conflict (EXPECT FAIL 422 - mart_id forbidden)
    p3 = base.copy()
    p3["mart_id"] = 9999
    p3["mart_name"] = "KEOTA_CC_RRL"
    run_test("TEST3(Conflict)", p3)

    # 4. Name only (EXPECT SUCCESS)
    p4 = base.copy()
    p4["mart_name"] = "KEOTA_CC_RRL"  # Valid Phase 2 Payload
    run_test("TEST4(NameOnly)", p4)

    check_db()


if __name__ == "__main__":
    main()
