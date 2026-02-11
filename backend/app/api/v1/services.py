from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import Optional

from app.database import get_db
from app.models.user import User
from app.models.machine import Machine
from app.models.service import Service

from app.dependencies import get_current_user
from app.schemas.service import ServiceCreate, ServiceUpdate, ServiceResponse, ServiceWithMachineResponse
from app.schemas.common import SuccessResponse, MessageResponse

router = APIRouter()


@router.get("/machines/{machine_id}/services", response_model=SuccessResponse[list[ServiceResponse]])
async def get_services_by_machine(
    machine_id: str,
    status_filter: Optional[str] = Query(None, alias="status", pattern="^(active|inactive)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get all services for a specific machine.
    
    Query Parameters:
        status: Filter by status (active | inactive)
    """
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )
    
    # Build query
    query = db.query(Service).filter(Service.machine_id == machine_id)
    
    if status_filter:
        query = query.filter(Service.status == status_filter)
    
    services = query.order_by(Service.created_at.desc()).all()
    
    return {
        "success": True,
        "data": [
            ServiceResponse(
                id=str(s.id),
                machine_id=str(s.machine_id),
                name=s.name,
                price=float(s.price),
                status=s.status,
                created_at=s.created_at,
                updated_at=s.updated_at
            )
            for s in services
        ]
    }


@router.get("/machines/{machine_id}/services/active", response_model=SuccessResponse[list[ServiceResponse]])
async def get_active_services(
    machine_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Get only active services for a specific machine.
    
    This is a convenience endpoint for client apps to quickly
    fetch only the services they need to display.
    
    Args:
        machine_id: Machine UUID
        db: Database session
        current_user: Current authenticated user/machine
        
    Returns:
        List of active services
    """
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )
    
    # Get only active services
    services = db.query(Service).filter(
        Service.machine_id == machine_id,
        Service.status == "active"
    ).order_by(Service.created_at.desc()).all()
    
    return {
        "success": True,
        "data": [
            ServiceResponse(
                id=str(s.id),
                machine_id=str(s.machine_id),
                name=s.name,
                price=float(s.price),
                status=s.status,
                created_at=s.created_at,
                updated_at=s.updated_at
            )
            for s in services
        ]
    }


@router.get("/services/{service_id}", response_model=SuccessResponse[ServiceWithMachineResponse])

async def get_service(
    service_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get details of a specific service."""
    service = db.query(Service).filter(Service.id == service_id).first()
    
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found"
        )
    
    # Get machine name
    machine = db.query(Machine).filter(Machine.id == service.machine_id).first()
    
    return {
        "success": True,
        "data": ServiceWithMachineResponse(
            id=str(service.id),
            machine_id=str(service.machine_id),
            machine_name=machine.name if machine else "Unknown",
            name=service.name,
            price=float(service.price),
            status=service.status,
            created_at=service.created_at,
            updated_at=service.updated_at
        )
    }


@router.post("/machines/{machine_id}/services", response_model=SuccessResponse[ServiceResponse], status_code=status.HTTP_201_CREATED)
async def create_service(
    machine_id: str,
    service_data: ServiceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Create a new service for a machine."""
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )
    
    # Create service
    service = Service(
        machine_id=machine_id,
        name=service_data.name,
        price=service_data.price,
        status=service_data.status
    )
    
    try:
        db.add(service)
        db.commit()
        db.refresh(service)
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to create service: {str(e)}"
        )
    
    return {
        "success": True,
        "data": ServiceResponse(
            id=str(service.id),
            machine_id=str(service.machine_id),
            name=service.name,
            price=float(service.price),
            status=service.status,
            created_at=service.created_at,
            updated_at=service.updated_at
        )
    }


@router.put("/services/{service_id}", response_model=SuccessResponse[ServiceResponse])
async def update_service(
    service_id: str,
    service_data: ServiceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update service details."""
    service = db.query(Service).filter(Service.id == service_id).first()
    
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found"
        )
    
    # Track changes for catalog history
    old_price = float(service.price)
    old_name = service.name
    price_changed = False
    name_changed = False
    
    # Update fields if provided
    if service_data.name is not None and service_data.name != old_name:
        name_changed = True
        service.name = service_data.name
    
    if service_data.price is not None:
        if float(service_data.price) != old_price:
            price_changed = True
            service.price = service_data.price
    
    if service_data.status is not None:
        service.status = service_data.status
    
    try:
        db.commit()
        db.refresh(service)
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to update service: {str(e)}"
        )
    
    return {
        "success": True,
        "data": ServiceResponse(
            id=str(service.id),
            machine_id=str(service.machine_id),
            name=service.name,
            price=float(service.price),
            status=service.status,
            created_at=service.created_at,
            updated_at=service.updated_at
        )
    }


@router.delete("/services/{service_id}", response_model=MessageResponse)
async def delete_service(
    service_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Delete a service."""
    service = db.query(Service).filter(Service.id == service_id).first()
    
    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Service not found"
        )
    
    try:
        db.delete(service)
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to delete service: {str(e)}"
        )
    
    return {
        "success": True,
        "message": "Service deleted successfully"
    }
