from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
from datetime import datetime, timezone

from app.database import get_db
from app.models.user import User, UserRole
from app.models.machine import Machine
from app.models.upi_change_request import UpiChangeRequest
from app.dependencies import get_current_superadmin
from app.core.security import get_password_hash
from app.schemas.common import SuccessResponse, MessageResponse

router = APIRouter()


def _mask_phone(phone: Optional[str]) -> Optional[str]:
    if not phone or len(phone) < 5:
        return phone
    return phone[:3] + "X" * (len(phone) - 5) + phone[-2:]


# ─── Admin management ─────────────────────────────────────────────────────────

@router.get("/admins", response_model=SuccessResponse[dict])
async def list_admins(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_superadmin),
):
    admins = db.query(User).filter(User.role == UserRole.ADMIN).order_by(User.created_at.desc()).all()

    machine_counts = dict(
        db.query(Machine.user_id, func.count(Machine.id))
        .filter(Machine.user_id.in_([a.id for a in admins]))
        .group_by(Machine.user_id)
        .all()
    ) if admins else {}

    return {
        "success": True,
        "data": {
            "admins": [
                {
                    "id": str(a.id),
                    "username": a.username,
                    "email": a.email,
                    "phone": _mask_phone(a.phone),
                    "is_active": a.is_active,
                    "machine_count": machine_counts.get(a.id, 0),
                    "created_at": a.created_at.isoformat() if a.created_at else None,
                }
                for a in admins
            ]
        },
    }


@router.get("/admins/{admin_id}", response_model=SuccessResponse[dict])
async def get_admin(
    admin_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_superadmin),
):
    admin = db.query(User).filter(User.id == admin_id, User.role == UserRole.ADMIN).first()
    if not admin:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Admin not found")

    machine_count = db.query(func.count(Machine.id)).filter(Machine.user_id == admin.id).scalar() or 0

    machines = db.query(Machine).filter(Machine.user_id == admin.id).all()

    pending_requests = (
        db.query(func.count(UpiChangeRequest.id))
        .filter(
            UpiChangeRequest.requested_by == admin.id,
            UpiChangeRequest.status == "pending",
        )
        .scalar() or 0
    )

    return {
        "success": True,
        "data": {
            "id": str(admin.id),
            "username": admin.username,
            "email": admin.email,
            "phone": _mask_phone(admin.phone),
            "is_active": admin.is_active,
            "machine_count": machine_count,
            "pending_upi_requests": pending_requests,
            "created_at": admin.created_at.isoformat() if admin.created_at else None,
            "machines": [
                {
                    "id": str(m.id),
                    "name": m.name,
                    "location": m.location,
                    "status": m.status,
                    "upi_id": m.upi_id,
                    "last_sync": m.last_sync.isoformat() if m.last_sync else None,
                }
                for m in machines
            ],
        },
    }


@router.post("/admins", response_model=SuccessResponse[dict], status_code=status.HTTP_201_CREATED)
async def create_admin(
    body: dict,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_superadmin),
):
    username = body.get("username", "").strip()
    email = body.get("email", "").strip()
    phone = body.get("phone", "").strip() or None
    password = body.get("password", "")

    if not username or not email or not password:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="username, email and password are required")

    if db.query(User).filter(User.username == username).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already exists")
    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already exists")

    user = User(
        username=username,
        email=email,
        phone=phone,
        hashed_password=get_password_hash(password),
        role=UserRole.ADMIN,
        is_active="true",
    )
    db.add(user)
    try:
        db.commit()
        db.refresh(user)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    return {
        "success": True,
        "data": {
            "id": str(user.id),
            "username": user.username,
            "email": user.email,
            "role": user.role,
            "created_at": user.created_at.isoformat(),
        },
    }


@router.patch("/admins/{admin_id}/status", response_model=SuccessResponse[dict])
async def toggle_admin_status(
    admin_id: str,
    body: dict,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_superadmin),
):
    admin = db.query(User).filter(User.id == admin_id, User.role == UserRole.ADMIN).first()
    if not admin:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Admin not found")

    new_status = body.get("is_active")
    if new_status not in ("true", "false"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="is_active must be 'true' or 'false'")

    admin.is_active = new_status
    db.commit()

    return {"success": True, "data": {"id": str(admin.id), "is_active": admin.is_active}}


