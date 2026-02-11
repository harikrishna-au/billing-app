from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from enum import Enum


class AlertSeverity(str, Enum):
    """Alert severity levels"""
    CRITICAL = "critical"
    WARNING = "warning"
    INFO = "info"


class AlertBase(BaseModel):
    """Base alert schema"""
    title: str = Field(..., max_length=200, description="Alert title")
    message: str = Field(..., max_length=500, description="Alert message")
    severity: AlertSeverity = Field(default=AlertSeverity.INFO, description="Alert severity level")
    machine_id: Optional[str] = Field(None, description="Related machine ID (optional)")


class AlertCreate(AlertBase):
    """Schema for creating a new alert"""
    pass


class AlertUpdate(BaseModel):
    """Schema for updating an alert"""
    resolved: Optional[bool] = Field(None, description="Mark alert as resolved/unresolved")
    title: Optional[str] = Field(None, max_length=200)
    message: Optional[str] = Field(None, max_length=500)
    severity: Optional[AlertSeverity] = None


class AlertResponse(AlertBase):
    """Schema for alert response"""
    id: str
    machine_name: Optional[str] = Field(None, description="Machine name if machine_id is set")
    resolved: bool
    resolved_at: Optional[datetime] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
