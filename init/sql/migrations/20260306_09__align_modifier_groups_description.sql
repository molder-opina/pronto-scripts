-- Migration: align pronto_modifier_groups with canonical schema/model.
-- Rollback: optional manual ALTER TABLE pronto_modifier_groups DROP COLUMN description;

ALTER TABLE pronto_modifier_groups
  ADD COLUMN IF NOT EXISTS description TEXT;