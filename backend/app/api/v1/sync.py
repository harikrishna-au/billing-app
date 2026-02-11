"""
Sync endpoints for client app offline data synchronization.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List

from app.database import get_db
from app.models.user import User
from app.models.machine import Machine
from app.models.service import Service
from app.models.payment import Payment
from app.dependencies import get_current_user
from app.schemas.sync import (
    SyncPushRequest, SyncPushResponse,
    SyncPullResponse, SyncStatusResponse
)
from app.schemas.common import SuccessResponse

router = APIRouter()


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
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == sync_data.machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )
    
    synced_count = 0
    failed_count = 0
    
    # Process payments
    for payment_data in sync_data.payments:
        try:
            # Check if payment already exists (by bill_number)
            existing = db.query(Payment).filter(
                Payment.bill_number == payment_data.bill_number
            ).first()
            
            if existing:
                # Skip duplicate
                continue
            
            # Create new payment
            payment = Payment(
                machine_id=payment_data.machine_id,
                bill_number=payment_data.bill_number,
                amount=payment_data.amount,
                method=payment_data.method,
                status=payment_data.status,
                created_at=payment_data.created_at or datetime.utcnow()
            )
            
            db.add(payment)
            synced_count += 1
            
        except Exception as e:
            failed_count += 1
            continue
    
    # Update machine last_sync
    machine.last_sync = datetime.utcnow()
    
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
            sync_timestamp=machine.last_sync
        )
    }


@router.post("/pull", response_model=SuccessResponse[SyncPullResponse])
async def sync_pull(
    machine_id: str,
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
    machine.last_sync = datetime.utcnow()
    
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
