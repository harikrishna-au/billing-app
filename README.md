# MIT Billing & POS Platform

A full-stack billing and point-of-sale system for managing POS terminals ("machines"), recording card / UPI / cash payments, and integrating with **Pine Labs Plutus Smart** terminals for in-person card and UPI transactions.

The platform has three parts:

| Component | Stack | Purpose |
|-----------|-------|---------|
| **Backend** | FastAPI · SQLAlchemy · PostgreSQL (Supabase) / SQLite | REST API, auth, payments, sync, analytics |
| **Admin** | React · TypeScript · Vite · shadcn/ui · TanStack Query · Recharts | Web dashboard for admins & superadmins |
| **Client** | Flutter · Riverpod · Dio · GoRouter | POS app running on Pine Labs A910S terminals |

---

## Architecture

```
                        ┌─────────────────────────────┐
                        │   Admin Web Panel (React)   │
                        │  dashboards, machines, UPI  │
                        └──────────────┬──────────────┘
                                       │ HTTPS / JWT
                                       ▼
┌──────────────────┐  HTTPS/JWT  ┌──────────────────────────────┐
│  Flutter POS App │────────────▶│   FastAPI Backend (Render)   │
│  (Pine A910S)    │◀────────────│   /v1 REST · JWT · SQLAlchemy│
│                  │   sync      └──────────────┬───────────────┘
│  ┌────────────┐  │                            │
│  │ Plutus IPC │  │                   ┌────────▼────────┐
│  │ MasterApp  │  │                   │  PostgreSQL DB  │
│  └────────────┘  │                   │   (Supabase)    │
└──────────────────┘                   └─────────────────┘
        │
        ▼
  Pine Labs MasterApp ──▶ Card / UPI payment host
  (com.pinelabs.masterapp)
```

**Data ownership model:** `User` (admin) → owns → `Machine` (POS terminal) → records → `Payment`. A superadmin sits above admins and approves sensitive changes (e.g. UPI ID updates).

---

## Repository Layout

```
mit/
├── backend/                 FastAPI REST API
│   ├── app/
│   │   ├── api/v1/           Route handlers (one file per resource)
│   │   ├── core/            config, security (JWT, hashing)
│   │   ├── models/          SQLAlchemy ORM models
│   │   ├── schemas/         Pydantic request/response schemas
│   │   └── main.py          App entry + inline startup migrations
│   ├── create_superadmin.py Seed first superadmin
│   ├── requirements.txt
│   └── render.yaml          (root) Render deploy config
│
├── admin/                   React + Vite admin panel
│   └── src/
│       ├── pages/           Route-level screens
│       ├── lib/api/         Typed API clients (axios)
│       ├── components/      UI + dashboard widgets (shadcn/ui)
│       └── hooks/
│
├── client/                  Flutter POS app
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/    api_constants, plutus_config, pine_terminal_config
│   │   │   ├── network/      Dio client, interceptors, token manager
│   │   │   └── services/     plutus_smart_service, printer, sync_queue, cache
│   │   ├── data/            models + repositories
│   │   └── presentation/    screens, providers (Riverpod), widgets
│   └── android/
│       └── app/
│           ├── libs/         Pine Labs SmartPos / EMV .jar + .so
│           └── src/main/kotlin/com/mit/MainActivity.kt   Plutus Messenger IPC
│
└── README.md
```

---

## Backend (FastAPI)

REST API mounted under `/v1`. Resources (one router each in `backend/app/api/v1/`):

| Route file | Responsibility |
|------------|----------------|
| `auth.py` | Admin login, machine login (`/auth/machine-login`), refresh, self-register (Clerk), Firebase login |
| `machines.py` | CRUD for POS terminals |
| `payments.py` | Record & list payments (tenant-scoped, idempotent) |
| `sync.py` | Offline payment push/pull (`/sync/push`, `/sync/pull`) |
| `analytics.py` | Aggregations, exports (Excel) |
| `dashboard.py` | Dashboard summary metrics |
| `logs.py` / `alerts.py` | Machine activity logs & alerts |
| `config.py` | Bill configuration (incl. admin-managed UPI ID) |
| `locations.py` / `services.py` | Location & service catalog |
| `superadmin.py` | Admin management + UPI-change approval flow |
| `razorpay.py` | Razorpay integration |

