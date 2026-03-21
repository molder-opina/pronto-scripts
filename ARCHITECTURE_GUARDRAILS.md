# PRONTO Architecture Guardrails

**Versión:** 1.0.0  
**Fecha:** 2026-03-20  
**Estado:** ✅ **ENFORCED** — Validación automática habilitada  
**Validador:** `pronto-layering-check`, `pronto-validate`, `pronto-invariant-check`

---

## 🎯 PROPÓSITO

Este documento **no es guía, es contrato**.

Cada regla aquí es:
- ✅ **Verificable automáticamente**
- ✅ **Bloqueante si se viola**
- ✅ **No negociable**

Si no se puede validar → no es guardrail, es opinión.

---

## 🔴 P0 — REGLAS BLOQUEANTES (NO NEGOCIABLES)

Violación = **REJECTED** (falla build, falla CI, falla merge)

---

### P0-001 — UI No Accede a DB

```yaml
RULE_ID: P0-001
SEVERITY: BLOCKING
DESCRIPTION: UI layers (client, employees) MUST NOT initialize or access database directly
ENFORCED_BY: pronto-layering-check, pronto-validate
VIOLATION_ACTION: FAIL BUILD
CHECK:
  - pronto-client/src/**/*.py NO importa pronto_shared.db.init_engine
  - pronto-employees/src/**/*.py NO importa pronto_shared.db.get_session
  - pronto-client/src/**/*.py NO importa pronto_shared.services.*_service
EXCEPTIONS: NONE
RATIONALE:
  Single source of truth for data access is API (:6082)
  UI → API → DB (never UI → DB)
```

**Validación:**
```bash
./pronto-scripts/bin/pronto-layering-check --files pronto-client/
./pronto-scripts/bin/pronto-layering-check --files pronto-employees/
```

---

### P0-002 — UI No Ejecuta Dominio

```yaml
RULE_ID: P0-002
SEVERITY: BLOCKING
DESCRIPTION: UI MUST NOT import or execute business logic from libs
ENFORCED_BY: pronto-layering-check
VIOLATION_ACTION: FAIL BUILD
CHECK:
  - pronto-client NO importa pronto_shared.services.* (except utils puros)
  - pronto-employees NO importa pronto_shared.services.* (except utils puros)
  - UI → API (HTTP) → services (never UI → services directo)
PERMITTED_IMPORTS:
  - pronto_shared.models.* (DTOs, schemas)
  - pronto_shared.constants.* (enums, constants)
  - pronto_shared.utils.* (pure functions, no side-effects)
  - pronto_shared.i18n.* (locale config only)
FORBIDDEN_IMPORTS:
  - pronto_shared.services.payment_service
  - pronto_shared.services.order_state_machine
  - pronto_shared.services.settings_service
  - pronto_shared.services.secret_service
EXCEPTIONS: NONE
RATIONALE:
  Business logic execution authority is API only
  UI is for rendering and user interaction
```

**Validación:**
```bash
./pronto-scripts/bin/pronto-layering-check --full
```

---

### P0-003 — Libs Es Pura (Sin Dependencias Externas)

```yaml
RULE_ID: P0-003
SEVERITY: BLOCKING
DESCRIPTION: libs MUST NOT depend on any other layer (api, client, employees, static)
ENFORCED_BY: pronto-layering-check
VIOLATION_ACTION: FAIL BUILD
CHECK:
  - pronto-libs/src/**/*.py NO importa pronto_api.*
  - pronto-libs/src/**/*.py NO importa pronto_clients.*
  - pronto-libs/src/**/*.py NO importa pronto_employees.*
  - pronto-libs/src/**/*.py NO importa pronto_static.*
EXCEPTIONS: NONE
RATIONALE:
  libs is domain core - must remain independent
  Dependency direction: apps → libs (never libs → apps)
```

**Validación:**
```bash
./pronto-scripts/bin/pronto-layering-check --files pronto-libs/
```

---

### P0-004 — Secretos Solo en API

