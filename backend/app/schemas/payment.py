"""
Pydantic schemas for Payment endpoints.
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


class PaymentCreate(BaseModel):
    """Schema for creating a new payment (manual entry)."""
    machine_id: str = Field(..., description="Machine UUID")
    bill_number: str = Field(..., min_length=1, max_length=100, description="Bill/transaction number")
    amount: float = Field(..., gt=0, description="Payment amount")
    method: str = Field(..., description="Payment method")
    status: str = Field(default="success", pattern="^(success|pending|failed)$", description="Payment status")

    @field_validator('method')
    @classmethod
    def validate_method(cls, v: str) -> str:
        if v.upper() not in ['UPI', 'CARD', 'CASH']:
            raise ValueError("Method must be UPI, Card, or Cash")
        
        # Normalize to Title Case for consistency
        if v.upper() == 'UPI':
            return 'UPI'
        return v.capitalize()


class PaymentUpdate(BaseModel):
    """Schema for updating an existing payment."""
    bill_number: Optional[str] = Field(None, min_length=1, max_length=100)
    amount: Optional[float] = Field(None, gt=0)
    method: Optional[str] = Field(None, pattern="^(UPI|Card|Cash)$")
    status: Optional[str] = Field(None, pattern="^(success|pending|failed)$")


class PaymentResponse(BaseModel):
    """Schema for payment response."""
    id: str
    machine_id: str
    bill_number: str
    amount: float
    method: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class PaymentWithMachineResponse(BaseModel):
    """Schema for payment response with machine details."""
    id: str
    machine_id: str
    machine_name: str
    bill_number: str
    amount: float
    method: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class PaymentSummary(BaseModel):
    """Schema for payment summary statistics."""
    total_amount: float
    total_count: int
    upi_amount: float
    card_amount: float
    cash_amount: float
    success_count: int
    pending_count: int
    failed_count: int


class PaymentListResponse(BaseModel):
    """Schema for paginated payment list with summary."""
    payments: list[PaymentWithMachineResponse]
    pagination: dict
    summary: PaymentSummary
