import sys

from sqlalchemy import text

from app.db.session import SessionLocal


def debug():
    db = SessionLocal()
    try:
        print("--- DB Debug Start ---")
        # List all tables in public schema
        res = db.execute(
            text(
                "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
            )
        ).fetchall()
        tables = [r[0] for r in res]
        print(f"Tables found: {tables}")

        # Test specific tables
        for t in ["rejectionentry", "rejection_entry", "rejection_entries"]:
            try:
                db.execute(text(f"SELECT COUNT(*) FROM {t}"))
                print(f"EXISTS: {t}")
            except Exception as e:
                print(f"NOT FOUND or ERROR for {t}: {str(e)[:100]}")
                db.rollback()

        # Check columns for RejectionEntry
        table_to_check = (
            "rejectionentry" if "rejectionentry" in tables else "rejection_entries"
        )
        print(f"Checking columns for: {table_to_check}")
        res = db.execute(
            text(
                f"SELECT column_name FROM information_schema.columns WHERE table_name='{table_to_check}'"
            )
        ).fetchall()
        print(f"Columns for {table_to_check}: {[r[0] for r in res]}")

    except Exception as e:
        print(f"Debug failed: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    debug()
