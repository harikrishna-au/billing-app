"""
One-time script to create the initial superadmin account.

Usage (from the backend/ directory):
    python create_superadmin.py

Edit the USERNAME / EMAIL / PASSWORD variables below before running.
"""

USERNAME  = "superadmin"
EMAIL     = "superadmin@yourdomain.com"
PHONE     = None          # optional, e.g. "+91 9876543210"
PASSWORD  = "changeme123" # change this!

# ─── Do not edit below ────────────────────────────────────────────────────────

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from app.database import SessionLocal
from app.models.user import User, UserRole
from app.core.security import get_password_hash


def main():
    db = SessionLocal()
    try:
        existing = db.query(User).filter(
            (User.username == USERNAME) | (User.email == EMAIL)
        ).first()

        if existing:
            print(f"❌  A user with username '{USERNAME}' or email '{EMAIL}' already exists.")
            print(f"    Username: {existing.username}, Role: {existing.role}")
            return

        user = User(
            username=USERNAME,
            email=EMAIL,
            phone=PHONE,
            hashed_password=get_password_hash(PASSWORD),
            role=UserRole.SUPERADMIN,
            is_active="true",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        print(f"✅  Superadmin created!")
        print(f"    Username : {user.username}")
        print(f"    Email    : {user.email}")
        print(f"    Role     : {user.role}")
        print(f"\n    Log in at /v1/auth/login with username='{USERNAME}' and your password.")
        print(f"    Change your password after first login.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
