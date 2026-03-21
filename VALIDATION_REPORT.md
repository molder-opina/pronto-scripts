# PRONTO Validation System — Architecture Guardrails Report

**Fecha:** 2026-03-20  
**Estado:** ✅ **0 VIOLACIONES** — Sistema validado y consistente  
**Validador:** AST-based layering checker (resolución por path físico)

---

## 🎯 ESTADO FINAL

| Métrica | Inicio | Final | Reducción |
|---------|--------|-------|-----------|
| **Total violaciones** | 200 | **0** | **100%** |
| **libs** | 13 | **0** | ✅ |
| **client** | 1 | **0** | ✅ |
| **employees** | 2 | **0** | ✅ |
| **scripts** | 179 | **0** | ✅ |
| **forbidden** | 8 | **0** | ✅ |
| **syntax errors** | 3 | **0** | ✅ |

**Archivos verificados:** 437  
**Capas:** 6 (api, client, employees, static, libs, scripts)

---

## 🔒 REGLAS ARQUITECTÓNICAS (P0 — BLOQUEANTES)

### 🔴 PROHIBIDO (VIOLACIÓN = REJECTED)

1. **UI → DB directo**
   - `pronto-client`, `pronto-employees` NO pueden inicializar DB
   - `pronto-client`, `pronto-employees` NO pueden ejecutar queries directas
   - ✅ Única vía: `UI → API → DB`

2. **UI → services de negocio**
   - `pronto-client`, `pronto-employees` NO pueden importar `pronto_shared.services.*`
   - ✅ Única vía: `UI → API (HTTP) → services`

3. **libs → capas externas**
   - `pronto-libs` NO puede importar de `api`, `client`, `employees`, `static`
   - ✅ libs es dominio puro, sin dependencias externas

4. **Acceso a secretos fuera de API**
   - `pronto-client`, `pronto-employees` NO pueden cargar secretos
   - ✅ Solo API tiene acceso a `secret_service`

5. **flask.session en empleados**
   - `pronto-employees` debe usar JWT (inmutable)
   - ✅ Excepción única: `pronto-client` (solo `customer_ref`, `dining_session_id`)

---

### 🟢 PERMITIDO (EXPLÍCITO)

**client/employees → libs SÍ puede importar:**

| Categoría | Ejemplos | Justificación |
|-----------|----------|---------------|
| DTOs / Schemas | `pronto_shared.models.*` | Data shapes, sin lógica |
| Enums / Constants | `pronto_shared.constants.OrderStatus` | Valores canónicos |
| Infraestructura | `logging`, `error_handlers`, `security_middleware` | Cross-cutting concerns |
| Utils puros | `input_sanitizer`, `money_utils` | Lógica sin efectos secundarios |
| i18n | `pronto_shared.i18n.service` | Configuración de locale |

**NO puede importar:**

| Categoría | Ejemplos | Razón |
|-----------|----------|-------|
| Services de negocio | `payment_service`, `order_state_machine` | Ejecución de dominio |
| DB access | `get_session()`, `SystemSetting` | Autoridad de API |
| Settings | `settings_service.get_setting()` | Autoridad de API |
| Secrets | `secret_service` | Autoridad de API |

---

### 🟡 ZONA GRIS (REQUIERE REVISIÓN)

Estos casos requieren validación arquitectónica antes de permitir:

| Caso | Decisión | Notas |
|------|----------|-------|
| `config loaders` | ✅ Permitido | Solo lectura, sin side-effects |
| `i18n service` | ✅ Permitido | Configuración de locale, sin DB |
| `Redis client` | ⚠️ Revisar | Solo para cache, NO para estado de negocio |
| `JWT service` | ⚠️ Revisar | Solo para decodificación, NO para creación |

---

## 🧠 PRINCIPIOS CANÓNICOS

> **UI nunca ejecuta dominio**

`pronto-client` y `pronto-employees` son SSR/UI. Toda lógica de negocio debe residir en `pronto-api`.

---

> **API es la única autoridad de negocio**

Solo `pronto-api` en `:6082` puede:
- Ejecutar services de negocio
- Acceder a DB directamente
- Cargar secretos
- Modificar settings de sistema

---

> **libs es dominio puro, sin dependencias externas**

`pronto-libs` contiene:
- ✅ Domain models
- ✅ State machines
- ✅ Business rules
- ✅ Pure services (sin IO)

NO contiene:
- ❌ HTTP requests
- ❌ DB access directo (usa session injection)
- ❌ UI-specific logic

---

> **Settings debe venir de API**

UI NO accede a DB para settings. Patrón correcto:

```python
# ❌ INCORRECTO (UI → DB)
from pronto_shared.services.settings_service import get_setting
value = get_setting("currency_code", "MXN")

# ✅ CORRECTO (UI → API → DB)
# En startup:
settings_cache = requests.get(f"{API_BASE}/api/settings/public").json()

# En request:
value = settings_cache.get("currency_code", "MXN")
```

---

## 🛠️ VALIDATION SYSTEM (RESUMEN TÉCNICO)

### Implementación

