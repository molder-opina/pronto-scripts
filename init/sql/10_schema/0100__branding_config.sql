CREATE TABLE IF NOT EXISTS branding_config (
  id         integer PRIMARY KEY,
  config     jsonb NOT NULL DEFAULT '{}'::jsonb,
  logo_bytes bytea NULL,
  logo_mime  text NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
