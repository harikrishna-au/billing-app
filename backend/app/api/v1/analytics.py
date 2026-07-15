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
import pytz

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.machine import Machine
from app.models.payment import Payment
from app.models.log import Log

IST = pytz.timezone('Asia/Kolkata')


def _ist_day_bounds(date):
    """UTC bounds of the given calendar date in IST — matches how the
    payments list and the client define a 'day'.

    For TODAY the window ends at the moment the report is generated
    (00:00 → now), so the printed End time reflects when it was taken.
    Past dates keep the full 00:00–23:59 window."""
    start = IST.localize(datetime(date.year, date.month, date.day, 0, 0, 0)).astimezone(timezone.utc)
    end = IST.localize(datetime(date.year, date.month, date.day, 23, 59, 59)).astimezone(timezone.utc)
    now = datetime.now(timezone.utc)
    if start <= now < end:
        end = now
    return start, end


def _to_ist(dt):
    """Convert a stored (UTC) timestamp to IST for display."""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(IST)


def _effective_machine_id(current_user, machine_id):
    """Machine tokens are always scoped to their own machine; admin tokens
    may pass an explicit machine_id (or None for all machines)."""
    if isinstance(current_user, Machine):
        return str(current_user.id)
    return machine_id
from app.schemas.common import SuccessResponse
from app.schemas.analytics import (
    RevenueAnalyticsResponse,
    RevenuePeriod,
    TopMachine,
    MachinePerformance,
    TransactionSummaryResponse,
    SalesSummaryResponse,
    PaymentDetail,
    MethodBreakdown
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
        
        # Calculate uptime from payment and log activity days in the period
        payment_day_set = {
            p.created_at.date()
            for p in db.query(Payment).filter(
                Payment.machine_id == machine.id,
                Payment.created_at >= start,
                Payment.created_at <= end
            ).all()
        }
        log_day_set = {
            l.created_at.date()
            for l in db.query(Log).filter(
                Log.machine_id == machine.id,
                Log.created_at >= start,
                Log.created_at <= end
            ).all()
        }
        active_days = len(payment_day_set | log_day_set)
        total_days = max((end - start).days, 1)
        if active_days > 0:
            uptime_percentage = min(round((active_days / total_days) * 100, 1), 99.9)
        elif machine.status == 'online':
            uptime_percentage = 99.5  # online but no data yet in this period
        else:
            uptime_percentage = 0.0
        
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
    
    elif export_type == "logs":
        query = db.query(Log)
        if start:
            query = query.filter(Log.created_at >= start)
        if end:
            query = query.filter(Log.created_at <= end)
        if machine_id:
            query = query.filter(Log.machine_id == machine_id)

        logs = query.all()

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(['ID', 'Machine ID', 'Action', 'Details', 'Type', 'Created At'])

        for log in logs:
            writer.writerow([
                str(log.id),
                str(log.machine_id),
                log.action,
                log.details or '',
                log.type,
                log.created_at.isoformat()
            ])

        from fastapi.responses import StreamingResponse
        output.seek(0)
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=logs_export.csv"}
        )

    else:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=f"Export type '{export_type}' not yet implemented."
        )


