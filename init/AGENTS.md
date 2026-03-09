# `pronto-scripts/init` AGENTS (alcance local)

Este documento complementa `AGENTS.md` raiz y cubre solo init/migrations/seeds.

## Autoridad y separacion

1. DDL canonico vive exclusivamente en `pronto-scripts/init/sql/**`.
2. Separacion obligatoria:
   - Init idempotente: `00_bootstrap..40_seeds` (sin `ALTER/RENAME/backfills`).
   - Evolutivo: `sql/migrations/` (`ALTER/RENAME/backfills/seed changes`).
3. Prohibido DDL runtime en `pronto-api/`, `pronto-client/`, `pronto-employees/`, `pronto-libs/src/`.

## Tipos y rutas

1. Entidades principales usan UUID.
2. En Flask routes usar converters explicitos:
   - UUID: `<uuid:...>`
   - Integer solo en allowlist tecnica (areas, roles, discount_codes, promotions, product_schedules, waiter_calls, notifications, admin_shortcuts).
3. Prohibido `<str:id>` para IDs de dominio.

## Operacion obligatoria (pre-commit)

1. `./pronto-scripts/bin/pronto-migrate --check`
2. `./pronto-scripts/bin/pronto-init --check`
3. `./pronto-scripts/bin/pronto-init-seed-review.sh`

## Reglas de seguridad de datos

1. Prohibido `DROP`/`TRUNCATE` fuera de excepciones permitidas en root AGENTS.
2. No tocar `pronto-postgresql` ni `pronto-redis` sin orden explicita.
3. Seeds/migrations deben ser idempotentes y trazables.