```yaml
RULE_ID: P0-004
SEVERITY: BLOCKING
DESCRIPTION: Secrets access is restricted to API layer only
ENFORCED_BY: pronto-layering-check, pronto-invariant-check
VIOLATION_ACTION: FAIL BUILD
CHECK:
  - pronto-client NO importa pronto_shared.services.secret_service
  - pronto-employees NO importa pronto_shared.services.secret_service
  - pronto-scripts NO importa pronto_shared.services.secret_service (except infra scripts)
EXCEPTIONS:
  - pronto-scripts/infra/ (deploy scripts con acceso controlado)
RATIONALE:
  Secrets must be centralized and audited
  API is the only layer with secrets authority
```

**Validación:**
```bash
rg "secret_service" pronto-client/ pronto-employees/ --type py
# Debe retornar 0 matches
```

---

### P0-005 — Layering Enforcement

```yaml
RULE_ID: P0-005
SEVERITY: BLOCKING
DESCRIPTION: Cross-layer imports MUST respect PRONTO_LAYERS rules
ENFORCED_BY: pronto-layering-check
VIOLATION_ACTION: FAIL BUILD
LAYERS:
  api:
    path: pronto-api/src/api_app
    can_import: [libs]
  client:
    path: pronto-client/src/pronto_clients
    can_import: [libs]  # infraestructura compartida ONLY
  employees:
    path: pronto-employees/src/pronto_employees
    can_import: [libs]  # infraestructura compartida ONLY
  static:
    path: pronto-static/src/vue
    can_import: []  # NO imports Python
  libs:
    path: pronto-libs/src/pronto_shared
    can_import: [libs]  # internal only
  scripts:
    path: pronto-scripts
    can_import: [libs]
EXCEPTIONS: NONE
RATIONALE:
  Clear architectural boundaries prevent degradation
  Automated enforcement ensures consistency
```

**Validación:**
```bash
./pronto-scripts/bin/pronto-layering-check --full
# Exit code 0 = PASSED
# Exit code 1 = FAILED (violations > 0)
```

---

### P0-006 — No Flask Session en Empleados

```yaml
RULE_ID: P0-006
SEVERITY: BLOCKING
DESCRIPTION: Employee authentication MUST use JWT (immutable), not flask.session
ENFORCED_BY: pronto-layering-check, pronto-validate
VIOLATION_ACTION: FAIL BUILD
CHECK:
  - pronto-employees NO usa flask.session para auth
  - pronto-employees usa JWT tokens (create_access_token, jwt_required)
EXCEPTIONS:
  - pronto-client PUEDE usar session SOLO para:
    - customer_ref
    - dining_session_id
RATIONALE:
  JWT is stateless, auditable, and secure
  flask.session is prohibited for employee auth (AGENTS.md P0.5)
```

**Validación:**
```bash
rg "flask\.session|from flask import session" pronto-employees/ --type py
# Debe retornar 0 matches (excluyendo comentarios)
```

---

### P0-007 — Settings Viene de API

```yaml
RULE_ID: P0-007
SEVERITY: BLOCKING
DESCRIPTION: Settings must be loaded from API, not direct DB access
ENFORCED_BY: pronto-layering-check
VIOLATION_ACTION: FAIL BUILD
CHECK:
  - pronto-client NO importa pronto_shared.services.settings_service
  - pronto-client NO llama get_setting() directo
  - pronto-client usa API endpoint /api/settings/public
EXCEPTIONS: NONE
RATIONALE:
  Settings are configuration data with DB backing
  API controls caching, validation, and access control
```

**Patrón Correcto:**
```python
# ✅ CORRECTO
# En startup:
settings_cache = requests.get(f"{API_BASE}/api/settings/public").json()

# En request:
value = settings_cache.get("currency_code", "MXN")

# ❌ INCORRECTO
from pronto_shared.services.settings_service import get_setting
value = get_setting("currency_code", "MXN")
```

---

### P0-008 — No Forbidden Imports

```yaml
RULE_ID: P0-008
SEVERITY: BLOCKING
DESCRIPTION: Forbidden imports are prohibited in all layers
ENFORCED_BY: pronto-layering-check
VIOLATION_ACTION: FAIL BUILD
FORBIDDEN:
  - flask.session (except pronto-client allowlist)
  - legacy_mysql
  - callbacks (SQLAlchemy deprecated)
EXCEPTIONS: NONE
RATIONALE:
  These are deprecated/legacy patterns that degrade architecture
```

