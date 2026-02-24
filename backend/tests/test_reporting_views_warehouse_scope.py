from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VIEWS_ROOT = ROOT / "app" / "db" / "views"


def _read(view_name: str) -> str:
    return (VIEWS_ROOT / view_name).read_text(encoding="utf-8").lower()


def test_inventory_summary_view_contains_warehouse_scope():
    sql = _read("inventory_summary_view.sql")
    assert "warehouse_id" in sql
    assert "group by" in sql
    assert "group by iv.warehouse_id" in sql


def test_inventory_signal_view_contains_warehouse_scope():
    sql = _read("inventory_signal_view.sql")
    assert "warehouse_id" in sql
    assert "group by warehouse_id, item_id" in sql


def test_batch_ledger_balance_view_contains_warehouse_scope():
    sql = _read("batch_ledger_balance_view.sql")
    assert "warehouse_id" in sql
    assert "group by warehouse_id, batch_id" in sql


def test_pnl_summary_view_contains_warehouse_scope():
    sql = _read("pnl_summary_view.sql")
    assert "warehouse_id" in sql
    assert "coalesce(s.warehouse_id, c.warehouse_id)" in sql
    assert "s.warehouse_id = c.warehouse_id" in sql
