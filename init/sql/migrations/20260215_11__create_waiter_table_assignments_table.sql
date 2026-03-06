-- Migration: create_waiter_table_assignments_table
-- Description: Create missing pronto_waiter_table_assignments table
-- Created: 2026-02-15
-- Updated: 2026-02-16 - Add notes column

-- Add notes column if not exists
ALTER TABLE pronto_waiter_table_assignments ADD COLUMN IF NOT EXISTS notes TEXT;

-- Rollback:
-- ALTER TABLE pronto_waiter_table_assignments DROP COLUMN IF EXISTS notes;

CREATE TABLE IF NOT EXISTS pronto_waiter_table_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    waiter_id UUID NOT NULL REFERENCES pronto_employees(id),
    table_id UUID NOT NULL REFERENCES pronto_tables(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unassigned_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(waiter_id, table_id, is_active)
);

CREATE INDEX IF NOT EXISTS ix_waiter_assignments_waiter ON pronto_waiter_table_assignments(waiter_id);
CREATE INDEX IF NOT EXISTS ix_waiter_assignments_table ON pronto_waiter_table_assignments(table_id);
CREATE INDEX IF NOT EXISTS ix_waiter_assignments_active ON pronto_waiter_table_assignments(is_active);
