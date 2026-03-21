# Plan de Remediación - Big Bang Controlado

**Fecha:** 2026-03-20  
**Fecha Actualización:** 2026-03-20 (Estrategia revisada)  
**Total Violaciones:** 200  
**Enfoque:** Restaurar autoridad arquitectónica, no solo "arreglar imports"

---

## ⚠️ ADVERTENCIA CRÍTICA

> **Un Big Bang sin control rompe contratos invisibles, introduce bugs silenciosos, y te deja con algo "más limpio" pero menos funcional.**

**Regla de oro:** No avanzar si `layering-check` no muestra mejora.

---

## 🎯 OBJETIVO REAL

No es "arreglar 200 imports"

Es: **restaurar autoridad arquitectónica**

---

## 🧱 ARQUITECTURA CANÓNICA

```
┌─────────────────────────────────────────┐
│         client / static (UI)            │  ← Solo HTTP, sin imports de backend
├─────────────────────────────────────────┤
│      api / employees (interfaces)       │  ← Contratos, sin importar static
├─────────────────────────────────────────┤
│         libs (domain core)              │  ← CERO imports hacia arriba
└─────────────────────────────────────────┘

scripts → tools de infraestructura (no capa fantasma)
```

### Prohibiciones Duras

| Desde | Hacia | Estado |
|-------|-------|--------|
| libs | client/api/static | ❌ PROHIBIDO |
| api | static | ❌ PROHIBIDO |
| client | api directo | ❌ Solo HTTP |
| scripts | todo sin control | ❌ Clasificar por tipo |

---

## 📋 FASES (ORDEN CORRECTO)

### 🔴 FASE 1 — LIMPIAR LIBS (PRIORIDAD ABSOLUTA)

**Violaciones:** 13  
**Tiempo:** 4-6 horas  
**Riesgo:** Medium

**Por qué primero:** Si libs está contaminado, todo lo que toque se contamina.

#### Archivos Críticos

```
pronto-libs/src/pronto_shared/jwt_service.py:18
pronto-libs/src/pronto_shared/internal_auth.py:115
pronto-libs/src/pronto_shared/services/order_state_machine_core.py:293
pronto-libs/src/pronto_shared/services/settings_service.py:12
pronto-libs/src/pronto_shared/services/waiter_calls_impl.py:17
```

#### Patrón de Solución

```python
# ❌ ANTES (libs → client)
from pronto_clients.src.pronto_clients.types import OrderStatus

# ✅ DESPUÉS
# Opción A: Mover tipos a libs
from pronto_shared.constants import OrderStatus

# Opción B: Usar tipos nativos / strings
def transition_to(order_id: str, new_status: str) -> bool:
    if new_status not in OrderStatus.VALID_STATUSES:
        raise ValueError(...)
```

#### Invariante a Mantener

> **Durante toda la Fase 1: `pronto-invariant-check` debe seguir pasando**

Si falla → estás rompiendo lógica de negocio, no limpiando.

#### Validación

```bash
# Después de cada archivo fixeado
./pronto-scripts/bin/pronto-layering-check --files pronto-libs/src/pronto_shared/jwt_service.py

# Ver progreso
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "libs:"
```

**Meta:** `libs: 13` → `libs: 0`

---

### 🟠 FASE 2 — CORTAR api → static

**Violaciones:** 2  
**Tiempo:** 2-3 horas  
**Riesgo:** Low

#### Archivos

```
pronto-api/src/api_app/app.py:25
pronto-api/src/api_app/routes/employees/admin.py:16
```

#### Patrón de Solución

```python
# ❌ ANTES (api → static)
from pronto_static.src.vue.employees import DASHBOARD_URL

# ✅ DESPUÉS
# Opción A: Configuración
DASHBOARD_URL = os.getenv('DASHBOARD_URL', '/employees/dashboard')

# Opción B: Contratos en libs
from pronto_shared.contracts import EmployeeRoutes
DASHBOARD_URL = EmployeeRoutes.DASHBOARD
```

#### Validación

```bash
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "api:"
```

**Meta:** `api: 2` → `api: 0`

---

### 🟠 FASE 3 — ELIMINAR employees → api

**Violaciones:** 2  
**Tiempo:** 2-3 horas  
**Riesgo:** Medium (puede ser proxy válido)

#### Archivos

```
pronto-employees/src/pronto_employees/app.py:223
pronto-employees/src/pronto_employees/routes/api/__init__.py:3
```

#### Verificación Previa

**¿Es proxy técnico SSR permitido?** (AGENTS.md 12.4.4)

```python
# ✅ VÁLIDO (proxy técnico)
# pronto-employees/routes/api/proxy_console_api.py
# Reenvía requests a pronto-api:6082 SIN lógica de negocio

# ❌ INVÁLIDO (lógica duplicada)
# employees importando servicios de negocio de api
```

#### Si es INVÁLIDO

```python
# ❌ ANTES
from pronto_api.src.api_app.services.order_service import get_order

# ✅ DESPUÉS
# Mover lógica a libs
from pronto_shared.services.order_service import get_order
```

