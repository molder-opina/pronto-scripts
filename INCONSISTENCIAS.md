# Inconsistencias Conocidas - Pronto Scripts

**Fecha:** 2026-02-02
**Estado:** Documentado, sin corregir (para mantener estabilidad)

---

## 1. Scripts que NO funcionarán

Los siguientes scripts usan `sys.path.insert(0, "build")` pero el directorio `build/` no existe:

| Script | Problema |
|--------|----------|
| `bin/python/create-cashier-users.py` | `build/` no existe |
| `bin/python/create-chef-user.py` | `build/` no existe |
| `bin/python/fix-employees.py` | `build/` no existe |
| `bin/python/test_auth.py` | `build/` no existe |
| `bin/python/update-credentials-jwt.py` | `build/` no existe |
| `bin/python/update-cashier-password.py` | `build/` no existe |
| `bin/python/create-test-data.py` | `build/` no existe |
| `bin/python/validate_and_seed.py` | `build/` no existe |
| `bin/python/fix-cashier-password.py` | `build/` no existe |
| `bin/python/update-all-cashiers.py` | `build/` no existe |
| `bin/python/fix-cashier-user.py` | `build/` no existe |
| `bin/python/refactor-session-to-jwt.py` | `build/` no existe |

**Solución requerida:** Crear el directorio `build/` y copiar `pronto_shared` ahí, o cambiar los imports a `from pronto_shared.*`.

---

## 2. Imports rotos

Los scripts intentan importar de `shared` que ya no existe como paquete local:

```python
from shared.security import hash_credentials, hash_identifier
from shared.jwt_service import create_client_token
from shared.serializers import success_response, error_response
from shared.db import get_session
from shared.models import Customer
from shared.config import load_config
```

**Archivos afectados:**
- `pronto-api/auth.py` (8 imports de `shared.*`)
- Todos los scripts de `bin/python/*.py` listados arriba

---

## 3. Scripts shell con rutas old

| Script | Referencia incorrecta |
|--------|----------------------|
| `bin/sync-shared-to-apps.sh` | `src/shared/static/js/` |
| `bin/init/06_initialize_areas.sh` | `src/shared/migrations/` |
| `bin/init/03_seed_params.sh` | `src/shared/services/seed.py` |
| `bin/sync-static-content.sh` | `src/shared/assets/branding/` |
| `bin/tests/validate-components.sh` | `src/shared/static/js/` |
| `bin/tests/test-jwt.sh` | `src/shared/jwt_service.py` |
| `bin/agents/deployment_agent.sh` | `src/shared/models.py` |

**Nota:** Estas rutas referencian la estructura old del monorepo. La nueva estructura tiene `pronto_shared` como package en `pronto-libs/`.

---

## 4. Estado de los Repositorios

| Repo | Estado |
|------|--------|
| `pronto-libs` | ✓ OK - Contiene `pronto_shared` package |
| `pronto-api` | ⚠️ Imports rotos en `pronto-api/auth.py` |
| `pronto-client` | ✓ OK |
| `pronto-employees` | ✓ OK |
| `pronto-scripts` | ✗ Scripts no funcionales |
| `pronto-static` | ✓ OK |
| `pronto-tests` | ✓ OK |
| `pronto-docs` | ✓ OK |
| `pronto-redis` | ✓ OK |
| `pronto-postgresql` | ✓ OK |

---

## Nota

Este documento se creó para registrar las inconsistencias sin modificar código existente, manteniendo la versión actual estable.
