import logging
import sys
from datetime import datetime
from typing import Optional

# Configure logging format
LOG_FORMAT = "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# Create logger
logger = logging.getLogger("billing_admin")
logger.setLevel(logging.DEBUG)

# Console handler
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.DEBUG)
console_formatter = logging.Formatter(LOG_FORMAT, DATE_FORMAT)
console_handler.setFormatter(console_formatter)

# Add handler
logger.addHandler(console_handler)


def log_request(method: str, path: str, status_code: int, duration_ms: float, user: Optional[str] = None):
    """Log HTTP request."""
    user_info = f"user={user}" if user else "anonymous"
    logger.info(f"{method} {path} | {status_code} | {duration_ms:.2f}ms | {user_info}")


def log_auth_success(username: str, ip: Optional[str] = None):
    """Log successful authentication."""
    ip_info = f"from {ip}" if ip else ""
    logger.info(f"🔐 AUTH SUCCESS | user={username} {ip_info}")


def log_auth_failure(username: str, reason: str, ip: Optional[str] = None):
    """Log failed authentication attempt."""
    ip_info = f"from {ip}" if ip else ""
    logger.warning(f"🔒 AUTH FAILED | user={username} | reason={reason} {ip_info}")


def log_token_refresh(user_id: str):
    """Log token refresh."""
    logger.info(f"🔄 TOKEN REFRESH | user_id={user_id}")


def log_logout(username: str):
    """Log user logout."""
    logger.info(f"👋 LOGOUT | user={username}")


def log_error(message: str, error: Exception):
    """Log error with exception details."""
    logger.error(f"❌ ERROR | {message} | {type(error).__name__}: {str(error)}")
