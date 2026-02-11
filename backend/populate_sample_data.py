"""
Script to populate the database with sample data for testing.
"""
from datetime import datetime, timedelta
import random
from app.database import SessionLocal
from app.models.machine import Machine
from app.models.payment import Payment


def populate_sample_data():
    """Add sample machines and payments to the database."""
    db = SessionLocal()
    
    try:
        # Check if data already exists
        existing_machines = db.query(Machine).count()
        if existing_machines > 0:
            print(f"⚠️  Database already has {existing_machines} machines. Skipping sample data creation.")
            return
        
        print("📊 Creating sample machines...")
        
        # Create sample machines
        machines = [
            Machine(
                name="Main Entrance POS",
                location="Lobby A",
                status="online",
                last_sync=datetime.now() - timedelta(minutes=5),
                online_collection=12500.00,
                offline_collection=5000.00
            ),
            Machine(
                name="Cafeteria Kiosk",
                location="Canteen",
                status="online",
                last_sync=datetime.now() - timedelta(minutes=10),
                online_collection=8500.00,
                offline_collection=2000.00
            ),
            Machine(
                name="Parking Gate 1",
                location="Basement Level 1",
                status="offline",
                last_sync=datetime.now() - timedelta(hours=3),
                online_collection=15000.00,
                offline_collection=3500.00
            ),
            Machine(
                name="Lobby Terminal",
                location="Main Lobby",
                status="maintenance",
                last_sync=datetime.now() - timedelta(hours=1),
                online_collection=9500.00,
                offline_collection=1500.00
            ),
        ]
        
        db.add_all(machines)
        db.commit()
        
        print(f"✅ Created {len(machines)} machines")
        
        # Refresh to get IDs
        for machine in machines:
            db.refresh(machine)
        
        print("💰 Creating sample payments...")
        
        # Create sample payments for the last 7 days
        payments = []
        today = datetime.now()
        
        for i in range(7):
            date = today - timedelta(days=6-i)
            # Create 5-15 payments per day
            num_payments = random.randint(5, 15)
            
            for j in range(num_payments):
                machine = random.choice(machines)
                amount = random.choice([50, 100, 150, 200, 250, 300, 500])
                method = random.choice(['UPI', 'Card', 'Cash'])
                
                # Set payment time to random hour of the day
                payment_time = date.replace(
                    hour=random.randint(8, 20),
                    minute=random.randint(0, 59),
                    second=random.randint(0, 59)
                )
                
                payment = Payment(
                    machine_id=machine.id,
                    bill_number=f"TXN-{date.strftime('%Y%m%d')}-{j+1:03d}",
                    amount=amount,
                    method=method,
                    status='success',
                    created_at=payment_time
                )
                payments.append(payment)
        
        db.add_all(payments)
        db.commit()
        
        print(f"✅ Created {len(payments)} payments")
        
        # Print summary
        total_amount = sum(p.amount for p in payments)
        print(f"\n📈 Summary:")
        print(f"   Total Machines: {len(machines)}")
        print(f"   Total Payments: {len(payments)}")
        print(f"   Total Amount: ₹{total_amount:,.2f}")
        print(f"\n✅ Sample data created successfully!")
        
    except Exception as e:
        print(f"❌ Error creating sample data: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    populate_sample_data()
