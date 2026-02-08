"""
Script to add username and password columns to existing machines table.
"""
from app.database import SessionLocal, engine
from sqlalchemy import text
from app.core.security import get_password_hash


def add_machine_credentials():
    """Add username and hashed_password columns to machines table."""
    db = SessionLocal()
    
    try:
        print("📊 Adding username and hashed_password columns to machines table...")
        
        # Add columns
        with engine.connect() as conn:
            # Add username column (nullable first)
            conn.execute(text("ALTER TABLE machines ADD COLUMN IF NOT EXISTS username VARCHAR(100)"))
            # Add hashed_password column (nullable first)
            conn.execute(text("ALTER TABLE machines ADD COLUMN IF NOT EXISTS hashed_password VARCHAR(255)"))
            conn.commit()
        
        print("✅ Columns added successfully")
        
        # Update existing machines with default credentials
        print("📝 Updating existing machines with default credentials...")
        
        machines = db.execute(text("SELECT id, name FROM machines WHERE username IS NULL")).fetchall()
        
        if machines:
            default_password_hash = get_password_hash("admin123")
            
            for idx, (machine_id, machine_name) in enumerate(machines, start=1):
                username = f"admin{idx:03d}"
                db.execute(
                    text("UPDATE machines SET username = :username, hashed_password = :password WHERE id = :id"),
                    {"username": username, "password": default_password_hash, "id": machine_id}
                )
            
            db.commit()
            print(f"✅ Updated {len(machines)} machines with credentials")
        
        # Now make columns NOT NULL and add unique constraint
        print("🔒 Adding constraints...")
        with engine.connect() as conn:
            conn.execute(text("ALTER TABLE machines ALTER COLUMN username SET NOT NULL"))
            conn.execute(text("ALTER TABLE machines ALTER COLUMN hashed_password SET NOT NULL"))
            conn.execute(text("ALTER TABLE machines ADD CONSTRAINT machines_username_key UNIQUE (username)"))
            conn.commit()
        
        print("✅ Constraints added successfully")
        
        # Show updated machines
        print("\n📋 Updated machines:")
        machines = db.execute(text("SELECT name, username FROM machines")).fetchall()
        for name, username in machines:
            print(f"   - {name}: {username}")
        
        print("\n✅ Migration completed successfully!")
        print("⚠️  Default password for all machines: admin123")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    add_machine_credentials()
