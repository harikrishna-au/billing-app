# 5-Phase Development Plan
## Billing Admin System - Client App & Admin Dashboard

---

## 📊 Phase Overview

| Phase | Focus | Duration | Complexity |
|-------|-------|----------|------------|
| **Phase 1** | MVP - Core Billing | 4-6 weeks | ⭐⭐ |
| **Phase 2** | Enhanced Operations | 3-4 weeks | ⭐⭐⭐ |
| **Phase 3** | Analytics & Reporting | 3-4 weeks | ⭐⭐⭐ |
| **Phase 4** | Advanced Features | 4-5 weeks | ⭐⭐⭐⭐ |
| **Phase 5** | Enterprise & Scale | 4-6 weeks | ⭐⭐⭐⭐⭐ |

---

## 🎯 Phase 1: MVP - Core Billing System

### **Goal:** Launch a functional POS system with basic billing capabilities

### **Client App Features:**

#### 1. Authentication
- Username/password login
- Session management
- Auto-logout (15 min inactivity)
- Basic role validation (operator/manager/admin)

#### 2. Machine Selection
- View assigned machines
- Select active machine
- Display machine status (online/offline)
- Show last sync time

#### 3. Service Catalog
- View all services for selected machine
- Display service name, price, status
- Search services by name
- Filter by active/inactive status

#### 4. Basic Billing
- Add services to cart
- Adjust quantities (+/-)
- Remove items from cart
- View cart total
- Clear cart

#### 5. Payment Processing
- **Cash payment** only (MVP)
- Enter amount tendered
- Calculate change
- Confirm payment

#### 6. Simple Receipt
- Display transaction summary
- Show bill number, items, total
- Payment method and timestamp
- Basic text receipt (no PDF)

#### 7. Payment History
- View today's transactions
- Display bill number, amount, time
- Basic search by bill number

#### 8. Basic Sync
- Manual sync button
- Sync status indicator
- Upload new payments
- Download service updates

### **Admin Dashboard Features:**

#### 1. Admin Login
- Username/password authentication
- JWT token management
- Role-based access control

#### 2. Machine Management
- View all machines
- Add new machine
- Edit machine details (name, location)
- Update machine status
- View machine statistics (basic)

#### 3. Service Management
- View all services per machine
- Add new service
- Edit service (name, price)
- Activate/deactivate service
- Delete service

#### 4. Payment Overview
- View all payments (table view)
- Filter by machine
- Filter by date (today/yesterday/last 7 days)
- Search by bill number
- View payment details

#### 5. Basic Dashboard
- Total machines count
- Total revenue (today)
- Total transactions (today)
- Active services count

### **Database Schema (Phase 1):**

```sql
-- Core Tables Required

1. users
   - id (UUID, PK)
   - username (VARCHAR, UNIQUE)
   - email (VARCHAR, UNIQUE)
   - hashed_password (VARCHAR)
   - role (ENUM: admin, manager, operator)
   - is_active (VARCHAR)
   - created_at, updated_at (TIMESTAMP)

2. machines
   - id (UUID, PK)
   - name (TEXT)
   - location (TEXT)
   - status (ENUM: online, offline, maintenance)
   - last_sync (TIMESTAMP)
   - created_at, updated_at (TIMESTAMP)

3. services
   - id (UUID, PK)
   - machine_id (UUID, FK)
   - name (TEXT)
   - price (NUMERIC)
   - status (ENUM: active, inactive)
   - created_at, updated_at (TIMESTAMP)

4. payments
   - id (UUID, PK)
   - machine_id (UUID, FK)
   - bill_number (TEXT)
   - amount (NUMERIC)
   - method (ENUM: Cash only for Phase 1)
   - status (ENUM: success, pending, failed)
   - created_at (TIMESTAMP)

-- Indexes
CREATE INDEX idx_services_machine_id ON services(machine_id);
CREATE INDEX idx_payments_machine_id ON payments(machine_id);
CREATE INDEX idx_payments_created_at ON payments(created_at);
```

### **API Endpoints (Phase 1):**
```
POST   /auth/login
POST   /auth/logout
GET    /machines
POST   /machines
PUT    /machines/:id
GET    /services?machine_id=
POST   /services
PUT    /services/:id
DELETE /services/:id
GET    /payments?machine_id=&date=
POST   /payments
GET    /sync/status
POST   /sync/pull
POST   /sync/push
```