@router.get("/payments-report/{date_str}")
async def get_payments_report(
    date_str: str,
    machine_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Generate comprehensive payment report with insights (00:00:00 to 23:59:59)."""

    try:
        date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Use YYYY-MM-DD"
        )

    start_time, end_time = _ist_day_bounds(date)

    query = db.query(Payment).filter(
        Payment.created_at >= start_time,
        Payment.created_at <= end_time
    )
    effective_machine = _effective_machine_id(current_user, machine_id)
    if effective_machine:
        query = query.filter(Payment.machine_id == effective_machine)

    payments = query.order_by(Payment.created_at).all()

    # Separate by status
    successful = [p for p in payments if p.status == 'success']
    failed = [p for p in payments if p.status != 'success']

    # Helper function
    def sum_by_method(payment_list, method):
        return sum(float(p.amount) for p in payment_list if p.method == method)

    def count_by_method(payment_list, method):
        return len([p for p in payment_list if p.method == method])

    # Totals
    success_total = sum(float(p.amount) for p in successful)
    success_cash = sum_by_method(successful, 'cash')
    success_upi = sum_by_method(successful, 'upi')
    success_card = sum_by_method(successful, 'card')

    failed_total = sum(float(p.amount) for p in failed)
    failed_cash = sum_by_method(failed, 'cash')
    failed_upi = sum_by_method(failed, 'upi')
    failed_card = sum_by_method(failed, 'card')

    # Generate CSV report
    output = io.StringIO()
    writer = csv.writer(output)

    # Header with report title
    writer.writerow([f'PAYMENT REPORT - {date.strftime("%d %B %Y")}'])
    writer.writerow(['Report Generated At', datetime.now(timezone.utc).strftime("%d-%m-%Y %H:%M:%S UTC")])
    writer.writerow([])

    # Executive Summary
    writer.writerow(['EXECUTIVE SUMMARY'])
    writer.writerow(['Metric', 'Value'])
    writer.writerow(['Total Successful Transactions', len(successful)])
    writer.writerow(['Total Failed Transactions', len(failed)])
    writer.writerow(['Total Payments', len(payments)])
    writer.writerow(['Success Rate', f"{(len(successful) / len(payments) * 100):.1f}%" if payments else "0%"])
    writer.writerow(['Total Revenue (Successful)', f"₹ {success_total:.2f}"])
    writer.writerow(['Total Failed Amount', f"₹ {failed_total:.2f}"])
    writer.writerow([])

    # Payment Method Breakdown
    writer.writerow(['PAYMENT METHOD BREAKDOWN (SUCCESSFUL)'])
    writer.writerow(['Method', 'Count', 'Amount', '% of Total'])

    for method, label in [('cash', 'CASH'), ('upi', 'UPI'), ('card', 'CARD')]:
        count = count_by_method(successful, method)
        amount = sum_by_method(successful, method)
        percentage = (amount / success_total * 100) if success_total > 0 else 0
        if count > 0:
            writer.writerow([label, count, f"₹ {amount:.2f}", f"{percentage:.1f}%"])

    writer.writerow([])

    # Failed Transactions Summary
    writer.writerow(['FAILED TRANSACTIONS SUMMARY'])
    writer.writerow(['Method', 'Count', 'Amount'])
    for method, label in [('cash', 'CASH'), ('upi', 'UPI'), ('card', 'CARD')]:
        count = count_by_method(failed, method)
        amount = sum_by_method(failed, method)
        if count > 0:
            writer.writerow([label, count, f"₹ {amount:.2f}"])

    writer.writerow([])

    # Hourly Distribution
    writer.writerow(['HOURLY TRANSACTION DISTRIBUTION'])
    writer.writerow(['Hour', 'Transactions', 'Revenue', 'Avg Transaction'])

    hourly = {}
    for p in successful:
        hour = _to_ist(p.created_at).hour
        if hour not in hourly:
            hourly[hour] = {'count': 0, 'amount': 0.0}
        hourly[hour]['count'] += 1
        hourly[hour]['amount'] += float(p.amount)

    for hour in range(24):
        if hour in hourly:
            data = hourly[hour]
            avg = data['amount'] / data['count'] if data['count'] > 0 else 0
            writer.writerow([f"{hour:02d}:00-{hour:02d}:59", data['count'], f"₹ {data['amount']:.2f}", f"₹ {avg:.2f}"])

    writer.writerow([])

    # Top 10 Transactions
    writer.writerow(['TOP 10 TRANSACTIONS'])
    writer.writerow(['Bill Number', 'Amount', 'Method', 'Time'])

    sorted_payments = sorted(successful, key=lambda p: float(p.amount), reverse=True)[:10]
    for p in sorted_payments:
        time_str = _to_ist(p.created_at).strftime("%H:%M:%S")
        writer.writerow([p.bill_number, f"₹ {float(p.amount):.2f}", p.method.upper(), time_str])

    writer.writerow([])

    # Key Metrics Summary
    writer.writerow(['KEY METRICS'])
    writer.writerow(['Metric', 'Value'])
    avg_transaction = success_total / len(successful) if successful else 0
    writer.writerow(['Average Transaction Value', f"₹ {avg_transaction:.2f}"])
    writer.writerow(['Highest Single Transaction', f"₹ {max(float(p.amount) for p in successful):.2f}" if successful else "N/A"])
    writer.writerow(['Lowest Single Transaction', f"₹ {min(float(p.amount) for p in successful):.2f}" if successful else "N/A"])

    if successful:
        sorted_amounts = sorted([float(p.amount) for p in successful])
        median = sorted_amounts[len(sorted_amounts)//2]
        writer.writerow(['Median Transaction Value', f"₹ {median:.2f}"])

    from fastapi.responses import StreamingResponse
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=payment_report_{date_str}.csv"}
    )


@router.get("/transaction-summary/{date_str}", response_model=SuccessResponse[TransactionSummaryResponse])
async def get_transaction_summary(
    date_str: str,
    machine_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get transaction summary for a specific IST day (00:00:00 to 23:59:59)."""

    try:
        date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Use YYYY-MM-DD"
        )

    # IST day boundaries — matches the payments list and the client's calendar day
    start_time, end_time = _ist_day_bounds(date)

    query = db.query(Payment).filter(
        Payment.created_at >= start_time,
        Payment.created_at <= end_time
    )
    effective_machine = _effective_machine_id(current_user, machine_id)
    if effective_machine:
        query = query.filter(Payment.machine_id == effective_machine)

    payments = query.order_by(Payment.created_at).all()

    # Separate by status
    successful = [p for p in payments if p.status == 'success']
    failed = [p for p in payments if p.status != 'success']

    # Calculate totals
    def sum_by_method(payment_list, method):
        return sum(float(p.amount) for p in payment_list if p.method == method)

    success_total = sum(float(p.amount) for p in successful)
    failed_total = sum(float(p.amount) for p in failed)

    success_cash = sum_by_method(successful, 'cash')
    success_upi = sum_by_method(successful, 'upi')
    success_card = sum_by_method(successful, 'card')
    failed_cash = sum_by_method(failed, 'cash')
    failed_upi = sum_by_method(failed, 'upi')
    failed_card = sum_by_method(failed, 'card')

    # Build payment details
    payment_details = [
        PaymentDetail(
            bill_number=p.bill_number,
            amount=float(p.amount),
            method=p.method.upper(),
            status=p.status.upper()
        )
        for p in payments
    ]

    return {
        "success": True,
        "data": TransactionSummaryResponse(
            date=date.isoformat(),
            start_time=_to_ist(start_time).strftime("%d-%m-%y %H:%M"),
            end_time=_to_ist(end_time).strftime("%d-%m-%y %H:%M"),
            payments=payment_details,
            successful_count=len(successful),
            successful_amount=success_total,
            successful_cash=success_cash,
            successful_upi=success_upi,
            successful_card=success_card,
            failed_count=len(failed),
            failed_amount=failed_total,
            failed_cash=failed_cash,
            failed_upi=failed_upi,
            failed_card=failed_card
        )
    }


