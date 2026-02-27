from datetime import datetime, timezone
from typing import Optional
from sqlalchemy.orm import Session

from app.models.alert import SystemAlert, AlertSeverity


def create_alert_if_not_exists(
    db: Session,
    machine_id: str,
    severity: AlertSeverity,
    title: str,
    message: str,
) -> Optional[SystemAlert]:
    """
    Create a DB alert only if there is no identical unresolved alert for this machine.
    Returns the existing or newly created alert, or None if machine_id is invalid.
    """
    existing = db.query(SystemAlert).filter(
        SystemAlert.machine_id == machine_id,
        SystemAlert.title == title,
        SystemAlert.resolved == False,
    ).first()

    if existing:
        return existing

    alert = SystemAlert(
        machine_id=machine_id,
        severity=severity,
        title=title,
        message=message,
        resolved=False,
    )
    db.add(alert)
    try:
        db.commit()
        db.refresh(alert)
    except Exception:
        db.rollback()
        return None

    return alert


def resolve_machine_alerts(
    db: Session,
    machine_id: str,
    title_filter: Optional[str] = None,
    resolved_by_id: Optional[str] = None,
) -> int:
    """
    Resolve all open alerts for a machine (optionally filtered by title).
    Returns the count of alerts resolved.
    """
    query = db.query(SystemAlert).filter(
        SystemAlert.machine_id == machine_id,
        SystemAlert.resolved == False,
    )
    if title_filter:
        query = query.filter(SystemAlert.title == title_filter)

    alerts = query.all()
    if not alerts:
        return 0

    now = datetime.now(timezone.utc)
    for alert in alerts:
        alert.resolved = True
        alert.resolved_at = now
        if resolved_by_id:
            alert.resolved_by = resolved_by_id

    try:
        db.commit()
    except Exception:
        db.rollback()
        return 0

    return len(alerts)
