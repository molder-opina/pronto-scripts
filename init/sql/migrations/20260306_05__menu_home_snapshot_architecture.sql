-- PRONTO v4 menu architecture: taxonomy + labels + home modules + static publish state

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) Categories: add slug + optimistic concurrency revision
-- -----------------------------------------------------------------------------
ALTER TABLE IF EXISTS pronto_menu_categories
    ADD COLUMN IF NOT EXISTS slug VARCHAR(120),
    ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;

UPDATE pronto_menu_categories
SET slug = lower(
    trim(
        regexp_replace(
            regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'),
            '(^-+|-+$)',
            '',
            'g'
        )
    )
)
WHERE slug IS NULL OR trim(slug) = '';

-- De-duplicate slugs deterministically when needed.
WITH duplicated AS (
    SELECT id, slug,
           ROW_NUMBER() OVER (PARTITION BY slug ORDER BY created_at, id) AS rn
    FROM pronto_menu_categories
)
UPDATE pronto_menu_categories c
SET slug = c.slug || '-' || right(replace(c.id::text, '-', ''), 6)
FROM duplicated d
WHERE c.id = d.id
  AND d.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_menu_categories_slug
    ON pronto_menu_categories(slug);

CREATE INDEX IF NOT EXISTS ix_menu_categories_active_order
    ON pronto_menu_categories(is_active, sort_order, display_order);

-- -----------------------------------------------------------------------------
-- 2) Subcategories table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pronto_menu_subcategories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_category_id UUID NOT NULL REFERENCES pronto_menu_categories(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    slug VARCHAR(120) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_menu_subcategories_category_slug UNIQUE (menu_category_id, slug)
);

CREATE INDEX IF NOT EXISTS ix_menu_subcategories_category_active_order
    ON pronto_menu_subcategories(menu_category_id, is_active, sort_order);

-- -----------------------------------------------------------------------------
-- 3) Menu items: new structural/commercial columns
-- -----------------------------------------------------------------------------
ALTER TABLE IF EXISTS pronto_menu_items
    ADD COLUMN IF NOT EXISTS menu_category_id UUID,
    ADD COLUMN IF NOT EXISTS menu_subcategory_id UUID,
    ADD COLUMN IF NOT EXISTS item_kind VARCHAR(16) NOT NULL DEFAULT 'product',
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;

-- Backfill menu_category_id from existing category_id when available.
UPDATE pronto_menu_items
SET menu_category_id = category_id
WHERE menu_category_id IS NULL
  AND category_id IS NOT NULL;

-- Create deterministic fallback category/subcategory for unresolved records.
INSERT INTO pronto_menu_categories (id, name, slug, description, sort_order, display_order, is_active)
SELECT
    '9b2dd8b8-6ea0-43bb-b82e-9ed3435e7f01'::uuid,
    'Sin clasificar',
    'sin-clasificar',
    'Categoría temporal para registros sin clasificación válida',
    9990,
    9990,
    FALSE
WHERE NOT EXISTS (
    SELECT 1 FROM pronto_menu_categories WHERE slug = 'sin-clasificar'
);

INSERT INTO pronto_menu_subcategories (id, menu_category_id, name, slug, sort_order, is_active)
SELECT
    '8e51fb5b-893b-4f2d-bdf2-1869d0dc47d1'::uuid,
    c.id,
    'General',
    'general',
    9990,
    FALSE
FROM pronto_menu_categories c
WHERE c.slug = 'sin-clasificar'
  AND NOT EXISTS (
      SELECT 1 FROM pronto_menu_subcategories s
      WHERE s.menu_category_id = c.id
        AND s.slug = 'general'
  );

-- Ensure each category has a generic subcategory to make backfill deterministic.
INSERT INTO pronto_menu_subcategories (menu_category_id, name, slug, sort_order, is_active)
SELECT c.id, 'General', 'general', 9990, c.is_active
FROM pronto_menu_categories c
WHERE NOT EXISTS (
    SELECT 1 FROM pronto_menu_subcategories s
    WHERE s.menu_category_id = c.id
      AND s.slug = 'general'
);

