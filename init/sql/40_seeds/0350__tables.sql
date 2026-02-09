-- ============================================================================
-- PRONTO SEED: Tables
-- ============================================================================
-- Creates restaurant tables with QR codes and UPSERT logic
-- Run order: 0350 (after areas, can be before or after menu items)
-- ============================================================================

-- Insert or update tables
-- Terraza tables (T1-T3)
INSERT INTO pronto_tables (id, table_number, area_id, capacity, qr_code, status, is_active)
VALUES
    -- Terraza tables (T1-T5)
    (gen_random_uuid(), 'T1', (SELECT id FROM pronto_areas WHERE name = 'Terraza'), 4, 'T1-QR-SEED', 'available', true),
    (gen_random_uuid(), 'T2', (SELECT id FROM pronto_areas WHERE name = 'Terraza'), 4, 'T2-QR-SEED', 'available', true),
    (gen_random_uuid(), 'T3', (SELECT id FROM pronto_areas WHERE name = 'Terraza'), 6, 'T3-QR-SEED', 'available', true),
    (gen_random_uuid(), 'T4', (SELECT id FROM pronto_areas WHERE name = 'Terraza'), 2, 'T4-QR-SEED', 'available', true),
    (gen_random_uuid(), 'T5', (SELECT id FROM pronto_areas WHERE name = 'Terraza'), 4, 'T5-QR-SEED', 'available', true),
    
    -- Salón Principal tables (M1-M8)
    (gen_random_uuid(), 'M1', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 2, 'M1-QR-SEED', 'available', true),
    (gen_random_uuid(), 'M2', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 4, 'M2-QR-SEED', 'available', true),
    (gen_random_uuid(), 'M3', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 4, 'M3-QR-SEED', 'available', true),
    (gen_random_uuid(), 'M4', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 6, 'M4-QR-SEED', 'available', true),
    (gen_random_uuid(), 'M5', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 2, 'M5-QR-SEED', 'available', true),
    (gen_random_uuid(), 'M6', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 4, 'M6-QR-SEED', 'available', true),
    (gen_random_uuid(), 'M7', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 6, 'M7-QR-SEED', 'available', true),
    (gen_random_uuid(), 'M8', (SELECT id FROM pronto_areas WHERE name = 'Salón Principal'), 8, 'M8-QR-SEED', 'available', true),
    
    -- VIP tables (V1-V3)
    (gen_random_uuid(), 'V1', (SELECT id FROM pronto_areas WHERE name = 'VIP'), 8, 'V1-QR-SEED', 'available', true),
    (gen_random_uuid(), 'V2', (SELECT id FROM pronto_areas WHERE name = 'VIP'), 6, 'V2-QR-SEED', 'available', true),
    (gen_random_uuid(), 'V3', (SELECT id FROM pronto_areas WHERE name = 'VIP'), 10, 'V3-QR-SEED', 'available', true),
    
    -- Bar tables (B1-B4)
    (gen_random_uuid(), 'B1', (SELECT id FROM pronto_areas WHERE name = 'Bar'), 2, 'B1-QR-SEED', 'available', true),
    (gen_random_uuid(), 'B2', (SELECT id FROM pronto_areas WHERE name = 'Bar'), 2, 'B2-QR-SEED', 'available', true),
    (gen_random_uuid(), 'B3', (SELECT id FROM pronto_areas WHERE name = 'Bar'), 4, 'B3-QR-SEED', 'available', true),
    (gen_random_uuid(), 'B4', (SELECT id FROM pronto_areas WHERE name = 'Bar'), 4, 'B4-QR-SEED', 'available', true),
    
    -- Jardín tables (J1-J3)
    (gen_random_uuid(), 'J1', (SELECT id FROM pronto_areas WHERE name = 'Jardín'), 4, 'J1-QR-SEED', 'available', true),
    (gen_random_uuid(), 'J2', (SELECT id FROM pronto_areas WHERE name = 'Jardín'), 6, 'J2-QR-SEED', 'available', true),
    (gen_random_uuid(), 'J3', (SELECT id FROM pronto_areas WHERE name = 'Jardín'), 8, 'J3-QR-SEED', 'available', true),
    
    -- Rooftop tables (R1-R2)
    (gen_random_uuid(), 'R1', (SELECT id FROM pronto_areas WHERE name = 'Rooftop'), 4, 'R1-QR-SEED', 'available', true),
    (gen_random_uuid(), 'R2', (SELECT id FROM pronto_areas WHERE name = 'Rooftop'), 6, 'R2-QR-SEED', 'available', true)
ON CONFLICT (table_number) DO UPDATE SET
    area_id = EXCLUDED.area_id,
    capacity = EXCLUDED.capacity,
    qr_code = EXCLUDED.qr_code,
    status = EXCLUDED.status,
    is_active = EXCLUDED.is_active;
