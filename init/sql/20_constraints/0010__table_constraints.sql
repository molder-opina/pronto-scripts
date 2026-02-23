-- Constraints for PRONTO tables
-- This file contains foreign key constraints and check constraints
-- Note: Some FK constraints are defined inline in 10_schema for simplicity

-- This file is intentionally minimal as most constraints are defined inline
-- with the table definitions in 10_schema/0110__core_tables.sql

-- Example of additional constraints that could be added here:
-- ALTER TABLE pronto_orders ADD CONSTRAINT chk_total_positive 
--   CHECK (total_amount >= 0);
