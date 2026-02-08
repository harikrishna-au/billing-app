"""
Pydantic schemas for Sync endpoints.
"""
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class PaymentSync(BaseModel):
    """Schema for payment data during sync."""
    machine_id: str
    bill_number: str
    amount: float
    method: str = Field(..., pattern="^(UPI|Card|Cash)$")
    status: str = Field(default="success", pattern="^(success|pending|failed)$")
    created_at: Optional[datetime] = None


class SyncPushRequest(BaseModel):
    """Schema for pushing offline data to server."""
    machine_id: str
    payments: List[PaymentSync] = []
    last_sync: Optional[datetime] = None


class SyncPushResponse(BaseModel):
    """Schema for sync push response."""
    synced_payments: int
    failed_payments: int
    sync_timestamp: datetime


class SyncPullResponse(BaseModel):
    """Schema for sync pull response."""
    services: List[dict]
    machine_status: str
    sync_timestamp: datetime


class SyncStatusResponse(BaseModel):
    """Schema for sync status response."""
    machine_id: str
    last_sync: Optional[datetime]
    status: str
    pending_uploads: int = 0
