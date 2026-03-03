from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from app.database import get_db
from app.models.user import User
from app.models.location import Location
from app.dependencies import get_current_user
import uuid

router = APIRouter()


class LocationCreate(BaseModel):
    name: str
    upi_id: Optional[str] = None


class LocationUpdate(BaseModel):
    name: Optional[str] = None
    upi_id: Optional[str] = None


class LocationResponse(BaseModel):
    id: str
    name: str
    upi_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


@router.get("/", response_model=dict)
async def list_locations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    locations = db.query(Location).filter(Location.user_id == current_user.id).all()
    return {
        "success": True,
        "data": [
            LocationResponse(
                id=str(loc.id),
                name=loc.name,
                upi_id=loc.upi_id,
                created_at=loc.created_at,
                updated_at=loc.updated_at,
            )
            for loc in locations
        ],
    }


@router.post("/", response_model=dict, status_code=status.HTTP_201_CREATED)
async def create_location(
    payload: LocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    location = Location(
        id=uuid.uuid4(),
        user_id=current_user.id,
        name=payload.name,
        upi_id=payload.upi_id or None,
    )
    db.add(location)
    db.commit()
    db.refresh(location)
    return {
        "success": True,
        "data": LocationResponse(
            id=str(location.id),
            name=location.name,
            upi_id=location.upi_id,
            created_at=location.created_at,
            updated_at=location.updated_at,
        ),
    }


@router.put("/{location_id}", response_model=dict)
async def update_location(
    location_id: str,
    payload: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    location = db.query(Location).filter(
        Location.id == location_id,
        Location.user_id == current_user.id,
    ).first()
    if not location:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Location not found")

    if payload.name is not None:
        location.name = payload.name
    if payload.upi_id is not None:
        location.upi_id = payload.upi_id.strip() or None

    db.commit()
    db.refresh(location)
    return {
        "success": True,
        "data": LocationResponse(
            id=str(location.id),
            name=location.name,
            upi_id=location.upi_id,
            created_at=location.created_at,
            updated_at=location.updated_at,
        ),
    }


@router.delete("/{location_id}", response_model=dict)
async def delete_location(
    location_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    location = db.query(Location).filter(
        Location.id == location_id,
        Location.user_id == current_user.id,
    ).first()
    if not location:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Location not found")

    db.delete(location)
    db.commit()
    return {"success": True, "message": "Location deleted successfully"}
