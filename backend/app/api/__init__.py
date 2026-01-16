from app.api.admin_ledger import router as admin_ledger_router
from app.api.admin_reconciliation import router as admin_recon_router
from app.api.audit_log import router as audit_router
from app.api.auth import router as auth_router
from app.api.batch import router as batch_router
from app.api.dispatch_entry import router as dispatch_router
from app.api.inventory_txn import router as inventory_txn_router
from app.api.invoice import router as invoice_router
from app.api.invoice_item import router as invoice_item_router
from app.api.item import router as item_router
from app.api.item_alias import router as item_alias_router
from app.api.item_conversion_map import router as conversion_router
from app.api.item_management import router as item_management_router
from app.api.mart import router as mart_router
from app.api.mart_bill import router as mart_bill_router
from app.api.mart_bill_item import router as mart_bill_item_router
from app.api.order import router as order_router
from app.api.rejection_entry import router as rejection_router
from app.api.reports import router as reports_router
from app.api.stock_adjustment import router as stock_adjustment_router
from app.api.stock_entry import router as stock_entry_router
from app.api.uom import router as uom_router
from app.api.user import router as user_router
from fastapi import APIRouter

router = APIRouter(prefix="/v1")

router.include_router(stock_entry_router)
router.include_router(stock_adjustment_router)
router.include_router(item_router)
router.include_router(batch_router)
router.include_router(auth_router)
router.include_router(dispatch_router)
router.include_router(rejection_router)
router.include_router(audit_router)
router.include_router(user_router)
router.include_router(invoice_router)
router.include_router(invoice_item_router)
router.include_router(order_router)
router.include_router(conversion_router)
router.include_router(reports_router)
router.include_router(item_alias_router)
router.include_router(uom_router)
router.include_router(inventory_txn_router)
router.include_router(mart_router)
router.include_router(item_management_router)
router.include_router(admin_ledger_router)
router.include_router(admin_recon_router)
router.include_router(mart_bill_router)
router.include_router(mart_bill_item_router)
