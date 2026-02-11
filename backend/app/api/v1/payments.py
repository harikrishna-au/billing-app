from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func
from typing import Optional
from datetime import datetime, timedelta

from app.database import get_db
from app.models.user import User
from app.models.machine import Machine
from app.models.payment import Payment
from app.dependencies import get_current_user
from app.schemas.payment import (
    PaymentCreate, PaymentUpdate, PaymentResponse, 
    PaymentWithMachineResponse, PaymentSummary, PaymentListResponse
)
from app.schemas.common import SuccessResponse, MessageResponse

router = APIRouter()


def calculate_payment_summary(payments: list[Payment]) -> PaymentSummary:
    """Calculate summary statistics for a list of payments."""
    total_amount = sum(float(p.amount) for p in payments)
    total_count = len(payments)
    
    upi_amount = sum(float(p.amount) for p in payments if p.method == "UPI")
    card_amount = sum(float(p.amount) for p in payments if p.method == "Card")
    cash_amount = sum(float(p.amount) for p in payments if p.method == "Cash")
    
    success_count = sum(1 for p in payments if p.status == "success")
    pending_count = sum(1 for p in payments if p.status == "pending")
    failed_count = sum(1 for p in payments if p.status == "failed")
    
    return PaymentSummary(
        total_amount=total_amount,
        total_count=total_count,
        upi_amount=upi_amount,
        card_amount=card_amount,
        cash_amount=cash_amount,
        success_count=success_count,
        pending_count=pending_count,
        failed_count=failed_count
    )


@router.get("/machines/{machine_id}/payments")
async def get_payments_by_machine(
    machine_id: str,
    period: Optional[str] = Query(None, pattern="^(day|week|month|year)$"),
    method: Optional[str] = Query(None, pattern="^(UPI|Card|Cash)$"),
    status_filter: Optional[str] = Query(None, alias="status", pattern="^(success|pending|failed)$"),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all payments for a specific machine with filters."""
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )
    
    # Build query
    query = db.query(Payment).filter(Payment.machine_id == machine_id)
    
    # Apply period filter
    if period:
        now = datetime.utcnow()
        if period == "day":
            start_dt = now - timedelta(days=1)
        elif period == "week":
            start_dt = now - timedelta(weeks=1)
        elif period == "month":
            start_dt = now - timedelta(days=30)
        else:  # year
            start_dt = now - timedelta(days=365)
        query = query.filter(Payment.created_at >= start_dt)
    
    # Apply date range filters
    if start_date:
        try:
            start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            query = query.filter(Payment.created_at >= start_dt)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid start_date format"
            )
    
    if end_date:
        try:
            end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            query = query.filter(Payment.created_at <= end_dt)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid end_date format"
            )
    
    # Apply method filter
    if method:
        query = query.filter(Payment.method == method)
    
    # Apply status filter
    if status_filter:
        query = query.filter(Payment.status == status_filter)
    
    # Get total count
    total = query.count()
    
    # Get all payments for summary (before pagination)
    all_payments = query.all()
    summary = calculate_payment_summary(all_payments)
    
    # Apply pagination
    payments = query.order_by(Payment.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    
    return {
        "success": True,
        "data": {
            "payments": [
                PaymentWithMachineResponse(
                    id=str(p.id),
                    machine_id=str(p.machine_id),
                    machine_name=machine.name,
                    bill_number=p.bill_number,
                    amount=float(p.amount),
                    method=p.method,
                    status=p.status,
                    created_at=p.created_at
                )
                for p in payments
            ],
            "pagination": {
                "current_page": page,
                "total_pages": (total + limit - 1) // limit,
                "total_items": total,
                "items_per_page": limit
            },
            "summary": summary
        }
    }


@router.get("/payments")
async def get_all_payments(
    period: Optional[str] = Query(None, pattern="^(day|week|month|year)$"),
    method: Optional[str] = Query(None, pattern="^(UPI|Card|Cash)$"),
    status_filter: Optional[str] = Query(None, alias="status", pattern="^(success|pending|failed)$"),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    machine_id: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all payments with filters."""
    query = db.query(Payment)
    
    # Apply machine filter
    if machine_id:
        query = query.filter(Payment.machine_id == machine_id)
    
    # Apply period filter
    if period:
        now = datetime.utcnow()
        if period == "day":
            start_dt = now - timedelta(days=1)
        elif period == "week":
            start_dt = now - timedelta(weeks=1)
        elif period == "month":
            start_dt = now - timedelta(days=30)
        else:  # year
            start_dt = now - timedelta(days=365)
        query = query.filter(Payment.created_at >= start_dt)
    
    # Apply date range filters
    if start_date:
        try:
            start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            query = query.filter(Payment.created_at >= start_dt)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid start_date format"
            )
    
    if end_date:
        try:
            end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            query = query.filter(Payment.created_at <= end_dt)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid end_date format"
            )
    
    # Apply method filter
    if method:
        query = query.filter(Payment.method == method)
    
    # Apply status filter
    if status_filter:
        query = query.filter(Payment.status == status_filter)
    
    # Get total count
    total = query.count()
    
    # Get all payments for summary (before pagination)
    all_payments = query.all()
    summary = calculate_payment_summary(all_payments)
    
    # Apply pagination
    payments = query.order_by(Payment.created_at.desc()).offset((page - 1) * limit).limit(limit).all()
    
    # Get machine names
    machine_ids = list(set(str(p.machine_id) for p in payments))
    machines = db.query(Machine).filter(Machine.id.in_(machine_ids)).all()
    machine_map = {str(m.id): m.name for m in machines}
    
    return {
        "success": True,
        "data": {
            "payments": [
                PaymentWithMachineResponse(
                    id=str(p.id),
                    machine_id=str(p.machine_id),
                    machine_name=machine_map.get(str(p.machine_id), "Unknown"),
                    bill_number=p.bill_number,
                    amount=float(p.amount),
                    method=p.method,
                    status=p.status,
                    created_at=p.created_at
                )
                for p in payments
            ],
            "pagination": {
                "current_page": page,
                "total_pages": (total + limit - 1) // limit,
                "total_items": total,
                "items_per_page": limit
            },
            "summary": summary
        }
    }


