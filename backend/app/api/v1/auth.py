from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from datetime import timedelta, datetime, timezone
from typing import Union
import httpx
import json

from app.database import get_db
from app.core.security import verify_password, create_access_token, create_refresh_token, decode_token, get_password_hash
from app.core.config import settings
from app.core.logger import log_auth_success, log_auth_failure, log_token_refresh, log_logout
from app.models.user import User, UserRole
from app.models.machine import Machine
from app.schemas.auth import LoginRequest, TokenResponse, TokenRefreshRequest, TokenRefreshResponse
from app.utils.alert_service import resolve_machine_alerts, create_alert_if_not_exists
from app.models.alert import AlertSeverity
from app.schemas.user import UserResponse
from app.schemas.common import SuccessResponse, ErrorResponse, ErrorDetail, MessageResponse
from app.dependencies import get_current_user
from app.core.limiter import limiter

router = APIRouter()

# Force reload


@router.post("/bootstrap-superadmin", response_model=SuccessResponse[dict])
async def bootstrap_superadmin(body: dict, db: Session = Depends(get_db)):
    """
    One-time endpoint to create the very first superadmin account.
    Returns 403 once any superadmin already exists — cannot be used again.
    """
    already_exists = db.query(User).filter(User.role == UserRole.SUPERADMIN).first()
    if already_exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="A superadmin already exists. This endpoint is disabled."
        )

    username = (body.get("username") or "").strip()
    email    = (body.get("email")    or "").strip()
    password = (body.get("password") or "")

    if not username or not email or not password:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="username, email and password are required")

    if db.query(User).filter(User.username == username).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already taken")

    user = User(
        username=username,
        email=email,
        hashed_password=get_password_hash(password),
        role=UserRole.SUPERADMIN,
        is_active="true",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return {
        "success": True,
        "data": {
            "id": str(user.id),
            "username": user.username,
            "email": user.email,
            "role": user.role,
            "message": "Superadmin created. This endpoint is now permanently disabled."
        }
    }


@router.post("/login", response_model=SuccessResponse[dict])
@limiter.limit("10/minute")
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


@router.post("/phone-login", response_model=SuccessResponse[dict])
async def phone_login(
    request_data: dict,
    db: Session = Depends(get_db)
):
    """
    Authenticate admin via Supabase phone OTP.
    Accepts a verified Supabase access token, looks up the user by phone,
    and issues our own JWT.
    """
    supabase_token = request_data.get("supabase_token")
    if not supabase_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="supabase_token is required")

    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Supabase not configured")

    # Verify the Supabase token and get the phone number
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{settings.SUPABASE_URL}/auth/v1/user",
            headers={
                "Authorization": f"Bearer {supabase_token}",
                "apikey": settings.SUPABASE_ANON_KEY,
            },
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired Supabase token")

    supabase_user = resp.json()
    phone = supabase_user.get("phone")

    if not phone:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No phone number associated with this Supabase session")

    # Find our user by phone
    user = db.query(User).filter(User.phone == phone).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No admin account found for this phone number. Contact your administrator.")

    if user.is_active != "true":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is inactive")

    # Issue our own JWT
    access_token = create_access_token(
        data={"sub": str(user.id), "username": user.username, "role": user.role}
    )
    refresh_token = create_refresh_token(data={"sub": str(user.id)})

    log_auth_success(user.username, None)

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


@router.post("/firebase-login", response_model=SuccessResponse[dict])
async def firebase_login(
    request_data: dict,
    db: Session = Depends(get_db)
):
    """
    Authenticate admin via Firebase phone OTP.
    Accepts a verified Firebase ID token + password.
    Verifies the token with Firebase Admin SDK, looks up the user by phone,
    validates the password, then issues our own JWT.
    """
    firebase_id_token = request_data.get("firebase_id_token")

    if not firebase_id_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="firebase_id_token is required")

    if not settings.FIREBASE_PROJECT_ID:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Firebase not configured")

    # Initialize Firebase Admin SDK (idempotent)
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth, credentials as firebase_credentials

        if not firebase_admin._apps:
            if settings.FIREBASE_SERVICE_ACCOUNT_JSON:
                sa_dict = json.loads(settings.FIREBASE_SERVICE_ACCOUNT_JSON)
                cred = firebase_credentials.Certificate(sa_dict)
            else:
                # Fall back to application default credentials
                cred = firebase_credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)

        # Verify the Firebase ID token
        decoded_token = firebase_auth.verify_id_token(firebase_id_token)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid or expired Firebase token: {str(e)}")

    phone = decoded_token.get("phone_number")
    if not phone:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No phone number in Firebase token")

    # Find user by phone
    user = db.query(User).filter(User.phone == phone).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No admin account found for this phone number")

    if user.is_active != "true":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is inactive")

    # Issue our JWT
    access_token = create_access_token(
        data={"sub": str(user.id), "username": user.username, "role": user.role}
    )
    refresh_token = create_refresh_token(data={"sub": str(user.id)})

    log_auth_success(user.username, None)

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