#### Validación

```bash
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "employees:"
```

**Meta:** `employees: 2` → `employees: 0`

---

### 🟡 FASE 4 — CLASIFICAR scripts (NO MOVER TODAVÍA)

**Violaciones:** 179  
**Tiempo:** 2-4 horas (solo clasificación)  
**Riesgo:** High si se hace mal

#### ⚠️ NO EMPEZAR A MOVER CÓDIGO

Primero entender QUÉ es cada script.

#### Taxonomía

```
scripts/
├── infra/          # Pueden tocar todo (deploy, db migrations)
│   ├── bin/pronto-init
│   ├── bin/pronto-migrate
│   └── python/infra/*.py
├── tools/          # Puros, sin side-effects
│   ├── bin/pronto-validate
│   ├── bin/pronto-layering-check
│   └── python/tools/*.py
├── business/       # Lógica que debería estar en libs
│   └── python/business/*.py → MIGRAR A libs
└── invalid/        # Para eliminar (duplican lógica de apps)
    └── *.py → ELIMINAR
```

#### Acción de Clasificación

```bash
# Para cada script con violación:
# 1. ¿Toca DB directamente? → infra/
# 2. ¿Es herramienta pura? → tools/
# 3. ¿Tiene lógica de negocio? → business/ (luego migrar a libs)
# 4. ¿Duplica algo en api/employees? → invalid/ (eliminar)
```

#### Crear `scripts/TAXONOMY.md`

```markdown
# Scripts Taxonomy

## infra/ (pueden importar todo)
- pronto-init: Database initialization
- pronto-migrate: Schema migrations

## tools/ (solo libs)
- pronto-validate: Validation orchestrator
- pronto-layering-check: AST layering

## business/ (migrar a libs)
- order_utils.py → pronto-libs/src/pronto_shared/services/
- payment_helpers.py → pronto-libs/src/pronto_shared/services/

## invalid/ (eliminar)
- legacy_sync.py → duplica api/sync.py
```

#### Validación

```bash
# Contar scripts por categoría
find scripts/infra -name "*.py" | wc -l
find scripts/tools -name "*.py" | wc -l
find scripts/business -name "*.py" | wc -l
find scripts/invalid -name "*.py" | wc -l
```

**Meta:** Taxonomía documentada, NO código movido todavía.

---

### 🟢 FASE 5 — MIGRAR scripts/business → libs

**Violaciones a reducir:** ~60 (estimado)  
**Tiempo:** 8-12 horas  
**Riesgo:** Medium

#### Proceso

1. **Por cada archivo en `business/`:**
   - Identificar dependencias
   - Mover a `pronto-libs/src/pronto_shared/services/`
   - Actualizar imports en scripts
   - Validar con tests

2. **Mantener wrapper en scripts:**
   ```python
   # scripts/python/business/order_utils.py
   # Wrapper que importa de libs (no tiene lógica)
   from pronto_shared.services.order_utils import *  # re-export
   ```

3. **Después de 2 semanas:** Eliminar wrappers si nada los usa

#### Validación

```bash
# Después de cada migración
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "scripts:"

# Verificar invariantes
./pronto-scripts/bin/pronto-invariant-check
```

**Meta:** `scripts: 179` → `scripts: ~50` (solo infra + tools)

---

### 🟢 FASE 6 — ELIMINAR scripts/invalid

**Violaciones a reducir:** ~30 (estimado)  
**Tiempo:** 2-4 horas  
**Riesgo:** Low (si están bien identificados)

#### Proceso

1. **Para cada archivo en `invalid/`:**
   - Verificar que no tiene únicos features
   - Buscar tests que lo referencien
   - Mover a `scripts/archive/` (no borrar todavía)
   - Actualizar documentación

2. **Después de 1 semana sin incidentes:**
   - Eliminar `scripts/archive/`

#### Validación

```bash
# Verificar que nada roto
./pronto-scripts/bin/pronto-validate --staged
```

**Meta:** `scripts/invalid/` → vacío

---

### 🟢 FASE 7 — SYNTAX ERRORS

**Violaciones:** 3  
**Tiempo:** 30 minutos  
**Riesgo:** None

#### Archivos (identificar del reporte)

```bash
# El reporte completo debe listarlos
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "syntax_error"
```

#### Acción

```bash
# Para cada archivo
python -m py_compile <archivo>
# Corregir error
python -m py_compile <archivo>  # verificar fix
```

**Meta:** `syntax_error: 3` → `syntax_error: 0`

---

### 🟢 FASE 8 — UNKNOWN LAYER

**Violaciones:** 3  
**Tiempo:** 1 hora  
**Riesgo:** Low

#### Acción

1. Identificar ubicación de archivos
2. Determinar categoría correcta
3. Mover a directorio apropiado
4. Actualizar configuración de layers si necesario

**Meta:** `unknown: 3` → `unknown: 0`

---

## 📊 CRONOGRAMA REVISADO