---

## 🚀 Phase 2: Enhanced Operations

### **Goal:** Add offline support, multiple payment methods, and better UX

### **Client App Features:**

#### 1. Enhanced Authentication
- **Biometric login** (fingerprint/face ID)
- Remember me functionality
- Offline login (cached credentials)

#### 2. Offline Mode
- **Local SQLite database**
- Queue transactions offline
- Auto-sync when online
- Offline indicator badge
- Pending sync counter

#### 3. Multi-Payment Methods
- **UPI payment** (QR code/intent)
- **Card payment** (manual entry)
- Cash payment (enhanced)
- Payment method selection UI

#### 4. Enhanced Billing
- **Apply discounts** (percentage/fixed)
- Add customer details (name, phone)
- Add notes/remarks to bill
- Save draft bills

#### 5. Digital Receipt
- **PDF generation**
- Share via WhatsApp/Email/SMS
- Save to device
- Custom branding (logo)

#### 6. Collections Report
- Daily collection summary
- Breakdown by payment method
- Transaction count
- Average transaction value

#### 7. Enhanced Payment History
- Filter by payment method
- Filter by date range (custom)
- Filter by amount range
- Sort by date/amount
- View full receipt

#### 8. Settings
- Switch machine
- Change password
- Theme selection (light/dark)
- Language selection
- Auto-sync toggle

### **Admin Dashboard Features:**

#### 1. Enhanced Dashboard
- Revenue charts (line/bar)
- Payment method distribution (pie chart)
- Machine status overview
- Top performing machines
- Recent activity feed

#### 2. Machine Analytics
- Per-machine revenue
- Transaction trends
- Service popularity
- Hourly sales breakdown

#### 3. User Management
- View all users
- Add new user (operator/manager)
- Edit user details
- Activate/deactivate user
- Assign machines to users

#### 4. Bulk Operations
- Bulk service updates
- Bulk price changes
- Export data (CSV/Excel)

#### 5. Activity Logs
- View system logs
- Filter by type (login, config, etc.)
- Search logs
- Export logs

### **Database Schema (Phase 2):**

```sql
-- New Tables

1. machine_logs
   - id (UUID, PK)
   - machine_id (UUID, FK)
   - action (TEXT)
   - details (TEXT)
   - type (ENUM: login, client, config, manager, system)
   - created_at (TIMESTAMP)

-- Enhanced Tables

2. machines (add columns)
   - online_collection (NUMERIC, DEFAULT 0)
   - offline_collection (NUMERIC, DEFAULT 0)

3. payments (update enum)
   - method (ENUM: UPI, Card, Cash)
   - Add fields:
     - customer_name (TEXT, nullable)
     - customer_phone (TEXT, nullable)
     - discount_amount (NUMERIC, DEFAULT 0)
     - notes (TEXT, nullable)

4. users (add columns)
   - last_login (TIMESTAMP)
   - assigned_machines (JSONB array of machine IDs)

-- New Indexes
CREATE INDEX idx_machine_logs_machine_id ON machine_logs(machine_id);
CREATE INDEX idx_machine_logs_type ON machine_logs(type);
CREATE INDEX idx_payments_method ON payments(method);
```

### **New API Endpoints:**
```
GET    /users
POST   /users
PUT    /users/:id
DELETE /users/:id
GET    /machine-logs?machine_id=
POST   /machine-logs
GET    /analytics/dashboard
GET    /analytics/machine/:id
POST   /bulk/services/update
GET    /export/payments?format=csv
```

---

## 📊 Phase 3: Analytics & Reporting

### **Goal:** Advanced analytics, insights, and comprehensive reporting

### **Client App Features:**

#### 1. Advanced Collections
- **Visual charts** (fl_chart)
- Hourly breakdown chart
- Payment method pie chart
- Week-over-week comparison
- Month-over-month trends

#### 2. Performance Insights
- Best selling services
- Peak hours analysis
- Average transaction time
- Daily/weekly/monthly summaries

#### 3. Export Capabilities
- Export payment history (CSV/PDF)
- Export collections report
- Email reports
- Scheduled reports (daily summary)

