from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import and_
from typing import Optional
from datetime import datetime, timezone

from app.database import get_db
from app.models.alert import SystemAlert, AlertSeverity
from app.models.machine import Machine
from app.models.user import User
from app.dependencies import get_current_user
from app.schemas.common import SuccessResponse, MessageResponse

router = APIRouter()


def _alert_to_dict(alert: SystemAlert) -> dict:
    machine_name = alert.machine.name if alert.machine else None
    return {
        "id": str(alert.id),
        "machine_id": str(alert.machine_id) if alert.machine_id else None,
        "machine_name": machine_name,
        "title": alert.title,
        "message": alert.message,
        "severity": alert.severity.value if hasattr(alert.severity, "value") else alert.severity,
        "resolved": alert.resolved,
        "resolved_at": alert.resolved_at.isoformat() if alert.resolved_at else None,
        "created_at": alert.created_at.isoformat(),
    }


@router.get("/", response_model=SuccessResponse[dict])
async def list_alerts(
    severity: Optional[str] = Query(None, pattern="^(critical|warning|info)$"),
    resolved: Optional[bool] = Query(None),
    machine_id: Optional[str] = Query(None),
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    List system alerts with optional filters.

    Scoped to machines owned by the current admin.
    Supports filtering by severity, resolved status, machine, and date range.
    """
    # Get IDs of machines belonging to this admin
    admin_machine_ids = [
        m.id for m in db.query(Machine.id).filter(Machine.user_id == current_user.id).all()
    ]

    query = db.query(SystemAlert).options(
        joinedload(SystemAlert.machine)
    ).filter(
        SystemAlert.machine_id.in_(admin_machine_ids)
    )

    if severity:
        query = query.filter(SystemAlert.severity == severity)
    if resolved is not None:
        query = query.filter(SystemAlert.resolved == resolved)
    if machine_id:
        query = query.filter(SystemAlert.machine_id == machine_id)
    if start_date:
        try:
            start_dt = datetime.fromisoformat(start_date)
            query = query.filter(SystemAlert.created_at >= start_dt)
        except ValueError:
            pass
    if end_date:
        try:
            end_dt = datetime.fromisoformat(end_date)
            # Include the full end day
            from datetime import timedelta
            end_dt = end_dt.replace(hour=23, minute=59, second=59)
            query = query.filter(SystemAlert.created_at <= end_dt)
        except ValueError:
            pass

    total = query.count()
    alerts = query.order_by(SystemAlert.created_at.desc()).offset((page - 1) * limit).limit(limit).all()

    unresolved_count = db.query(SystemAlert).filter(
        SystemAlert.machine_id.in_(admin_machine_ids),
        SystemAlert.resolved == False,
    ).count()

    return {
        "success": True,
        "data": {
            "alerts": [_alert_to_dict(a) for a in alerts],
            "pagination": {
                "current_page": page,
                "total_pages": max(1, (total + limit - 1) // limit),
                "total_items": total,
                "items_per_page": limit,
            },
            "unresolved_count": unresolved_count,
        },
    }


@router.patch("/{alert_id}/resolve", response_model=SuccessResponse[dict])
async def resolve_alert(
    alert_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark a specific alert as resolved."""
    # Verify the alert belongs to one of this admin's machines
    admin_machine_ids = [
        m.id for m in db.query(Machine.id).filter(Machine.user_id == current_user.id).all()
    ]

    alert = db.query(SystemAlert).options(
        joinedload(SystemAlert.machine)
    ).filter(
        SystemAlert.id == alert_id,
        SystemAlert.machine_id.in_(admin_machine_ids),
    ).first()

    if not alert:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")

    if alert.resolved:
        return {"success": True, "data": _alert_to_dict(alert)}

    alert.resolved = True
    alert.resolved_at = datetime.now(timezone.utc)
    alert.resolved_by = current_user.id

    try:
        db.commit()
        db.refresh(alert)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to resolve alert")

    return {"success": True, "data": _alert_to_dict(alert)}


@router.delete("/{alert_id}", response_model=MessageResponse)
async def delete_alert(
    alert_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a specific alert."""
    admin_machine_ids = [
        m.id for m in db.query(Machine.id).filter(Machine.user_id == current_user.id).all()
    ]

    alert = db.query(SystemAlert).filter(
        SystemAlert.id == alert_id,
        SystemAlert.machine_id.in_(admin_machine_ids),
    ).first()

    if not alert:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alert not found")

    try:
        db.delete(alert)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to delete alert")

    return {"success": True, "message": "Alert deleted successfully"}


@router.get("/unresolved-count", response_model=SuccessResponse[dict])
async def get_unresolved_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get count of unresolved alerts for the sidebar badge."""
    admin_machine_ids = [
        m.id for m in db.query(Machine.id).filter(Machine.user_id == current_user.id).all()
    ]
    count = db.query(SystemAlert).filter(
        SystemAlert.machine_id.in_(admin_machine_ids),
        SystemAlert.resolved == False,
    ).count()

    return {"success": True, "data": {"count": count}}