-- Items in legacy "combos" category become item_kind=combo.
UPDATE pronto_menu_items mi
SET item_kind = 'combo'
FROM pronto_menu_categories c
WHERE mi.menu_category_id = c.id
  AND lower(trim(c.name)) IN ('combos', 'combo');

-- If unresolved category, move to fallback category.
UPDATE pronto_menu_items
SET menu_category_id = (
        SELECT id FROM pronto_menu_categories WHERE slug = 'sin-clasificar' LIMIT 1
    )
WHERE menu_category_id IS NULL;

-- Assign subcategory from category's general bucket when empty.
UPDATE pronto_menu_items mi
SET menu_subcategory_id = s.id
FROM pronto_menu_subcategories s
WHERE mi.menu_subcategory_id IS NULL
  AND s.menu_category_id = mi.menu_category_id
  AND s.slug = 'general';

-- Last resort fallback for missing subcategory.
UPDATE pronto_menu_items
SET menu_subcategory_id = (
    SELECT s.id
    FROM pronto_menu_subcategories s
    JOIN pronto_menu_categories c ON c.id = s.menu_category_id
    WHERE c.slug = 'sin-clasificar' AND s.slug = 'general'
    LIMIT 1
)
WHERE menu_subcategory_id IS NULL;

ALTER TABLE pronto_menu_items
    ALTER COLUMN menu_category_id SET NOT NULL,
    ALTER COLUMN menu_subcategory_id SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_menu_items_item_kind'
          AND conrelid = 'pronto_menu_items'::regclass
    ) THEN
        ALTER TABLE pronto_menu_items
            ADD CONSTRAINT chk_menu_items_item_kind
            CHECK (item_kind IN ('product', 'combo', 'package'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_menu_items_structural_active_order
    ON pronto_menu_items(menu_category_id, menu_subcategory_id, is_active, sort_order);

-- -----------------------------------------------------------------------------
-- 4) Commercial labels
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pronto_product_labels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    slug VARCHAR(120) NOT NULL,
    label_type VARCHAR(24) NOT NULL DEFAULT 'badge',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_quick_filter BOOLEAN NOT NULL DEFAULT FALSE,
    quick_filter_sort_order INTEGER NOT NULL DEFAULT 0,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_product_labels_slug UNIQUE (slug),
    CONSTRAINT chk_product_labels_type CHECK (label_type IN ('promo', 'badge', 'collection'))
);

CREATE TABLE IF NOT EXISTS pronto_product_label_map (
    product_id UUID NOT NULL REFERENCES pronto_menu_items(id) ON DELETE CASCADE,
    label_id UUID NOT NULL REFERENCES pronto_product_labels(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, label_id)
);

CREATE INDEX IF NOT EXISTS ix_product_label_map_label
    ON pronto_product_label_map(label_id);

