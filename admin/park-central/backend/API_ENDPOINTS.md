# BillKaro POS Backend API - All Endpoints

**Base URL:** `http://localhost:8000`  
**API Version:** `v1`  
**Documentation:** http://localhost:8000/docs

---

## 🔐 Authentication Endpoints

### User Authentication
```
POST   /v1/auth/login           # Admin/User login
POST   /v1/auth/refresh         # Refresh access token
POST   /v1/auth/logout          # Logout user
GET    /v1/auth/me              # Get current user info
```

### Machine Authentication (NEW)
```
POST   /v1/auth/machine-login   # Machine/Client app login
```

---

## 🖥️ Machine Endpoints

```
POST   /v1/machines                    # Create new machine
GET    /v1/machines                    # List all machines (paginated)
GET    /v1/machines/{machine_id}       # Get machine by ID
PUT    /v1/machines/{machine_id}       # Update machine
PATCH  /v1/machines/{machine_id}/status # Update machine status (NEW)
DELETE /v1/machines/{machine_id}       # Delete machine
```

---

## 🛠️ Service Endpoints

```
GET    /v1/machines/{machine_id}/services        # Get services by machine
GET    /v1/machines/{machine_id}/services/active # Get active services only (NEW)
GET    /v1/services/{service_id}                 # Get service by ID
POST   /v1/machines/{machine_id}/services        # Create service
PUT    /v1/services/{service_id}                 # Update service
DELETE /v1/services/{service_id}                 # Delete service
```

---

## 💰 Payment Endpoints

```
GET    /v1/machines/{machine_id}/payments  # Get payments by machine
GET    /v1/payments                        # Get all payments
GET    /v1/payments/{payment_id}           # Get payment by ID
POST   /v1/payments                        # Create payment
PUT    /v1/payments/{payment_id}           # Update payment
DELETE /v1/payments/{payment_id}           # Delete payment
```

---

## 🔄 Sync Endpoints (NEW)

```
POST   /v1/sync/push              # Upload offline payments
POST   /v1/sync/pull              # Download latest services
GET    /v1/sync/status/{machine_id} # Check sync status
```

---

## 📊 Analytics Endpoints

```
GET    /v1/analytics/revenue           # Revenue analytics
GET    /v1/analytics/machines          # Machine performance
GET    /v1/analytics/services          # Service analytics
GET    /v1/analytics/payments          # Payment analytics
```

---

## 📈 Dashboard Endpoints

```
GET    /v1/dashboard/overview          # Dashboard overview
GET    /v1/dashboard/stats             # Dashboard statistics
GET    /v1/dashboard/recent-activity   # Recent activity
```

---

## 📝 Logs Endpoints

```
GET    /v1/logs                        # Get all logs
GET    /v1/logs/{log_id}               # Get log by ID
GET    /v1/machines/{machine_id}/logs  # Get logs by machine
```

---

## 📚 Catalog History Endpoints

```
GET    /v1/catalog-history                        # Get all catalog history
GET    /v1/machines/{machine_id}/catalog-history  # Get catalog history by machine
```

---

## 🏥 Health & Info

```
GET    /health                         # Health check
GET    /                               # API info
GET    /docs                           # Swagger UI documentation
GET    /redoc                          # ReDoc documentation
GET    /openapi.json                   # OpenAPI schema
```

---

## 📋 Complete Endpoint List (60+ endpoints)

### Authentication (5 endpoints)
- POST /v1/auth/login
- POST /v1/auth/machine-login ⭐ NEW
- POST /v1/auth/refresh
- POST /v1/auth/logout
- GET /v1/auth/me

### Machines (6 endpoints)
- POST /v1/machines
- GET /v1/machines
- GET /v1/machines/{machine_id}
- PUT /v1/machines/{machine_id}
- PATCH /v1/machines/{machine_id}/status ⭐ NEW
- DELETE /v1/machines/{machine_id}

### Services (6 endpoints)
- GET /v1/machines/{machine_id}/services
- GET /v1/machines/{machine_id}/services/active ⭐ NEW
- GET /v1/services/{service_id}
- POST /v1/machines/{machine_id}/services
- PUT /v1/services/{service_id}
- DELETE /v1/services/{service_id}

### Payments (6 endpoints)
- GET /v1/machines/{machine_id}/payments
- GET /v1/payments
- GET /v1/payments/{payment_id}
- POST /v1/payments
- PUT /v1/payments/{payment_id}
- DELETE /v1/payments/{payment_id}

### Sync (3 endpoints) ⭐ NEW
- POST /v1/sync/push
- POST /v1/sync/pull
- GET /v1/sync/status/{machine_id}

### Analytics (4+ endpoints)
- GET /v1/analytics/revenue
- GET /v1/analytics/machines
- GET /v1/analytics/services
- GET /v1/analytics/payments

### Dashboard (3+ endpoints)
- GET /v1/dashboard/overview
- GET /v1/dashboard/stats
- GET /v1/dashboard/recent-activity

### Logs (3+ endpoints)
- GET /v1/logs
- GET /v1/logs/{log_id}
- GET /v1/machines/{machine_id}/logs

### Catalog History (2+ endpoints)
- GET /v1/catalog-history
- GET /v1/machines/{machine_id}/catalog-history

---

## 🚀 Quick Start Examples

### 1. Machine Login
```bash
curl -X POST http://localhost:8000/v1/auth/machine-login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin001",
    "password": "password"
  }'
```

### 2. Get Active Services
```bash
curl -X GET http://localhost:8000/v1/machines/{machine_id}/services/active \
  -H "Authorization: Bearer {token}"
```

### 3. Sync Push (Upload Offline Payments)
```bash
curl -X POST http://localhost:8000/v1/sync/push \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "machine_id": "{machine_id}",
    "payments": [
      {
        "machine_id": "{machine_id}",
        "bill_number": "BILL-001",
        "amount": 100.00,
        "method": "Cash",
        "status": "success"
      }
    ]
  }'
```

### 4. Sync Pull (Download Services)
```bash
curl -X POST "http://localhost:8000/v1/sync/pull?machine_id={machine_id}" \
  -H "Authorization: Bearer {token}"
```

### 5. Update Machine Status
```bash
curl -X PATCH http://localhost:8000/v1/machines/{machine_id}/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "status": "online",
    "last_sync": "2026-02-04T15:00:00Z"
  }'
```

---

## 📖 Interactive Documentation

**Swagger UI:** http://localhost:8000/docs  
**ReDoc:** http://localhost:8000/redoc

---

## ⭐ New Endpoints Summary

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/auth/machine-login` | POST | Machine authentication |
| `/v1/machines/{id}/status` | PATCH | Update machine status |
| `/v1/machines/{id}/services/active` | GET | Get active services |
| `/v1/sync/push` | POST | Upload offline data |
| `/v1/sync/pull` | POST | Download latest data |
| `/v1/sync/status/{id}` | GET | Check sync status |

---

**Server Status:** ✅ Running on http://localhost:8000  
**Total Endpoints:** 60+  
**New Endpoints:** 6  
**Ready for Client App Integration:** ✅