@router.get("/payments/{payment_id}", response_model=SuccessResponse[PaymentWithMachineResponse])
async def get_payment(
    payment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get details of a specific payment."""
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment not found"
        )
    
    # Get machine name
    machine = db.query(Machine).filter(Machine.id == payment.machine_id).first()
    
    return {
        "success": True,
        "data": PaymentWithMachineResponse(
            id=str(payment.id),
            machine_id=str(payment.machine_id),
            machine_name=machine.name if machine else "Unknown",
            bill_number=payment.bill_number,
            amount=float(payment.amount),
            method=payment.method,
            status=payment.status,
            created_at=payment.created_at
        )
    }


@router.post("/payments", response_model=SuccessResponse[PaymentResponse], status_code=status.HTTP_201_CREATED)
async def create_payment(
    payment_data: PaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new payment (manual entry)."""
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == payment_data.machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )
    
    # Create payment
    payment = Payment(
        machine_id=payment_data.machine_id,
        bill_number=payment_data.bill_number,
        amount=payment_data.amount,
        method=payment_data.method,
        status=payment_data.status
    )
    
    try:
        db.add(payment)
        db.commit()
        db.refresh(payment)
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to create payment: {str(e)}"
        )
    
    return {
        "success": True,
        "data": PaymentResponse(
            id=str(payment.id),
            machine_id=str(payment.machine_id),
            bill_number=payment.bill_number,
            amount=float(payment.amount),
            method=payment.method,
            status=payment.status,
            created_at=payment.created_at
        )
    }