@router.get("/sales-summary/{date_str}", response_model=SuccessResponse[SalesSummaryResponse])
async def get_sales_summary(
    date_str: str,
    machine_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get sales summary for a specific IST day (00:00:00 to 23:59:59)."""

    try:
        date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Use YYYY-MM-DD"
        )

    # IST day boundaries — matches the payments list and the client's calendar day
    start_time, end_time = _ist_day_bounds(date)

    query = db.query(Payment).filter(
        Payment.created_at >= start_time,
        Payment.created_at <= end_time
    )
    effective_machine = _effective_machine_id(current_user, machine_id)
    if effective_machine:
        query = query.filter(Payment.machine_id == effective_machine)

    payments = query.order_by(Payment.created_at).all()

    if not payments:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No payments found for this date"
        )

    # Separate by status
    successful = [p for p in payments if p.status == 'success']
    failed = [p for p in payments if p.status != 'success']

    # Calculate totals
    def sum_by_method(payment_list, method):
        return sum(float(p.amount) for p in payment_list if p.method == method)

    def count_by_method(payment_list, method):
        return len([p for p in payment_list if p.method == method])

    total_amount = sum(float(p.amount) for p in successful)
    failed_upi_total = sum_by_method(failed, 'upi')
    failed_card_total = sum_by_method(failed, 'card')

    # Build method breakdown — always include all three methods so the
    # printed report shows 0.00 rows instead of dropping them.
    methods = ['cash', 'upi', 'card']
    method_breakdown = []

    for method in methods:
        method_breakdown.append(
            MethodBreakdown(
                method=method.upper(),
                count=count_by_method(successful, method),
                amount=sum_by_method(successful, method),
                failed_count=count_by_method(failed, method),
                failed_amount=sum_by_method(failed, method)
            )
        )

    return {
        "success": True,
        "data": SalesSummaryResponse(
            date=date.isoformat(),
            start_time=_to_ist(start_time).strftime("%d-%m-%y %H:%M"),
            end_time=_to_ist(end_time).strftime("%d-%m-%y %H:%M"),
            first_bill=payments[0].bill_number,
            last_bill=payments[-1].bill_number,
            total_count=len(successful),
            total_amount=total_amount,
            by_method=method_breakdown,
            failed_upi_amount=failed_upi_total,
            failed_card_amount=failed_card_total
        )
    }
