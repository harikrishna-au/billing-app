from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from datetime import timedelta, datetime
from typing import Union

from app.database import get_db
from app.core.security import verify_password, create_access_token, create_refresh_token, decode_token, get_password_hash
from app.core.config import settings
from app.core.logger import log_auth_success, log_auth_failure, log_token_refresh, log_logout
from app.models.user import User
from app.models.machine import Machine
from app.schemas.auth import LoginRequest, TokenResponse, TokenRefreshRequest, TokenRefreshResponse
from app.utils.alert_service import resolve_machine_alerts, create_alert_if_not_exists
from app.models.alert import AlertSeverity
from app.schemas.user import UserResponse
from app.schemas.common import SuccessResponse, ErrorResponse, ErrorDetail, MessageResponse
from app.dependencies import get_current_user

router = APIRouter()

# Force reload


@router.post("/login", response_model=SuccessResponse[dict])
async def login(
    credentials: LoginRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Authenticate user and return JWT tokens.
    
    Args:
        credentials: Username and password
        request: Request object for IP logging
        db: Database session
        
    Returns:
        Access token, refresh token, and user information
        
    Raises:
        HTTPException: If credentials are invalid
    """
    # Get client IP
    client_ip = request.client.host if request.client else None
    
    # Find user by username
    user = db.query(User).filter(User.username == credentials.username).first()
    
    # Verify user exists and password is correct
    if not user or not verify_password(credentials.password, user.hashed_password):
        log_auth_failure(credentials.username, "Invalid credentials", client_ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    
    # Check if user is active
    if user.is_active != "true":
        log_auth_failure(credentials.username, "Account inactive", client_ip)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    
    # Create access token
    access_token = create_access_token(
        data={"sub": str(user.id), "username": user.username, "role": user.role}
    )
    
    # Create refresh token
    refresh_token = create_refresh_token(
        data={"sub": str(user.id)}
    )
    
    # Log successful authentication
    log_auth_success(user.username, client_ip)
    
    return {
        "success": True,
        "data": {
            "user": {
                "id": str(user.id),
                "username": user.username,
                "email": user.email,
                "role": user.role,
                "created_at": user.created_at.isoformat()
            },
            "token": access_token,
            "refresh_token": refresh_token,
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        }
    }


@router.post("/machine-login", response_model=SuccessResponse[dict])
async def machine_login(
    credentials: LoginRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Authenticate machine (client app) and return JWT tokens.
    
    This endpoint is specifically for machine/client app authentication.
    Machines login with their username and password to access the API.
    
    Args:
        credentials: Machine username and password
        request: Request object for IP logging
        db: Database session
        
    Returns:
        Access token, refresh token, and machine information
        
    Raises:
        HTTPException: If credentials are invalid
    """
    # Import Machine model here to avoid circular imports
    from app.models.machine import Machine
    
    # Get client IP
    client_ip = request.client.host if request.client else None
    
    # Find machine by username
    machine = db.query(Machine).filter(Machine.username == credentials.username).first()
    
    # Verify machine exists and password is correct
    if not machine or not verify_password(credentials.password, machine.hashed_password):
        log_auth_failure(credentials.username, "Invalid machine credentials", client_ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid machine username or password",
        )
    
    # Check if machine is active (not in maintenance mode permanently)
    if machine.status == "maintenance":
        log_auth_failure(credentials.username, "Machine in maintenance mode", client_ip)
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Machine is in maintenance mode"
        )
    
    # Create access token with machine context
    access_token = create_access_token(
        data={
            "sub": str(machine.id),
            "username": machine.username,
            "type": "machine",  # Identify this as a machine token
            "machine_id": str(machine.id)
        }
    )
    
    # Create refresh token
    refresh_token = create_refresh_token(
        data={"sub": str(machine.id), "type": "machine"}
    )
    
    # Update machine status to online and last_sync
    machine.status = "online"
    machine.last_sync = datetime.utcnow()

    try:
        db.commit()
    except Exception:
        db.rollback()

    # Resolve any existing offline/maintenance alerts now that machine is online
    resolve_machine_alerts(db, str(machine.id))
    
    # Log successful authentication
    log_auth_success(machine.username, client_ip)
    
    return {
        "success": True,
        "data": {
            "machine": {
                "id": str(machine.id),
                "name": machine.name,
                "location": machine.location,
                "username": machine.username,
                "status": machine.status,
                "last_sync": machine.last_sync.isoformat() if machine.last_sync else None
            },
            "token": access_token,
            "refresh_token": refresh_token,
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        }
    }


@router.post("/refresh", response_model=SuccessResponse[TokenRefreshResponse])

async def refresh_token(
    request: TokenRefreshRequest,
    db: Session = Depends(get_db)
):
    """
    Refresh an expired access token using a refresh token.
    
    Args:
        request: Refresh token
        db: Database session
        
    Returns:
        New access token
        
    Raises:
        HTTPException: If refresh token is invalid
    """
    # Decode refresh token
    payload = decode_token(request.refresh_token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    # Check token type
    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type"
        )
    
    # Get user
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    # Check if user is active
    if user.is_active != "true":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    
    # Create new access token
    access_token = create_access_token(
        data={"sub": str(user.id), "username": user.username, "role": user.role}
    )
    
    # Log token refresh
    log_token_refresh(str(user.id))
    
    return {
        "success": True,
        "data": {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        }
    }


@router.post("/logout", response_model=MessageResponse)
async def logout(
    current_user: User = Depends(get_current_user)
):
    """
    Logout current user.
    
    Note: With JWT tokens, logout is handled client-side by removing the token.
    This endpoint is provided for consistency and can be extended to implement
    token blacklisting if needed.
    
    Args:
        current_user: Current authenticated user
        
    Returns:
        Success message
    """
    # Log logout event
    log_logout(current_user.username)
    
    return {
        "success": True,
        "message": "Logged out successfully"
    }


@router.get("/me", response_model=SuccessResponse[dict])
async def get_current_user_info(
    current_user: Union[User, Machine] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current authenticated user or machine information.
    For machine tokens, also marks the machine as online.
    """
    if isinstance(current_user, Machine):
        # Update machine status to online whenever the app calls /me
        current_user.status = "online"
        current_user.last_sync = datetime.utcnow()
        try:
            db.commit()
        except Exception:
            db.rollback()

        # Resolve any existing offline/maintenance alerts
        resolve_machine_alerts(db, str(current_user.id))

        return {
            "success": True,
            "data": {
                "id": str(current_user.id),
                "username": current_user.username,
                "is_active": "true",
                "status": current_user.status,
                "last_sync": current_user.last_sync.isoformat() if current_user.last_sync else None,
            }
        }

    return {
        "success": True,
        "data": {
            "id": str(current_user.id),
            "username": current_user.username,
            "email": current_user.email,
            "role": current_user.role,
            "created_at": current_user.created_at
        }
    }
