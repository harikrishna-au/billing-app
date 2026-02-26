# MIT - Billing Admin

## Running the Backend

### Prerequisites
- Python 3.8+
- PostgreSQL (via Supabase)

### Setup & Run

```bash
cd backend

# Option 1: Quick setup script
chmod +x start.sh && ./start.sh

# Option 2: Manual setup
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Copy and fill in env vars
cp .env.example .env            # Update DATABASE_URL in .env

# Init DB and start server
python -m app.init_db
uvicorn app.main:app --reload
```

API runs at `http://localhost:8000`
Docs at `http://localhost:8000/docs`

Default credentials: `admin` / `admin`
