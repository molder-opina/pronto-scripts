-- Migration: Align modifier columns with ORM model
-- Rename columns and add/remove columns as needed

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pronto_modifiers' AND column_name='sort_order') THEN
        ALTER TABLE pronto_modifiers RENAME COLUMN sort_order TO display_order;
    END IF;
END $$;

ALTER TABLE pronto_modifiers ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;
