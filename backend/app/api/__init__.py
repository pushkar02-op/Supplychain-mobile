from fastapi import APIRouter
from app.api.stock_entry import router as stock_entry_router
from app.api.item import router as item_router
from app.api.batch import router as batch_router


router = APIRouter()

router.include_router(stock_entry_router, prefix="/stock-entry", tags=["Stock Entry"])
router.include_router(item_router, prefix="/item", tags=["Items"])
router.include_router(batch_router, prefix="/batch", tags=["Batches"])


