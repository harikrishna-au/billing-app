from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import Optional
import io
import csv

from app.database import get_db
from app.models.user import User
from app.models.machine import Machine
from app.models.service import Service

from app.dependencies import get_current_user
from app.schemas.service import ServiceCreate, ServiceUpdate, ServiceResponse, ServiceWithMachineResponse
from app.schemas.common import SuccessResponse, MessageResponse

router = APIRouter()


def _parse_excel_file(content: bytes) -> list[dict]:
    """Parse an xlsx/xls file and return a list of row dicts."""
    try:
        import openpyxl
        wb = openpyxl.load_workbook(io.BytesIO(content), data_only=True)
        ws = wb.active

        rows = list(ws.iter_rows(values_only=True))
        if not rows:
            raise ValueError("Excel file is empty")

        # Get headers from the first row
        headers = [str(h).strip() if h is not None else "" for h in rows[0]]
        data = []
        for row in rows[1:]:
            row_dict = {headers[i]: row[i] for i in range(len(headers))}
            data.append(row_dict)
        return data
    except ImportError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="openpyxl is not installed on the server"
        )


def _parse_csv_file(content: bytes) -> list[dict]:
    """Parse a CSV file and return a list of row dicts."""
    text = content.decode("utf-8-sig")  # handle BOM
    reader = csv.DictReader(io.StringIO(text))
    return [row for row in reader]


def _extract_service_row(row: dict) -> tuple[Optional[str], Optional[float]]:
    """
    Try to extract (name, price) from a row dict.
    Supports multiple column name variants from the tariff sheet.
    """
    name = None
    price = None

    # Name detection – priority order
    for col in ["Activity name/details", "Activity Name/Details", "activity name/details",
                "name", "Name", "Service Name", "service_name", "Activity"]:
        if col in row and row[col]:
            name = str(row[col]).strip()
            break

    # Price detection
    for col in ["Rate Per Head/Person", "Rate per Head/Person", "rate per head/person",
                "Price", "price", "Rate", "rate", "Amount", "amount"]:
        if col in row and row[col] is not None:
            try:
                val = str(row[col]).replace("₹", "").replace(",", "").strip()
                price = float(val)
                break
            except (ValueError, TypeError):
                continue

    return name, price


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


@router.post("/machines/{machine_id}/services/bulk-import")
async def bulk_import_services(
    machine_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Bulk import services for a machine from an Excel (.xlsx) or CSV (.csv) file.

    Expected columns (case-insensitive, flexible matching):
      - Activity name/details  →  service name
      - Rate Per Head/Person   →  service price

    Returns a summary of how many services were imported and how many rows were skipped.
    """
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Machine not found"
        )

    # Read file content
    content = await file.read()
    filename = file.filename or ""

    # Parse based on file type
    try:
        if filename.lower().endswith(".csv"):
            rows = _parse_csv_file(content)
        elif filename.lower().endswith(".xlsx") or filename.lower().endswith(".xls"):
            rows = _parse_excel_file(content)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Unsupported file type. Please upload a .xlsx or .csv file."
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to parse file: {str(e)}"
        )

    if not rows:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The file contains no data rows."
        )

    # Process rows
    created_services = []
    skipped_rows = []

    for i, row in enumerate(rows, start=2):  # start=2 because row 1 is the header
        name, price = _extract_service_row(row)

        if not name:
            skipped_rows.append({"row": i, "reason": "Missing service name"})
            continue
        if price is None or price <= 0:
            skipped_rows.append({"row": i, "reason": f"Invalid or missing price for '{name}'"})
            continue

        service = Service(
            machine_id=machine_id,
            name=name,
            price=price,
            status="active"
        )
        db.add(service)
        created_services.append(name)

    if not created_services:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No valid services found in the file. Make sure it has 'Activity name/details' and 'Rate Per Head/Person' columns."
        )

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to save services: {str(e)}"
        )

    return {
        "success": True,
        "imported": len(created_services),
        "skipped": len(skipped_rows),
        "skipped_details": skipped_rows,
        "message": f"Successfully imported {len(created_services)} service(s). {len(skipped_rows)} row(s) skipped."
    }
