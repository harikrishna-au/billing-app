# BillKaro POS - Backend API Specification

## 📋 Overview

This document specifies all REST API endpoints required for the BillKaro POS system (Client App + Admin Dashboard).

**Base URL:** `https://your-project.supabase.co/rest/v1`

**Authentication:** JWT Bearer tokens via Supabase Auth

---

## 🔑 Required Headers

```http
apikey: YOUR_SUPABASE_ANON_KEY
Authorization: Bearer USER_JWT_TOKEN
Content-Type: application/json
```

---

## 📚 API Endpoints Summary

| Category | Endpoints | Methods |
|----------|-----------|---------|
| **Authentication** | 3 | POST, GET |
| **Machines** | 3 | GET, PATCH |
| **Services** | 6 | GET, POST, PATCH, DELETE |
| **Payments** | 5 | GET, POST, PATCH |
| **Analytics** | 1 | GET (RPC) |
| **Total** | **18** | - |

---

## 1️⃣ Authentication Endpoints

### 1.1 Login (Username/Password)

**Endpoint:** `POST /auth/v1/token?grant_type=password`

**Request Body:**
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**Response (Success - 200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "v1.MRjfECXBgudWEuEOdYvhPA...",
  "user": {
    "id": "uuid-here",
    "email": "admin@example.com",
    "username": "admin"
  }
}
```

**Response (Error - 400):**
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid login credentials"
}
```

---

### 1.2 Logout

**Endpoint:** `POST /auth/v1/logout`

**Headers:**
```http
Authorization: Bearer {access_token}
```

**Response (Success - 204):**
```
No content
```

---

### 1.3 Get Current User

**Endpoint:** `GET /auth/v1/user`

**Headers:**
```http
Authorization: Bearer {access_token}
```

**Response (Success - 200):**
```json
{
  "id": "uuid-here",
  "email": "admin@example.com",
  "username": "admin",
  "role": "admin",
  "is_active": "true",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-02-04T14:00:00Z"
}
```

---

## 2️⃣ Machine Endpoints

### 2.1 Get All Machines

**Endpoint:** `GET /machines`

**Query Parameters:**
- `select=*` (optional) - Select specific fields
- `order=name.asc` (optional) - Sort order

**Response (Success - 200):**
```json
[
  {
    "id": "mach_001",
    "name": "Main Entrance POS",
    "location": "Lobby A",
    "status": "online",
    "last_sync": "2026-02-04T14:30:00Z",
    "online_collection": 12500.00,
    "offline_collection": 0.00,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-02-04T14:30:00Z"
  },
  {
    "id": "mach_002",
    "name": "Cafeteria Kiosk",
    "location": "Food Court",
    "status": "online",
    "last_sync": "2026-02-04T14:25:00Z",
    "online_collection": 5000.00,
    "offline_collection": 0.00,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-02-04T14:25:00Z"
  }
]
```

---

### 2.2 Get Machine by ID

**Endpoint:** `GET /machines?id=eq.{machine_id}`

**Response (Success - 200):**
```json
[
  {
    "id": "mach_001",
    "name": "Main Entrance POS",
    "location": "Lobby A",
    "status": "online",
    "last_sync": "2026-02-04T14:30:00Z",
    "online_collection": 12500.00,
    "offline_collection": 0.00,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-02-04T14:30:00Z"
  }
]
```

---

### 2.3 Update Machine Status

**Endpoint:** `PATCH /machines?id=eq.{machine_id}`

**Request Body:**
```json
{
  "status": "offline",
  "last_sync": "2026-02-04T15:00:00Z"
}
```

**Response (Success - 200):**
```json
[
  {
    "id": "mach_001",
    "status": "offline",
    "last_sync": "2026-02-04T15:00:00Z"
  }
]
```

---

## 3️⃣ Service Endpoints

### 3.1 Get All Services

**Endpoint:** `GET /services`

**Query Parameters:**
- `machine_id=eq.{machine_id}` - Filter by machine
- `status=eq.active` - Filter by status
- `select=*` - Select all fields

