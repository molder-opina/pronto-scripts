-- Migration: Convert notifications recipient_id to UUID
-- Date: 2026-03-05

BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pronto_notifications'
          AND column_name = 'recipient_id'
          AND udt_name <> 'uuid'
    ) THEN
        ALTER TABLE pronto_notifications
            ALTER COLUMN recipient_id TYPE UUID
            USING (
                CASE
                    WHEN recipient_id IS NULL THEN NULL
                    WHEN trim(recipient_id::text) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                        THEN trim(recipient_id::text)::uuid
                    ELSE NULL
                END
            );
    END IF;
END $$;

COMMIT;
