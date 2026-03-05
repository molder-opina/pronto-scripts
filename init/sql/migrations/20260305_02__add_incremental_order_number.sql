-- Migration: Add incremental public order number (1..9999999999)
-- Date: 2026-03-05

BEGIN;

CREATE SEQUENCE IF NOT EXISTS pronto_orders_order_number_seq
  AS BIGINT
  START WITH 1
  INCREMENT BY 1
  MINVALUE 1
  MAXVALUE 9999999999
  CACHE 1;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pronto_orders'
          AND column_name = 'order_number'
    ) THEN
        ALTER TABLE pronto_orders
        ADD COLUMN order_number BIGINT;
    END IF;
END $$;

DO $$
DECLARE
    current_udt text;
BEGIN
    SELECT c.udt_name
    INTO current_udt
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'pronto_orders'
      AND c.column_name = 'order_number';

    IF current_udt IS DISTINCT FROM 'int8' THEN
        ALTER TABLE pronto_orders
        ALTER COLUMN order_number TYPE BIGINT
        USING (
            CASE
                WHEN trim(COALESCE(order_number::text, '')) ~ '^[0-9]{1,10}$'
                    THEN trim(order_number::text)::BIGINT
                ELSE NULL
            END
        );
    END IF;
END $$;

ALTER TABLE pronto_orders
    ALTER COLUMN order_number SET DEFAULT nextval('pronto_orders_order_number_seq');

WITH existing AS (
    SELECT COALESCE(MAX(order_number), 0)::BIGINT AS base
    FROM pronto_orders
),
ordered AS (
    SELECT id, row_number() OVER (ORDER BY created_at, id)::BIGINT AS rn
    FROM pronto_orders
    WHERE order_number IS NULL
)
UPDATE pronto_orders p
SET order_number = existing.base + ordered.rn
FROM ordered, existing
WHERE p.id = ordered.id;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_schema = 'public'
          AND table_name = 'pronto_orders'
          AND constraint_name = 'ck_pronto_orders_order_number_range'
    ) THEN
        ALTER TABLE pronto_orders DROP CONSTRAINT ck_pronto_orders_order_number_range;
    END IF;
END $$;

ALTER TABLE pronto_orders
    ADD CONSTRAINT ck_pronto_orders_order_number_range
    CHECK (order_number BETWEEN 1 AND 9999999999);

CREATE UNIQUE INDEX IF NOT EXISTS ix_orders_order_number
ON pronto_orders(order_number);

ALTER TABLE pronto_orders
    ALTER COLUMN order_number SET NOT NULL;

SELECT setval(
    'pronto_orders_order_number_seq',
    COALESCE((SELECT MAX(order_number) FROM pronto_orders), 0) + 1,
    false
);

COMMIT;
