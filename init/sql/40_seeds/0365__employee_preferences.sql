-- Seed inicial de preferencias de perfil por empleado.
-- Crea una fila base por empleado en pronto_employee_preferences (key=profile)
-- para que la edición de perfil esté lista desde el primer login.

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
