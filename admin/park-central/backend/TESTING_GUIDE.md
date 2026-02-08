# Backend API Enhancements - Testing Guide

## New Endpoints Added

### 1. Machine Login
**Endpoint:** `POST /v1/auth/machine-login`

**Purpose:** Authenticate client app machines

**Test:**
```bash
curl -X POST http://localhost:8000/v1/auth/machine-login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin001",
    "password": "your_password"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "machine": {
      "id": "uuid",
      "name": "Machine Name",
      "location": "Location",
      "username": "admin001",
      "status": "online",
      "last_sync": "2026-02-04T..."
    },
    "token": "eyJ...",
    "refresh_token": "eyJ...",
    "expires_in": 1800
  }
}
```

---

### 2. Machine Status Update
**Endpoint:** `PATCH /v1/machines/{machine_id}/status`

**Purpose:** Update machine status and sync time

**Test:**
```bash
curl -X PATCH http://localhost:8000/v1/machines/{machine_id}/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "status": "online",
    "last_sync": "2026-02-04T15:00:00Z",
    "online_collection": 1500.50,
    "offline_collection": 500.00
  }'
```

---

### 3. Sync Push
**Endpoint:** `POST /v1/sync/push`

**Purpose:** Upload offline payments to server

**Test:**
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

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "synced_payments": 1,
    "failed_payments": 0,
    "sync_timestamp": "2026-02-04T..."
  }
}
```

---

### 4. Sync Pull
**Endpoint:** `POST /v1/sync/pull?machine_id={machine_id}`

**Purpose:** Download latest services and config

**Test:**
```bash
curl -X POST "http://localhost:8000/v1/sync/pull?machine_id={machine_id}" \
  -H "Authorization: Bearer {token}"
```

**Expected Response:**
```json
{
  "success": true,
  "data": {
    "services": [
      {
        "id": "uuid",
        "name": "Service Name",
        "price": 50.00,
        "status": "active",
        "created_at": "...",
        "updated_at": "..."
      }
    ],
    "machine_status": "online",
    "sync_timestamp": "2026-02-04T..."
  }
}
```

---

### 5. Sync Status
**Endpoint:** `GET /v1/sync/status/{machine_id}`

**Purpose:** Check sync status for a machine

**Test:**
```bash
curl -X GET http://localhost:8000/v1/sync/status/{machine_id} \
  -H "Authorization: Bearer {token}"
```

---

### 6. Active Services
**Endpoint:** `GET /v1/machines/{machine_id}/services/active`

**Purpose:** Get only active services for a machine

**Test:**
```bash
curl -X GET http://localhost:8000/v1/machines/{machine_id}/services/active \
  -H "Authorization: Bearer {token}"
```

**Expected Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "machine_id": "uuid",
      "name": "Service 1",
      "price": 50.00,
      "status": "active",
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

---

## Complete Test Flow

### 1. Machine Login
```bash
# Login as machine
RESPONSE=$(curl -s -X POST http://localhost:8000/v1/auth/machine-login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin001", "password": "password"}')

# Extract token
TOKEN=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['token'])")
MACHINE_ID=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['machine']['id'])")

echo "Token: $TOKEN"
echo "Machine ID: $MACHINE_ID"
```

### 2. Pull Latest Services
```bash
curl -X POST "http://localhost:8000/v1/sync/pull?machine_id=$MACHINE_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### 3. Create Offline Payment
```bash
curl -X POST http://localhost:8000/v1/sync/push \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"machine_id\": \"$MACHINE_ID\",
    \"payments\": [
      {
        \"machine_id\": \"$MACHINE_ID\",
        \"bill_number\": \"OFFLINE-001\",
        \"amount\": 150.00,
        \"method\": \"Cash\",
        \"status\": \"success\"
      }
    ]
  }" | python3 -m json.tool
```

### 4. Update Machine Status
```bash
curl -X PATCH "http://localhost:8000/v1/machines/$MACHINE_ID/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "status": "offline",
    "online_collection": 1500.00
  }' | python3 -m json.tool
```

### 5. Check Sync Status
```bash
curl -X GET "http://localhost:8000/v1/sync/status/$MACHINE_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

---

## API Documentation

View complete API documentation at:
- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

---

## Files Modified

1. **`app/api/v1/auth.py`** - Added `machine_login` endpoint
2. **`app/api/v1/machines.py`** - Added `update_machine_status` endpoint
3. **`app/api/v1/services.py`** - Added `get_active_services` endpoint
4. **`app/api/v1/sync.py`** - NEW file with push/pull/status endpoints
5. **`app/api/v1/__init__.py`** - Registered sync router
6. **`app/schemas/sync.py`** - NEW file with sync schemas
7. **`app/schemas/machine.py`** - Added `MachineStatusUpdate` schema

---

## Next Steps

- [ ] Add payment service_details column (requires migration)
- [ ] Create PostgreSQL collections summary function
- [ ] Write unit tests
- [ ] Update .env.example
