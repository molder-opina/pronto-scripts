-- Migration: Align modifier_groups columns with ORM model
-- Rename columns and add/remove columns as needed

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pronto_modifier_groups' AND column_name='min_selections') THEN
        ALTER TABLE pronto_modifier_groups RENAME COLUMN min_selections TO min_selection;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='pronto_modifier_groups' AND column_name='max_selections') THEN
        ALTER TABLE pronto_modifier_groups RENAME COLUMN max_selections TO max_selection;
    END IF;
END $$;

ALTER TABLE pronto_modifier_groups ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;