**Validación:**
```bash
rg "flask\.session|legacy_mysql|callbacks" pronto-*/src/ --type py
# Debe retornar 0 matches (excluyendo comentarios y checker mismo)
```

---

## 🟡 P1 — REGLAS FUERTES (WARNINGS, NO BLOQUEANTES)

Violación = **WARNING** (se registra, no falla build)

---

### P1-001 — Config Loaders

```yaml
RULE_ID: P1-001
SEVERITY: WARNING
DESCRIPTION: Config loaders should be read-only, no side-effects
ENFORCED_BY: pronto-validate
VIOLATION_ACTION: WARNING + REVIEW
CHECK:
  - config loaders NO modifican DB
  - config loaders NO tienen side-effects
RATIONALE:
  Config loading should be pure function
  Side-effects belong in initialization, not config
```

---

### P1-002 — i18n Usage

```yaml
RULE_ID: P1-002
SEVERITY: WARNING
DESCRIPTION: i18n service should only set locale, not load from DB per-request
ENFORCED_BY: pronto-layering-check
VIOLATION_ACTION: WARNING + REVIEW
CHECK:
  - i18n.set_locale() se llama en startup o before_request
  - NO se llama get_setting() en cada request para i18n
RATIONALE:
  Per-request DB calls for locale cause performance issues
  Cache settings at startup
```

---

### P1-003 — Cross-Cutting Services

```yaml
RULE_ID: P1-003
SEVERITY: WARNING
DESCRIPTION: Cross-cutting services (logging, security) should be in libs, not duplicated
ENFORCED_BY: pronto-drift-detect
VIOLATION_ACTION: WARNING + DEDUPLICATION
CHECK:
  - logging_config NO está duplicado en múltiples capas
  - security_middleware NO está duplicado
RATIONALE:
  Duplication leads to inconsistency and maintenance burden
  Shared infrastructure belongs in libs
```

---

## 🧠 DECISION RECORDS (DR)

Decisiones arquitectónicas documentadas. No se pueden revertir sin revisar este doc.

---

### DR-001 — Client/Employees Pueden Importar Infra de Libs

```yaml
DECISION_ID: DR-001
DATE: 2026-03-20
STATUS: ACCEPTED
CONTEXT:
  UI layers need cross-cutting concerns (logging, error handlers, security)
  Duplicating these in each layer leads to inconsistency

DECISION:
  client/employees PUEDEN importar de libs:
  - logging_config
  - error_handlers
  - security_middleware
  - input_sanitizer
  - i18n.service

CONSTRAINTS:
  - NO business logic services
  - NO DB access
  - NO settings_service

CONSEQUENCES:
  - Consistent logging across layers
  - Single source of truth for infrastructure
  - Must enforce boundary (libs → no business logic for UI)

REVIEW_DATE: 2026-09-20
```

---

### DR-002 — Settings via API, Not Direct DB

```yaml
DECISION_ID: DR-002
DATE: 2026-03-20
STATUS: ACCEPTED
CONTEXT:
  Client was accessing settings via get_setting() → DB direct
  This violated UI → API → DB pattern
  Caused performance issues (DB calls per-request)

DECISION:
  Settings MUST come from API endpoint /api/settings/public
  Client caches at startup, uses cache for all requests

CONSTRAINTS:
  - API endpoint must be fast (Redis cached)
  - Client must handle API failure gracefully (defaults)
  - Settings must be loaded once at startup

CONSEQUENCES:
  - Performance: 1 API call at startup vs N DB calls per-request
  - Consistency: All settings go through API auth/validation
  - Decoupling: Client doesn't need DB connection

REVIEW_DATE: 2026-09-20
```

---

### DR-003 — Exclude venv from Layering Check

```yaml
DECISION_ID: DR-003
DATE: 2026-03-20
STATUS: ACCEPTED
CONTEXT:
  Layering checker was scanning venv/ directories
  Caused 8 false positive "forbidden" violations (third-party libs)
  Wasted time and reduced trust in checker

DECISION:
  Exclude these directories from layering check:
  - venv/, .venv/
  - node_modules/
  - __pycache__/
  - .git/
  - build/, dist/
  - *.egg-info/

CONSTRAINTS:
  - Must not exclude actual project code
  - Must be configurable if needed

CONSEQUENCES:
  - Accurate violation counts (no false positives)
  - Faster check execution
  - Maintained trust in validation system

REVIEW_DATE: 2027-03-20
```