**Response (Success - 200):**
```json
[
  {
    "id": "srv_001",
    "machine_id": "mach_001",
    "name": "Entry Ticket - Adult",
    "price": 150.00,
    "status": "active",
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-02-04T10:00:00Z"
  },
  {
    "id": "srv_002",
    "machine_id": "mach_001",
    "name": "Entry Ticket - Child",
    "price": 75.00,
    "status": "active",
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-02-04T10:00:00Z"
  }
]
```

---

### 3.2 Get Services by Machine

**Endpoint:** `GET /services?machine_id=eq.{machine_id}`

**Response:** Same as 3.1

---

### 3.3 Get Active Services by Machine

**Endpoint:** `GET /services?machine_id=eq.{machine_id}&status=eq.active`

**Response:** Same as 3.1 (filtered)

---

### 3.4 Create Service

**Endpoint:** `POST /services`

**Request Body:**
```json
{
  "machine_id": "mach_001",
  "name": "Premium Pass",
  "price": 1000.00,
  "status": "active"
}
```

**Response (Success - 201):**
```json
[
  {
    "id": "srv_012",
    "machine_id": "mach_001",
    "name": "Premium Pass",
    "price": 1000.00,
    "status": "active",
    "created_at": "2026-02-04T15:00:00Z",
    "updated_at": "2026-02-04T15:00:00Z"
  }
]
```

---

### 3.5 Update Service

**Endpoint:** `PATCH /services?id=eq.{service_id}`

**Request Body:**
```json
{
  "status": "inactive",
  "updated_at": "2026-02-04T15:00:00Z"
}
```

**Response (Success - 200):**
```json
[
  {
    "id": "srv_001",
    "status": "inactive",
    "updated_at": "2026-02-04T15:00:00Z"
  }
]
```

---

### 3.6 Delete Service

**Endpoint:** `DELETE /services?id=eq.{service_id}`

**Response (Success - 204):**
```
No content
```

---

## 4️⃣ Payment Endpoints

### 4.1 Get All Payments

**Endpoint:** `GET /payments`

**Query Parameters:**
- `machine_id=eq.{machine_id}` - Filter by machine
- `method=eq.Cash` - Filter by payment method
- `status=eq.success` - Filter by status
- `order=created_at.desc` - Sort by date (newest first)
- `limit=50` - Limit results

**Response (Success - 200):**
```json
[
  {
    "id": "pay_001",
    "machine_id": "mach_001",
    "bill_number": "M001-20260204-0001",
    "amount": 177.00,
    "method": "Cash",
    "status": "success",
    "created_at": "2026-02-04T12:30:00Z",
    "updated_at": "2026-02-04T12:30:00Z"
  }
]
```

---

### 4.2 Get Payments by Machine

**Endpoint:** `GET /payments?machine_id=eq.{machine_id}&order=created_at.desc`

**Response:** Same as 4.1

---

### 4.3 Get Payments by Date Range

**Endpoint:** `GET /payments?created_at=gte.{start_date}&created_at=lte.{end_date}`

**Example:**
```
GET /payments?created_at=gte.2026-02-04T00:00:00Z&created_at=lte.2026-02-04T23:59:59Z
```

**Response:** Same as 4.1

---

### 4.4 Create Payment

**Endpoint:** `POST /payments`

**Request Body:**
```json
{
  "machine_id": "mach_001",
  "bill_number": "M001-20260204-0005",
  "amount": 177.00,
  "method": "Cash",
  "status": "success"
}
```

**Response (Success - 201):**
```json
[
  {
    "id": "pay_006",
    "machine_id": "mach_001",
    "bill_number": "M001-20260204-0005",
    "amount": 177.00,
    "method": "Cash",
    "status": "success",
    "created_at": "2026-02-04T15:00:00Z",
    "updated_at": "2026-02-04T15:00:00Z"
  }
]
```

---

### 4.5 Update Payment Status

**Endpoint:** `PATCH /payments?id=eq.{payment_id}`

