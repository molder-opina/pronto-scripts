# pronto-scripts/init

## Principios
- Fuente unica de DDL: pronto-scripts/init/**
- Init (00..40) = creacion base idempotente (sin ALTER/RENAME/backfills)
- Migrations = TODO cambio evolutivo (ALTER/RENAME/backfills/seed changes)
- DROP INDEX IF EXISTS permitido SOLO en sql/migrations/

## Orden canonico
00_bootstrap
10_schema
20_constraints
30_indexes
40_seeds
migrations

## Normalizacion SQL (sql_norm_sha)
sql_norm_sha = sha256(sql_sin_comentarios + colapsar_whitespace + trim)
- remover comentarios: `-- ...` y `/* ... */`
- strip por linea
- colapsar whitespace a un espacio
- trim final

## Deploy pre-boot (obligatorio)
./pronto-scripts/bin/pronto-migrate --apply
./pronto-scripts/bin/pronto-init --check
