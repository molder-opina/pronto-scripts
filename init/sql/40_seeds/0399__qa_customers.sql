-- QA customer accounts for client login tests.
-- Seeded in INIT (idempotent) to avoid runtime python seeding.

INSERT INTO pronto_customers (
  id,
  first_name,
  last_name,
  email_hash,
  password_hash,
  email_normalized,
  kind,
  loyalty_points,
  total_spent,
  visit_count,
  created_at,
  updated_at
)
SELECT
  '55555555-5555-5555-5555-555555555001'::uuid,
  'Luartx',
  'QA',
  NULL,
  'pbkdf2:sha256:600000$Qir8jv8UDn44Nddl$5e156d3a55f729d0083c421980dff8bdd62678c0277243a4f370803b3630e16f',
  'luartx@gmail.com',
  'customer',
  0,
  0,
  0,
  now(),
  now()
WHERE NOT EXISTS (
  SELECT 1
  FROM pronto_customers
  WHERE lower(trim(email_normalized)) = 'luartx@gmail.com'
)
ON CONFLICT DO NOTHING;
