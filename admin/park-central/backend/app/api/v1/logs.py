from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional

from app.database import get_db
from app.models.log import Log
from app.models.machine import Machine
from app.schemas.log import LogCreate, LogResponse, LogListResponse
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.common import SuccessResponse

router = APIRouter()

@router.get("/machines/{machine_id}/logs", response_model=SuccessResponse[LogListResponse])
async def get_machine_logs(
    machine_id: str,
    type_filter: Optional[str] = Query(None, alias="type"),
    page: int = 1,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(status_code=404, detail="Machine not found")

    query = db.query(Log).filter(Log.machine_id == machine_id)
    
    if type_filter:
        query = query.filter(Log.type == type_filter)
    
    # Pagination
    total_items = query.count()
    total_pages = (total_items + limit - 1) // limit
    
    logs = query.order_by(desc(Log.created_at))\
        .offset((page - 1) * limit)\
        .limit(limit)\
        .all()
    
    return {
        "success": True,
        "data": {
            "logs": [
                LogResponse(
                    id=str(log.id),
                    machine_id=str(log.machine_id),
                    action=log.action,
                    details=log.details,
                    type=log.type,
                    created_at=log.created_at,
                    machine_name=machine.name
                ) for log in logs
            ],
            "pagination": {
                "current_page": page,
                "total_pages": total_pages,
                "total_items": total_items,
                "items_per_page": limit
            }
        }
    }

@router.post("/machines/{machine_id}/logs", response_model=SuccessResponse[LogResponse], status_code=status.HTTP_201_CREATED)
async def create_machine_log(
    machine_id: str,
    log_data: LogCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Verify machine exists
    machine = db.query(Machine).filter(Machine.id == machine_id).first()
    if not machine:
        raise HTTPException(status_code=404, detail="Machine not found")
        
    db_log = Log(
        machine_id=machine_id,
        action=log_data.action,
        details=log_data.details,
        type=log_data.type
    )
    
    try:
        db.add(db_log)
        db.commit()
        db.refresh(db_log)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
        
    return {
        "success": True,
        "data": LogResponse(
            id=str(db_log.id),
            machine_id=str(db_log.machine_id),
            action=db_log.action,
            details=db_log.details,
            type=db_log.type,
            created_at=db_log.created_at,
            machine_name=machine.name
        )
    }

@router.get("/logs/recent", response_model=SuccessResponse[List[LogResponse]])
async def get_recent_logs(
    limit: int = 10,
    type_filter: Optional[str] = Query(None, alias="type"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Log).join(Machine)
    
    if type_filter:
        query = query.filter(Log.type == type_filter)
        
    logs = query.order_by(desc(Log.created_at))\
        .limit(limit)\
        .all()
        
    # We need to manually fetch machine names usually, but generic relation or join works
    # Here logs are joined with machine to ensure existence, but we need machine name for response
    
    results = []
    for log in logs:
        # Simple fetch or if joined properly
        machine_name = db.query(Machine.name).filter(Machine.id == log.machine_id).scalar()
        results.append(
            LogResponse(
                id=str(log.id),
                machine_id=str(log.machine_id),
                action=log.action,
                details=log.details,
                type=log.type,
                created_at=log.created_at,
                machine_name=machine_name
            )
        )
        
    return {
        "success": True,
        "data": results
    }
