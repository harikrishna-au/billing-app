"""
Bill configuration endpoints.

GET  /config/machine/{machine_id}  — fetch config (any authenticated caller)
PUT  /config/machine/{machine_id}  — upsert config (admin only)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user, get_current_admin_user
from app.models.bill_config import BillConfig
from app.schemas.bill_config import BillConfigUpdate, BillConfigResponse

router = APIRouter()


@router.get("/machine/{machine_id}", tags=["Config"])
async def get_bill_config(
    machine_id: str,
    db: Session = Depends(get_db),
    _current=Depends(get_current_user),
):
    """Return the bill configuration for a machine. Returns null data if not set yet."""
    config = db.query(BillConfig).filter(BillConfig.machine_id == machine_id).first()
    if not config:
        return {"success": True, "data": None}
    return {
        "success": True,
        "data": BillConfigResponse.model_validate(config).model_dump(),
    }


@router.put("/machine/{machine_id}", tags=["Config"])
async def upsert_bill_config(
    machine_id: str,
    payload: BillConfigUpdate,
    db: Session = Depends(get_db),
    _admin=Depends(get_current_admin_user),
):
    """Create or update the bill configuration for a machine (admin only)."""
    config = db.query(BillConfig).filter(BillConfig.machine_id == machine_id).first()

    if not config:
        config = BillConfig(machine_id=machine_id)
        db.add(config)

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(config, field, value)

    db.commit()
    db.refresh(config)

    return {
        "success": True,
        "data": BillConfigResponse.model_validate(config).model_dump(),
    }