**Request Body:**
```json
{
  "status": "failed",
  "updated_at": "2026-02-04T15:00:00Z"
}
```

**Response (Success - 200):**
```json
[
  {
    "id": "pay_001",
    "status": "failed",
    "updated_at": "2026-02-04T15:00:00Z"
  }
]
```

---

## 5️⃣ Analytics Endpoints

### 5.1 Get Collections Summary

**Endpoint:** `GET /rpc/get_collections_summary`

**Query Parameters:**
```json
{
  "machine_id": "mach_001",
  "start_date": "2026-02-04T00:00:00Z",
  "end_date": "2026-02-04T23:59:59Z"
}
```

**Response (Success - 200):**
```json
{
  "total_amount": 800.00,
  "transaction_count": 5,
  "average_transaction": 160.00,
  "by_method": {
    "Cash": 450.00,
    "UPI": 250.00,
    "Card": 100.00
  },
  "by_status": {
    "success": 800.00,
    "pending": 0.00,
    "failed": 0.00
  }
}
```

**SQL Function (Create in Supabase):**
```sql
CREATE OR REPLACE FUNCTION get_collections_summary(
  machine_id TEXT,
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_amount', COALESCE(SUM(amount), 0),
    'transaction_count', COUNT(*),
    'average_transaction', COALESCE(AVG(amount), 0),
    'by_method', (
      SELECT json_object_agg(method, total)
      FROM (
        SELECT method, SUM(amount) as total
        FROM payments
        WHERE machine_id = $1
          AND created_at >= $2
          AND created_at <= $3
        GROUP BY method
      ) methods
    ),
    'by_status', (
      SELECT json_object_agg(status, total)
      FROM (
        SELECT status, SUM(amount) as total
        FROM payments
        WHERE machine_id = $1
          AND created_at >= $2
          AND created_at <= $3
        GROUP BY status
      ) statuses
    )
  ) INTO result
  FROM payments
  WHERE machine_id = $1
    AND created_at >= $2
    AND created_at <= $3;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;
```

---

## ❌ Error Responses

### Standard Error Format

```json
{
  "code": "PGRST116",
  "message": "The result contains 0 rows",
  "details": null,
  "hint": null
}
```

### Common HTTP Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Success |
| 201 | Created | Resource created |
| 204 | No Content | Success with no response body |
| 400 | Bad Request | Invalid request |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Duplicate resource |
| 500 | Internal Server Error | Server error |

---

## 🗄️ Database Schema

### Required Tables

```sql
-- Users table (handled by Supabase Auth)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  hashed_password VARCHAR(255) NOT NULL,
  role user_role DEFAULT 'operator' NOT NULL,
  is_active VARCHAR(10) DEFAULT 'true' NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Machines table
CREATE TABLE machines (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  location TEXT NOT NULL,
  status machine_status DEFAULT 'offline',
  last_sync TIMESTAMPTZ DEFAULT NOW(),
  online_collection NUMERIC(10,2) DEFAULT 0,
  offline_collection NUMERIC(10,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Services table
CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  status service_status DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Payments table
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
  bill_number TEXT UNIQUE NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  method payment_method NOT NULL,
  status payment_status DEFAULT 'success',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_services_machine_id ON services(machine_id);
CREATE INDEX idx_payments_machine_id ON payments(machine_id);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);
CREATE INDEX idx_payments_bill_number ON payments(bill_number);
```

---

## 🔒 Row Level Security (RLS)

### Enable RLS

```sql
ALTER TABLE machines ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
```

### RLS Policies

```sql
-- Machines: Allow authenticated users to read
CREATE POLICY "Allow read access to machines"
  ON machines FOR SELECT
  USING (auth.role() = 'authenticated');

-- Machines: Allow admins to modify
CREATE POLICY "Allow admin to modify machines"
  ON machines FOR ALL
  USING (auth.jwt() ->> 'role' = 'admin');

-- Services: Allow authenticated users to read
CREATE POLICY "Allow read access to services"
  ON services FOR SELECT
  USING (auth.role() = 'authenticated');

-- Services: Allow managers to modify
CREATE POLICY "Allow managers to modify services"
  ON services FOR ALL
  USING (auth.jwt() ->> 'role' IN ('admin', 'manager'));

-- Payments: Allow authenticated users to create/read
CREATE POLICY "Allow insert payments"
  ON payments FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow read payments"
  ON payments FOR SELECT
  USING (auth.role() = 'authenticated');
```

