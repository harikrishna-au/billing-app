-- Migration: Create system_alerts table
-- Description: Adds a dedicated table for storing system alerts
-- Date: 2026-02-04

-- Create enum type for alert severity
CREATE TYPE alert_severity AS ENUM ('critical', 'warning', 'info');

-- Create system_alerts table
CREATE TABLE IF NOT EXISTS system_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Alert details
    title VARCHAR(200) NOT NULL,
    message VARCHAR(500) NOT NULL,
    severity alert_severity NOT NULL DEFAULT 'info',
    
    -- Related machine (optional)
    machine_id UUID REFERENCES machines(id) ON DELETE CASCADE,
    
    -- Alert status
    resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_system_alerts_severity ON system_alerts(severity);
CREATE INDEX idx_system_alerts_machine_id ON system_alerts(machine_id);
CREATE INDEX idx_system_alerts_resolved ON system_alerts(resolved);
CREATE INDEX idx_system_alerts_created_at ON system_alerts(created_at DESC);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_system_alerts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_system_alerts_updated_at
    BEFORE UPDATE ON system_alerts
    FOR EACH ROW
    EXECUTE FUNCTION update_system_alerts_updated_at();

-- Add comment to table
COMMENT ON TABLE system_alerts IS 'System alerts for monitoring machine status and system events';
COMMENT ON COLUMN system_alerts.severity IS 'Alert severity: critical, warning, or info';
COMMENT ON COLUMN system_alerts.resolved IS 'Whether the alert has been resolved';
COMMENT ON COLUMN system_alerts.machine_id IS 'Related machine (optional - some alerts are system-wide)';