#### 4. Receipt Enhancements
- **Thermal printer support** (Bluetooth)
- Custom receipt templates
- Add QR code to receipt
- Reprint previous receipts

#### 5. Notifications
- Low sync status alerts
- End-of-day reminders
- Payment failure notifications
- System updates

### **Admin Dashboard Features:**

#### 1. Advanced Analytics Dashboard
- Revenue trends (daily/weekly/monthly/yearly)
- Growth metrics (MoM, YoY)
- Machine performance comparison
- Service performance analysis
- Geographic distribution (if applicable)

#### 2. Custom Reports
- Report builder interface
- Custom date ranges
- Multiple filters
- Save report templates
- Schedule automated reports

#### 3. Financial Reports
- Daily sales summary
- Monthly revenue report
- Tax reports (if applicable)
- Profit/loss analysis
- Payment reconciliation

#### 4. Service Analytics
- Service popularity ranking
- Revenue per service
- Service trends over time
- Inactive service identification

#### 5. Client Management (Basic)
- View client list
- Client transaction history
- Client statistics
- Export client data

### **Database Schema (Phase 3):**

```sql
-- New Tables

1. catalog_history
   - id (UUID, PK)
   - machine_id (UUID, FK)
   - service_id (UUID, FK, nullable)
   - action (TEXT)
   - details (TEXT)
   - user_name (TEXT)
   - type (ENUM: update, create, delete, status)
   - created_at (TIMESTAMP)

2. reports (saved report templates)
   - id (UUID, PK)
   - name (TEXT)
   - type (TEXT)
   - filters (JSONB)
   - schedule (TEXT, nullable)
   - created_by (UUID, FK to users)
   - created_at, updated_at (TIMESTAMP)

3. notifications
   - id (UUID, PK)
   - user_id (UUID, FK)
   - machine_id (UUID, FK, nullable)
   - title (TEXT)
   - message (TEXT)
   - type (ENUM: alert, info, warning, error)
   - is_read (BOOLEAN, DEFAULT false)
   - created_at (TIMESTAMP)

-- Enhanced Tables

4. payments (add columns)
   - items (JSONB array of {service_id, name, price, quantity})
   - subtotal (NUMERIC)
   - tax_amount (NUMERIC, DEFAULT 0)
   - receipt_url (TEXT, nullable)

-- New Indexes
CREATE INDEX idx_catalog_history_machine_id ON catalog_history(machine_id);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
```

### **New API Endpoints:**
```
GET    /analytics/revenue?period=
GET    /analytics/services/top
GET    /analytics/machines/comparison
GET    /reports
POST   /reports
PUT    /reports/:id
DELETE /reports/:id
GET    /reports/:id/generate
GET    /catalog-history?machine_id=
GET    /notifications?user_id=
PUT    /notifications/:id/read
POST   /export/report
```

---

## 🎨 Phase 4: Advanced Features

### **Goal:** Customer management, inventory, loyalty, and integrations

### **Client App Features:**

#### 1. Customer Management
- Customer database
- Add customer during billing
- Customer search (phone/name)
- View customer purchase history
- Customer notes

#### 2. Loyalty Program
- Points accumulation
- Redeem points for discounts
- Loyalty tiers (Bronze/Silver/Gold)
- Special offers for members

#### 3. Inventory Management (Basic)
- Stock tracking per service
- Low stock alerts
- Stock adjustments
- Inventory sync

#### 4. Split Payments
- Multiple payment methods per bill
- Partial payments
- Payment breakdown display

#### 5. Refunds & Cancellations
- Refund processing
- Cancellation reasons
- Manager approval for refunds
- Refund history

#### 6. Advanced Offline
- Conflict resolution UI
- Manual conflict resolution
- Offline data compression
- Background sync

#### 7. Barcode Scanner
- Scan product barcodes
- Quick add to cart
- Barcode-based search

### **Admin Dashboard Features:**

#### 1. Customer Analytics
- Customer lifetime value (CLV)
- Customer segmentation
- Purchase patterns
- Retention analysis
- Churn prediction

#### 2. Inventory Management
- Stock levels overview
- Reorder point alerts
- Stock movement history
- Supplier management (basic)
- Purchase orders