---

## 🔧 MAPEADO A VALIDACIONES

Cada regla debe ser enforceable. Este es el mapeo:

| Regla | Validator | Command | Exit Code |
|-------|-----------|---------|-----------|
| P0-001 | pronto-layering-check | `--files pronto-client/` | 0=OK, 1=FAIL |
| P0-002 | pronto-layering-check | `--full` | 0=OK, 1=FAIL |
| P0-003 | pronto-layering-check | `--files pronto-libs/` | 0=OK, 1=FAIL |
| P0-004 | pronto-layering-check | `--full` + grep | 0=OK, 1=FAIL |
| P0-005 | pronto-layering-check | `--full` | 0=OK, 1=FAIL |
| P0-006 | pronto-validate | `--staged` | 0=OK, 1=FAIL |
| P0-007 | pronto-layering-check | `--files pronto-client/` | 0=OK, 1=FAIL |
| P0-008 | pronto-layering-check | `--full` | 0=OK, 1=FAIL |
| P1-001 | pronto-validate | `--staged` | Warning only |
| P1-002 | pronto-layering-check | `--full` | Warning only |
| P1-003 | pronto-drift-detect | `--changed` | Warning only |

---

## 🚨 QUÉ HACER CUANDO FALLA

### Si P0 Rule Fails:

```bash
1. STOP — No hacer commit, no hacer merge
2. DO NOT PATCH — No añadir excepciones "temporales"
3. Identify root cause:
   - ¿Es violación real? → Fix arquitectónico
   - ¿Es bug en checker? → Fix checker (prioridad alta)
   - ¿Es falso positivo? → Excluir directorio (venv, etc.)
4. Fix at architecture level:
   - Mover código a capa correcta
   - Refactorizar a patrón permitido
   - Actualizar Decision Record si cambia arquitectura
5. Re-run validation:
   ./pronto-scripts/bin/pronto-layering-check --full
6. Commit solo si violations = 0
```

### Si P1 Rule Fails:

```bash
1. Log warning en PR description
2. Evaluar impacto:
   - ¿Es performance crítico? → Fix ahora
   - ¿Es deuda técnica menor? → Crear ticket, fix en sprint siguiente
3. Documentar en Decision Record si se acepta excepción
```

---

## 🔁 ENFORCEMENT AUTOMÁTICO

### Baseline Protection (CRÍTICO)

> **Baseline NUNCA se modifica automáticamente en CI**

```bash
# CI environment (GitHub Actions, etc.)
export CI=true
export PRONTO_BASELINE_READONLY=1

# Intentar modificar baseline en CI → ERROR
./pronto-scripts/bin/pronto-drift-detect --save-baseline
# ❌ ERROR: Baseline modification prohibited in CI

# Correcto: modificar baseline LOCALMENTE
./pronto-scripts/bin/pronto-drift-detect --save-baseline
git add pronto-scripts/.validation-baseline/baseline-imports.json
git commit -m "Update validation baseline"
git push
```

**Protecciones:**

| Protección | Implementación |
|------------|----------------|
| CI detection | `os.getenv("CI")` check |
| Env var lock | `PRONTO_BASELINE_READONLY=1` |
| Force flag | `--force-baseline-update` (solo local) |
| Audit trail | Baseline changes require explicit commit |

---

### Regression Tests (ANTI-REGRESIÓN)

> **Todo bug arquitectónico se convierte en test permanente**

```bash
# Ejecutar tests del checker
cd pronto-scripts
python3 -m pytest tests/test_layering_checker.py -v
```

**Tests críticos:**

| Test | Bug Previene |
|------|--------------|
| `test_no_false_positive_redis_client` | `"client" in "redis_client"` |
| `test_no_false_positive_internal_auth` | `"auth" in "internal_auth"` |
| `test_detects_real_cross_layer_violation` | Falsos negativos |
| `test_external_imports_return_none` | Imports externos marcados como violación |

---

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -euo pipefail

echo "Running architecture guardrails validation..."

