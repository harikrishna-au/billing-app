"""
Pydantic schemas for Service endpoints.
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class ServiceCreate(BaseModel):
    """Schema for creating a new service."""
    name: str = Field(..., min_length=1, max_length=255, description="Service name")
    price: float = Field(..., gt=0, description="Service price")
    status: str = Field(default="active", pattern="^(active|inactive)$", description="Service status")


class ServiceUpdate(BaseModel):
    """Schema for updating an existing service."""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    price: Optional[float] = Field(None, gt=0)
    status: Optional[str] = Field(None, pattern="^(active|inactive)$")


class ServiceResponse(BaseModel):
    """Schema for service response."""
    id: str
    machine_id: str
    name: str
    price: float
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ServiceWithMachineResponse(BaseModel):
    """Schema for service response with machine details."""
    id: str
    machine_id: str
    machine_name: str
    name: str
    price: float
    status: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
