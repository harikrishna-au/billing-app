"""
Migration script to add user_id to machines table.
This links each machine to its owner admin.
"""
from sqlalchemy import text
from app.database import engine, SessionLocal
from app.models.user import User
from app.models.machine import Machine

def migrate():
    print("🔧 Starting migration: Add user_id to machines...")
    
    with engine.connect() as conn:
        # Check if column already exists
        result = conn.execute(text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='machines' AND column_name='user_id'
        """))
        
        if result.fetchone():
            print("ℹ️  Column user_id already exists in machines table")
            return
        
        # Add user_id column (nullable first)
        print("📝 Adding user_id column to machines table...")
        conn.execute(text("""
            ALTER TABLE machines 
            ADD COLUMN user_id UUID
        """))
        conn.commit()
        print("✅ Column added")
    
    # Assign existing machines to default admin
    db = SessionLocal()
    try:
        # Get the first admin user (or create one)
        admin = db.query(User).filter(User.username == "admin").first()
        
        if not admin:
            print("❌ No admin user found. Please create an admin user first.")
            return
        
        print(f"📌 Assigning all existing machines to admin: {admin.username}")
        
        # Update all machines without user_id
        machines = db.query(Machine).filter(Machine.user_id == None).all()
        for machine in machines:
            machine.user_id = admin.id
        
        db.commit()
        print(f"✅ Assigned {len(machines)} machines to {admin.username}")
        
    except Exception as e:
        print(f"❌ Error assigning machines: {e}")
        db.rollback()
    finally:
        db.close()
    
    # Make user_id NOT NULL and add foreign key
    with engine.connect() as conn:
        print("🔒 Adding NOT NULL constraint and foreign key...")
        conn.execute(text("""
            ALTER TABLE machines 
            ALTER COLUMN user_id SET NOT NULL
        """))
        
        conn.execute(text("""
            ALTER TABLE machines 
            ADD CONSTRAINT fk_machines_user_id 
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        """))
        conn.commit()
        print("✅ Constraints added")
    
    print("✅ Migration complete!")

if __name__ == "__main__":
    migrate()
