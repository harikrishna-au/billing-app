from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, case
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.database import get_db
from app.models.user import User
from app.models.machine import Machine
from app.models.payment import Payment
from app.dependencies import get_current_user
from app.schemas.common import SuccessResponse

router = APIRouter()


@router.get("/stats", response_model=SuccessResponse[dict])
async def get_dashboard_stats(
    period: Optional[str] = Query("today", pattern="^(today|week|month|year)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get aggregated statistics for the main dashboard.
    
    Query Parameters:
        period: today | week | month | year (default: today)
    
    Returns:
        Dashboard statistics including machine counts and payment totals
    """
    # Get machine counts by status (filtered by current admin)
    total_machines = db.query(func.count(Machine.id)).filter(Machine.user_id == current_user.id).scalar() or 0
    online_machines = db.query(func.count(Machine.id)).filter(Machine.user_id == current_user.id, Machine.status == 'online').scalar() or 0
    offline_machines = db.query(func.count(Machine.id)).filter(Machine.user_id == current_user.id, Machine.status == 'offline').scalar() or 0
    maintenance_machines = db.query(func.count(Machine.id)).filter(Machine.user_id == current_user.id, Machine.status == 'maintenance').scalar() or 0
    
    # Calculate date ranges
    now = datetime.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    
    # Get today's payment stats (filtered by admin's machines)
    today_stats = db.query(
        func.count(Payment.id).label('count'),
        func.coalesce(func.sum(Payment.amount), 0).label('total')
    ).join(Machine, Payment.machine_id == Machine.id).filter(
        and_(
            Machine.user_id == current_user.id,
            Payment.created_at >= today_start,
            Payment.status == 'success'
        )
    ).first()
    
    today_collection = float(today_stats.total) if today_stats else 0.00
    total_transactions_today = today_stats.count if today_stats else 0
    
    # Get monthly payment stats (filtered by admin's machines)
    month_stats = db.query(
        func.count(Payment.id).label('count'),
        func.coalesce(func.sum(Payment.amount), 0).label('total')
    ).join(Machine, Payment.machine_id == Machine.id).filter(
        and_(
            Machine.user_id == current_user.id,
            Payment.created_at >= month_start,
            Payment.status == 'success'
        )
    ).first()
    
    monthly_collection = float(month_stats.total) if month_stats else 0.00
    total_transactions_month = month_stats.count if month_stats else 0
    
    # Calculate average transaction value
    average_transaction_value = (
        monthly_collection / total_transactions_month 
        if total_transactions_month > 0 
        else 0.00
    )
    
    return {
        "success": True,
        "data": {
            "total_machines": total_machines,
            "online_machines": online_machines,
            "offline_machines": offline_machines,
            "maintenance_machines": maintenance_machines,
            "today_collection": round(today_collection, 2),
            "monthly_collection": round(monthly_collection, 2),
            "total_transactions_today": total_transactions_today,
            "total_transactions_month": total_transactions_month,
            "average_transaction_value": round(average_transaction_value, 2)
        }
    }


@router.get("/revenue/weekly", response_model=SuccessResponse[list])
async def get_weekly_revenue(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get revenue data for the past 7 days.
    
    Returns:
        List of daily revenue with transaction counts
    """
    # Calculate date range (last 7 days including today)
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    week_ago = today - timedelta(days=6)
    
    # Query payments grouped by date (filtered by admin's machines)
    daily_stats = db.query(
        func.date(Payment.created_at).label('date'),
        func.coalesce(func.sum(Payment.amount), 0).label('revenue'),
        func.count(Payment.id).label('transaction_count')
    ).join(Machine, Payment.machine_id == Machine.id).filter(
        and_(
            Machine.user_id == current_user.id,
            Payment.created_at >= week_ago,
            Payment.status == 'success'
        )
    ).group_by(
        func.date(Payment.created_at)
    ).all()
    
    # Create a map of dates to stats
    stats_map = {
        stat.date: {
            'revenue': float(stat.revenue),
            'transaction_count': stat.transaction_count
        }
        for stat in daily_stats
    }
    
    # Generate complete 7-day data (fill missing days with zeros)
    day_names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    result = []
    
    for i in range(7):
        date = week_ago + timedelta(days=i)
        date_str = date.strftime('%Y-%m-%d')
        day_name = day_names[date.weekday() + 1 if date.weekday() < 6 else 0]  # Adjust for Monday start
        
        stats = stats_map.get(date.date(), {'revenue': 0.00, 'transaction_count': 0})
        
        result.append({
            "date": date_str,
            "day_name": day_name,
            "revenue": round(stats['revenue'], 2),
            "transaction_count": stats['transaction_count']
        })
    
    return {
        "success": True,
        "data": result
    }


@router.get("/alerts", response_model=SuccessResponse[list])
async def get_system_alerts(
    limit: int = Query(5, ge=1, le=50),
    severity: Optional[str] = Query(None, pattern="^(critical|warning|info)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get system alerts and notifications.
    
    Query Parameters:
        limit: Number of alerts to return (default: 5, max: 50)
        severity: Filter by severity (critical | warning | info)
    
    Returns:
        List of system alerts based on machine status
    """
    alerts = []
    now = datetime.now(timezone.utc)
    
    # Get all machines (filtered by current admin)
    machines = db.query(Machine).filter(Machine.user_id == current_user.id).all()
    
    for machine in machines:
        # Calculate time since last sync
        if machine.last_sync:
            time_diff = now - machine.last_sync
            hours_since_sync = time_diff.total_seconds() / 3600
        else:
            hours_since_sync = None
        
        # Critical: Machine offline for > 2 hours or never synced
        if machine.status == 'offline' and (hours_since_sync is None or hours_since_sync > 2):
            alert_severity = 'critical'
            if severity is None or severity == alert_severity:
                if hours_since_sync is None:
                    message = "Machine has never synced"
                else:
                    message = f"Machine Offline for > {int(hours_since_sync)} hours"
                
                alerts.append({
                    "id": f"offline-{machine.id}",
                    "machine_id": str(machine.id),
                    "machine_name": machine.name,
                    "title": "Machine Offline",
                    "message": message,
                    "severity": alert_severity,
                    "created_at": machine.last_sync.isoformat() if machine.last_sync else now.isoformat(),
                    "resolved": False
                })
        
        # Warning: Machine in maintenance
        elif machine.status == 'maintenance':
            alert_severity = 'warning'
            if severity is None or severity == alert_severity:
                alerts.append({
                    "id": f"maintenance-{machine.id}",
                    "machine_id": str(machine.id),
                    "machine_name": machine.name,
                    "title": "Maintenance Mode",
                    "message": "Machine in maintenance mode",
                    "severity": alert_severity,
                    "created_at": machine.updated_at.isoformat() if machine.updated_at else now.isoformat(),
                    "resolved": False
                })
        
        # Warning: Sync delayed (> 30 minutes for online machines)
        elif machine.status == 'online' and hours_since_sync is not None and hours_since_sync > 0.5:
            alert_severity = 'warning'
            if severity is None or severity == alert_severity:
                minutes_since_sync = int(hours_since_sync * 60)
                alerts.append({
                    "id": f"sync-{machine.id}",
                    "machine_id": str(machine.id),
                    "machine_name": machine.name,
                    "title": "Sync Delayed",
                    "message": f"Sync delayed (Last sync: {minutes_since_sync}m ago)",
                    "severity": alert_severity,
                    "created_at": machine.last_sync.isoformat() if machine.last_sync else now.isoformat(),
                    "resolved": False
                })
    
    # Sort by severity (critical first, then warning, then info)
    severity_order = {'critical': 0, 'warning': 1, 'info': 2}
    alerts.sort(key=lambda x: severity_order[x['severity']])
    
    # Add info alert if no critical/warning alerts
    if len(alerts) == 0 and (severity is None or severity == 'info'):
        alerts.append({
            "id": "info-all-ok",
            "machine_id": None,
            "machine_name": "System",
            "message": "All systems operational",
            "severity": "info",
            "created_at": now.isoformat(),
            "resolved": False
        })
    
    # Return limited results
    return {
        "success": True,
        "data": alerts[:limit]
    }


# Legacy endpoints for backward compatibility (will be deprecated)
@router.get("/machines", response_model=SuccessResponse[list])
async def get_machines_legacy(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get all machines (legacy endpoint).
    Use GET /v1/machines instead.
    """
    machines = db.query(Machine).filter(Machine.user_id == current_user.id).all()
    
    result = [
        {
            "id": str(machine.id),
            "name": machine.name,
            "location": machine.location,
            "status": machine.status,
            "last_sync": machine.last_sync.isoformat() if machine.last_sync else None,
            "online_collection": float(machine.online_collection),
            "offline_collection": float(machine.offline_collection)
        }
        for machine in machines
    ]
    
    return {
        "success": True,
        "data": result
    }


@router.get("/payments/chart", response_model=SuccessResponse[list])
async def get_payments_chart_legacy(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get payment data for charts (legacy endpoint).
    Use GET /v1/dashboard/revenue/weekly instead.
    """
    # Calculate date range (last 7 days)
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    week_ago = today - timedelta(days=6)
    
    # Query payments grouped by date (filtered by admin's machines)
    daily_stats = db.query(
        func.date(Payment.created_at).label('date'),
        func.coalesce(func.sum(Payment.amount), 0).label('amount')
    ).join(Machine, Payment.machine_id == Machine.id).filter(
        and_(
            Machine.user_id == current_user.id,
            Payment.created_at >= week_ago,
            Payment.status == 'success'
        )
    ).group_by(
        func.date(Payment.created_at)
    ).all()
    
    # Create a map of dates to amounts
    stats_map = {stat.date: float(stat.amount) for stat in daily_stats}
    
    # Generate complete 7-day data
    result = []
    for i in range(7):
        date = week_ago + timedelta(days=i)
        date_str = date.strftime('%Y-%m-%dT%H:%M:%S')
        amount = stats_map.get(date.date(), 0.00)
        
        result.append({
            "created_at": date_str,
            "amount": round(amount, 2)
        })
    
    return {
        "success": True,
        "data": result
    }
