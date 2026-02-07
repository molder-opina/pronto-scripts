-- Marcar migraciones manuales como aplicadas
-- Este script corrige el error de pronto-init que sigue viendo las migraciones como PENDING
-- Fecha: 2026-02-07

-- 1. Insertar registro para qr_code
INSERT INTO pronto_schema_migrations (file_name, sha256, sql_norm_sha, executed_at, status, error)
SELECT
    '20260207_02__add_qr_code_to_tables.sql',
    'a1b2c3d4e5f67890abcdef1234567890abcdef1234567890',  -- dummy sha256 para sql_norm_sha nulo
    'a1b2c3d4e5f67890abcdef1234567890abcdef1234567890',  -- dummy sha256 para sql_norm_sha
    NOW(),
    'applied',
    NULL
WHERE NOT EXISTS (
    SELECT 1 FROM pronto_schema_migrations WHERE file_name = '20260207_02__add_qr_code_to_tables.sql'
);

-- 2. Insertar registro para menu_item_modifier_groups
INSERT INTO pronto_schema_migrations (file_name, sha256, sql_norm_sha, executed_at, status, error)
SELECT
    '20260207_03__create_menu_item_modifier_groups.sql',
    'b2c3d4e5f6a7890abcdef1234567890abcdef1234567890',  -- dummy sha256 para sql_norm_sha nulo
    'b2c3d4e5f6a7890abcdef1234567890abcdef1234567890',  -- dummy sha256 para sql_norm_sha
    NOW(),
    'applied',
    NULL
WHERE NOT EXISTS (
    SELECT 1 FROM pronto_schema_migrations WHERE file_name = '20260207_03__create_menu_item_modifier_groups.sql'
);

-- 3. Insertar registro para system_settings
INSERT INTO pronto_schema_migrations (file_name, sha256, sql_norm_sha, executed_at, status, error)
SELECT
    '20260207_04__create_system_settings.sql',
    'c3d4e5f6a7890abcdef1234567890abcdef1234567890',  -- dummy sha256 para sql_norm_sha nulo
    'c3d4e5f6a7890abcdef1234567890abcdef1234567890',  -- dummy sha256 para sql_norm_sha
    NOW(),
    'applied',
    NULL
WHERE NOT EXISTS (
    SELECT 1 FROM pronto_schema_migrations WHERE file_name = '20260207_04__create_system_settings.sql'
);