#### 3. Loyalty Program Management
- Configure point rules
- Manage tiers
- Create special offers
- View loyalty statistics

#### 4. Advanced User Management
- Granular permissions
- Role customization
- Activity tracking per user
- Performance metrics per operator

#### 5. Integration Hub
- Payment gateway integrations
- Accounting software sync (Tally, QuickBooks)
- SMS gateway for receipts
- Email service integration

#### 6. Audit & Compliance
- Complete audit trail
- Compliance reports
- Data retention policies
- GDPR compliance tools

### **Database Schema (Phase 4):**

```sql
-- New Tables

1. customers
   - id (UUID, PK)
   - name (TEXT)
   - phone (VARCHAR, UNIQUE)
   - email (VARCHAR, nullable)
   - loyalty_points (INTEGER, DEFAULT 0)
   - loyalty_tier (ENUM: bronze, silver, gold, platinum)
   - total_spent (NUMERIC, DEFAULT 0)
   - visit_count (INTEGER, DEFAULT 0)
   - created_at, updated_at (TIMESTAMP)

2. customer_transactions
   - id (UUID, PK)
   - customer_id (UUID, FK)
   - payment_id (UUID, FK)
   - points_earned (INTEGER)
   - points_redeemed (INTEGER)
   - created_at (TIMESTAMP)

3. inventory
   - id (UUID, PK)
   - service_id (UUID, FK)
   - machine_id (UUID, FK)
   - stock_quantity (INTEGER)
   - reorder_point (INTEGER)
   - last_restocked (TIMESTAMP)
   - created_at, updated_at (TIMESTAMP)

4. inventory_movements
   - id (UUID, PK)
   - inventory_id (UUID, FK)
   - type (ENUM: sale, restock, adjustment, return)
   - quantity (INTEGER)
   - reason (TEXT, nullable)
   - user_id (UUID, FK)
   - created_at (TIMESTAMP)

5. refunds
   - id (UUID, PK)
   - payment_id (UUID, FK)
   - amount (NUMERIC)
   - reason (TEXT)
   - approved_by (UUID, FK to users)
   - status (ENUM: pending, approved, rejected, completed)
   - created_at, updated_at (TIMESTAMP)

6. loyalty_rules
   - id (UUID, PK)
   - name (TEXT)
   - points_per_rupee (NUMERIC)
   - min_purchase (NUMERIC)
   - tier (TEXT)
   - is_active (BOOLEAN)
   - created_at, updated_at (TIMESTAMP)

7. split_payments
   - id (UUID, PK)
   - payment_id (UUID, FK)
   - method (payment_method)
   - amount (NUMERIC)
   - transaction_ref (TEXT, nullable)
   - created_at (TIMESTAMP)

-- Enhanced Tables

8. payments (add columns)
   - customer_id (UUID, FK, nullable)
   - loyalty_points_earned (INTEGER, DEFAULT 0)
   - loyalty_points_redeemed (INTEGER, DEFAULT 0)
   - is_refunded (BOOLEAN, DEFAULT false)
   - refund_id (UUID, FK, nullable)

9. services (add columns)
   - barcode (VARCHAR, nullable, UNIQUE)
   - track_inventory (BOOLEAN, DEFAULT false)

-- New Indexes
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customers_email ON customers(email);
CREATE INDEX idx_customer_transactions_customer_id ON customer_transactions(customer_id);
CREATE INDEX idx_inventory_service_id ON inventory(service_id);
CREATE INDEX idx_refunds_payment_id ON refunds(payment_id);
CREATE INDEX idx_services_barcode ON services(barcode);
```

### **New API Endpoints:**
```
GET    /customers
POST   /customers
PUT    /customers/:id
GET    /customers/:id/history
GET    /customers/search?q=
POST   /loyalty/points/earn
POST   /loyalty/points/redeem
GET    /loyalty/rules
POST   /loyalty/rules
GET    /inventory
POST   /inventory/adjust
GET    /inventory/alerts
POST   /refunds
PUT    /refunds/:id/approve
GET    /integrations
POST   /integrations/configure
POST   /payments/split
```

---

## 🌟 Phase 5: Enterprise & Scale

### **Goal:** Multi-location, franchises, AI insights, and enterprise features

### **Client App Features:**

