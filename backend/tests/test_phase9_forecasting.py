"""
Phase 9 Forecasting Tests

Verifies:
- Burn rate calculation correctness
- Depletion math correctness
- Zero-outflow handling
- Signal classification correctness
- No domain table mutations
"""

import pytest
from datetime import date, datetime, timedelta
from decimal import Decimal
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models.inventory_flow_daily import InventoryFlowDaily
from app.db.models.item import Item
from app.db.models.item_burn_rate import ItemBurnRate
from app.db.models.stock_depletion_forecast import StockDepletionForecast
from app.db.models.uom import UOM
from app.db.models.batch import Batch
from app.db.models.warehouse import Warehouse
from app.services.forecasting import (
    classify_signal,
    compute_burn_rate,
    compute_depletion_forecast,
    refresh_forecast_for_item,
    get_forecast_summary,
    SIGNAL_CRITICAL,
    SIGNAL_REORDER_SOON,
    SIGNAL_WATCH,
)


@pytest.fixture(scope="function")
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Session = sessionmaker(bind=engine)
    session = Session()

    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    session.add(Warehouse(name="Main Warehouse", code="MAIN", is_active=True))
    session.commit()

    # Cleanup Phase 9 tables
    session.rollback()
    session.query(ItemBurnRate).delete()
    session.query(StockDepletionForecast).delete()
    session.query(InventoryFlowDaily).delete()
    session.commit()

    yield session
    session.close()


# ================== Signal Classification Tests ==================


def test_classify_signal_critical():
    """CRITICAL when days_to_zero < 3"""
    assert classify_signal(0) == "CRITICAL"
    assert classify_signal(1) == "CRITICAL"
    assert classify_signal(2.9) == "CRITICAL"


def test_classify_signal_reorder_soon():
    """REORDER_SOON when 3 <= days_to_zero < 7"""
    assert classify_signal(3) == "REORDER_SOON"
    assert classify_signal(5) == "REORDER_SOON"
    assert classify_signal(6.9) == "REORDER_SOON"


def test_classify_signal_watch():
    """WATCH when 7 <= days_to_zero < 14"""
    assert classify_signal(7) == "WATCH"
    assert classify_signal(10) == "WATCH"
    assert classify_signal(13.9) == "WATCH"


def test_classify_signal_stable():
    """STABLE when days_to_zero >= 14 or None"""
    assert classify_signal(14) == "STABLE"
    assert classify_signal(100) == "STABLE"
    assert classify_signal(None) == "STABLE"


# ================== Burn Rate Calculation Tests ==================


def test_burn_rate_with_flow_data(db_session):
    """Burn rate should aggregate outflow from InventoryFlowDaily"""
    # Setup: Create item and flow data
    uom = db_session.query(UOM).filter_by(code="kg").first()
    if not uom:
        uom = UOM(code="kg", description="Kilogram")
        db_session.add(uom)
        db_session.commit()

    item = db_session.query(Item).filter_by(id=901).first()
    if not item:
        item = Item(id=901, name="Burn Rate Test Item", default_uom_id=uom.id)
        db_session.add(item)
        db_session.commit()

    # Add flow data for last 7 days (10 units out per day)
    today = date.today()
    for i in range(7):
        flow_date = today - timedelta(days=i)
        flow = InventoryFlowDaily(
            item_id=901, date=flow_date, in_qty=0.0, out_qty=10.0, net_qty=-10.0
        )
        db_session.add(flow)
    db_session.commit()

    # Test
    result = compute_burn_rate(db_session, 901)

    # Verify
    assert result["avg_daily_outflow_7d"] == 10.0  # 70 / 7 = 10
    assert result["avg_daily_outflow_14d"] == 5.0  # 70 / 14 = 5
    assert float(result["avg_daily_outflow_30d"]) == pytest.approx(70 / 30, rel=0.01)


def test_burn_rate_no_flow_data(db_session):
    """Burn rate should be 0 when no flow data exists"""
    result = compute_burn_rate(db_session, 999)  # Non-existent item

    assert result["avg_daily_outflow_7d"] == 0.0
    assert result["avg_daily_outflow_14d"] == 0.0
    assert result["avg_daily_outflow_30d"] == 0.0


# ================== Depletion Forecast Tests ==================


