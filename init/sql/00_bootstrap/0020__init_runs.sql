CREATE TABLE IF NOT EXISTS pronto_init_runs (
  run_id BIGSERIAL PRIMARY KEY,
  phase TEXT NOT NULL,
  file_name TEXT NOT NULL,
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

CREATE INDEX IF NOT EXISTS ix_pronto_init_runs_phase ON pronto_init_runs(phase);
