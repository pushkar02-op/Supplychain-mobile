from datetime import datetime
from pydantic import BaseModel

class AuditLogRead(BaseModel):
    id: int
    user_id: int
    action_type: str
    table_name: str
    record_id: int
    timestamp: datetime
    changes: str

    class Config:
        orm_mode = True
