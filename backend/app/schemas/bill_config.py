"""Pydantic schemas for Bill Configuration endpoints."""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class BillConfigUpdate(BaseModel):
    """All fields optional — sent as a PATCH-style PUT."""
    org_name: Optional[str] = Field(None, max_length=255)
    tagline: Optional[str] = Field(None, max_length=255)
    logo_url: Optional[str] = Field(None, max_length=500)

    unit_name: Optional[str] = Field(None, max_length=255)
    territory: Optional[str] = Field(None, max_length=255)
    gst_number: Optional[str] = Field(None, max_length=50)
    pos_id: Optional[str] = Field(None, max_length=50)

    cgst_percent: Optional[float] = Field(None, ge=0, le=100)
    sgst_percent: Optional[float] = Field(None, ge=0, le=100)

    footer_message: Optional[str] = Field(None, max_length=500)
    website: Optional[str] = Field(None, max_length=255)
    toll_free: Optional[str] = Field(None, max_length=50)


class BillConfigResponse(BaseModel):
    """Full config returned by the API."""
    id: str
    machine_id: str
    org_name: str
    tagline: Optional[str]
    logo_url: Optional[str]
    unit_name: Optional[str]
    territory: Optional[str]
    gst_number: Optional[str]
    pos_id: Optional[str]
    cgst_percent: float
    sgst_percent: float
    footer_message: Optional[str]
    website: Optional[str]
    toll_free: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
