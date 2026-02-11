"""
Pydantic schemas for Machine endpoints.
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class MachineCreate(BaseModel):
    """Schema for creating a new machine."""
    name: str = Field(..., min_length=1, max_length=255, description="Machine display name")
    location: str = Field(..., min_length=1, max_length=255, description="Physical location")
    username_prefix: str = Field(default="admin", min_length=1, max_length=50, description="Username prefix for auto-generation")
    password: str = Field(..., min_length=4, description="Machine login password")


class MachineUpdate(BaseModel):
    """Schema for updating an existing machine."""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    location: Optional[str] = Field(None, min_length=1, max_length=255)
    username: Optional[str] = Field(None, min_length=1, max_length=100)
    password: Optional[str] = Field(None, min_length=4, description="Leave empty to keep current password")
    status: Optional[str] = Field(None, pattern="^(online|offline|maintenance)$")


class MachineResponse(BaseModel):
    """Schema for machine response."""
    id: str
    user_id: str
    name: str
    location: str
    username: str
    status: str
    last_sync: Optional[datetime]
    online_collection: float
    offline_collection: float
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MachineStatusUpdate(BaseModel):
    """Schema for updating machine status and sync time."""
    status: Optional[str] = Field(None, pattern="^(online|offline|maintenance)$")
    last_sync: Optional[datetime] = None
    online_collection: Optional[float] = None
    offline_collection: Optional[float] = None
