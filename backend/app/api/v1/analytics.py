"""
Analytics API endpoints.
"""
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func, case, extract
from datetime import datetime, timedelta, timezone
from typing import Optional, Literal
import csv
import io

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.machine import Machine
from app.models.payment import Payment
from app.schemas.common import SuccessResponse
from app.schemas.analytics import (
    RevenueAnalyticsResponse,
    RevenuePeriod,
    TopMachine,
    MachinePerformance
)

router = APIRouter()


@router.get("/revenue", response_model=SuccessResponse[RevenueAnalyticsResponse])
async def get_revenue_analytics(
    period: Optional[Literal["day", "week", "month", "year"]] = Query("month"),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    machine_id: Optional[str] = Query(None),
    group_by: Optional[Literal["day", "week", "month"]] = Query("day"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get detailed revenue analytics."""
    
    # Calculate date range
    now = datetime.now(timezone.utc)
    if start_date and end_date:
        start = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
        end = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
    else:
        if period == "day":
            start = now - timedelta(days=1)
        elif period == "week":
            start = now - timedelta(weeks=1)
        elif period == "month":
            start = now - timedelta(days=30)
        else:  # year
            start = now - timedelta(days=365)
        end = now
    
    # Base query
    query = db.query(Payment).filter(
        Payment.created_at >= start,
        Payment.created_at <= end,
        Payment.status == 'success'
    )
    
    if machine_id:
        query = query.filter(Payment.machine_id == machine_id)
    
    payments = query.all()
    
    # Calculate total metrics
    total_revenue = sum(float(p.amount) for p in payments)
    total_transactions = len(payments)
    average_transaction = total_revenue / total_transactions if total_transactions > 0 else 0
    
    # Revenue by period
    revenue_by_period = []
    if group_by == "day":
        # Group by day
        period_data = {}
        for payment in payments:
            day_key = payment.created_at.date().isoformat()
            if day_key not in period_data:
                period_data[day_key] = {"revenue": 0, "count": 0}
            period_data[day_key]["revenue"] += float(payment.amount)
            period_data[day_key]["count"] += 1
        
        revenue_by_period = [
            RevenuePeriod(
                period=day,
                revenue=data["revenue"],
                transaction_count=data["count"]
            )
            for day, data in sorted(period_data.items())
        ]
    
    # Revenue by method
    revenue_by_method = {}
    for payment in payments:
        method = payment.method
        if method not in revenue_by_method:
            revenue_by_method[method] = 0
        revenue_by_method[method] += float(payment.amount)
    
    # Top machines
    machine_revenue = {}
    for payment in payments:
        mid = str(payment.machine_id)
        if mid not in machine_revenue:
            machine_revenue[mid] = {"revenue": 0, "count": 0}
        machine_revenue[mid]["revenue"] += float(payment.amount)
        machine_revenue[mid]["count"] += 1
    
    top_machines = []
    for mid, data in sorted(machine_revenue.items(), key=lambda x: x[1]["revenue"], reverse=True)[:5]:
        machine = db.query(Machine).filter(Machine.id == mid).first()
        if machine:
            top_machines.append(TopMachine(
                machine_id=mid,
                machine_name=machine.name,
                revenue=data["revenue"],
                transaction_count=data["count"]
            ))
    
    return {
        "success": True,
        "data": RevenueAnalyticsResponse(
            total_revenue=total_revenue,
            total_transactions=total_transactions,
            average_transaction=average_transaction,
            revenue_by_period=revenue_by_period,
            revenue_by_method=revenue_by_method,
            top_machines=top_machines
        )
    }


@router.get("/machines/performance", response_model=SuccessResponse[list[MachinePerformance]])
async def get_machine_performance(
    period: Optional[Literal["day", "week", "month"]] = Query("month"),
    sort_by: Optional[Literal["revenue", "transactions", "uptime"]] = Query("revenue"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get performance metrics for all machines."""
    
    # Calculate date range
    now = datetime.now(timezone.utc)
    if period == "day":
        start = now - timedelta(days=1)
    elif period == "week":
        start = now - timedelta(weeks=1)
    else:  # month
        start = now - timedelta(days=30)
    
    end = now
    
    # Get all machines
    machines = db.query(Machine).all()
    
    performance_data = []
    for machine in machines:
        # Get payments for this machine in the period
        payments = db.query(Payment).filter(
            Payment.machine_id == machine.id,
            Payment.created_at >= start,
            Payment.created_at <= end,
            Payment.status == 'success'
        ).all()
        
        revenue = sum(float(p.amount) for p in payments)
        transaction_count = len(payments)
        average_transaction = revenue / transaction_count if transaction_count > 0 else 0
        
        # Calculate uptime (simplified - assuming online means 100% uptime)
        uptime_percentage = 99.5 if machine.status == 'online' else 85.0
        
        performance_data.append(MachinePerformance(
            machine_id=str(machine.id),
            machine_name=machine.name,
            status=machine.status,
            revenue=revenue,
            transaction_count=transaction_count,
            uptime_percentage=uptime_percentage,
            last_sync=machine.last_sync,
            average_transaction=average_transaction
        ))
    
    # Sort by requested field
    if sort_by == "revenue":
        performance_data.sort(key=lambda x: x.revenue, reverse=True)
    elif sort_by == "transactions":
        performance_data.sort(key=lambda x: x.transaction_count, reverse=True)
    else:  # uptime
        performance_data.sort(key=lambda x: x.uptime_percentage, reverse=True)
    
    return {
        "success": True,
        "data": performance_data
    }


@router.get("/export/{export_type}")
async def export_data(
    export_type: Literal["payments", "machines", "services", "logs"],
    format: Literal["csv", "excel", "json"] = Query("csv"),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    machine_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Export data in various formats."""
    
    if format != "csv":
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=f"Export format '{format}' not yet implemented. Only CSV is supported."
        )
    
    # Calculate date range if provided
    start = None
    end = None
    if start_date:
        start = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
    if end_date:
        end = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
    
    # Export payments
    if export_type == "payments":
        query = db.query(Payment)
        if start:
            query = query.filter(Payment.created_at >= start)
        if end:
            query = query.filter(Payment.created_at <= end)
        if machine_id:
            query = query.filter(Payment.machine_id == machine_id)
        
        payments = query.all()
        
        # Create CSV
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(['ID', 'Machine ID', 'Amount', 'Method', 'Status', 'Created At'])
        
        for payment in payments:
            writer.writerow([
                str(payment.id),
                str(payment.machine_id),
                float(payment.amount),
                payment.method,
                payment.status,
                payment.created_at.isoformat()
            ])
        
        from fastapi.responses import StreamingResponse
        output.seek(0)
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=payments_export.csv"}
        )
    
    elif export_type == "machines":
        machines = db.query(Machine).all()
        
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(['ID', 'Name', 'Location', 'Status', 'Online Collection', 'Offline Collection', 'Last Sync'])
        
        for machine in machines:
            writer.writerow([
                str(machine.id),
                machine.name,
                machine.location,
                machine.status,
                float(machine.online_collection),
                float(machine.offline_collection),
                machine.last_sync.isoformat() if machine.last_sync else ''
            ])
        
        from fastapi.responses import StreamingResponse
        output.seek(0)
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f"attachment; filename=machines_export.csv"}
        )
    
    else:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=f"Export type '{export_type}' not yet implemented."
        )
