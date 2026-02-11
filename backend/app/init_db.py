"""
Database initialization script.
Creates default admin user and sets up initial data.
"""
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models.user import User, UserRole
from app.core.security import get_password_hash


def init_db():
    """Initialize database with default data."""
    # Create all tables
    Base.metadata.create_all(bind=engine)
    
    # Create database session
    db = SessionLocal()
    
    try:
        # Check if admin user already exists
        admin_user = db.query(User).filter(User.username == "admin").first()
        
        if not admin_user:
            # Create default admin user
            # Note: bcrypt has a 72-byte password limit, so we use a simple password
            admin_password = "admin"  # Simple password for initial setup
            admin_user = User(
                username="admin",
                email="admin@billingadmin.com",
                hashed_password=get_password_hash(admin_password),
                role=UserRole.ADMIN,
                is_active="true"
            )
            db.add(admin_user)
            db.commit()
            print("✅ Created default admin user")
            print(f"   Username: admin")
            print(f"   Password: {admin_password}")
            print("   ⚠️  IMPORTANT: Change this password after first login!")
        else:
            print("ℹ️  Admin user already exists")
        
        # You can add more default data here
        # For example: default machines, services, etc.
        
        print("✅ Database initialized successfully")
        
    except Exception as e:
        print(f"❌ Error initializing database: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    print("🔧 Initializing database...")
    init_db()