**Data model (core tables):**

- **User** — admins/superadmins. `username`, `email`, `phone`, `hashed_password`, `role`.
- **Machine** — a POS terminal. `user_id` (owner), `name`, `location`, `username`/`hashed_password` (machine login), `upi_id` (admin-set), `bill_counter`, `status`, `online/offline_collection`.
- **Payment** — `machine_id`, `bill_number`, `amount`, `method` (UPI/Card/Cash), `status` (success/pending/failed).
- **UpiChangeRequest** — pending UPI ID changes awaiting superadmin approval.
- **Location**, **Service**, **Log**, **Alert**, **BillConfig**.

**Migrations:** No Alembic in active use — schema changes are applied as inline `ALTER TABLE` / `CREATE TABLE` statements in `main.py`'s `startup_event`, guarded so they're idempotent.

### Run locally

```bash
cd backend
python3 -m venv venv
source venv/bin/activate            # Windows: venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env                # set DATABASE_URL, SECRET_KEY, etc.
python -m app.init_db               # init tables (or rely on startup_event)
uvicorn app.main:app --reload
```

- API: `http://localhost:8000`
- Interactive docs: `http://localhost:8000/docs`

**First superadmin:** `python create_superadmin.py` (or hit the `bootstrap-superadmin` endpoint once).

### Key environment variables

| Var | Purpose |
|-----|---------|
| `DATABASE_URL` | Postgres connection string (SQLite fallback locally) |
| `SECRET_KEY` | JWT signing key |
| `CORS_ORIGINS` | Allowed origins for the admin panel |
| `SELF_REGISTER_TOKEN` | Secret token gating hidden admin self-registration |
| `CLERK_SECRET_KEY` | Clerk management API (admin signup) |

---

## Admin Panel (React)

Vite + TypeScript SPA using shadcn/ui, TanStack Query, and Recharts.

**Pages (`admin/src/pages/`):** Login, Dashboard, Clients (machines), ClientDashboard, MachineCatalog, MachinePayments, MachineLogs, BillSettings, Alerts, SuperAdmin.

**API clients (`admin/src/lib/api/`):** one typed module per backend resource (`auth`, `machines`, `payments`, `analytics`, `dashboard`, `logs`, `locations`, `services`, `config`, `superadmin`).

