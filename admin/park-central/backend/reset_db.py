"""
Script to reset the database.
WARNING: This will delete ALL data in the database.
"""
import sys
from sqlalchemy import text
from app.database import engine
from app.models.user import User
from app.models.machine import Machine
from app.models.payment import Payment
from app.models.service import Service
from app.models.log import Log
from app.models.alert import SystemAlert
# Import other models if they exist to ensure metadata is loaded

from app.init_db import init_db

def reset_db():
    print("⚠️  WARNING: This will DELETE ALL DATA in the database!")
    confirm = input("Are you sure you want to continue? (y/n): ")
    
    if confirm.lower() != 'y':
        print("Operation cancelled.")
        sys.exit(0)
        
    print("\n🗑️  Dropping all tables (CASCADE)...")
    # Use raw SQL to drop schema cascade - this works for Postgres
    # and handles all dependencies and unmapped tables
    with engine.connect() as conn:
        conn.execute(text("DROP SCHEMA public CASCADE;"))
        conn.execute(text("CREATE SCHEMA public;"))
        conn.commit()
    print("✅ Schema reset.")
    
    print("\nRE-INITIALIZING DATABASE...")
    # This will create tables and the default admin user
    init_db()
    
    print("\n✅ Database reset complete!")

if __name__ == "__main__":
    reset_db()
