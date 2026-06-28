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


class PaymentDetail(BaseModel):
    """Schema for individual payment in summary."""
    bill_number: str
    amount: float
    method: str
    status: str


class TransactionSummaryResponse(BaseModel):
    """Schema for transaction summary report."""
    date: str
    start_time: str
    end_time: str
    payments: List[PaymentDetail]
    successful_count: int
    successful_amount: float
    successful_cash: float
    successful_upi: float
    successful_card: float
    failed_count: int
    failed_amount: float
    failed_cash: float
    failed_upi: float
    failed_card: float


class MethodBreakdown(BaseModel):
    """Schema for payment method breakdown in sales summary."""
    method: str
    count: int
    amount: float
    failed_count: int = 0
    failed_amount: float = 0.0


class SalesSummaryResponse(BaseModel):
    """Schema for sales summary report."""
    date: str
    start_time: str
    end_time: str
    first_bill: str
    last_bill: str
    total_count: int
    total_amount: float
    by_method: List[MethodBreakdown]
    failed_upi_amount: float = 0.0
    failed_card_amount: float = 0.0
