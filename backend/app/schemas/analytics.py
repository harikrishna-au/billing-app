"""
Pydantic schemas for Analytics endpoints.
"""
from pydantic import BaseModel
from typing import List, Dict, Optional
from datetime import datetime


class RevenuePeriod(BaseModel):
    """Schema for revenue by period."""
    period: str
    revenue: float
    transaction_count: int


class TopMachine(BaseModel):
    """Schema for top performing machine."""
    machine_id: str
    machine_name: str
    revenue: float
    transaction_count: int


class RevenueAnalyticsResponse(BaseModel):
    """Schema for revenue analytics response."""
    total_revenue: float
    total_transactions: int
    average_transaction: float
    revenue_by_period: List[RevenuePeriod]
    revenue_by_method: Dict[str, float]
    top_machines: List[TopMachine]


class MachinePerformance(BaseModel):
    """Schema for machine performance metrics."""
    machine_id: str
    machine_name: str
    status: str
    revenue: float
    transaction_count: int
    uptime_percentage: float
    last_sync: Optional[datetime]
    average_transaction: float

    class Config:
        from_attributes = True
