"""
Supplier Norm Rule Service.

CRUD operations for supplier item normalization rules,
plus the high-level orchestration for generating norm suggestions
and stock entries from verified bills.
"""

import logging
from datetime import datetime
from decimal import Decimal
from typing import Dict, List, Optional

from app.core.exceptions import AppException
from app.db.models.item import Item
from app.db.models.mart import Mart
from app.db.models.mart_bill import MartBill
from app.db.models.mart_bill_item import MartBillItem
from app.db.models.stock_entry import StockEntry
from app.db.models.supplier_item_norm_rule import SupplierItemNormRule
from app.db.schemas.supplier_norm_rule import (
    GenerateStockItem,
    GenerateStockResponse,
    GenerateStockSkipped,
    NormSuggestionItem,
    NormSuggestionsResponse,
    RuleConfirmation,
    RuleConfirmationResponse,
    TargetItemBrief,
)
from app.services.audit import log_action
from app.services.norm_rule_engine import (
    RuleType,
    SuggestionSource,
    suggest_normalization,
)
from app.services.suffix_parser import extract_item_name_stem
from app.services.warehouse_scope import resolve_system_warehouse_id
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


# ── Norm Suggestions ──────────────────────────────────────────────────


def get_norm_suggestions(
    db: Session,
    bill_id: int,
    warehouse_id: Optional[int] = None,
) -> NormSuggestionsResponse:
    """Generate normalization suggestions for all MAPPED items in a bill.

    Only processes items where resolution_status = 'MAPPED' and item_id is set.
    """
    resolved_wh = resolve_system_warehouse_id(db, warehouse_id)

    # Load bill with its mart for company_name
    bill = (
        db.query(MartBill)
        .filter(MartBill.id == bill_id, MartBill.warehouse_id == resolved_wh)
        .first()
    )
    if not bill:
        raise AppException("Bill not found", status_code=404)

    # Get company_name from the mart
    mart = (
        db.query(Mart).filter(Mart.id == bill.mart_id).first() if bill.mart_id else None
    )
    company_name = mart.company_name if mart else (bill.mart_name or "unknown")
    format_type = bill.format_type or "zomato"

    # Load all MAPPED bill items
    bill_items = (
        db.query(MartBillItem)
        .filter(
            MartBillItem.invoice_id == bill_id,
            MartBillItem.resolution_status == "MAPPED",
            MartBillItem.item_id.isnot(None),
            MartBillItem.warehouse_id == resolved_wh,
        )
        .all()
    )

    if not bill_items:
        return NormSuggestionsResponse(
            bill_id=bill_id,
            suggestions=[],
            auto_count=0,
            confirm_count=0,
            review_count=0,
            manual_count=0,
        )

    # Pre-load all target items
    item_ids = list({bi.item_id for bi in bill_items})
    items_map: Dict[int, Item] = {
        item.id: item for item in db.query(Item).filter(Item.id.in_(item_ids)).all()
    }

    # Check for already-generated stock entries
    bill_item_ids = [bi.id for bi in bill_items]
    existing_stock = set(
        row[0]
        for row in db.query(StockEntry.source_bill_item_id)
        .filter(
            StockEntry.source_bill_item_id.in_(bill_item_ids),
            StockEntry.is_active == True,  # noqa: E712
        )
        .all()
        if row[0] is not None
    )

    suggestions = []
    auto_count = confirm_count = review_count = manual_count = 0

    for bi in bill_items:
        target_item = items_map.get(bi.item_id)
        if not target_item or not target_item.default_uom_code:
            # Item exists but has no UOM configured — manual
            suggestions.append(
                NormSuggestionItem(
                    bill_item_id=bi.id,
                    item_name=bi.item_name,
                    item_code=bi.item_code,
                    billed_qty=bi.quantity,
                    billed_uom=bi.uom,
                    target_item=TargetItemBrief(
                        id=target_item.id if target_item else 0,
                        name=target_item.name if target_item else "Unknown",
                        stock_uom="unknown",
                    ),
                    rule_type=RuleType.AMBIGUOUS_REVIEW,
                    rule_value=None,
                    stock_qty=None,
                    stock_uom="unknown",
                    source=SuggestionSource.AMBIGUOUS,
                    needs_confirmation=True,
                )
            )
            manual_count += 1
            continue

        # Skip if stock already generated for this bill item
        if bi.id in existing_stock:
            continue

        suggestion = suggest_normalization(
            db=db,
            item_name=bi.item_name,
            item_code=bi.item_code,
            raw_uom=bi.uom,
            billed_qty=bi.quantity,
            target_item_id=target_item.id,
            target_item_stock_uom=target_item.default_uom_code,
            company_name=company_name,
            warehouse_id=resolved_wh,
            format_type=format_type,
        )

        # Categorize
        if suggestion.source == SuggestionSource.CONFIRMED_RULE:
            auto_count += 1
        elif suggestion.rule_type == RuleType.AMBIGUOUS_REVIEW:
            manual_count += 1
        elif suggestion.rule_type == RuleType.RANGE_WEIGHT_REVIEW:
            review_count += 1
        else:
            confirm_count += 1

        suggestions.append(
            NormSuggestionItem(
                bill_item_id=bi.id,
                item_name=bi.item_name,
                item_code=bi.item_code,
                billed_qty=bi.quantity,
                billed_uom=bi.uom,
                target_item=TargetItemBrief(
                    id=target_item.id,
                    name=target_item.name,
                    stock_uom=target_item.default_uom_code,
                ),
                rule_type=suggestion.rule_type,
                rule_value=suggestion.rule_value,
                stock_qty=suggestion.stock_qty,
                stock_uom=suggestion.stock_uom,
                source=suggestion.source,
                existing_rule_id=suggestion.existing_rule_id,
                needs_confirmation=suggestion.needs_confirmation,
                suffix_pattern=suggestion.suffix_pattern,
                range_low_kg=suggestion.range_low_kg,
                range_high_kg=suggestion.range_high_kg,
            )
        )

    return NormSuggestionsResponse(
        bill_id=bill_id,
        suggestions=suggestions,
        auto_count=auto_count,
        confirm_count=confirm_count,
        review_count=review_count,
        manual_count=manual_count,
    )


