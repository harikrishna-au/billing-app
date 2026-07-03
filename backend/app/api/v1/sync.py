"""
Sync endpoints for client app offline data synchronization.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import List
import re

from app.database import get_db
from app.models.user import User
from app.models.machine import Machine
from app.models.service import Service
from app.models.payment import Payment
from app.models.bill_counter import BillCounter
from app.dependencies import get_current_user, assert_machine_owns
from app.schemas.sync import (
    SyncPushRequest, SyncPushResponse,
    SyncPullResponse, SyncStatusResponse
)
from app.schemas.common import SuccessResponse

router = APIRouter()


def _normalize_bill_number(bill_number: str) -> str:
    """Strip leading zeros from numeric suffix: POSID/000123 → POSID/123."""
    m = re.match(r'^(.+/)0*(\d+)$', bill_number)
    return f"{m.group(1)}{m.group(2)}" if m else bill_number


@router.post("/push", response_model=SuccessResponse[SyncPushResponse])
async def sync_push(
    sync_data: SyncPushRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Push offline data from client app to server.
    
    This endpoint allows client apps to upload payments that were
    created while offline.
    
    Args:
        sync_data: Offline data to sync
        db: Database session
        current_user: Current authenticated user/machine
        
    Returns:
        Sync statistics
    """
    # Machine tokens may only push data for their own machine
    assert_machine_owns(current_user, str(sync_data.machine_id))

    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == sync_data.machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )

    synced_count = 0
    failed_count = 0
    max_num_by_posid = {}  # highest bill number synced per POSID

    # Process payments
    for payment_data in sync_data.payments:
        try:
            normalized_bill = _normalize_bill_number(payment_data.bill_number)

            # Check if payment already exists — scoped to this machine
            existing = db.query(Payment).filter(
                Payment.machine_id == payment_data.machine_id,
                Payment.bill_number == normalized_bill,
            ).first()

            if existing:
                # Skip duplicate
                continue

            # Create new payment
            payment = Payment(
                machine_id=payment_data.machine_id,
                bill_number=normalized_bill,
                amount=payment_data.amount,
                method=payment_data.method,
                status=payment_data.status,
                created_at=payment_data.created_at or datetime.now(timezone.utc)
            )

            db.add(payment)
            synced_count += 1

            bill_match = re.match(r'^(.+?)/(\d+)$', normalized_bill)
            if bill_match:
                posid, num = bill_match.group(1), int(bill_match.group(2))
                max_num_by_posid[posid] = max(max_num_by_posid.get(posid, 0), num)

        except Exception as e:
            failed_count += 1
            continue

    # Keep the per-POSID counters (used by POST /payments validation) in step
    # with offline-synced payments so they don't flag later bills as resets.
    for posid, max_num in max_num_by_posid.items():
        counter = db.query(BillCounter).filter(
            BillCounter.machine_id == sync_data.machine_id,
            BillCounter.posid == posid,
        ).first()
        if counter:
            counter.next_number = max(counter.next_number, max_num + 1)
        else:
            db.add(BillCounter(
                machine_id=sync_data.machine_id,
                posid=posid,
                next_number=max_num + 1
            ))

    # Update machine last_sync and bill_counter (take the max so we never go
    # backwards). Semantics: LAST USED number — same as POST /payments and login.
    machine.last_sync = datetime.now(timezone.utc)
    highest_synced = max(max_num_by_posid.values(), default=0)
    machine.bill_counter = max(
        machine.bill_counter or 0,
        sync_data.client_bill_counter,
        highest_synced,
    )

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to sync data: {str(e)}"
        )

    return {
        "success": True,
        "data": SyncPushResponse(
            synced_payments=synced_count,
            failed_payments=failed_count,
            sync_timestamp=machine.last_sync,
            latest_bill_counter=machine.bill_counter
        )
    }


@router.post("/pull", response_model=SuccessResponse[SyncPullResponse])
async def sync_pull(
    machine_id: str = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Pull latest data from server to client app.
    
    This endpoint allows client apps to download the latest
    services and configuration.
    
    Args:
        machine_id: Machine UUID
        db: Database session
        current_user: Current authenticated user/machine
        
    Returns:
        Latest services and machine status
    """
    # Machine tokens may only pull data for their own machine
    assert_machine_owns(current_user, machine_id)

    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )

    # Get active services for this machine
    services = db.query(Service).filter(
        Service.machine_id == machine_id,
        Service.status == "active"
    ).all()
    
    services_data = [
        {
            "id": str(s.id),
            "name": s.name,
            "price": float(s.price),
            "status": s.status,
            "created_at": s.created_at.isoformat(),
            "updated_at": s.updated_at.isoformat()
        }
        for s in services
    ]
    
    # Update machine last_sync
    machine.last_sync = datetime.now(timezone.utc)
    
    try:
        db.commit()
    except Exception:
        db.rollback()
    
    return {
        "success": True,
        "data": SyncPullResponse(
            services=services_data,
            machine_status=machine.status,
            sync_timestamp=machine.last_sync
        )
    }


@router.get("/status/{machine_id}", response_model=SuccessResponse[SyncStatusResponse])
async def sync_status(
    machine_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get sync status for a machine.
    
    Args:
        machine_id: Machine UUID
        db: Database session
        current_user: Current authenticated user/machine
        
    Returns:
        Sync status information
    """
    # Machine tokens may only check status for their own machine
    assert_machine_owns(current_user, machine_id)

    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )

    return {
        "success": True,
        "data": SyncStatusResponse(
            machine_id=str(machine.id),
            last_sync=machine.last_sync,
            status=machine.status,
            pending_uploads=0  # Client app tracks this locally
        )
    }
