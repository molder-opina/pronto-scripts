# Inicialización de entorno

Scripts para preparar un nuevo despliegue con variables de ambiente, sincronización de parámetros y seed opcional.

## Flujo

1. `01_backup_envs.sh` → crea backup con timestamp.
2. `02_apply_envs.sh` → actualiza `.env`.
3. `03_seed_params.sh` → sincroniza env → DB y carga dummy opcional.
4. `04_deploy.sh` → compila y despliega.

## Uso interactivo

```bash
bash bin/init/init.sh --business-name "Mi Negocio" --restaurant-slug "mi-negocio" --dummy-data
```

## Uso silencioso

```bash
bash bin/init/init.sh --non-interactive --yes \
  --business-name "Mi Negocio" \
  --restaurant-slug "mi-negocio" \
  --set TAX_RATE=0.16 \
  --general-env /ruta/.env \
  --dummy-data
  --skip-build
  --skip-migrations
  --rollback-migrations
  --force-rollback
  --non-interactive
  --yes
```

## Migraciones

- Crear tabla de secretos: `build/shared/migrations/009_add_pronto_secrets.sql`
- Rollback: `build/shared/migrations/009_add_pronto_secrets_rollback.sql`
- Ejecuta automático en `bin/init/03_seed_params.sh` (usa `--skip-migrations`, `--rollback-migrations` o `--force-rollback`)
- `bin/init/05_apply_migrations.sh` acepta `--force-rollback` para aplicar el rollback sin prompt

## Rollback rápido

```bash
bash bin/init/init.sh --rollback-migrations --force-rollback --skip-build --non-interactive
```

## Solo migración

```bash
bash bin/init/05_apply_migrations.sh build/shared/migrations/009_add_pronto_secrets.sql
```

## Solo seed/sync

```bash
bash bin/init/03_seed_params.sh --dummy-data
```

## Allowlist opcional

- `ENV_ALLOWLIST` (separada por comas)
