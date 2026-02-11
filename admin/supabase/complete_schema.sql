-- =====================================================
-- BILLING ADMIN SYSTEM - COMPLETE DATABASE SCHEMA
-- =====================================================
-- This schema includes all tables for the billing admin system
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- ENUMS
-- =====================================================

CREATE TYPE machine_status AS ENUM ('online', 'offline', 'maintenance');
CREATE TYPE service_status AS ENUM ('active', 'inactive');
CREATE TYPE log_type AS ENUM ('login', 'client', 'config', 'manager', 'system');
CREATE TYPE history_type AS ENUM ('update', 'create', 'delete', 'status');
CREATE TYPE payment_method AS ENUM ('UPI', 'Card', 'Cash');
CREATE TYPE payment_status AS ENUM ('success', 'pending', 'failed');
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'operator');

-- =====================================================
-- USERS TABLE (for backend authentication)
-- =====================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role user_role DEFAULT 'operator' NOT NULL,
    is_active VARCHAR(10) DEFAULT 'true' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for users
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- =====================================================
-- MACHINES TABLE
-- =====================================================

CREATE TABLE machines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    location TEXT NOT NULL,
    status machine_status DEFAULT 'offline',
    last_sync TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    online_collection NUMERIC(10, 2) DEFAULT 0,
    offline_collection NUMERIC(10, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- SERVICES TABLE
-- =====================================================

CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    status service_status DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- MACHINE LOGS TABLE
-- =====================================================

CREATE TABLE machine_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details TEXT,
    type log_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- CATALOG HISTORY TABLE
-- =====================================================

CREATE TABLE catalog_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    service_id UUID REFERENCES services(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    details TEXT,
    user_name TEXT DEFAULT 'System',
    type history_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PAYMENTS TABLE
-- =====================================================

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    bill_number TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    method payment_method NOT NULL,
    status payment_status DEFAULT 'success',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX idx_services_machine_id ON services(machine_id);
CREATE INDEX idx_machine_logs_machine_id ON machine_logs(machine_id);
CREATE INDEX idx_catalog_history_machine_id ON catalog_history(machine_id);
CREATE INDEX idx_payments_machine_id ON payments(machine_id);
CREATE INDEX idx_payments_created_at ON payments(created_at);

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_machines_updated_at BEFORE UPDATE ON machines
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_services_updated_at BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE machines ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE machine_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Allow all for now - adjust based on your auth requirements)
CREATE POLICY "Allow all access to users" ON users FOR ALL USING (true);
CREATE POLICY "Allow all access to machines" ON machines FOR ALL USING (true);
CREATE POLICY "Allow all access to services" ON services FOR ALL USING (true);
CREATE POLICY "Allow all access to machine_logs" ON machine_logs FOR ALL USING (true);
CREATE POLICY "Allow all access to catalog_history" ON catalog_history FOR ALL USING (true);
CREATE POLICY "Allow all access to payments" ON payments FOR ALL USING (true);

-- =====================================================
-- SEED DATA
-- =====================================================

-- Insert sample machines
INSERT INTO machines (name, location, status, last_sync, online_collection, offline_collection) VALUES
    ('Main Entrance POS', 'Lobby A', 'online', NOW() - INTERVAL '2 minutes', 12500, 5000),
    ('Cafeteria Kiosk', 'Canteen', 'online', NOW() - INTERVAL '5 minutes', 8500, 2000),
    ('Parking Gate 1', 'Basement', 'maintenance', NOW() - INTERVAL '1 hour', 0, 0),
    ('Gift Shop', 'First Floor', 'offline', NOW() - INTERVAL '1 day', 1200, 3500);

-- Insert services, logs, history, and payments
DO $$
DECLARE
    machine1_id UUID;
    machine2_id UUID;
    service1_id UUID;
BEGIN
    -- Get machine IDs
    SELECT id INTO machine1_id FROM machines WHERE name = 'Main Entrance POS';
    SELECT id INTO machine2_id FROM machines WHERE name = 'Cafeteria Kiosk';

    -- Insert services for Machine 1
    INSERT INTO services (machine_id, name, price, status) VALUES
        (machine1_id, 'Standard Parking', 50, 'active'),
        (machine1_id, 'Premium Valet', 150, 'active'),
        (machine1_id, 'Monthly Pass', 2500, 'active'),
        (machine1_id, 'Event Rate', 200, 'inactive')
    RETURNING id INTO service1_id;

    -- Insert services for Machine 2
    INSERT INTO services (machine_id, name, price, status) VALUES
        (machine2_id, 'Coffee', 80, 'active'),
        (machine2_id, 'Sandwich', 120, 'active'),
        (machine2_id, 'Combo Meal', 200, 'active');

    -- Insert machine logs
    INSERT INTO machine_logs (machine_id, action, details, type) VALUES
        (machine1_id, 'Machine Online', 'System startup sequence complete', 'system'),
        (machine1_id, 'Shift Started', 'Operator logged in', 'login'),
        (machine1_id, 'Tariff Update', 'Updated weekday rates', 'config'),
        (machine1_id, 'Maintenance Mode', 'Technician mode enabled', 'manager'),
        (machine2_id, 'Machine Online', 'System startup complete', 'system'),
        (machine2_id, 'Menu Updated', 'Added new items', 'config');

    -- Insert catalog history
    INSERT INTO catalog_history (machine_id, service_id, action, details, user_name, type) VALUES
        (machine1_id, service1_id, 'Price Update', 'Increased Monthly Pass from 2200 to 2500', 'Admin', 'update'),
        (machine1_id, NULL, 'Item Added', 'Added Standard Parking service', 'System', 'create'),
        (machine2_id, NULL, 'Menu Update', 'Updated cafeteria menu', 'Manager', 'update');

    -- Insert payments
    INSERT INTO payments (machine_id, bill_number, amount, method, status, created_at) VALUES
        -- Today's payments
        (machine1_id, 'TXN-001', 1250, 'UPI', 'success', NOW() - INTERVAL '2 hours'),
        (machine1_id, 'TXN-002', 500, 'Cash', 'success', NOW() - INTERVAL '1 hour'),
        (machine1_id, 'BILL-001', 150, 'UPI', 'success', NOW() - INTERVAL '30 minutes'),
        (machine2_id, 'BILL-002', 80, 'Cash', 'success', NOW() - INTERVAL '1 hour'),
        (machine2_id, 'BILL-003', 200, 'Card', 'success', NOW() - INTERVAL '45 minutes'),
        -- Yesterday's payments
        (machine1_id, 'BILL-004', 2500, 'UPI', 'success', NOW() - INTERVAL '1 day'),
        (machine1_id, 'BILL-005', 150, 'Cash', 'success', NOW() - INTERVAL '1 day'),
        (machine2_id, 'BILL-006', 320, 'Card', 'success', NOW() - INTERVAL '1 day'),
        -- Last week's payments
        (machine1_id, 'BILL-007', 1800, 'UPI', 'success', NOW() - INTERVAL '3 days'),
        (machine1_id, 'BILL-008', 950, 'Cash', 'success', NOW() - INTERVAL '5 days'),
        (machine2_id, 'BILL-009', 480, 'Card', 'success', NOW() - INTERVAL '4 days');
END $$;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check all tables
SELECT 'users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'machines', COUNT(*) FROM machines
UNION ALL
SELECT 'services', COUNT(*) FROM services
UNION ALL
SELECT 'machine_logs', COUNT(*) FROM machine_logs
UNION ALL
SELECT 'catalog_history', COUNT(*) FROM catalog_history
UNION ALL
SELECT 'payments', COUNT(*) FROM payments;
