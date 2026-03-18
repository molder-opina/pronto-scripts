-- Remove redundant and deprecated table_number column from sessions
-- Reference: TICKET-C3 BUG-20260309-TABLE-NUMBER-DESYNC
ALTER TABLE pronto_dining_sessions DROP COLUMN IF EXISTS table_number;
