from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func
from typing import Optional
from datetime import datetime, timedelta, timezone
import pytz

from app.database import get_db
from app.models.user import User
from app.models.machine import Machine
from app.models.payment import Payment
from app.dependencies import get_current_user, assert_machine_owns
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
    limit: int = Query(200, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get all payments for a specific machine with filters."""
    assert_machine_owns(current_user, machine_id)

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
        IST = pytz.timezone('Asia/Kolkata')
        now_ist = datetime.now(IST)
        if period == "day":
            # All of today in IST (midnight to just before next midnight)
            start_dt = IST.localize(datetime(now_ist.year, now_ist.month, now_ist.day, 0, 0, 0)).astimezone(timezone.utc)
            end_dt = IST.localize(datetime(now_ist.year, now_ist.month, now_ist.day, 23, 59, 59)).astimezone(timezone.utc)
        elif period == "week":
            # This week (Monday through Sunday in IST)
            start_of_week = now_ist - timedelta(days=now_ist.weekday())
            end_of_week = start_of_week + timedelta(days=6)
            start_dt = IST.localize(datetime(start_of_week.year, start_of_week.month, start_of_week.day, 0, 0, 0)).astimezone(timezone.utc)
            end_dt = IST.localize(datetime(end_of_week.year, end_of_week.month, end_of_week.day, 23, 59, 59)).astimezone(timezone.utc)
        elif period == "month":
            # This calendar month in IST
            start_dt = IST.localize(datetime(now_ist.year, now_ist.month, 1, 0, 0, 0)).astimezone(timezone.utc)
            # Last day of this month
            if now_ist.month == 12:
                end_of_month = datetime(now_ist.year + 1, 1, 1) - timedelta(days=1)
            else:
                end_of_month = datetime(now_ist.year, now_ist.month + 1, 1) - timedelta(days=1)
            end_dt = IST.localize(datetime(end_of_month.year, end_of_month.month, end_of_month.day, 23, 59, 59)).astimezone(timezone.utc)
        else:  # year
            start_dt = IST.localize(datetime(now_ist.year, 1, 1, 0, 0, 0)).astimezone(timezone.utc)
            end_dt = IST.localize(datetime(now_ist.year, 12, 31, 23, 59, 59)).astimezone(timezone.utc)
        query = query.filter(and_(Payment.created_at >= start_dt, Payment.created_at <= end_dt))

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
        IST = pytz.timezone('Asia/Kolkata')
        now_ist = datetime.now(IST)
        if period == "day":
            # All of today in IST (midnight to just before next midnight)
            start_dt = IST.localize(datetime(now_ist.year, now_ist.month, now_ist.day, 0, 0, 0)).astimezone(timezone.utc)
            end_dt = IST.localize(datetime(now_ist.year, now_ist.month, now_ist.day, 23, 59, 59)).astimezone(timezone.utc)
        elif period == "week":
            # This week (Monday through Sunday in IST)
            start_of_week = now_ist - timedelta(days=now_ist.weekday())
            end_of_week = start_of_week + timedelta(days=6)
            start_dt = IST.localize(datetime(start_of_week.year, start_of_week.month, start_of_week.day, 0, 0, 0)).astimezone(timezone.utc)
            end_dt = IST.localize(datetime(end_of_week.year, end_of_week.month, end_of_week.day, 23, 59, 59)).astimezone(timezone.utc)
        elif period == "month":
            # This calendar month in IST
            start_dt = IST.localize(datetime(now_ist.year, now_ist.month, 1, 0, 0, 0)).astimezone(timezone.utc)
            # Last day of this month
            if now_ist.month == 12:
                end_of_month = datetime(now_ist.year + 1, 1, 1) - timedelta(days=1)
            else:
                end_of_month = datetime(now_ist.year, now_ist.month + 1, 1) - timedelta(days=1)
            end_dt = IST.localize(datetime(end_of_month.year, end_of_month.month, end_of_month.day, 23, 59, 59)).astimezone(timezone.utc)
        else:  # year
            start_dt = IST.localize(datetime(now_ist.year, 1, 1, 0, 0, 0)).astimezone(timezone.utc)
            end_dt = IST.localize(datetime(now_ist.year, 12, 31, 23, 59, 59)).astimezone(timezone.utc)
        query = query.filter(and_(Payment.created_at >= start_dt, Payment.created_at <= end_dt))

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


def _normalize_bill_number(bill_number: str) -> str:
    """
    Normalize POSID/000123 → POSID/123.
    Different app versions format the numeric suffix differently (some zero-pad to 6 digits,
    newer ones don't). Stripping leading zeros before storing means both formats map to the
    same string, so the unique index on (machine_id, bill_number) catches cross-device
    duplicates even when two phones are logged into the same machine account.
    """
    import re
    m = re.match(r'^(.+/)0*(\d+)$', bill_number)
    return f"{m.group(1)}{m.group(2)}" if m else bill_number


@router.post("/payments", response_model=SuccessResponse[PaymentResponse], status_code=status.HTTP_201_CREATED)
async def create_payment(
    payment_data: PaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new payment (manual entry)."""
    assert_machine_owns(current_user, str(payment_data.machine_id))

    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == payment_data.machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )

    # Normalize bill number: strip leading zeros from numeric suffix so that
    # "WSSBI-AP/000330" and "WSSBI-AP/330" are treated as the same bill.
    normalized_bill = _normalize_bill_number(payment_data.bill_number)

    # Idempotency: if this bill_number is already recorded for this machine, return it.
    existing = db.query(Payment).filter(
        Payment.machine_id == payment_data.machine_id,
        Payment.bill_number == normalized_bill,
    ).first()
    if existing:
        return {
            "success": True,
            "data": PaymentResponse(
                id=str(existing.id),
                machine_id=str(existing.machine_id),
                bill_number=existing.bill_number,
                amount=float(existing.amount),
                method=existing.method,
                status=existing.status,
                created_at=existing.created_at
            )
        }

    # Create payment — explicitly set created_at to UTC now (don't rely on DB server time)
    payment = Payment(
        machine_id=payment_data.machine_id,
        bill_number=normalized_bill,
        amount=payment_data.amount,
        method=payment_data.method,
        status=payment_data.status,
        created_at=datetime.now(timezone.utc)
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


