-- ============================================================================
-- PRONTO SEED: Employees
-- ============================================================================
-- Creates seed employees with encrypted data
-- Run order: 0360 (after areas and tables)
-- 
-- NOTE: This uses pgcrypto extension for encryption
-- Password hash format: SHA256(email + password + salt)
-- Name/Email encryption: AES with SECRET_KEY from environment
-- ============================================================================

-- Enable pgcrypto if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Helper function to hash credentials (mimics Python hash_credentials)
-- Format: SHA256(email + password + PASSWORD_HASH_SALT)
CREATE OR REPLACE FUNCTION pronto_hash_credentials(p_email TEXT, p_password TEXT)
RETURNS TEXT AS $$
DECLARE
    v_salt TEXT;
BEGIN
    -- Get salt from environment or use default
    v_salt := COALESCE(current_setting('app.password_hash_salt', true), 'default-salt');
    RETURN encode(digest(p_email || p_password || v_salt, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper function to encrypt string (mimics Python encrypt_string)
-- Uses AES encryption with SECRET_KEY
CREATE OR REPLACE FUNCTION pronto_encrypt_string(p_plaintext TEXT)
RETURNS TEXT AS $$
DECLARE
    v_key TEXT;
    v_encrypted BYTEA;
BEGIN
    -- Get encryption key from environment or use default
    v_key := COALESCE(current_setting('app.secret_key', true), 'change-me-please');
    
    -- Encrypt using AES
    v_encrypted := encrypt(p_plaintext::bytea, v_key::bytea, 'aes');
    
    -- Return base64 encoded
    RETURN encode(v_encrypted, 'base64');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper function to hash identifier (mimics Python hash_identifier)
CREATE OR REPLACE FUNCTION pronto_hash_identifier(p_identifier TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(digest(lower(p_identifier), 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Insert or update employees
-- Default password: ChangeMe!123 (can be overridden with SEED_EMPLOYEE_PASSWORD env var)
DO $$
DECLARE
    v_default_password TEXT;
BEGIN
    -- Get default password from environment or use default
    v_default_password := COALESCE(current_setting('app.seed_employee_password', true), 'ChangeMe!123');
    
    -- System Admin
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Admin General'),
        pronto_encrypt_string('admin@cafeteria.test'),
        pronto_hash_identifier('admin@cafeteria.test'),
        pronto_hash_credentials('admin@cafeteria.test', v_default_password),
        'system',
        NULL,
        '["system", "admin", "waiter", "chef", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Admin Roles
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Admin Roles'),
        pronto_encrypt_string('admin.roles@cafeteria.test'),
        pronto_hash_identifier('admin.roles@cafeteria.test'),
        pronto_hash_credentials('admin.roles@cafeteria.test', v_default_password),
        'admin',
        NULL,
        '["admin", "waiter", "chef", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Waiter 1
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Juan'),
        pronto_encrypt_string('juan.mesero@cafeteria.test'),
        pronto_hash_identifier('juan.mesero@cafeteria.test'),
        pronto_hash_credentials('juan.mesero@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Waiter 2
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Maria'),
        pronto_encrypt_string('maria.mesera@cafeteria.test'),
        pronto_hash_identifier('maria.mesera@cafeteria.test'),
        pronto_hash_credentials('maria.mesera@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Waiter 3
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Pedro'),
        pronto_encrypt_string('pedro.mesero@cafeteria.test'),
        pronto_hash_identifier('pedro.mesero@cafeteria.test'),
        pronto_hash_credentials('pedro.mesero@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Chef 1
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Carlos'),
        pronto_encrypt_string('carlos.chef@cafeteria.test'),
        pronto_hash_identifier('carlos.chef@cafeteria.test'),
        pronto_hash_credentials('carlos.chef@cafeteria.test', v_default_password),
        'chef',
        NULL,
        '["chef"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Chef 2
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Ana'),
        pronto_encrypt_string('ana.chef@cafeteria.test'),
        pronto_hash_identifier('ana.chef@cafeteria.test'),
        pronto_hash_credentials('ana.chef@cafeteria.test', v_default_password),
        'chef',
        NULL,
        '["chef"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Cashier 1
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Luis'),
        pronto_encrypt_string('luis.cajero@cafeteria.test'),
        pronto_hash_identifier('luis.cajero@cafeteria.test'),
        pronto_hash_credentials('luis.cajero@cafeteria.test', v_default_password),
        'cashier',
        NULL,
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Cashier 2
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Sofia'),
        pronto_encrypt_string('sofia.cajera@cafeteria.test'),
        pronto_hash_identifier('sofia.cajera@cafeteria.test'),
        pronto_hash_credentials('sofia.cajera@cafeteria.test', v_default_password),
        'cashier',
        NULL,
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Test Waiter
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Test Waiter'),
        pronto_encrypt_string('test.waiter@cafeteria.test'),
        pronto_hash_identifier('test.waiter@cafeteria.test'),
        pronto_hash_credentials('test.waiter@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Additional employees for testing
    
    -- Waiter 4
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Roberto'),
        pronto_encrypt_string('roberto.mesero@cafeteria.test'),
        pronto_hash_identifier('roberto.mesero@cafeteria.test'),
        pronto_hash_credentials('roberto.mesero@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Waiter 5
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Laura'),
        pronto_encrypt_string('laura.mesera@cafeteria.test'),
        pronto_hash_identifier('laura.mesera@cafeteria.test'),
        pronto_hash_credentials('laura.mesera@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Waiter 6
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Diego'),
        pronto_encrypt_string('diego.mesero@cafeteria.test'),
        pronto_hash_identifier('diego.mesero@cafeteria.test'),
        pronto_hash_credentials('diego.mesero@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Chef 3
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Miguel'),
        pronto_encrypt_string('miguel.chef@cafeteria.test'),
        pronto_hash_identifier('miguel.chef@cafeteria.test'),
        pronto_hash_credentials('miguel.chef@cafeteria.test', v_default_password),
        'chef',
        NULL,
        '["chef"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Chef 4
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Elena'),
        pronto_encrypt_string('elena.chef@cafeteria.test'),
        pronto_hash_identifier('elena.chef@cafeteria.test'),
        pronto_hash_credentials('elena.chef@cafeteria.test', v_default_password),
        'chef',
        NULL,
        '["chef"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Cashier 3
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Patricia'),
        pronto_encrypt_string('patricia.cajera@cafeteria.test'),
        pronto_hash_identifier('patricia.cajera@cafeteria.test'),
        pronto_hash_credentials('patricia.cajera@cafeteria.test', v_default_password),
        'cashier',
        NULL,
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Cashier 4
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Fernando'),
        pronto_encrypt_string('fernando.cajero@cafeteria.test'),
        pronto_hash_identifier('fernando.cajero@cafeteria.test'),
        pronto_hash_credentials('fernando.cajero@cafeteria.test', v_default_password),
        'cashier',
        NULL,
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Admin 2
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Admin Manager'),
        pronto_encrypt_string('manager@cafeteria.test'),
        pronto_hash_identifier('manager@cafeteria.test'),
        pronto_hash_credentials('manager@cafeteria.test', v_default_password),
        'admin',
        NULL,
        '["admin", "waiter", "chef", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Waiter 7
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Carmen'),
        pronto_encrypt_string('carmen.mesera@cafeteria.test'),
        pronto_hash_identifier('carmen.mesera@cafeteria.test'),
        pronto_hash_credentials('carmen.mesera@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
    -- Waiter 8
    INSERT INTO pronto_employees (
        id, name_encrypted, email_encrypted, email_hash, auth_hash,
        role, additional_roles, allow_scopes, is_active
    ) VALUES (
        gen_random_uuid(),
        pronto_encrypt_string('Javier'),
        pronto_encrypt_string('javier.mesero@cafeteria.test'),
        pronto_hash_identifier('javier.mesero@cafeteria.test'),
        pronto_hash_credentials('javier.mesero@cafeteria.test', v_default_password),
        'waiter',
        '["cashier"]',
        '["waiter", "cashier"]'::jsonb,
        true
    ) ON CONFLICT (email_hash) DO UPDATE SET
        name_encrypted = EXCLUDED.name_encrypted,
        role = EXCLUDED.role,
        allow_scopes = EXCLUDED.allow_scopes;
    
END $$;

-- Drop helper functions (cleanup)
DROP FUNCTION IF EXISTS pronto_hash_credentials(TEXT, TEXT);
DROP FUNCTION IF EXISTS pronto_encrypt_string(TEXT);
DROP FUNCTION IF EXISTS pronto_hash_identifier(TEXT);
