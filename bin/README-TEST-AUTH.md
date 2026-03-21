# Test Authentication Bootstrap

## Propósito

Este script garantiza que todas las cuentas de prueba para empleados existan con credenciales canónicas y hashes consistentes.

## Uso Rápido

```bash
# Verificar si las cuentas están correctamente configuradas
./pronto-scripts/bin/pronto-setup-test-auth --check

# Crear o actualizar cuentas (idempotente)
./pronto-setup-test-auth --fix

# Verificar y auto-corregir si hay problemas
./pronto-setup-test-auth --verify
```

## Variables de Entorno Requeridas

El script requiere estas variables (pueden estar en `.env` o exportadas):

```bash
POSTGRES_HOST=localhost          # Database host
POSTGRES_USER=pronto             # Database user
POSTGRES_PASSWORD=pronto123      # Database password
POSTGRES_DB=pronto               # Database name
PASSWORD_HASH_SALT=<salt>        # Salt para hashing (ver .env)
HANDOFF_PEPPER=<pepper>          # Pepper para hashing (ver .env)
```

## Cuentas Canónicas

Todas las cuentas usan password: `ChangeMe!123`

| Email | Rol | Scopes Permitidos |
|-------|-----|-------------------|
| `admin.roles@cafeteria.test` | admin | admin, waiter, chef, cashier |
| `admin@cafeteria.test` | system | system, admin, waiter, chef, cashier |
| `juan.mesero@cafeteria.test` | waiter | waiter |
| `carlos.chef@cafeteria.test` | chef | chef |
| `laura.cajera@cafeteria.test` | cashier | cashier |

## Casos de Uso

### CI/CD Pipeline

```bash
# Before running tests
./pronto-scripts/bin/pronto-setup-test-auth --verify

# Run tests
cd pronto-tests
npx playwright test smoke-chaos-roles.spec.ts
python -m pytest tests/functionality/e2e/test_config_settings_roundtrip_live.py
```

### Desarrollo Local

```bash
# After fresh database setup
./pronto-scripts/bin/pronto-setup-test-auth --fix

# Verify before committing
./pronto-scripts/bin/pronto-setup-test-auth --check
```

### Entornos de Testing

```bash
# Docker environment
docker-compose exec pronto-api bash
./pronto-scripts/bin/pronto-setup-test-auth --verify
```

## Integración con Pre-Commit

Para validar cuentas antes de cada commit:

```bash
# Agregar al hook .git/hooks/pre-commit
./pronto-scripts/bin/pronto-setup-test-auth --check || {
  echo "❌ Test auth accounts not configured. Run:"
  echo "   ./pronto-scripts/bin/pronto-setup-test-auth --fix"
  exit 1
}
```

## Troubleshooting

### Error: "Missing environment variables"

Asegúrate de tener `.env` configurado o exportar las variables:

```bash
export POSTGRES_HOST=localhost
export POSTGRES_USER=pronto
# ... etc
```

### Error: "NOT FOUND" para alguna cuenta

Ejecuta con `--fix` para crear/actualizar:

```bash
./pronto-scripts/bin/pronto-setup-test-auth --fix
```

### Error: "role mismatch"

El script actualiza automáticamente el rol con `--fix`:

```bash
./pronto-scripts/bin/pronto-setup-test-auth --verify
```

## Documentación Relacionada

- [Employee Auth Flows](../../../pronto-docs/contracts/auth/employee-auth-flows.md)
- [Customer Auth Flows](../../../pronto-docs/contracts/auth/customer-auth-flows.md)
- [Test Credentials](../../../pronto-tests/.env.example)

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0779 | 2026-03-21 | Initial release |

