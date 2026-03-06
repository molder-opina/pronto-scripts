-- Migration: Convert pronto_areas.id from UUID to Integer
-- This aligns the schema with SQLAlchemy models (AGENTS.md 12.5)
-- Date: 2026-02-19

BEGIN;

-- Step 1: Create mapping table
CREATE TEMP TABLE area_id_mapping AS
SELECT id as old_id, ROW_NUMBER() OVER (ORDER BY name) as new_id
FROM pronto_areas;

-- Step 2: Add temporary integer columns
ALTER TABLE pronto_areas ADD COLUMN new_id INTEGER;
ALTER TABLE pronto_tables ADD COLUMN new_area_id INTEGER;

-- Step 3: Populate new IDs
UPDATE pronto_areas a SET new_id = m.new_id
FROM area_id_mapping m WHERE a.id = m.old_id;

UPDATE pronto_tables t SET new_area_id = m.new_id
FROM area_id_mapping m, pronto_areas a
WHERE t.area_id = a.id AND a.id = m.old_id;

-- Step 4: Drop foreign key constraint
ALTER TABLE pronto_tables DROP CONSTRAINT IF EXISTS pronto_tables_area_id_fkey;

-- Step 5: Drop old columns and rename
ALTER TABLE pronto_areas DROP COLUMN id;
ALTER TABLE pronto_areas RENAME COLUMN new_id TO id;

-- Step 6: Set up primary key and sequence
CREATE SEQUENCE IF NOT EXISTS pronto_areas_id_seq;
SELECT setval('pronto_areas_id_seq', (SELECT MAX(id) FROM pronto_areas));
ALTER TABLE pronto_areas ALTER COLUMN id SET DEFAULT nextval('pronto_areas_id_seq');
ALTER TABLE pronto_areas ADD PRIMARY KEY (id);

-- Step 7: Update tables
ALTER TABLE pronto_tables DROP COLUMN area_id;
ALTER TABLE pronto_tables RENAME COLUMN new_area_id TO area_id;
ALTER TABLE pronto_tables ALTER COLUMN area_id SET NOT NULL;

-- Step 8: Recreate foreign key
ALTER TABLE pronto_tables ADD CONSTRAINT pronto_tables_area_id_fkey
  FOREIGN KEY (area_id) REFERENCES pronto_areas(id) ON DELETE RESTRICT;

-- Step 9: Recreate indexes
DROP INDEX IF EXISTS ix_area_name;
CREATE UNIQUE INDEX ix_area_name ON pronto_areas(name);
DROP INDEX IF EXISTS ix_area_prefix;
CREATE UNIQUE INDEX ix_area_prefix ON pronto_areas(prefix);
DROP INDEX IF EXISTS ix_area_active;
CREATE INDEX ix_area_active ON pronto_areas(is_active);
DROP INDEX IF EXISTS ix_table_area;
CREATE INDEX ix_table_area ON pronto_tables(area_id);

-- Step 10: Drop sequence if it was auto-created incorrectly
DROP SEQUENCE IF EXISTS pronto_areas_id_seq CASCADE;
CREATE SEQUENCE pronto_areas_id_seq;
SELECT setval('pronto_areas_id_seq', (SELECT COALESCE(MAX(id), 0) FROM pronto_areas));
ALTER TABLE pronto_areas ALTER COLUMN id SET DEFAULT nextval('pronto_areas_id_seq');
ALTER SEQUENCE pronto_areas_id_seq OWNED BY pronto_areas.id;

COMMIT;

-- Verify
DO $$
DECLARE
  area_count INTEGER;
  table_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO area_count FROM pronto_areas WHERE id IS NOT NULL;
  SELECT COUNT(*) INTO table_count FROM pronto_tables WHERE area_id IS NOT NULL;
  RAISE NOTICE 'Migration complete: % areas, % tables with area_id', area_count, table_count;
END $$;
