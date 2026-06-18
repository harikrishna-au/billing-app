# MIT Billing System

A full-stack POS and billing platform consisting of three components:

| Component | Stack | Purpose |
|-----------|-------|---------|
| **Backend** | FastAPI · Python · PostgreSQL | REST API, auth, payments, sync |
| **Admin Panel** | React · TypeScript · shadcn/ui | Manage clients, machines, services, revenue |
| **Client App** | Flutter · Dart · Riverpod | POS terminal — checkout, receipts, offline sync |

---

## Architecture Overview

```
┌──────────────────┐        ┌───────────────────────┐
│   Admin Panel    │        │     Flutter Client     │
│  (React/Vite)   │        │   (POS Terminal App)   │
└────────┬─────────┘        └──────────┬────────────┘
         │  REST + JWT                 │  REST + Machine JWT
         ▼                             ▼
┌──────────────────────────────────────────────────────┐
│                   FastAPI Backend                    │
│  /auth  /payments  /sync  /config  /superadmin      │
│  PostgreSQL (Supabase)  ·  Clerk (email OTP)        │
└──────────────────────────────────────────────────────┘
```

**Auth model:**
- **Superadmin** — full platform control; logs in via username/password
- **Admin** — manages their own machines; logs in via Clerk email OTP
- **Machine** — POS device; logs in via `/auth/machine-login` and gets its own JWT

---

## Quick Start

### Prerequisites

- Python 3.10+
- Node.js 18+
- Flutter 3.19+
- A PostgreSQL database (Supabase free tier works)
- A Clerk account (for admin email OTP)

---

### 1. Backend

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate       # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env           # then fill in all values (see below)

# Start server (tables are created automatically on first run)
uvicorn app.main:app --reload
```

API: `http://localhost:8000`  
Interactive docs: `http://localhost:8000/docs`

#### Backend Environment Variables

```env
# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# JWT signing key — generate with: openssl rand -hex 32
SECRET_KEY=your-secret-key-here

# Clerk (for admin email OTP login)
CLERK_SECRET_KEY=sk_test_...

# Self-registration secret — generate with: python3 -c "import secrets; print(secrets.token_urlsafe(32))"
# NO DEFAULT — server will refuse to start if this is not set.
SELF_REGISTER_TOKEN=your-strong-random-token

# CORS (comma-separated origins)
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000

# Optional
DEBUG=True
PORT=8000
```

> **Important:** Never commit `.env` to git. The `SELF_REGISTER_TOKEN` has no hardcoded fallback — the server will not start without it.

---

### 2. Admin Panel

```bash
cd admin
npm install
npm run dev
```

Panel: `http://localhost:5173`

The panel has two separate portals:

| URL | Who | What |
|-----|-----|------|
| `/login` | Admins | Clerk email OTP sign-in |
| `/dashboard` | Admins | Clients, payments, analytics |
| `/superadmin` | Superadmin only | Admin accounts, UPI approvals, audit logs |

Route guards enforce role separation — an admin's JWT cannot access `/superadmin/*` routes, and the superadmin is redirected away from admin routes.

#### Admin Panel Environment Variables

Create `admin/.env`:
```env
VITE_API_BASE_URL=http://localhost:8000/v1
```

---

### 3. Flutter Client (POS App)

```bash
cd client
flutter pub get

# Run on connected Android device or emulator
flutter run --dart-define=PLUTUS_APPLICATION_ID=50269e0a955c4370a9c04c78fb111bd4
```

#### Building a Release APK

```bash
flutter build apk --release \
  --dart-define=PLUTUS_APPLICATION_ID=50269e0a955c4370a9c04c78fb111bd4
```

The `--dart-define` flag injects the Pine Labs Application ID at build time. The default in `plutus_config.dart` matches the value above, so the flag is only needed if you need to override it.

---

## Features

### Admin Panel
- **Client management** — create machines, set UPI ID, configure bill settings
- **Catalog management** — add/edit/delete services per machine
- **Payments dashboard** — filter by period, method, machine; export to Excel
- **Analytics** — revenue charts, uptime %, activity heatmap
- **Alerts** — offline machine detection, low-activity warnings
- **Superadmin panel** — create/suspend admin accounts, approve UPI change requests, view audit logs

