-- Migration: Agregar campo kind a Customer para distinguir clientes normales de kioskos
-- Bug: AUTH-001
-- Fecha: 2026-02-14
-- Autorización: Usuario explícita (modificación DOMINIO INMUTABLE Sección 3 AGENTS.md)

-- Agregar columna kind con default 'customer'
ALTER TABLE pronto_customers 
ADD COLUMN IF NOT EXISTS kind VARCHAR(20) NOT NULL DEFAULT 'customer';

-- Agregar columna kiosk_location para kioskos
ALTER TABLE pronto_customers 
ADD COLUMN IF NOT EXISTS kiosk_location VARCHAR(50) NULL;

-- Check constraint para valores válidos (idempotente)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_customer_kind' 
        AND conrelid = 'pronto_customers'::regclass
    ) THEN
        ALTER TABLE pronto_customers 
        ADD CONSTRAINT chk_customer_kind 
        CHECK (kind IN ('customer', 'kiosk'));
    END IF;
END $$;

-- Index para filtros por kind
CREATE INDEX IF NOT EXISTS ix_customer_kind ON pronto_customers(kind);

-- Actualizar kioskos existentes por email interno
UPDATE pronto_customers 
SET kind = 'kiosk', kiosk_location = REPLACE(SPLIT_PART(email_normalized, '@', 1), 'kiosk-', '')
WHERE email_normalized LIKE 'kiosk-%@pronto.internal';

-- Index para kiosk_location
CREATE INDEX IF NOT EXISTS ix_customer_kiosk_location ON pronto_customers(kiosk_location) 
WHERE kind = 'kiosk';