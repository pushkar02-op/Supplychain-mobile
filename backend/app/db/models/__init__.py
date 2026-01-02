# backend/app/db/models/__init__.py
"""
Explicit re-exports for model classes.
This file intentionally uses `Name as Name` to satisfy linters that expect explicit re-exports.
Do not place runtime logic in this module.
"""

from .audit_log import AuditLog as AuditLog
from .auth import RefreshToken as RefreshToken
from .batch import Batch as Batch
from .dispatch_entry import DispatchEntry as DispatchEntry
from .dispatch_reversal import DispatchReversal as DispatchReversal
from .idempotency_record import IdempotencyRecord
from .inventory_txn import InventoryTxn as InventoryTxn
from .invoice import Invoice as Invoice
from .invoice_item import InvoiceItem as InvoiceItem
from .item import Item as Item
from .item_alias import ItemAlias as ItemAlias
from .item_conversion_map import ItemConversionMap as ItemConversionMap
from .mart import Mart as Mart
from .order import Order as Order
from .rejection_entry import RejectionEntry as RejectionEntry
from .stock_entry import StockEntry as StockEntry
from .uom import UOM as UOM
from .user import User as User

# Exported names for `from app.db.models import *` or explicit import consumers.
__all__ = [
    "User",
    "Item",
    "Batch",
    "StockEntry",
    "DispatchEntry",
    "DispatchReversal",
    "Invoice",
    "RejectionEntry",
    "InvoiceItem",
    "Order",
    "ItemConversionMap",
    "AuditLog",
    "ItemAlias",
    "InventoryTxn",
    "UOM",
    "Mart",
    "RefreshToken",
    "IdempotencyRecord",
]