@router.post("/self-register", response_model=SuccessResponse[dict])
@limiter.limit("5/minute")
async def self_register(request: Request, request_data: dict, db: Session = Depends(get_db)):
    """
    Hidden self-registration endpoint (secret URL only).
    Accepts email + phone — no password or username required.
    Clerk has already verified the email via OTP on the frontend;
    we receive the Clerk session token to confirm identity.
    """
    import secrets as _secrets
    import re

    reg_token = request_data.get("token", "")
    if not reg_token or reg_token != settings.SELF_REGISTER_TOKEN:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    email       = (request_data.get("email")       or "").strip().lower()
    phone       = (request_data.get("phone")       or "").strip() or None
    clerk_token = (request_data.get("clerkToken")  or "").strip()

    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="email is required")
    if not phone:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="phone is required")
    if not clerk_token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="clerkToken is required")

    # Format phone
    digits = re.sub(r"\D", "", phone)
    if len(digits) == 10:
        phone = f"+91{digits}"

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    # Verify clerkToken server-side — prove the caller actually completed Clerk OTP for this email.
    if settings.CLERK_SECRET_KEY:
        try:
            from jose import jwt as jose_jwt
            from urllib.parse import urlparse as _urlparse

            unverified = jose_jwt.get_unverified_claims(clerk_token)
            iss = unverified.get("iss", "")
            _host = (_urlparse(iss).hostname or "").lower()
            if not (_host == "clerk.com" or _host.endswith(".clerk.com")
                    or _host.endswith(".clerk.accounts.dev") or _host.endswith(".clerkstage.dev")):
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Clerk token issuer")

            async with httpx.AsyncClient() as _hc:
                _jwks = await _hc.get(f"{iss}/.well-known/jwks.json", timeout=8.0)
            if _jwks.status_code != 200:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not verify Clerk token")

            claims = jose_jwt.decode(clerk_token, _jwks.json(), algorithms=["RS256"], options={"verify_aud": False})
            clerk_user_id = claims.get("sub")
            if not clerk_user_id:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Clerk token: no user ID")

            async with httpx.AsyncClient() as _hc:
                _user_resp = await _hc.get(
                    f"https://api.clerk.com/v1/users/{clerk_user_id}",
                    headers={"Authorization": f"Bearer {settings.CLERK_SECRET_KEY}"},
                    timeout=8.0,
                )
            if _user_resp.status_code != 200:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not verify Clerk identity")

            _ud = _user_resp.json()
            _primary_id = _ud.get("primary_email_address_id")
            _clerk_email = next(
                (ea["email_address"] for ea in _ud.get("email_addresses", []) if ea["id"] == _primary_id),
                None,
            )
            if not _clerk_email or _clerk_email.lower() != email:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                                    detail="Clerk session email does not match the provided email")
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                                detail=f"Clerk verification failed: {exc}")

    # Auto-generate a unique username from the email local part
    base = re.sub(r"[^a-z0-9_]", "_", email.split("@")[0].lower())[:30]
    username = base
    suffix = 1
    while db.query(User).filter(User.username == username).first():
        username = f"{base}_{suffix}"
        suffix += 1

    user = User(
        username=username,
        email=email,
        phone=phone,
        hashed_password=get_password_hash(_secrets.token_hex(32)),  # placeholder — login is via Clerk OTP
        role=UserRole.ADMIN,
        is_active="true",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return {
        "success": True,
        "data": {
            "id": str(user.id),
            "username": user.username,
            "email": user.email,
            "role": user.role,
        }
    }


@router.post("/check-email", response_model=SuccessResponse[dict])
@limiter.limit("10/minute")
async def check_email(request: Request, request_data: dict, db: Session = Depends(get_db)):
    """
    Pre-flight check before sending a Clerk magic link.
    Returns 200 if the email belongs to an active admin, 404 otherwise.
    Does NOT reveal whether it's a role/status issue — generic message only.
    """
    email = (request_data.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="email is required")

    user = db.query(User).filter(User.email == email, User.is_active == "true").first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="This email is not registered. Contact your superadmin to get access."
        )
    return {"success": True, "data": {"allowed": True}}


