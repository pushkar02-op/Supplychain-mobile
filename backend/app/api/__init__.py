from fastapi import APIRouter
from app.api.stock_entry import router as stock_entry_router
from app.api.item import router as item_router
from app.api.batch import router as batch_router
from app.api.auth import router as auth_router
from app.api.dispatch_entry import router as dispatch_router
from app.api.rejection_entry import router as rejection_router
from app.api.audit_log import router as audit_router
from app.api.user import router as user_router
from app.api.invoice import router as invoice_router
from app.api.invoice_item import router as invoice_item_router
from app.api.order import router as order_router
from app.api.item_conversion_map import router as conversion_router
from app.api.reports import router as reports_router
from app.api.item_alias import router as item_alias_router

router = APIRouter(prefix="/v1")

router.include_router(stock_entry_router)
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