def test_depletion_forecast_normal(db_session):
    """days_to_zero = ledger_qty / avg_outflow"""
    # Setup: Create item with stock
    uom = db_session.query(UOM).filter_by(code="kg").first()
    if not uom:
        uom = UOM(code="kg", description="Kilogram")
        db_session.add(uom)
        db_session.commit()

    item = db_session.query(Item).filter_by(id=902).first()
    if not item:
        item = Item(id=902, name="Depletion Test Item", default_uom_id=uom.id)
        db_session.add(item)
        db_session.commit()

    # Clean up existing batches
    db_session.query(Batch).filter(Batch.item_id == 902).delete()

    # Add batch with 100 units
    batch = Batch(
        item_id=902,
        warehouse_id=1,
        quantity=100.0,
        unit="kg",
        received_at=datetime.utcnow(),
    )
    db_session.add(batch)
    db_session.commit()

    # Test: With 100 units and 10/day outflow = 10 days
    result = compute_depletion_forecast(db_session, 902, 10.0)

    assert result["current_ledger_qty"] == 100.0
    assert result["avg_daily_outflow"] == 10.0
    assert result["days_to_zero"] == 10.0
    assert result["projected_stockout_date"] == date.today() + timedelta(days=10)


def test_depletion_forecast_zero_outflow(db_session):
    """Zero outflow should return None for days_to_zero (STABLE)"""
    result = compute_depletion_forecast(db_session, 999, 0.0)

    assert result["days_to_zero"] is None
    assert result["projected_stockout_date"] is None
    assert classify_signal(result["days_to_zero"]) == "STABLE"


def test_depletion_forecast_no_divide_by_zero(db_session):
    """Guard against division by zero"""
    # This should not raise an exception
    result = compute_depletion_forecast(db_session, 999, 0)

    assert result["days_to_zero"] is None
    assert result["avg_daily_outflow"] == 0.0


# ================== Integration Tests ==================


def test_refresh_forecast_for_item(db_session):
    """Full refresh should persist burn rate and forecast"""
    # Setup
    uom = db_session.query(UOM).filter_by(code="kg").first()
    if not uom:
        uom = UOM(code="kg", description="Kilogram")
        db_session.add(uom)
        db_session.commit()

    item = db_session.query(Item).filter_by(id=903).first()
    if not item:
        item = Item(id=903, name="Refresh Test Item", default_uom_id=uom.id)
        db_session.add(item)
        db_session.commit()

    # Clean up existing batches
    db_session.query(Batch).filter(Batch.item_id == 903).delete()

    # Add batch
    batch = Batch(
        item_id=903,
        warehouse_id=1,
        quantity=50.0,
        unit="kg",
        received_at=datetime.utcnow(),
    )
    db_session.add(batch)

    # Add flow data
    today = date.today()
    for i in range(7):
        flow = InventoryFlowDaily(
            item_id=903,
            date=today - timedelta(days=i),
            in_qty=0.0,
            out_qty=5.0,
            net_qty=-5.0,
        )
        db_session.add(flow)
    db_session.commit()

    # Test
    result = refresh_forecast_for_item(db_session, 903)

    # Verify persisted data
    burn_rate = db_session.query(ItemBurnRate).filter_by(item_id=903).first()
    forecast = db_session.query(StockDepletionForecast).filter_by(item_id=903).first()

    assert burn_rate is not None
    assert burn_rate.avg_daily_outflow_7d == 5.0

    assert forecast is not None
    assert forecast.current_ledger_qty == 50.0
    assert forecast.days_to_zero == 10.0  # 50 / 5 = 10

    assert result["signal"] == "WATCH"  # 10 days = WATCH


def test_no_domain_table_mutations(db_session):
    """Forecasting should NOT mutate Item, Batch, InventoryTxn"""
    from app.db.models.inventory_txn import InventoryTxn

    # Setup: Create a valid item to avoid FK/Integrity errors
    uom = db_session.query(UOM).filter_by(code="kg").first()
    if not uom:
        uom = UOM(code="kg", description="Kilogram")
        db_session.add(uom)
        db_session.commit()

    item = db_session.query(Item).filter_by(name="Mutation Test Item").first()
    if not item:
        item = Item(name="Mutation Test Item", default_uom_id=uom.id)
        db_session.add(item)
        db_session.commit()
    item_id = item.id

    # Get counts before
    item_count_before = db_session.query(Item).count()
    txn_count_before = db_session.query(InventoryTxn).count()

    # Run forecast refresh
    refresh_forecast_for_item(db_session, item_id)

    # Get counts after
    item_count_after = db_session.query(Item).count()
    txn_count_after = db_session.query(InventoryTxn).count()

    # Verify no mutations to domain tables
    assert item_count_before == item_count_after
    assert txn_count_before == txn_count_after
