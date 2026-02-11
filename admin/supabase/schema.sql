-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create ENUMS
CREATE TYPE machine_status AS ENUM ('online', 'offline', 'maintenance');
CREATE TYPE service_status AS ENUM ('active', 'inactive');
CREATE TYPE log_type AS ENUM ('login', 'client', 'config', 'manager', 'system');
CREATE TYPE history_type AS ENUM ('update', 'create', 'delete', 'status');
CREATE TYPE payment_method AS ENUM ('UPI', 'Card', 'Cash');
CREATE TYPE payment_status AS ENUM ('success', 'pending', 'failed');

-- Machines Table
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

-- Services Table
CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    status service_status DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Machine Logs Table
CREATE TABLE machine_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details TEXT,
    type log_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Catalog History Table
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

-- Payments Table
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    bill_number TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    method payment_method NOT NULL,
    status payment_status DEFAULT 'success',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_services_machine_id ON services(machine_id);
CREATE INDEX idx_machine_logs_machine_id ON machine_logs(machine_id);
CREATE INDEX idx_catalog_history_machine_id ON catalog_history(machine_id);
CREATE INDEX idx_payments_machine_id ON payments(machine_id);
CREATE INDEX idx_payments_created_at ON payments(created_at);

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

-- Enable Row Level Security (RLS)
ALTER TABLE machines ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE machine_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Allow all for now - adjust based on your auth requirements)
CREATE POLICY "Allow all access to machines" ON machines FOR ALL USING (true);
CREATE POLICY "Allow all access to services" ON services FOR ALL USING (true);
CREATE POLICY "Allow all access to machine_logs" ON machine_logs FOR ALL USING (true);
CREATE POLICY "Allow all access to catalog_history" ON catalog_history FOR ALL USING (true);
CREATE POLICY "Allow all access to payments" ON payments FOR ALL USING (true);

-- Seed Data
INSERT INTO machines (name, location, status, last_sync, online_collection, offline_collection) VALUES
    ('Main Entrance POS', 'Lobby A', 'online', NOW() - INTERVAL '2 minutes', 12500, 5000),
    ('Cafeteria Kiosk', 'Canteen', 'online', NOW() - INTERVAL '5 minutes', 8500, 2000),
    ('Parking Gate 1', 'Basement', 'maintenance', NOW() - INTERVAL '1 hour', 0, 0),
    ('Gift Shop', 'First Floor', 'offline', NOW() - INTERVAL '1 day', 1200, 3500);

-- Get machine IDs for seed data
DO $$
DECLARE
    machine1_id UUID;
    machine2_id UUID;
    service1_id UUID;
    service2_id UUID;
    service3_id UUID;
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

    -- Insert machine logs
    INSERT INTO machine_logs (machine_id, action, details, type) VALUES
        (machine1_id, 'Machine Online', 'System startup sequence complete', 'system'),
        (machine1_id, 'Machine Offline', 'Shut down by operator', 'system'),
        (machine1_id, 'Shift Started', 'Operator logged in', 'login'),
        (machine1_id, 'Tariff Update', 'Updated weekday rates', 'config'),
        (machine1_id, 'Machine Offline', 'Power failure detected', 'system'),
        (machine1_id, 'Maintenance Mode', 'Technician mode enabled', 'manager');

    -- Insert catalog history
    INSERT INTO catalog_history (machine_id, service_id, action, details, user_name, type) VALUES
        (machine1_id, NULL, 'Price Update', 'Increased Monthly Pass from 2200 to 2500', 'Admin', 'update'),
        (machine1_id, NULL, 'Item Added', 'Added Standard Parking service', 'System', 'create');

    -- Insert payments
    INSERT INTO payments (machine_id, bill_number, amount, method, status) VALUES
        (machine1_id, 'TXN-001', 1250, 'UPI', 'success'),
        (machine1_id, 'TXN-002', 500, 'Cash', 'success'),
        (machine1_id, 'BILL-001', 150, 'UPI', 'success'),
        (machine1_id, 'BILL-002', 50, 'Cash', 'success'),
        (machine1_id, 'BILL-003', 1200, 'Card', 'success'),
        (machine1_id, 'BILL-004', 80, 'UPI', 'success'),
        (machine1_id, 'BILL-005', 200, 'Cash', 'success');
END $$;