Highlights:
- Machine CRUD with an **Edit Machine** dialog (name / location / UPI ID / password).
- **UPI ID is admin-managed** — set here, surfaced to the client via BillConfig (clients can't edit it).
- Payment & log **CSV/Excel export** wired to `analyticsApi.exportData()`.
- Superadmin panel: manage admins, approve UPI change requests.

### Run locally

```bash
cd admin
npm install
npm run dev          # Vite dev server
npm run build        # production build
npm test             # vitest
```

---

## Client — Flutter POS App

Runs on **Pine Labs A910S** Android terminals. State via Riverpod, networking via Dio, routing via GoRouter, local persistence via SharedPreferences.

**Screens (`lib/presentation/screens/`):** splash, auth, orders (create / checkout / card / UPI), reports, settings.

**Providers (`lib/presentation/providers/`):** auth, cart, catalogue, orders, payment, dashboard, bill_config, upi_settings, queued-tickets sync scheduler.

**Core services (`lib/core/services/`):**
- `plutus_smart_service.dart` — Plutus Smart transactions & print via Messenger IPC.
- `printer_service.dart` — thermal receipt printing.
- `sync_queue_service.dart` — offline payment queue (SharedPreferences), serialized writes.
- `cache_service.dart` — local response cache.

### Offline-first payment flow

The client never loses a payment to a flaky network:

1. **Enqueue before POST** — every payment is written to the local sync queue *before* the network call, so it survives an app kill mid-request.
2. **POST to backend** — on success, the record is removed from the queue (server becomes source of truth).
3. **Auto-sync** — queued payments flush automatically when connectivity returns (connectivity listener) and via a 30s periodic fallback, through `/sync/push`.
4. **Idempotency** — the backend ignores duplicate `bill_number`s for a machine (failed/cancelled records don't block a retry).

`api_client.dart` also serializes concurrent **401 token-refresh** requests through a single `Completer` so simultaneous requests don't each trigger their own refresh.

### Run / build

```bash
cd client
flutter pub get
flutter run                          # dev (uses API_BASE_URL default)

# Point at a different backend
flutter run --dart-define=API_BASE_URL=https://your-host.com/v1
```

Default backend: `https://billing-app-xceo.onrender.com/v1`.

---

## Pine Labs Plutus Smart Integration

In-person **card and UPI** payments go through the Pine Labs **MasterApp** (`com.pinelabs.masterapp`) on the terminal.

**How it works:** `MainActivity.kt` uses pure **Messenger IPC** — binds to `com.pinelabs.masterapp.SERVER`, sends `MASTERAPPREQUEST`, and receives `MASTERAPPRESPONSE` (matching Pine Labs' reference sample exactly). Dart talks to it over the `PLUTUS-API` MethodChannel via `PlutusSmartService`.

**Request types** (`PlutusRequestBuilder`):
- `1001` DoTransaction — Card sale (`TransactionType 4001`), UPI sale (`5120`), UPI status (`5122`).
- `1002` DoPrint — receipt printing.

**Config (`lib/core/constants/plutus_config.dart`):** driven by `--dart-define`.

| Flag | Default |
|------|---------|
| `PLUTUS_ENABLED` | `true` (pinelabs branch) |
| `PLUTUS_APPLICATION_ID` | `14103d3b12a444d6b5ffff15022d8a27` (**production**) |
| `PLUTUS_USER_ID` | `user1234` |
| `PLUTUS_API_VERSION` | `1.0` |

### Production release build (per Pine Labs security requirements)

```bash
cd client
flutter build apk --release \
  --dart-define=PLUTUS_ENABLED=true \
  --dart-define=PLUTUS_APPLICATION_ID=14103d3b12a444d6b5ffff15022d8a27
```

Output: `client/build/app/outputs/flutter-apk/app-release.apk`

Pine Labs hardening checklist (all satisfied in `android/`):
- ✅ Release APK, developer-signed with **V1 + V2** (`enableV1Signing` / `enableV2Signing` in `build.gradle`).
- ✅ HTTPS only — `usesCleartextTraffic="false"` + `network_security_config.xml`.
- ✅ `android:allowBackup="false"`, debuggable false (release).
- ✅ Signing credentials kept out of source (`key.properties`).

### Terminal provisioning notes

- Target terminal serial: **`2842079646`** (A910S), package `com.mit`.
- UAT validated the full chain: AppId accepted, card read (`onCardDetect`), and host reachable ("Reward Txn declined by Host. Proceed with Sale?"). **UAT declines real cards by design** — end-to-end UAT testing needs Pine Labs test cards.
- Production AppId issued 2026-06-19; APK submitted to Pine Labs security team for sanity testing and TMS store onboarding.

---

## Deployment

- **Backend + DB:** Render (`render.yaml`) — Python web service in Singapore region, Postgres database. `SECRET_KEY` auto-generated, `DATABASE_URL` injected from the managed DB.
- **Admin panel:** static build (`npm run build`) deployable to any static host.
- **Client:** APK / AAB distributed via Pine Labs POS TMS store (production) or sideloaded for testing.

---

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Mainline |
| `pinelabs` | Pine Labs A910S integration (active) — `PLUTUS_ENABLED=true` |
| `phonepay` | PhonePe P1000 device build — `PLUTUS_ENABLED=false` |
| `paytm-pos` | Paytm POS variant |

---

## Default Credentials (local/dev only)

`admin` / `admin` — change immediately in any non-local environment.