# ── Rule Confirmation ─────────────────────────────────────────────────


def confirm_rules(
    db: Session,
    bill_id: int,
    confirmations: List[RuleConfirmation],
    user_id: Optional[int] = None,
    warehouse_id: Optional[int] = None,
) -> RuleConfirmationResponse:
    """Confirm normalization rules for bill items, creating/updating stored rules."""
    resolved_wh = resolve_system_warehouse_id(db, warehouse_id)

    bill = (
        db.query(MartBill)
        .filter(MartBill.id == bill_id, MartBill.warehouse_id == resolved_wh)
        .first()
    )
    if not bill:
        raise AppException("Bill not found", status_code=404)

    mart = (
        db.query(Mart).filter(Mart.id == bill.mart_id).first() if bill.mart_id else None
    )
    company_name = mart.company_name if mart else (bill.mart_name or "unknown")

    # Load bill items by ID
    bill_item_ids = [c.bill_item_id for c in confirmations]
    bill_items_map = {
        bi.id: bi
        for bi in db.query(MartBillItem)
        .filter(MartBillItem.id.in_(bill_item_ids))
        .all()
    }

    created_rule_ids = []

    for conf in confirmations:
        if not conf.accepted:
            continue

        bi = bill_items_map.get(conf.bill_item_id)
        if not bi or not bi.item_id:
            continue

        item_name_stem = extract_item_name_stem(bi.item_name)

        # Try to find existing rule to update
        existing = (
            db.query(SupplierItemNormRule)
            .filter(
                SupplierItemNormRule.company_name == company_name,
                SupplierItemNormRule.item_code == bi.item_code,
                SupplierItemNormRule.raw_uom == bi.uom,
                SupplierItemNormRule.warehouse_id == resolved_wh,
            )
            .first()
        )

        if existing:
            existing.rule_type = conf.rule_type
            existing.rule_value = conf.rule_value
            existing.target_item_id = bi.item_id
            existing.confirmed = True
            existing.confirmed_by = user_id
            existing.confirmed_at = datetime.utcnow()
            existing.updated_by = str(user_id) if user_id else None
            db.flush()
            created_rule_ids.append(existing.id)
        else:
            # Parse suffix for pattern keying
            from app.services.suffix_parser import parse_suffix

            suffix = parse_suffix(bi.item_name)

            new_rule = SupplierItemNormRule(
                company_name=company_name,
                item_code=bi.item_code,
                item_name_stem=item_name_stem,
                raw_uom=bi.uom,
                suffix_pattern=suffix.suffix_pattern,
                target_item_id=bi.item_id,
                rule_type=conf.rule_type,
                rule_value=conf.rule_value,
                confirmed=True,
                confirmed_by=user_id,
                confirmed_at=datetime.utcnow(),
                warehouse_id=resolved_wh,
                created_by=str(user_id) if user_id else None,
                updated_by=str(user_id) if user_id else None,
            )
            db.add(new_rule)
            db.flush()
            created_rule_ids.append(new_rule.id)

    try:
        log_action(
            db=db,
            actor_user_id=user_id or 0,
            action_type="norm_rules_confirmed",
            entity_type="mart_bill",
            entity_id=bill_id,
            metadata={
                "confirmed_count": len(created_rule_ids),
                "rule_ids": created_rule_ids,
            },
        )
    except Exception:
        logger.warning("Audit log failed for norm_rules_confirmed", exc_info=True)

    db.commit()

    return RuleConfirmationResponse(
        confirmed_count=len(created_rule_ids),
        created_rules=created_rule_ids,
    )