-- -----------------------------------------------------------------------------
-- 5) Home modules (draft model)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pronto_menu_home_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(160) NOT NULL,
    slug VARCHAR(160) NOT NULL,
    module_type VARCHAR(32) NOT NULL,
    source_type VARCHAR(32) NOT NULL,
    source_ref_id UUID,
    source_item_kind VARCHAR(16),
    placement VARCHAR(32) NOT NULL DEFAULT 'home_client',
    sort_order INTEGER NOT NULL DEFAULT 0,
    max_items INTEGER NOT NULL DEFAULT 8,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    show_title BOOLEAN NOT NULL DEFAULT TRUE,
    show_view_all BOOLEAN NOT NULL DEFAULT FALSE,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_menu_home_modules_slug UNIQUE (slug),
    CONSTRAINT chk_menu_home_module_type CHECK (module_type IN ('hero', 'carousel', 'grid', 'chips', 'category_section')),
    CONSTRAINT chk_menu_home_source_type CHECK (source_type IN ('label', 'category', 'subcategory', 'item_kind', 'manual')),
    CONSTRAINT chk_menu_home_item_kind CHECK (source_item_kind IS NULL OR source_item_kind IN ('product', 'combo', 'package')),
    CONSTRAINT chk_menu_home_source_ref_rules CHECK (
        (source_type = 'manual' AND source_ref_id IS NULL)
        OR (source_type = 'item_kind' AND source_ref_id IS NULL AND source_item_kind IS NOT NULL)
        OR (source_type IN ('label', 'category', 'subcategory') AND source_ref_id IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS ix_menu_home_modules_placement_active_order
    ON pronto_menu_home_modules(placement, is_active, sort_order);

CREATE INDEX IF NOT EXISTS ix_menu_home_modules_source
    ON pronto_menu_home_modules(source_type, source_ref_id);

CREATE TABLE IF NOT EXISTS pronto_menu_home_module_products (
    module_id UUID NOT NULL REFERENCES pronto_menu_home_modules(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES pronto_menu_items(id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (module_id, product_id)
);

CREATE INDEX IF NOT EXISTS ix_menu_home_module_products_order
    ON pronto_menu_home_module_products(module_id, sort_order);

-- -----------------------------------------------------------------------------
-- 6) Snapshot publication state (atomic publish)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pronto_menu_home_publication_state (
    placement VARCHAR(32) PRIMARY KEY,
    draft_version INTEGER NOT NULL DEFAULT 1,
    published_version INTEGER NOT NULL DEFAULT 1,
    snapshot_revision VARCHAR(64) NOT NULL DEFAULT 'baseline-v1',
    publish_lock BOOLEAN NOT NULL DEFAULT FALSE,
    publish_status VARCHAR(16) NOT NULL DEFAULT 'idle',
    last_publish_at TIMESTAMPTZ,
    last_publish_error TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_menu_home_publish_status CHECK (publish_status IN ('idle', 'running', 'failed', 'succeeded'))
);

CREATE TABLE IF NOT EXISTS pronto_menu_home_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    placement VARCHAR(32) NOT NULL,
    version INTEGER NOT NULL,
    revision VARCHAR(64) NOT NULL,
    payload JSONB NOT NULL,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_menu_home_snapshot_version UNIQUE (placement, version),
    CONSTRAINT uq_menu_home_snapshot_revision UNIQUE (placement, revision)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_menu_home_snapshot_published
    ON pronto_menu_home_snapshots(placement)
    WHERE is_published;

INSERT INTO pronto_menu_home_publication_state (placement, draft_version, published_version, snapshot_revision, publish_lock, publish_status)
VALUES ('home_client', 1, 1, 'baseline-v1', FALSE, 'idle')
ON CONFLICT (placement) DO NOTHING;

INSERT INTO pronto_menu_home_snapshots (placement, version, revision, payload, is_published)
VALUES (
    'home_client',
    1,
    'baseline-v1',
    '{"placement":"home_client","modules":[],"generated_at":null}'::jsonb,
    TRUE
)
ON CONFLICT (placement, version) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 7) Seed core labels and baseline home modules
-- -----------------------------------------------------------------------------
INSERT INTO pronto_product_labels (name, slug, label_type, is_active, is_quick_filter, quick_filter_sort_order)
VALUES
    ('Promoción', 'promocion', 'promo', TRUE, TRUE, 10),
    ('Oferta', 'oferta', 'promo', TRUE, TRUE, 20),
    ('Nuevo', 'nuevo', 'badge', TRUE, TRUE, 30),
    ('Popular', 'popular', 'badge', TRUE, TRUE, 40),
    ('Recomendado', 'recomendado', 'badge', TRUE, FALSE, 0),
    ('Temporada', 'temporada', 'collection', TRUE, FALSE, 0)
ON CONFLICT (slug) DO NOTHING;

COMMIT;