# ─── Machine overview ─────────────────────────────────────────────────────────

@router.get("/machines", response_model=SuccessResponse[dict])
async def list_all_machines(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_superadmin),
):
    machines = db.query(Machine).order_by(Machine.created_at.desc()).all()

    admin_ids = list({m.user_id for m in machines})
    admins = {str(u.id): u.username for u in db.query(User).filter(User.id.in_(admin_ids)).all()}

    return {
        "success": True,
        "data": {
            "machines": [
                {
                    "id": str(m.id),
                    "name": m.name,
                    "location": m.location,
                    "username": m.username,
                    "status": m.status,
                    "upi_id": m.upi_id,
                    "admin": admins.get(str(m.user_id), "—"),
                    "admin_id": str(m.user_id),
                    "last_sync": m.last_sync.isoformat() if m.last_sync else None,
                    "created_at": m.created_at.isoformat() if m.created_at else None,
                }
                for m in machines
            ]
        },
    }


# ─── UPI change request approval ─────────────────────────────────────────────

@router.get("/upi-requests", response_model=SuccessResponse[dict])
async def list_upi_requests(
    request_status: Optional[str] = Query(None, alias="status"),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_superadmin),
):
    q = db.query(UpiChangeRequest)
    if request_status:
        q = q.filter(UpiChangeRequest.status == request_status)
    requests = q.order_by(UpiChangeRequest.created_at.desc()).all()

    machine_ids = list({r.machine_id for r in requests})
    admin_ids = list({r.requested_by for r in requests})

    machines = {str(m.id): m for m in db.query(Machine).filter(Machine.id.in_(machine_ids)).all()}
    admins = {str(u.id): u.username for u in db.query(User).filter(User.id.in_(admin_ids)).all()}

    return {
        "success": True,
        "data": {
            "requests": [
                {
                    "id": str(r.id),
                    "machine_id": str(r.machine_id),
                    "machine_name": machines[str(r.machine_id)].name if str(r.machine_id) in machines else "—",
                    "requested_by_id": str(r.requested_by),
                    "requested_by": admins.get(str(r.requested_by), "—"),
                    "old_upi_id": r.old_upi_id,
                    "new_upi_id": r.new_upi_id,
                    "status": r.status,
                    "superadmin_note": r.superadmin_note,
                    "created_at": r.created_at.isoformat() if r.created_at else None,
                    "resolved_at": r.resolved_at.isoformat() if r.resolved_at else None,
                }
                for r in requests
            ]
        },
    }


@router.post("/upi-requests/{request_id}/approve", response_model=SuccessResponse[dict])
async def approve_upi_request(
    request_id: str,
    db: Session = Depends(get_db),
    superadmin: User = Depends(get_current_superadmin),
):
    req = db.query(UpiChangeRequest).filter(UpiChangeRequest.id == request_id).first()
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    if req.status != "pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Request is already {req.status}")

    machine = db.query(Machine).filter(Machine.id == req.machine_id).first()
    if not machine:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Machine no longer exists")

    machine.upi_id = req.new_upi_id
    req.status = "approved"
    req.resolved_by = superadmin.id
    req.resolved_at = datetime.now(timezone.utc)

    db.commit()

    return {
        "success": True,
        "data": {
            "request_id": str(req.id),
            "machine_id": str(machine.id),
            "applied_upi_id": req.new_upi_id,
        },
    }


@router.post("/upi-requests/{request_id}/reject", response_model=SuccessResponse[dict])
async def reject_upi_request(
    request_id: str,
    body: dict,
    db: Session = Depends(get_db),
    superadmin: User = Depends(get_current_superadmin),
):
    req = db.query(UpiChangeRequest).filter(UpiChangeRequest.id == request_id).first()
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    if req.status != "pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Request is already {req.status}")

    req.status = "rejected"
    req.superadmin_note = body.get("note", "").strip() or None
    req.resolved_by = superadmin.id
    req.resolved_at = datetime.now(timezone.utc)

    db.commit()

    return {"success": True, "data": {"request_id": str(req.id), "status": "rejected"}}
