from fastapi import APIRouter
from app.api.stock_entry import router as stock_entry_router


router = APIRouter()

router.include_router(stock_entry_router, prefix="/stock-entry", tags=["Stock Entry"])
