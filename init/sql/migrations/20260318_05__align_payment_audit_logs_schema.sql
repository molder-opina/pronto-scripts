-- Align pronto_payment_audit_logs table with ORM model used by pronto_shared.models.PaymentAuditLog
-- Resolves legacy shape created by older migration (SERIAL id + employee_role/action)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Canonical columns expected by ORM
ALTER TABLE pronto_payment_audit_logs
  ADD COLUMN IF NOT EXISTS operation_type VARCHAR(50),
  ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'MXN',
  ADD COLUMN IF NOT EXISTS reference VARCHAR(255),
  ADD COLUMN IF NOT EXISTS metadata JSONB,
  ADD COLUMN IF NOT EXISTS client_ip VARCHAR(45),
  ADD COLUMN IF NOT EXISTS user_agent TEXT,
  ADD COLUMN IF NOT EXISTS correlation_id VARCHAR(100);

-- Backfill operation_type from legacy action column when present
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'pronto_payment_audit_logs'
      AND column_name = 'action'
  ) THEN
    UPDATE pronto_payment_audit_logs
    SET operation_type = COALESCE(operation_type, action, 'legacy_action');
  ELSE
    UPDATE pronto_payment_audit_logs
    SET operation_type = COALESCE(operation_type, 'legacy_action');
  END IF;
END $$;

ALTER TABLE pronto_payment_audit_logs
  ALTER COLUMN operation_type SET NOT NULL,
  ALTER COLUMN currency SET DEFAULT 'MXN';

-- Legacy columns may exist and be NOT NULL; relax to avoid insert failures
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'pronto_payment_audit_logs' AND column_name = 'payment_id'
  ) THEN
    ALTER TABLE pronto_payment_audit_logs ALTER COLUMN payment_id DROP NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'pronto_payment_audit_logs' AND column_name = 'payment_method'
  ) THEN
    ALTER TABLE pronto_payment_audit_logs ALTER COLUMN payment_method TYPE VARCHAR(50);
    ALTER TABLE pronto_payment_audit_logs ALTER COLUMN payment_method DROP NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'pronto_payment_audit_logs' AND column_name = 'amount'
  ) THEN
    ALTER TABLE pronto_payment_audit_logs ALTER COLUMN amount TYPE NUMERIC(12, 2);
    ALTER TABLE pronto_payment_audit_logs ALTER COLUMN amount DROP NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'pronto_payment_audit_logs' AND column_name = 'employee_role'
  ) THEN
    ALTER TABLE pronto_payment_audit_logs ALTER COLUMN employee_role DROP NOT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'pronto_payment_audit_logs' AND column_name = 'action'
  ) THEN
    ALTER TABLE pronto_payment_audit_logs ALTER COLUMN action DROP NOT NULL;
  END IF;
END $$;

-- Convert legacy integer PK to UUID PK expected by ORM (`id: UUID`)
DO $$
DECLARE
  id_data_type TEXT;
  pk_name TEXT;
BEGIN
  SELECT data_type
  INTO id_data_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'pronto_payment_audit_logs'
    AND column_name = 'id';

  IF id_data_type IS DISTINCT FROM 'uuid' THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'pronto_payment_audit_logs'
        AND column_name = 'id_uuid_tmp'
    ) THEN
      ALTER TABLE pronto_payment_audit_logs ADD COLUMN id_uuid_tmp UUID;
    END IF;

    UPDATE pronto_payment_audit_logs
    SET id_uuid_tmp = gen_random_uuid()
    WHERE id_uuid_tmp IS NULL;

    ALTER TABLE pronto_payment_audit_logs
      ALTER COLUMN id_uuid_tmp SET DEFAULT gen_random_uuid(),
      ALTER COLUMN id_uuid_tmp SET NOT NULL;

    SELECT conname
    INTO pk_name
    FROM pg_constraint
    WHERE conrelid = 'pronto_payment_audit_logs'::regclass
      AND contype = 'p'
    LIMIT 1;

    IF pk_name IS NOT NULL THEN
      EXECUTE format('ALTER TABLE pronto_payment_audit_logs DROP CONSTRAINT %I', pk_name);
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'pronto_payment_audit_logs'
        AND column_name = 'id'
    )
    AND NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'pronto_payment_audit_logs'
        AND column_name = 'legacy_id'
    ) THEN
      ALTER TABLE pronto_payment_audit_logs RENAME COLUMN id TO legacy_id;
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'pronto_payment_audit_logs'
        AND column_name = 'id_uuid_tmp'
    ) THEN
      ALTER TABLE pronto_payment_audit_logs RENAME COLUMN id_uuid_tmp TO id;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conrelid = 'pronto_payment_audit_logs'::regclass
        AND contype = 'p'
    ) THEN
      ALTER TABLE pronto_payment_audit_logs
        ADD CONSTRAINT pronto_payment_audit_logs_pkey PRIMARY KEY (id);
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_session_id
  ON pronto_payment_audit_logs(session_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_payment_id
  ON pronto_payment_audit_logs(payment_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_employee_id
  ON pronto_payment_audit_logs(employee_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_created_at
  ON pronto_payment_audit_logs(created_at);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_correlation_id
  ON pronto_payment_audit_logs(correlation_id);
