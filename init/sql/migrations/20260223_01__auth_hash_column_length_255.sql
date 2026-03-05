-- Align auth hash column length with modern password hash formats
ALTER TABLE pronto_employees
  ALTER COLUMN auth_hash TYPE VARCHAR(255);

ALTER TABLE pronto_customers
  ALTER COLUMN auth_hash TYPE VARCHAR(255);