### Flutter POS App
- **Checkout** — service catalogue, cart, GST calculation, bill preview
- **Payment flows** — Cash · UPI QR · Pine Labs card/UPI (Plutus terminal)
- **Receipt printing** — thermal printer via Pine Labs Plutus IPC
- **Offline mode** — payments queued locally when backend is unreachable; auto-synced on reconnect
- **Day summary** — daily totals by payment method, printable sales summary
- **Settings** — profile, notification preferences, UPI ID display

### Backend
- JWT auth with access + refresh tokens (separate for users and machines)
- Idempotent payment creation — retries never create duplicate records
- Offline sync — `/sync/push` and `/sync/pull` with machine-ownership enforcement
- Catalog versioning — `catalog_version` bumped on every service change; client detects stale catalog
- Rate limiting — auth endpoints protected with slowapi
- Audit logging — superadmin actions recorded with actor, target, and details

---

## Database

All schema changes are applied automatically at startup via inline migrations in `app/main.py`. There is no Alembic setup — each migration is idempotent and safe to run multiple times.

Tables: `users` · `machines` · `payments` · `services` · `bill_configs` · `locations` · `upi_change_requests` · `audit_logs`

---

## Pine Labs Integration

The client integrates with Pine Labs Plutus terminals (model A910S) via Messenger IPC to `com.pinelabs.masterapp`.

**Config file:** `client/lib/config/plutus_config.dart`

The Application ID is the 32-character string provided by Pine Labs for your registered package name + terminal serial. The current default (`50269e0a955c4370a9c04c78fb111bd4`) is the UAT ID for serial `2842079646` / package `com.mit`.

If the terminal returns `ResponseCode: 14 (Invalid Application Id)`:
1. Clear data from MasterApp / Home App on the terminal
2. Re-activate and let it sync to download provisioning changes
3. Retry — the IPC chain is confirmed working; code 14 is always a provisioning/mapping issue on Pine Labs' side, not a code bug

---

## Security Notes

- **SELF_REGISTER_TOKEN** — rotate it by updating `.env` and redeploying. Must be a strong random value; the server will not start without it.
- **Clerk verification** — `/auth/self-register` verifies the Clerk session token server-side (JWKS + backend API email check) before creating any account.
- **Machine isolation** — machine JWTs can only read and write data for their own machine. Cross-machine access returns 403.
- **SSRF protection** — Clerk JWT `iss` claims are validated against a strict domain allowlist before any outbound HTTP request.

---

## Project Structure

```
mit/
├── backend/               # FastAPI application
│   ├── app/
│   │   ├── api/v1/        # Route handlers (auth, payments, sync, config, superadmin, …)
│   │   ├── core/          # Config, security, logging, rate limiter
│   │   ├── models/        # SQLAlchemy ORM models
│   │   ├── schemas/       # Pydantic request/response schemas
│   │   └── main.py        # App factory + startup migrations
│   ├── requirements.txt
│   └── .env               # Not committed
│
├── admin/                 # React admin panel
│   ├── src/
│   │   ├── pages/         # Route-level page components
│   │   │   └── superadmin/  # Superadmin-only pages
│   │   ├── components/    # Shared UI components (ProtectedRoute, …)
│   │   └── lib/api/       # Typed API clients per domain
│   └── package.json
│
└── client/                # Flutter POS app
    └── lib/
        ├── config/        # App constants (API URL, Plutus config)
        ├── core/
        │   ├── network/   # Dio client, interceptors, providers
        │   └── services/  # Bill number generator, sync queue, print utils
        ├── data/
        │   ├── models/    # Domain models (Payment, BillConfig, Service, …)
        │   └── repositories/
        └── presentation/
            ├── providers/ # Riverpod state (auth, payment, bill config, cart)
            └── screens/   # All UI screens
```

---

## Contributing

Branch from `main`, make your changes, open a PR. The backend auto-migrates on startup so no manual schema steps are needed for new columns — just add the migration block in `startup_event` in `main.py` following the existing pattern.
