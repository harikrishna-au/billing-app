"""
Pydantic schemas for Sync endpoints.
"""
from pydantic import BaseModel, Field, field_validator
from typing import List, Optional
from datetime import datetime


class PaymentSync(BaseModel):
    """Schema for payment data during sync."""
    machine_id: str
    bill_number: str
    amount: float
    method: str
    status: str = Field(default="success", pattern="^(success|pending|failed)$")
    created_at: Optional[datetime] = None

    @field_validator('method')
    @classmethod
    def normalize_method(cls, v: str) -> str:
        """Normalize method to title-case (Flutter sends CASH/UPI/CARD uppercase)."""
        upper = v.strip().upper()
        if upper == 'UPI':
            return 'UPI'
        elif upper == 'CASH':
            return 'Cash'
        elif upper == 'CARD':
            return 'Card'
        raise ValueError("Method must be UPI, Card, or Cash")


class SyncPushRequest(BaseModel):
    """Schema for pushing offline data to server."""
    machine_id: str
    payments: List[PaymentSync] = []
    last_sync: Optional[datetime] = None
    client_bill_counter: int = 0


class SyncPushResponse(BaseModel):
    """Schema for sync push response."""
    synced_payments: int
    failed_payments: int
    sync_timestamp: datetime
    latest_bill_counter: int = 0


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
