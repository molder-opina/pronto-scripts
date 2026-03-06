-- Migration: Ensure pronto_system_settings has is_public for compatibility
-- Date: 2026-03-04

BEGIN;

ALTER TABLE IF EXISTS pronto_system_settings
    ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE;

COMMIT;
