-- Migration: Add area_id column to pronto_tables
-- Description: Adds the area_id column to support table areas feature

-- Add area_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'pronto_tables'
        AND column_name = 'area_id'
    ) THEN
        ALTER TABLE pronto_tables
        ADD COLUMN area_id INTEGER;

        -- Create index for area_id
        CREATE INDEX IF NOT EXISTS ix_table_area ON pronto_tables(area_id);

        RAISE NOTICE 'Column area_id added to pronto_tables';
    ELSE
        RAISE NOTICE 'Column area_id already exists in pronto_tables';
    END IF;
END $$;

-- Note: Foreign key constraint to pronto_areas is not added here
-- because the pronto_areas table may not exist yet.
-- The constraint will be added when the areas feature is fully implemented.