| Componente | Ubicación | Propósito |
|------------|-----------|-----------|
| `core.py` | `pronto-scripts/lib/validation/` | Evidence, ValidationResult, ValidationEngine |
| `layering.py` | `pronto-scripts/lib/validation/` | AST parser, resolución por path físico |
| `invariants.py` | `pronto-scripts/lib/validation/` | 19 invariantes SQL de negocio |
| `drift.py` | `pronto-scripts/lib/validation/` | Baseline tracking, diff detection |
| `complexity.py` | `pronto-scripts/lib/validation/` | +30% lines, new layers |

### CLI Tools

| Herramienta | Propósito | Exit code |
|-------------|-----------|-----------|
| `pronto-validate` | Orquestador maestro | 0=PASSED, 1=FAILED |
| `pronto-layering-check` | AST layering validator | 0=OK, 1=VIOLATIONS |
| `pronto-invariant-check` | SQL invariant validator | 0=OK, 1=VIOLATIONS |
| `pronto-drift-detect` | Import drift detector | 0=OK, 2=DRIFT |
| `pronto-isolation-test` | P9-002 isolation test | 0=OK, 1=HIDDEN_DEPS |

### Validación Técnica

**AST-based (no regex):**
- Resuelve imports a paths físicos reales
- No string matching (`"client" in "redis_client"` = BUG)
- Cachea resoluciones para performance

**Evidencia obligatoria:**
- stdout, stderr, return_code
- match_count, row_count, file_count
- raw_output, diff_output

**Exclusión de directorios:**
```python
excluded_dirs = {
    "__pycache__", "venv", ".venv", "node_modules",
    ".git", "build", "dist", ".eggs", "*.egg-info",
}
```

---

## 🚨 FAILURE MODES (DETECCIÓN DE REGRESIONES)

### Si vuelve a aparecer:

| Síntoma | Causa Probable | Acción |
|---------|----------------|--------|
| `"client" in "redis_client"` | BUG en layering checker | Fix línea 179 de `layering.py` |
| `libs > 0` | VIOLACIÓN CRÍTICA | Revertir commit, investigar |
| `client usando services` | MAL DISEÑO | Refactorizar a API → HTTP |
| `forbidden imports > 0` | flask.session, legacy | Eliminar inmediatamente |
| `syntax_error > 0` | Archivos corruptos | Corregir sintaxis Python |

### Comandos de validación rápida

```bash
# Validar todo el proyecto
./pronto-scripts/bin/pronto-layering-check --full

# Validar archivo específico
./pronto-scripts/bin/pronto-layering-check --files <archivo.py>

# Validar cambios staged
./pronto-scripts/bin/pronto-validate --staged

# Validar invariantes DB (requiere POSTGRES_HOST)
./pronto-scripts/bin/pronto-invariant-check
```

---

## 🔁 ENFORCEMENT (OBLIGATORIO)

### Pre-commit Hook

```bash
# .git/hooks/pre-commit
./pronto-scripts/bin/pronto-validate --staged --mode enforce

# Exit code 1 = REJECTED (no commit)
# Exit code 0 = APPROVED
```

### CI/CD Pipeline

```yaml
# .github/workflows/validation.yml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - run: ./pronto-scripts/bin/pronto-layering-check --full
        # Fail si violations > 0
```

### Regla de Merge

> **No se permite merge con violaciones > 0**

Pull requests deben pasar:
- ✅ `pronto-layering-check --full` (0 violaciones)
- ✅ `pronto-invariant-check` (si DB disponible)
- ✅ `pronto-drift-detect` (sin drift no aprobado)

---

## 📖 REFERENCIAS

| Documento | Propósito |
|-----------|-----------|
| `AGENTS.md` | Arquitectura canónica, guardrails P0 |
| `pronto-docs/standards/validation-system.md` | Guía de uso del sistema |
| `pronto-docs/contracts/` | Contratos entre servicios |
| `pronto-scripts/LAYERING_FIX_PLAN.md` | Plan de remediación aplicado |

---

## 🧭 PRÓXIMO NIVEL (OPCIONAL)

Estas mejoras son futuras, no bloqueantes:

| Mejora | Propósito | Prioridad |
|--------|-----------|-----------|
| CI/CD enforcement | GitHub Actions que falle duro | Alta |
| Dashboard de salud | Trend de violaciones en tiempo | Media |
| Auto-fix para casos simples | Scripts que sugieren fixes | Media |
| Reglas más estrictas | Bloquear services en UI | Baja |

---

## 🧠 LECCIÓN CRÍTICA

> **Validación incorrecta = arquitectura degradada**

Un checker que miente es peor que no tener checker.

**Porque:**
- Optimizás lo incorrecto
- Perdés confianza en el sistema
- No detectás problemas reales

**Este sistema ahora:**
- ✅ Dice la verdad (0 falsos positivos)
- ✅ Es ejecutable (CLI tools)
- ✅ Es enforceable (pre-commit, CI)
- ✅ Es mantenible (documentado, automatizado)

---

**Fin del reporte.**

*Documento generado: 2026-03-20*  
*Validador: pronto-layering-check v1.0.0*  
*Estado: 0 violaciones — Sistema consistente*