#### 1. Multi-Location Support
- Switch between locations
- Location-specific inventory
- Location-specific pricing
- Cross-location transfers

#### 2. AI-Powered Features
- Smart product recommendations
- Demand forecasting
- Fraud detection
- Optimal pricing suggestions

#### 3. Voice Commands
- Voice-activated billing
- Hands-free operation
- Voice search
- Voice confirmations

#### 4. Advanced Hardware Integration
- Weighing scale integration
- Cash drawer automation
- Multi-screen support (customer display)
- NFC/RFID support

#### 5. Queue Management
- Token generation
- Queue status display
- Estimated wait time
- Customer notifications

#### 6. Subscription Services
- Recurring billing
- Subscription management
- Auto-renewal
- Subscription analytics

### **Admin Dashboard Features:**

#### 1. Multi-Tenant Architecture
- Franchise management
- Location hierarchy
- Centralized vs. local control
- White-label support

#### 2. AI Analytics Dashboard
- Predictive analytics
- Anomaly detection
- Trend forecasting
- Smart alerts

#### 3. Advanced Reporting
- Executive dashboards
- Board-level reports
- Comparative analysis (locations)
- Benchmark reports

#### 4. Supply Chain Management
- Vendor management
- Purchase orders
- Inventory optimization
- Demand planning

#### 5. Employee Management
- Shift scheduling
- Attendance tracking
- Performance reviews
- Commission calculations

#### 6. Marketing Automation
- Campaign management
- Customer segmentation
- Automated promotions
- SMS/Email campaigns

#### 7. API & Webhooks
- Public API for integrations
- Webhook support
- Developer portal
- API analytics

#### 8. Advanced Security
- Two-factor authentication (2FA)
- IP whitelisting
- Advanced audit logs
- Penetration testing tools

### **Database Schema (Phase 5):**

