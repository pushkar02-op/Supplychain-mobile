from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class MartItemAliasBase(BaseModel):
    mart_id: int
    item_id: int
    alias_code: Optional[str] = None
    alias_name: str


class MartItemAliasCreate(MartItemAliasBase):
    pass


class MartItemAliasRead(MartItemAliasBase):
    id: int
    created_at: datetime
    created_by: Optional[str]

    class Config:
        orm_mode = True


class ResolutionRequest(BaseModel):
    # Used for bulk re-resolution or manual mapping
    mart_id: int
    # Optional logic: re-resolve all for mart, or specific ones.
    # For now, simplistic: Create alias triggers resolution.
    pass
