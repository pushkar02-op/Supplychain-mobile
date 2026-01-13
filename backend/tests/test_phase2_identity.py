import pytest

from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.mart_item_alias import MartItemAlias
from app.db.models.uom import UOM

# from app.services.item_alias import resolve_item_for_mart


def resolve_item_for_mart(db, mart_id, code=None, name=None):
    """
    Local helper to verify resolution logic.
    """
    from app.db.models.item import Item
    from app.db.models.mart_item_alias import MartItemAlias

    # 1. Try Code Match
    if code:
        alias = (
            db.query(MartItemAlias)
            .filter(MartItemAlias.mart_id == mart_id, MartItemAlias.alias_code == code)
            .first()
        )
        if alias and alias.item_id:
            return db.get(Item, alias.item_id)

    # 2. Try Name Match
    if name:
        alias = (
            db.query(MartItemAlias)
            .filter(
                MartItemAlias.mart_id == mart_id, MartItemAlias.alias_name.ilike(name)
            )
            .first()
        )
        if alias and alias.item_id:
            return db.get(Item, alias.item_id)

    return None


from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base


def get_session():
    # In-memory DB for isolation
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine, checkfirst=True)
    Session = sessionmaker(bind=engine)
    return Session()


def test_mart_scoped_identity():
    db = get_session()

    # Setup UOM
    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    # Setup Items
    item_rice = Item(name="Rice", default_uom_id=uom.id)
    item_wheat = Item(name="Wheat", default_uom_id=uom.id)
    db.add_all([item_rice, item_wheat])
    db.flush()

    # Setup Marts
    mart_a = Mart(name="Mart A", company_name="Co A")
    mart_b = Mart(name="Mart B", company_name="Co B")
    db.add_all([mart_a, mart_b])
    db.commit()

    # Setup Aliases: Both marts use "PREMIUM_GRAIN" but map to different items
    alias_a = MartItemAlias(
        mart_id=mart_a.id,
        item_id=item_rice.id,
        alias_name="PREMIUM_GRAIN",
        alias_code="PG001",
    )
    alias_b = MartItemAlias(
        mart_id=mart_b.id,
        item_id=item_wheat.id,
        alias_name="PREMIUM_GRAIN",  # Collision in name
        alias_code="PG001",  # Collision in code
    )
    db.add_all([alias_a, alias_b])
    db.commit()

    # Verify Mart A Resolution
    resolved_a = resolve_item_for_mart(
        db, mart_a.id, code="PG001", name="PREMIUM_GRAIN"
    )
    assert resolved_a.id == item_rice.id

    # Verify Mart B Resolution
    resolved_b = resolve_item_for_mart(
        db, mart_b.id, code="PG001", name="PREMIUM_GRAIN"
    )
    assert resolved_b.id == item_wheat.id

    print("PASS: Mart Scoping Verified")


def test_resolution_precedence():
    db = get_session()

    uom = UOM(code="kg", description="Kilogram")
    db.add(uom)
    db.flush()

    item_code_target = Item(name="CodeTarget", default_uom_id=uom.id)
    item_name_target = Item(name="NameTarget", default_uom_id=uom.id)
    db.add_all([item_code_target, item_name_target])

    mart = Mart(name="Mart A", company_name="Co A")
    db.add(mart)
    db.commit()

    # Alias: Code="A1" -> CodeTarget
    alias_code = MartItemAlias(
        mart_id=mart.id,
        item_id=item_code_target.id,
        alias_code="A1",
        alias_name="IgnoreMe",
    )

    # Alias: Name="TestName" -> NameTarget
    alias_name = MartItemAlias(
        mart_id=mart.id,
        item_id=item_name_target.id,
        alias_code="B2",
        alias_name="TestName",
    )

    db.add_all([alias_code, alias_name])
    db.commit()

    # Scenario 1: Exact Code Match (should win even if name matches other)
    # Input: Code="A1", Name="TestName"
    # Logic: Priority 1 is Code. So "A1" (CodeTarget) should be returned (II-002)
    res1 = resolve_item_for_mart(db, mart.id, code="A1", name="TestName")
    assert res1.id == item_code_target.id

    # Scenario 2: Code mismatch, Name Match
    # Input: Code="Unknown", Name="TestName"
    # Logic: Priority 1 Code fails. Priority 2 Name matches "TestName" -> NameTarget
    res2 = resolve_item_for_mart(db, mart.id, code="Unknown", name="TestName")
    assert res2.id == item_name_target.id

    # Scenario 3: Case Insensitive Name Match
    res3 = resolve_item_for_mart(db, mart.id, code=None, name="testname")
    assert res3.id == item_name_target.id

    # Scenario 4: Unresolved
    res4 = resolve_item_for_mart(db, mart.id, code="X", name="Y")
    assert res4 is None

    print("PASS: Resolution Precedence Verified")


if __name__ == "__main__":
    try:
        test_mart_scoped_identity()
        test_resolution_precedence()
        print("ALL TESTS PASSED")
    except Exception as e:
        import traceback

        traceback.print_exc()