```sql
-- New Tables

1. locations (multi-tenant)
   - id (UUID, PK)
   - parent_id (UUID, FK, nullable) -- for hierarchy
   - name (TEXT)
   - code (VARCHAR, UNIQUE)
   - address (TEXT)
   - city (TEXT)
   - state (TEXT)
   - country (TEXT)
   - timezone (TEXT)
   - is_active (BOOLEAN)
   - created_at, updated_at (TIMESTAMP)

2. subscriptions
   - id (UUID, PK)
   - customer_id (UUID, FK)
   - service_id (UUID, FK)
   - frequency (ENUM: daily, weekly, monthly, yearly)
   - start_date (DATE)
   - end_date (DATE, nullable)
   - next_billing_date (DATE)
   - amount (NUMERIC)
   - status (ENUM: active, paused, cancelled, expired)
   - created_at, updated_at (TIMESTAMP)

3. employees
   - id (UUID, PK)
   - user_id (UUID, FK)
   - location_id (UUID, FK)
   - employee_code (VARCHAR, UNIQUE)
   - designation (TEXT)
   - salary (NUMERIC, nullable)
   - commission_rate (NUMERIC, nullable)
   - join_date (DATE)
   - is_active (BOOLEAN)
   - created_at, updated_at (TIMESTAMP)

4. shifts
   - id (UUID, PK)
   - employee_id (UUID, FK)
   - machine_id (UUID, FK)
   - start_time (TIMESTAMP)
   - end_time (TIMESTAMP, nullable)
   - break_duration (INTEGER) -- minutes
   - sales_amount (NUMERIC, DEFAULT 0)
   - transaction_count (INTEGER, DEFAULT 0)
   - created_at (TIMESTAMP)

5. vendors
   - id (UUID, PK)
   - name (TEXT)
   - contact_person (TEXT)
   - phone (VARCHAR)
   - email (VARCHAR)
   - address (TEXT)
   - payment_terms (TEXT)
   - is_active (BOOLEAN)
   - created_at, updated_at (TIMESTAMP)

6. purchase_orders
   - id (UUID, PK)
   - vendor_id (UUID, FK)
   - location_id (UUID, FK)
   - order_number (VARCHAR, UNIQUE)
   - order_date (DATE)
   - expected_delivery (DATE)
   - total_amount (NUMERIC)
   - status (ENUM: draft, sent, received, cancelled)
   - created_by (UUID, FK to users)
   - created_at, updated_at (TIMESTAMP)

7. purchase_order_items
   - id (UUID, PK)
   - purchase_order_id (UUID, FK)
   - service_id (UUID, FK)
   - quantity (INTEGER)
   - unit_price (NUMERIC)
   - total_price (NUMERIC)

8. campaigns
   - id (UUID, PK)
   - name (TEXT)
   - type (ENUM: sms, email, push, discount)
   - target_segment (JSONB) -- customer filter criteria
   - message (TEXT)
   - discount_percentage (NUMERIC, nullable)
   - start_date (TIMESTAMP)
   - end_date (TIMESTAMP)
   - status (ENUM: draft, active, completed, cancelled)
   - created_by (UUID, FK)
   - created_at, updated_at (TIMESTAMP)

9. campaign_analytics
   - id (UUID, PK)
   - campaign_id (UUID, FK)
   - sent_count (INTEGER)
   - opened_count (INTEGER)
   - clicked_count (INTEGER)
   - converted_count (INTEGER)
   - revenue_generated (NUMERIC)
   - updated_at (TIMESTAMP)

10. api_keys
    - id (UUID, PK)
    - user_id (UUID, FK)
    - key_hash (VARCHAR)
    - name (TEXT)
    - permissions (JSONB)
    - rate_limit (INTEGER)
    - expires_at (TIMESTAMP, nullable)
    - last_used (TIMESTAMP)
    - is_active (BOOLEAN)
    - created_at (TIMESTAMP)

11. webhooks
    - id (UUID, PK)
    - user_id (UUID, FK)
    - url (TEXT)
    - events (JSONB array) -- [payment.created, customer.updated, etc.]
    - secret (VARCHAR)
    - is_active (BOOLEAN)
    - created_at, updated_at (TIMESTAMP)

12. webhook_logs
    - id (UUID, PK)
    - webhook_id (UUID, FK)
    - event_type (TEXT)
    - payload (JSONB)
    - response_status (INTEGER)
    - response_body (TEXT)
    - attempt_count (INTEGER)
    - created_at (TIMESTAMP)

13. ai_insights
    - id (UUID, PK)
    - type (ENUM: recommendation, forecast, anomaly, optimization)
    - entity_type (TEXT) -- machine, service, customer
    - entity_id (UUID)
    - insight (JSONB)
    - confidence_score (NUMERIC)
    - is_actioned (BOOLEAN)
    - created_at (TIMESTAMP)

-- Enhanced Tables

14. machines (add columns)
    - location_id (UUID, FK)
    - device_id (VARCHAR, UNIQUE)
    - ip_address (VARCHAR)
    - mac_address (VARCHAR)

15. users (add columns)
    - two_factor_enabled (BOOLEAN, DEFAULT false)
    - two_factor_secret (VARCHAR, nullable)
    - allowed_ips (JSONB array, nullable)

16. payments (add columns)
    - location_id (UUID, FK)
    - employee_id (UUID, FK, nullable)
    - shift_id (UUID, FK, nullable)

-- New Indexes
CREATE INDEX idx_locations_parent_id ON locations(parent_id);
CREATE INDEX idx_subscriptions_customer_id ON subscriptions(customer_id);
CREATE INDEX idx_subscriptions_next_billing ON subscriptions(next_billing_date);
CREATE INDEX idx_employees_location_id ON employees(location_id);
CREATE INDEX idx_shifts_employee_id ON shifts(employee_id);
CREATE INDEX idx_purchase_orders_vendor_id ON purchase_orders(vendor_id);
CREATE INDEX idx_campaigns_status ON campaigns(status);
CREATE INDEX idx_webhooks_user_id ON webhooks(user_id);
CREATE INDEX idx_machines_location_id ON machines(location_id);
```

