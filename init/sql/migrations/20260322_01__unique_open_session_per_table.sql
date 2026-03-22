-- Migration: 20260322_01__unique_open_session_per_table.sql
-- Purpose: Enforce that only ONE open dining session can exist per table at any time.
-- This is a business invariant: a table cannot have two concurrent open sessions.
-- The partial unique index only applies when status = 'open', allowing historical closed/paid sessions.

-- Safety: close any remaining duplicate open sessions before creating the unique index
-- (keep the most recent one with orders; close older duplicates)
WITH session_order_counts AS (
  SELECT
    ds.id,
    ds.table_id,
    COUNT(o.id) AS order_count,
    ROW_NUMBER() OVER (
      PARTITION BY ds.table_id
      ORDER BY COUNT(o.id) DESC, ds.opened_at DESC
    ) AS rn
  FROM pronto_dining_sessions ds
  LEFT JOIN pronto_orders o ON o.session_id = ds.id
  WHERE ds.status = 'open'
    AND ds.table_id IS NOT NULL
  GROUP BY ds.id, ds.table_id, ds.opened_at
)
UPDATE pronto_dining_sessions
SET status = 'closed',
    closed_at = NOW()
WHERE id IN (
  SELECT id FROM session_order_counts WHERE rn > 1
);

-- Create partial unique index: only one 'open' session per table_id is allowed
DROP INDEX IF EXISTS idx_dining_session_open_table;
CREATE UNIQUE INDEX idx_dining_session_open_table
  ON pronto_dining_sessions (table_id)
  WHERE status = 'open';