# ── Generate Stock Entries ────────────────────────────────────────────


def generate_stock_from_bill(
    db: Session,
    bill_id: int,
    user_id: Optional[int] = None,
    warehouse_id: Optional[int] = None,
) -> GenerateStockResponse:
    """Generate stock entries for all MAPPED items in a verified bill.

    Prerequisites:
    - Bill must be VERIFIED
    - All items must be MAPPED
    - Each item must have a confirmed norm rule OR auto-applicable rule

    Items without rules are skipped (not blocked).
    """
    from app.db.schemas.stock_entry import StockEntryCreate
    from app.services.stock_entry import create_stock_entry

    resolved_wh = resolve_system_warehouse_id(db, warehouse_id)

    bill = (
        db.query(MartBill)
        .filter(MartBill.id == bill_id, MartBill.warehouse_id == resolved_wh)
        .first()
    )
    if not bill:
        raise AppException("Bill not found", status_code=404)

    if bill.status != "VERIFIED":
        raise AppException(
            "Bill must be verified before generating stock entries",
            status_code=400,
        )

    # Get company info
    mart = (
        db.query(Mart).filter(Mart.id == bill.mart_id).first() if bill.mart_id else None
    )
    company_name = mart.company_name if mart else (bill.mart_name or "unknown")
    format_type = bill.format_type or "zomato"

    # Load MAPPED bill items
    bill_items = (
        db.query(MartBillItem)
        .filter(
            MartBillItem.invoice_id == bill_id,
            MartBillItem.resolution_status == "MAPPED",
            MartBillItem.item_id.isnot(None),
            MartBillItem.warehouse_id == resolved_wh,
        )
        .all()
    )

    # Check for unresolved items
    unresolved_count = (
        db.query(MartBillItem)
        .filter(
            MartBillItem.invoice_id == bill_id,
            MartBillItem.resolution_status == "UNRESOLVED",
            MartBillItem.warehouse_id == resolved_wh,
        )
        .count()
    )
    if unresolved_count > 0:
        raise AppException(
            f"Cannot generate stock: {unresolved_count} item(s) are still unresolved",
            status_code=400,
        )

    # Pre-load items
    item_ids = list({bi.item_id for bi in bill_items})
    items_map = {
        item.id: item for item in db.query(Item).filter(Item.id.in_(item_ids)).all()
    }

    # Check for already-generated entries
    bill_item_ids = [bi.id for bi in bill_items]
    existing_stock = set(
        row[0]
        for row in db.query(StockEntry.source_bill_item_id)
        .filter(
            StockEntry.source_bill_item_id.in_(bill_item_ids),
            StockEntry.is_active == True,  # noqa: E712
        )
        .all()
        if row[0] is not None
    )

    created = []
    skipped = []

    for bi in bill_items:
        # Skip if already generated
        if bi.id in existing_stock:
            skipped.append(
                GenerateStockSkipped(
                    bill_item_id=bi.id,
                    item_name=bi.item_name,
                    reason="Stock entry already exists",
                )
            )
            continue

        target_item = items_map.get(bi.item_id)
        if not target_item or not target_item.default_uom_code:
            skipped.append(
                GenerateStockSkipped(
                    bill_item_id=bi.id,
                    item_name=bi.item_name,
                    reason="Item has no default UOM configured",
                )
            )
            continue

        # Get suggestion (should find confirmed rule or parser suggestion)
        suggestion = suggest_normalization(
            db=db,
            item_name=bi.item_name,
            item_code=bi.item_code,
            raw_uom=bi.uom,
            billed_qty=bi.quantity,
            target_item_id=target_item.id,
            target_item_stock_uom=target_item.default_uom_code,
            company_name=company_name,
            warehouse_id=resolved_wh,
            format_type=format_type,
        )

        # Only generate stock for items with a determined rule_value
        if suggestion.rule_value is None or suggestion.stock_qty is None:
            skipped.append(
                GenerateStockSkipped(
                    bill_item_id=bi.id,
                    item_name=bi.item_name,
                    reason=f"No confirmed normalization rule ({suggestion.rule_type})",
                )
            )
            continue

        # Skip unconfirmed suggestions (user must confirm first via the preview screen)
        if suggestion.needs_confirmation:
            skipped.append(
                GenerateStockSkipped(
                    bill_item_id=bi.id,
                    item_name=bi.item_name,
                    reason="Rule needs confirmation before stock can be generated",
                )
            )
            continue

        # Compute price per stock unit
        # bill price is per billed unit, we need price per stock unit
        if suggestion.rule_value and suggestion.rule_value != Decimal("0"):
            price_per_stock_unit = bi.price / suggestion.rule_value
        else:
            price_per_stock_unit = bi.price

        total_cost = suggestion.stock_qty * price_per_stock_unit

        # Derive invoice date for received_date

        received_date = (
            bi.invoice_date.date()
            if hasattr(bi.invoice_date, "date")
            else bi.invoice_date
        )

        # Idempotency key
        idempotency_key = f"bill_{bill_id}_item_{bi.id}"

        try:
            entry_data = StockEntryCreate(
                item_id=target_item.id,
                warehouse_id=resolved_wh,
                received_date=received_date,
                price_per_unit=price_per_stock_unit,
                total_cost=total_cost,
                source=f"Bill #{bill_id}",
                quantity=suggestion.stock_qty,
                unit=suggestion.stock_uom,
            )

            stock_entry = create_stock_entry(
                db=db,
                entry=entry_data,
                created_by=user_id,
                idempotency_key=idempotency_key,
                warehouse_id=resolved_wh,
            )

            # Set source_bill_item_id (not in StockEntryCreate schema)
            stock_entry.source_bill_item_id = bi.id
            db.flush()

            created.append(
                GenerateStockItem(
                    bill_item_id=bi.id,
                    item_name=bi.item_name,
                    stock_entry_id=stock_entry.id,
                    stock_qty=suggestion.stock_qty,
                    stock_uom=suggestion.stock_uom,
                    price_per_unit=price_per_stock_unit,
                    total_cost=total_cost,
                )
            )

        except Exception as e:
            logger.error(
                f"Failed to create stock entry for bill_item {bi.id}: {e}",
                exc_info=True,
            )
            skipped.append(
                GenerateStockSkipped(
                    bill_item_id=bi.id,
                    item_name=bi.item_name,
                    reason=f"Error: {str(e)[:200]}",
                )
            )

    try:
        log_action(
            db=db,
            actor_user_id=user_id or 0,
            action_type="stock_generated_from_bill",
            entity_type="mart_bill",
            entity_id=bill_id,
            metadata={
                "created_count": len(created),
                "skipped_count": len(skipped),
                "warehouse_id": resolved_wh,
            },
        )
    except Exception:
        logger.warning("Audit log failed for stock_generated_from_bill", exc_info=True)

    db.commit()

    return GenerateStockResponse(
        bill_id=bill_id,
        created=created,
        skipped=skipped,
        total_created=len(created),
        total_skipped=len(skipped),
    )
