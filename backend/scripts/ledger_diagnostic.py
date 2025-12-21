import sys
import os
import json

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.db.session import SessionLocal
from app.services.reconciliation import get_ledger_health_report


def run_diagnostic():
    db = SessionLocal()
    try:
        report = get_ledger_health_report(db)

        if not report:
            result = {
                "status": "HEALTHY",
                "message": "No ledger drift or negative stock detected.",
                "unhealthy_batches": [],
            }
        else:
            result = {
                "status": "WARNING",
                "message": f"Found {len(report)} batches with issues (drift or negative stock).",
                "unhealthy_batches": report,
            }

        # Output JSON for easy parsing or manual review
        print(json.dumps(result, indent=2))

    except Exception as e:
        error_res = {"status": "ERROR", "message": str(e)}
        print(json.dumps(error_res, indent=2))
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    run_diagnostic()