### **New API Endpoints:**
```
-- Multi-tenant
GET    /locations
POST   /locations
PUT    /locations/:id
GET    /locations/:id/hierarchy

-- Subscriptions
GET    /subscriptions
POST   /subscriptions
PUT    /subscriptions/:id/pause
PUT    /subscriptions/:id/cancel

-- Employees & Shifts
GET    /employees
POST   /employees
GET    /shifts
POST   /shifts/start
PUT    /shifts/:id/end

-- Supply Chain
GET    /vendors
POST   /vendors
GET    /purchase-orders
POST   /purchase-orders
PUT    /purchase-orders/:id/receive

-- Marketing
GET    /campaigns
POST   /campaigns
PUT    /campaigns/:id/activate
GET    /campaigns/:id/analytics

-- API & Webhooks
POST   /api-keys
DELETE /api-keys/:id
GET    /webhooks
POST   /webhooks
GET    /webhooks/:id/logs

-- AI Insights
GET    /ai/insights?type=
GET    /ai/recommendations?entity=
GET    /ai/forecast?metric=
POST   /ai/insights/:id/action
```

---

## 📈 Phase Comparison Matrix

| Feature Category | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|------------------|---------|---------|---------|---------|---------|
| **Authentication** | Basic | Biometric | - | - | 2FA |
| **Payment Methods** | Cash | UPI, Card | - | Split | - |
| **Offline Support** | ❌ | ✅ | ✅ | Advanced | ✅ |
| **Receipts** | Text | PDF | Printer | - | - |
| **Analytics** | Basic | Charts | Advanced | - | AI-powered |
| **Customers** | ❌ | ❌ | Basic | Full CRM | Segmentation |
| **Inventory** | ❌ | ❌ | ❌ | Basic | Full SCM |
| **Loyalty** | ❌ | ❌ | ❌ | ✅ | Advanced |
| **Multi-location** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **API/Webhooks** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Subscriptions** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Employees** | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 🗄️ Complete Database Evolution

### **Tables by Phase:**

| Phase | New Tables | Enhanced Tables | Total Tables |
|-------|------------|-----------------|--------------|
| **1** | 4 (users, machines, services, payments) | - | 4 |
| **2** | 1 (machine_logs) | 3 | 5 |
| **3** | 3 (catalog_history, reports, notifications) | 1 | 8 |
| **4** | 7 (customers, customer_transactions, inventory, inventory_movements, refunds, loyalty_rules, split_payments) | 2 | 15 |
| **5** | 13 (locations, subscriptions, employees, shifts, vendors, purchase_orders, purchase_order_items, campaigns, campaign_analytics, api_keys, webhooks, webhook_logs, ai_insights) | 3 | 28 |

---

## 🎯 Recommended Development Approach

### **For Startups/MVPs:**
- **Phase 1** → Launch quickly (4-6 weeks)
- **Phase 2** → Add after user feedback (3-4 weeks)
- **Phase 3** → When scaling (3-4 weeks)

### **For Established Businesses:**
- **Phase 1 + 2** → Combined MVP (6-8 weeks)
- **Phase 3** → Immediate priority (3-4 weeks)
- **Phase 4** → Based on business needs (4-5 weeks)

### **For Enterprises:**
- **All Phases** → Comprehensive rollout (18-25 weeks)
- Parallel development teams
- Phased deployment per location

---

## 📊 Effort Estimation

| Phase | Client App | Admin Dashboard | Backend API | Database | Total |
|-------|-----------|-----------------|-------------|----------|-------|
| **1** | 2 weeks | 2 weeks | 1 week | 1 week | 6 weeks |
| **2** | 2 weeks | 1 week | 1 week | 0.5 weeks | 4.5 weeks |
| **3** | 1.5 weeks | 2 weeks | 1 week | 0.5 weeks | 5 weeks |
| **4** | 2 weeks | 2 weeks | 1.5 weeks | 1 week | 6.5 weeks |
| **5** | 2.5 weeks | 3 weeks | 2 weeks | 1 week | 8.5 weeks |

**Total:** ~30 weeks (7.5 months) for complete system

---

## 🚀 Quick Start Recommendation

**Start with Phase 1 + Essential Phase 2 features:**
- Phase 1: All features
- Phase 2: Offline mode + UPI/Card payments + PDF receipts

**This gives you:**
- Functional POS system ✅
- Multiple payment methods ✅
- Offline capability ✅
- Digital receipts ✅
- Basic analytics ✅

**Timeline:** 8-10 weeks  
**Team:** 2 Flutter devs + 1 Backend dev + 1 Designer

---

**Document Version:** 1.0  
**Created:** 04 Feb 2026  
**Author:** Billing Admin Team
