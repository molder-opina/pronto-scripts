-- Promotion: Promociones
CREATE TABLE IF NOT EXISTS pronto_promotions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    promotion_type VARCHAR(32) NOT NULL,
    discount_percentage NUMERIC(5, 2),
    discount_amount NUMERIC(10, 2),
    min_purchase_amount NUMERIC(10, 2),
    applies_to VARCHAR(32) NOT NULL DEFAULT 'products',
    applicable_tags JSONB,
    applicable_products JSONB,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    banner_message VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    CHECK (discount_amount >= 0)
);

CREATE INDEX IF NOT EXISTS ix_promotion_active_dates ON pronto_promotions(is_active, valid_from, valid_until);

-- DiscountCode: Códigos de descuento
CREATE TABLE IF NOT EXISTS pronto_discount_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    discount_type VARCHAR(32) NOT NULL,
    discount_percentage NUMERIC(5, 2),
    discount_amount NUMERIC(10, 2),
    min_purchase_amount NUMERIC(10, 2),
    usage_limit INTEGER,
    times_used INTEGER NOT NULL DEFAULT 0,
    applies_to VARCHAR(32) NOT NULL DEFAULT 'products',
    applicable_tags JSONB,
    applicable_products JSONB,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    CHECK (discount_amount >= 0),
    CHECK (usage_limit >= 0),
    CHECK (times_used >= 0)
);

CREATE INDEX IF NOT EXISTS ix_discount_code ON pronto_discount_codes(code);
CREATE INDEX IF NOT EXISTS ix_discount_active_dates ON pronto_discount_codes(is_active, valid_from, valid_until);
