import json
from datetime import date
from fastapi.encoders import jsonable_encoder

# Mock schema if import fails, but best to import
try:
    from app.db.schemas.stock_entry import StockEntryCreate

    HAS_SCHEMA = True
except ImportError:
    HAS_SCHEMA = False
    print("WARNING: Could not import StockEntryCreate")


def test():
    print("Testing serialization...")
    payload = {
        "item_id": 1,
        "quantity": 10.0,
        "unit": "kg",
        "received_date": date.today(),
        "price_per_unit": 10.0,
        "total_cost": 100.0,
        "source": "Initial",
    }
    print(f"Original payload: {payload}")

    try:
        encoded = jsonable_encoder(payload)
        print(f"Encoded: {encoded}")
    except Exception as e:
        print(f"Encoder failed: {e}")
        return

    try:
        dumped = json.dumps(encoded, sort_keys=True)
        print(f"Dumped: {dumped}")
    except Exception as e:
        print(f"Dumper failed: {e}")
        # Try to identify what failed
        for k, v in encoded.items():
            try:
                json.dumps({k: v})
            except:
                print(f"FAILED KEY: {k}, VALUE: {v}, TYPE: {type(v)}")


if __name__ == "__main__":
    test()