./pronto-scripts/bin/pronto-validate --staged --mode enforce

exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "❌ Architecture guardrails violated"
  echo "Fix violations before commit"
  exit 1
fi

echo "✅ Architecture guardrails passed"
exit 0
```

### CI/CD Pipeline

```yaml
# .github/workflows/validation.yml
name: Architecture Guardrails

on: [push, pull_request]

env:
  # CRITICAL: Prevent baseline modification in CI
  PRONTO_BASELINE_READONLY: "1"

jobs:
  guardrails:
    name: Validation Suite
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Run layering check
        run: |
          ./pronto-scripts/bin/pronto-layering-check --full
          # Exit 1 if violations > 0 (BLOCKS MERGE)
      
      - name: Run validation
        run: |
          ./pronto-scripts/bin/pronto-validate --changed
          # Exit 1 = FAIL (blocks merge)
      
      - name: Run checker tests (anti-regression)
        run: |
          cd pronto-scripts
          python3 -m pytest tests/test_layering_checker.py -v
          # Ensures checker bugs don't regress
      
      - name: Run invariant check
        run: |
          ./pronto-scripts/bin/pronto-invariant-check
        env:
          POSTGRES_HOST: ${{ secrets.DB_HOST }}
          POSTGRES_PORT: 5432
          POSTGRES_DB: ${{ secrets.DB_NAME }}
          POSTGRES_USER: ${{ secrets.DB_USER }}
          POSTGRES_PASSWORD: ${{ secrets.DB_PASSWORD }}
        continue-on-error: true  # DB may not be available
      
      - name: Run drift check
        run: |
          ./pronto-scripts/bin/pronto-drift-detect --changed
          # Exit 0 = OK, 2 = WARNING (drift detected but approved)
        continue-on-error: true  # Warnings don't block
```

### Merge Block

> **No se permite merge con violations P0 > 0**

GitHub PR checks deben incluir:
- ✅ `pronto-layering-check --full` (0 violations)
- ✅ `pronto-validate --staged` (0 failures)

---

## 📊 HEALTH SCORING (OPCIONAL)

Métrica de salud arquitectónica:

```bash
# Architecture Health Score (0-100)
score = 100 - (violations * 5) - (warnings * 1)

# Ejemplo:
# 0 violations, 0 warnings = 100 (perfect)
# 0 violations, 3 warnings = 97 (excellent)
# 1 violation, 0 warnings = 95 (good, needs fix)
# 5 violations, 0 warnings = 75 (degraded, action required)
# 20 violations, 0 warnings = 0 (critical, blocked)
```

---

## 🧭 PRÓXIMO NIVEL (OPCIONAL)

Estas mejoras son futuras, no bloqueantes:

| Mejora | Propósito | Esfuerzo |
|--------|-----------|----------|
| `--strict-mode` | Fail hasta por warnings | Bajo |
| Baseline drift blocking | Fail si baseline cambia sin approval | Medio |
| PR comments automáticos | Comentar violaciones en código | Medio |
| Architecture dashboard | Trend de violations en tiempo | Alto |
| Auto-fix suggestions | Sugerir fixes automáticos | Alto |

---

## 📖 REFERENCIAS

| Documento | Propósito |
|-----------|-----------|
| `AGENTS.md` | Arquitectura canónica, reglas P0 |
| `VALIDATION_REPORT.md` | Estado del sistema, métricas |
| `pronto-docs/standards/validation-system.md` | Guía de uso |
| `pronto-docs/contracts/` | Contratos entre servicios |

---

**Fin del documento.**

*Documento generado: 2026-03-20*  
*Versión: 1.0.0*  
*Estado: ENFORCED*  
*Validador: pronto-layering-check v1.0.0*

---

## 🧠 NOTA FINAL

> **Este documento no protege la arquitectura por sí solo.**

Lo que la protege es:

1. ✅ **Validación automática** (no confianza)
2. ✅ **Enforcement duro** (no excepciones)
3. ✅ **Decisiones documentadas** (no memoria)
4. ✅ **Failure modes claros** (no ambigüedad)

**Si no se ejecuta → no existe.**

---

*Última actualización: 2026-03-20*  
*Próxima revisión: 2026-09-20*