| Fase | Violaciones | Tiempo | Orden | Estado |
|------|-------------|--------|-------|--------|
| 1. Limpiar libs | 13 | 4-6h | **1ro** | ⏳ Pendiente |
| 2. api → static | 2 | 2-3h | **2do** | ⏳ Pendiente |
| 3. employees → api | 2 | 2-3h | **3ro** | ⏳ Pendiente |
| 4. Clasificar scripts | 179 | 2-4h | **4to** | ⏳ Pendiente |
| 5. Migrar business → libs | ~60 | 8-12h | **5to** | ⏳ Pendiente |
| 6. Eliminar invalid | ~30 | 2-4h | **6to** | ⏳ Pendiente |
| 7. Syntax errors | 3 | 0.5h | **7mo** | ⏳ Pendiente |
| 8. Unknown layer | 3 | 1h | **8vo** | ⏳ Pendiente |

**Total estimado:** 21-35 horas

**Cambio clave vs plan anterior:** Scripts se hace **después** de libs, no antes.

---

## 🔒 INVARIANTES DURANTE EL BIG BANG

### Regla Dura

> **Si `pronto-invariant-check` falla después de un cambio → REVERTIR**

### Validación por Fase

```bash
# Fase 1-3 (libs, api, employees)
./pronto-scripts/bin/pronto-invariant-check  # debe pasar

# Fase 5-6 (scripts)
./pronto-scripts/bin/pronto-layering-check --full  # debe mejorar
```

### Gate de Progreso

```bash
# Antes de avanzar a siguiente fase:
PREV=$(./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "Violations found:" | awk '{print $3}')
CURRENT=$(./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "Violations found:" | awk '{print $3}')

if [ "$CURRENT" -ge "$PREV" ]; then
  echo "❌ VIOLATIONS NO MEJORARON - NO AVANZAR"
  exit 1
fi

echo "✅ Violations: $PREV → $CURRENT"
```

---

## 🧪 VALIDACIÓN CONTINUA

### Después de Cada Archivo

```bash
# 1. Validar archivo específico
./pronto-scripts/bin/pronto-layering-check --files <archivo>

# 2. Validar capa
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "<layer>:"

# 3. Validar total
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "Violations found:"
```

### Al Final de Cada Fase

```bash
# 1. Layering completo
./pronto-scripts/bin/pronto-layering-check --full

# 2. Invariantes (si aplica)
./pronto-scripts/bin/pronto-invariant-check

# 3. Drift (actualizar baseline si todo OK)
./pronto-scripts/bin/pronto-drift-detect --save-baseline
```

---

## 📈 MÉTRICAS DE ÉXITO

### Por Fase

| Fase | Métrica | Meta |
|------|---------|------|
| 1 | libs violations | 13 → 0 |
| 2 | api violations | 2 → 0 |
| 3 | employees violations | 2 → 0 |
| 4 | taxonomía documentada | 100% scripts clasificados |
| 5 | scripts violations | 179 → ~50 |
| 6 | invalid eliminados | ~30 → 0 |
| 7 | syntax errors | 3 → 0 |
| 8 | unknown | 3 → 0 |

### Global

| Métrica | Base | Meta |
|---------|------|------|
| Total violations | 200 | < 20 |
| Forbidden imports | 8 | 0 |
| Cross-layer libs | 13 | 0 |
| Scripts clasificados | 0% | 100% |
| Invariantes passing | N/A | 19/19 |

---

## 🚨 ERRORES PROHIBIDOS

### ❌ "Solo hago excepciones temporales"

→ Eso mata el sistema en semanas

### ❌ "Muevo imports sin entender"

→ Rompes flujo real

### ❌ "Arreglo scripts al final"

→ Scripts te vuelven a contaminar todo

### ❌ "Avanzo aunque violations no mejoren"

→ No es refactor, es maquillaje

---

## 🎯 CHECKLIST PRE-INICIO

- [ ] Backup de baseline actual guardado
- [ ] `pronto-invariant-check` pasando (si DB disponible)
- [ ] `pronto-layering-check --full` documentado (200 violations)
- [ ] Team entiende orden de fases (libs primero)
- [ ] Gate de progreso configurado
- [ ] Plan de rollback por fase

---

## 🚀 COMANDO DE INICIO

```bash
# Fase 1 - Día 1
echo "=== FASE 1: LIMPIAR LIBS ==="
echo "Violaciones iniciales: 13"
echo ""

# Primer archivo crítico
./pronto-scripts/bin/pronto-layering-check --files pronto-libs/src/pronto_shared/jwt_service.py

# Después de fixear
./pronto-scripts/bin/pronto-layering-check --full 2>&1 | grep "libs:"
# Debe mostrar: libs: < 13
```

---

## 📖 REFERENCIAS

- `AGENTS.md` Sección 1 - Arquitectura Inmutable
- `pronto-docs/standards/validation-system.md` - Sistema de validación
- `pronto-scripts/IMPLEMENTATION_SUMMARY.md` - Resumen de implementación

---

**PRÓXIMO PASO:** Comenzar Fase 1 (limpiar libs) cuando el team esté listo.

**REGLA:** No avanzar a Fase 2 hasta que `libs: 0`.
