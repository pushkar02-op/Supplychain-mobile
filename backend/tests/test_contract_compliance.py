import pytest
from app.db.models.order import Order
from app.db.models.mart import Mart
from app.db.models.item import Item
from starlette.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_ord_009_zero_quantity_order_error_contract(
    db_session, create_mart, create_item
):
    """
    Verifies that attempting to create an order with 0 quantity returns:
    - 422 Unprocessable Entity
    - Response body containing:
      - rule_id: "ORD-009"
      - detail: "Quantity ordered must be greater than zero."
    """
    mart = create_mart(name="ContractTestMart")
    item = create_item(name="ContractTestItem")

    payload = {
        "item_id": item.id,
        "mart_name": mart.name,
        "order_date": "2025-01-01",
        "quantity_ordered": 0,  # VIOLATION: ORD-009
        "unit": "kg",
    }

    # Act
    # We expect this to fail validation in Pydantic first if schema enforces >0,
    # but service layer also checks it.
    # Let's see if Pydantic catches it. If so, Pydantic error usually doesn't have rule_id.
    # We need to hit the Service Layer raise.
    # If Schema allows 0 but Service forbids, we hit the App Exception.

    try:
        response = client.post("/v1/orders/", json=payload)
    except Exception as e:
        import traceback

        with open("/app/test_error.log", "w") as f:
            f.write(traceback.format_exc())
        raise e

    # Assert
    with open("/app/response.log", "w") as f:
        f.write(f"Status: {response.status_code}\n")
        f.write(f"Body: {response.text}\n")

    assert response.status_code == 422
    data = response.json()

    assert "detail" in data
    assert data.get("rule_id") == "ORD-009", (
        f"Expected rule_id 'ORD-009', got {data.get('rule_id')}"
    )


def test_ord_007_over_dispatch_error_contract(
    db_session, create_mart, create_item, client
):
    """
    Verifies that attempting to dispatch more than ordered returns:
    - 409 Conflict
    - Response body containing:
      - rule_id: "ORD-007"
      - extra metadata: requested_quantity, remaining_quantity
    """
    mart = create_mart(name="ContractTestMart2")
    item = create_item(name="ContractTestItem2")

    # Create Order (Quantity: 10)
    # We need to create an order first. The service create_order handles this.
    # But for simplicity in this test, we might need an order fixture or create via API.
    # Let's create via DB model directly to avoid circular dependency or service overhead.
    from app.db.models.order import Order
    from datetime import date

    order = Order(
        item_id=item.id,
        mart_id=mart.id,
        quantity_ordered=10,
        unit="kg",
        order_date=date.today(),
        status="Pending",
        quantity_dispatched=0,
    )
    db_session.add(order)
    db_session.commit()
    db_session.refresh(order)

    # Use a dummy batch
    from app.db.models.batch import Batch

    batch = Batch(
        item_id=item.id,
        quantity=100.0,  # Plenty of stock
        unit="kg",
        received_at=date.today(),
    )
    db_session.add(batch)
    db_session.commit()
    db_session.refresh(batch)

    # Act: Dispatch 15 (Exceeds 10)
    payload = {
        "item_id": item.id,
        "batch_id": batch.id,
        "mart_name": mart.name,
        "dispatch_date": str(date.today()),
        "quantity": 15,  # VIOLATION: ORD-007
        "unit": "kg",
        "order_id": order.id,
    }

    try:
        response = client.post("/v1/dispatch-entries/", json=payload)
    except Exception as e:
        import traceback

        with open("/app/test_error_ord007.log", "w") as f:
            f.write(traceback.format_exc())
        raise e

    # Assert
    assert response.status_code == 409
    data = response.json()

    assert "detail" in data
    assert data.get("rule_id") == "ORD-007", (
        f"Expected rule_id 'ORD-007', got {data.get('rule_id')}"
    )
    assert data.get("requested_quantity") == 15.0
    assert data.get("remaining_quantity") == 10.0
