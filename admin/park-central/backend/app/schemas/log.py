from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field

class LogBase(BaseModel):
    action: str = Field(..., min_length=1, max_length=255)
    details: Optional[str] = None
    type: str = Field(..., pattern="^(login|client|config|manager|system)$")

class LogCreate(LogBase):
    pass

class LogResponse(LogBase):
    id: str
    machine_id: str
    created_at: datetime
    machine_name: Optional[str] = None  # Generic machine name field if joined

    class Config:
        from_attributes = True

class LogListResponse(BaseModel):
    logs: List[LogResponse]
    pagination: dict
