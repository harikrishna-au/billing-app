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
from app.models.machine import Machine
from app.models.location import Location
from app.models.bill_counter import BillCounter
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
    machine = db.query(Machine).filter(Machine.id == machine_id).first()

    # Use location's UPI ID if machine is linked to a location, else fall back to machine's own upi_id
    upi_id = machine.upi_id if machine else None
    if machine and machine.location_id:
        location = db.query(Location).filter(Location.id == machine.location_id).first()
        if location and location.upi_id:
            upi_id = location.upi_id

    # Get next bill number from bill_counters table (use pos_id from config if available)
    next_bill_number = 1
    if config and config.pos_id:
        counter = db.query(BillCounter).filter(
            BillCounter.machine_id == machine_id,
            BillCounter.posid == config.pos_id,
        ).first()
        if counter:
            next_bill_number = counter.next_number

    if not config:
        return {
            "success": True,
            "data": {
                "upi_id": upi_id,
                "next_bill_number": next_bill_number,
            } if upi_id or next_bill_number > 1 else None
        }

    data = BillConfigResponse.model_validate(config).model_dump()
    data["upi_id"] = upi_id
    data["next_bill_number"] = next_bill_number
    return {"success": True, "data": data}


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
