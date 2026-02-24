from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AuditLogRead(BaseModel):
    id: int
    actor_user_id: int
    action_type: str
    entity_type: str
    entity_id: Optional[int] = None
    metadata: Optional[dict] = Field(default=None, alias="event_metadata")
    created_at: datetime

    class Config:
        orm_mode = True
        allow_population_by_field_name = True