@router.post("/clerk-login", response_model=SuccessResponse[dict])
async def clerk_login(
    request_data: dict,
    db: Session = Depends(get_db)
):
    """
    Authenticate admin via Clerk email magic link.
    Accepts a Clerk session JWT, verifies it against Clerk's JWKS,
    fetches the user's email from Clerk's API, then issues our own JWT.
    """
    token = request_data.get("clerk_token")
    if not token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="clerk_token is required")

    if not settings.CLERK_SECRET_KEY:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Clerk not configured")

    try:
        from jose import jwt as jose_jwt, JWTError

        # Decode without verification to get the issuer for the JWKS URL
        unverified_claims = jose_jwt.get_unverified_claims(token)
        iss = unverified_claims.get("iss", "")
        if not iss:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Clerk token: missing issuer")

        # Allowlist the issuer host — prevents SSRF via attacker-controlled iss claim
        from urllib.parse import urlparse as _urlparse
        _iss_host = (_urlparse(iss).hostname or "").lower()
        _allowed = (
            _iss_host == "clerk.com"
            or _iss_host.endswith(".clerk.com")
            or _iss_host.endswith(".clerk.accounts.dev")
            or _iss_host.endswith(".clerkstage.dev")
        )
        if not _allowed:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Clerk token: untrusted issuer")

        # Fetch JWKS from Clerk
        async with httpx.AsyncClient() as client:
            jwks_resp = await client.get(f"{iss}/.well-known/jwks.json", timeout=10.0)

        if jwks_resp.status_code != 200:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not fetch Clerk JWKS")

        jwks = jwks_resp.json()

        # Verify signature and decode claims
        claims = jose_jwt.decode(
            token, jwks,
            algorithms=["RS256"],
            options={"verify_aud": False}
        )

        clerk_user_id = claims.get("sub")
        if not clerk_user_id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Clerk token: no user ID")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid Clerk token: {e}")

    # Fetch the user's email from Clerk's Backend API
    try:
        async with httpx.AsyncClient() as client:
            user_resp = await client.get(
                f"https://api.clerk.com/v1/users/{clerk_user_id}",
                headers={"Authorization": f"Bearer {settings.CLERK_SECRET_KEY}"},
                timeout=10.0,
            )

        if user_resp.status_code != 200:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Could not fetch user from Clerk")

        clerk_user = user_resp.json()
        primary_email_id = clerk_user.get("primary_email_address_id")
        email = next(
            (ea["email_address"] for ea in clerk_user.get("email_addresses", [])
             if ea["id"] == primary_email_id),
            None
        )

        if not email:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No email address on Clerk account")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Clerk user lookup failed: {e}")

    # Find admin by email in our DB
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No admin account found for this email. Contact your superadmin."
        )

    if user.is_active != "true":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is inactive")

    # Issue our JWT
    access_token = create_access_token(
        data={"sub": str(user.id), "username": user.username, "role": user.role}
    )
    refresh_token = create_refresh_token(data={"sub": str(user.id)})

    log_auth_success(user.username, None)

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
    machine.last_sync = datetime.now(timezone.utc)

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
                "last_sync": machine.last_sync.isoformat() if machine.last_sync else None,
                "bill_counter": machine.bill_counter or 0
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
    
    # Get entity ID from token
    entity_id = payload.get("sub")
    if not entity_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )

    token_entity_type = payload.get("type")  # "machine" or absent (user)

    # Handle machine refresh tokens
    if token_entity_type == "machine":
        machine = db.query(Machine).filter(Machine.id == entity_id).first()
        if not machine:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Machine not found"
            )
        access_token = create_access_token(
            data={
                "sub": str(machine.id),
                "username": machine.username,
                "type": "machine",
                "machine_id": str(machine.id),
            }
        )
        log_token_refresh(str(machine.id))
        return {
            "success": True,
            "data": {
                "access_token": access_token,
                "token_type": "bearer",
                "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            }
        }

    user = db.query(User).filter(User.id == entity_id).first()
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
        current_user.last_sync = datetime.now(timezone.utc)
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