---

## 🔄 API Usage Examples

### Example 1: Login and Get Machines

```javascript
// 1. Login
const loginResponse = await fetch('https://your-project.supabase.co/auth/v1/token?grant_type=password', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'apikey': 'YOUR_SUPABASE_ANON_KEY'
  },
  body: JSON.stringify({
    username: 'admin',
    password: 'admin123'
  })
});

const { access_token } = await loginResponse.json();

// 2. Get all machines
const machinesResponse = await fetch('https://your-project.supabase.co/rest/v1/machines', {
  headers: {
    'apikey': 'YOUR_SUPABASE_ANON_KEY',
    'Authorization': `Bearer ${access_token}`
  }
});

const machines = await machinesResponse.json();
```

---

### Example 2: Create Payment

```javascript
const paymentResponse = await fetch('https://your-project.supabase.co/rest/v1/payments', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'apikey': 'YOUR_SUPABASE_ANON_KEY',
    'Authorization': `Bearer ${access_token}`,
    'Prefer': 'return=representation'
  },
  body: JSON.stringify({
    machine_id: 'mach_001',
    bill_number: 'M001-20260204-0010',
    amount: 225.00,
    method: 'UPI',
    status: 'success'
  })
});

const payment = await paymentResponse.json();
```

---

### Example 3: Get Today's Collections

```javascript
const today = new Date();
const startOfDay = new Date(today.setHours(0, 0, 0, 0)).toISOString();
const endOfDay = new Date(today.setHours(23, 59, 59, 999)).toISOString();

const collectionsResponse = await fetch(
  `https://your-project.supabase.co/rest/v1/rpc/get_collections_summary?` +
  `machine_id=mach_001&start_date=${startOfDay}&end_date=${endOfDay}`,
  {
    headers: {
      'apikey': 'YOUR_SUPABASE_ANON_KEY',
      'Authorization': `Bearer ${access_token}`
    }
  }
);

const collections = await collectionsResponse.json();
```

---

## 📊 API Endpoint Mapping by Phase

### Phase 1 (MVP)
- ✅ POST /auth/v1/token
- ✅ GET /machines
- ✅ GET /services
- ✅ POST /payments
- ✅ GET /payments

### Phase 2 (Enhanced)
- ✅ POST /services
- ✅ PATCH /services
- ✅ DELETE /services
- ✅ PATCH /machines

### Phase 3 (Analytics)
- ✅ GET /rpc/get_collections_summary

### Phase 4 (Advanced)
- Additional RPC functions for customer analytics
- Inventory endpoints
- Refund endpoints

### Phase 5 (Enterprise)
- Multi-tenant endpoints
- Webhook endpoints
- API key management

---

## 🚀 Quick Start

### 1. Setup Supabase Project
```bash
# Create new Supabase project at https://supabase.com
# Copy your project URL and anon key
```

### 2. Run Schema Migration
```bash
# Execute complete_schema.sql in Supabase SQL Editor
```

### 3. Configure Environment
```bash
# .env file
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 4. Test API
```bash
# Use Postman or curl to test endpoints
curl -X GET "https://your-project.supabase.co/rest/v1/machines" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 📝 Notes

1. **All endpoints** use Supabase's auto-generated REST API
2. **No custom backend code** required for basic CRUD operations
3. **RLS policies** handle authorization automatically
4. **JWT tokens** are managed by Supabase Auth
5. **Timestamps** are in ISO 8601 format (UTC)

---

**Document Version:** 1.0  
**Last Updated:** 04 Feb 2026  
**Author:** BillKaro POS Team
