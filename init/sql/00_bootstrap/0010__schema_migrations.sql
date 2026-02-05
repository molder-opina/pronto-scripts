CREATE TABLE IF NOT EXISTS pronto_schema_migrations (
  file_name TEXT PRIMARY KEY,
  sha256 TEXT NOT NULL,
  sql_norm_sha TEXT NOT NULL,
  executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL CHECK (status IN ('applied','failed')),
  error TEXT NULL,
  executed_by TEXT NULL,
  app_version TEXT NULL,
  git_sha TEXT NULL,
  sql_head_sha TEXT NULL
);
