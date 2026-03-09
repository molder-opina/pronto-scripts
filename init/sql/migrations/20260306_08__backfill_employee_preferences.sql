-- Migration: backfill employee profile preferences after pronto_employee_preferences exists.
-- Rollback: optional manual DELETE FROM pronto_employee_preferences WHERE key='profile';

INSERT INTO pronto_employee_preferences (employee_id, key, value)
SELECT
  e.id,
  'profile',
  jsonb_build_object(
    'personal_email', NULL,
    'contact_phone', NULL,
    'contact_person_name', NULL,
    'contact_person_phone', NULL
  )
FROM pronto_employees AS e
ON CONFLICT DO NOTHING;