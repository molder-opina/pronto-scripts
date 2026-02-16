# AGENTS.md

Documento maestro de guardrails, arquitectura, reglas operativas, gates y agentes para proteger el proyecto PRONTO contra regresiones, rupturas de rutas, corrupción de datos, cambios de arquitectura, desviaciones de estándar y errores de automatización.

---

# 0) PRINCIPIOS ABSOLUTOS (P0) — BLOQUEANTES

Violación a cualquiera ⇒ **REJECTED**.

1. No modificar arquitectura salvo solicitud explícita del usuario.
2. No eliminar bases de datos.
3. No tocar pods PostgreSQL ni Redis.
4. No tocar `pronto-postgresql` ni `pronto-redis` (código, config, pods) sin orden explícita.
5. Prohibido `flask.session` / `session` en `pronto-api` y `pronto-employees`.
6. Excepción única de sesión (solo `pronto-client`):
   - allowlist: `dining_session_id`, `customer_ref`
   - PII fuera de session; Redis TTL 60m: `pronto:client:customer_ref:<uuid>`
   - Prohibido PII/tokens/auth en session.
7. Autenticación empleados = JWT (inmutable).
8. Todo contenido estático es Vue y vive exclusivamente en `pronto-static`.
9. Vue se compila únicamente en build.
10. Prohibido estáticos locales en `pronto-client` / `pronto-employees`.
11. No inventar roles; roles canónicos: `waiter`, `chef`, `cashier`, `admin`, `system`.
12. No cambiar lógica de negocio actual sin orden explícita.
13. Prohibido DDL runtime en:
    - `pronto-api/`, `pronto-employees/`, `pronto-client/`, `pronto-libs/src/`
14. Fuente única DDL: `pronto-scripts/init/**`
    - `DROP INDEX IF EXISTS` permitido solo en `pronto-scripts/init/sql/migrations/`
    - todo lo demás `DROP*` prohibido.
15. Prohibido código legacy y patrones anticuados:
    - Prohibido `flask.session` para autenticación de empleados (usar JWT).
    - Prohibido directorio `legacy_mysql` en `pronto-scripts/init/`.
    - Prohibido funciones de hash legacy (SHA256+pepper) - usar PBKDF2.
    - Prohibido `callbacks` en SQLAlchemy (usar eventos si es necesario).
    - Prohibido patrones deprecated de Flask/Werkzeug.
16. No se permite código que dependa de funcionalidad deprecated o sin mantenimiento.
15. Init/Migrations canónicos pre-boot (OBLIGATORIO):
    - `./pronto-scripts/bin/pronto-migrate --apply`
    - `./pronto-scripts/bin/pronto-init --check`
16. Separación dura Init vs Migrations:
    - Init: `pronto-scripts/init/sql/00_bootstrap..40_seeds` (idempotente, sin `ALTER/RENAME/backfills`)
    - Migrations: `pronto-scripts/init/sql/migrations/` (evolutivo: `ALTER/RENAME/backfills/seed changes`)
17. Reutilización: Antes de crear funcionalidad nueva, revisar `pronto-libs (pronto_shared)` y reutilizar ahí.
18. No cambios silenciosos en `docker-compose*` ni en `pronto-scripts/bin`.
19. Herramienta estándar de búsqueda: `rg`.
20. Python deps: cada servicio `pronto-*` debe tener una sola fuente de verdad en `requirements.txt` en la raíz del proyecto del servicio (sin duplicados bajo `src/`). Excepción: `pronto-audit` usa `pyproject.toml` (poetry) y mantiene su propio ambiente virtual (`.venv`) interno.
21. PostgreSQL canónico: **16-alpine**
22. Root PRONTO es workspace aggregator local. **No se pushea**.
- Versión versionada en: `pronto-scripts/pronto-root/`
- Ver sección 0.5.5 para flujo de versionado.
- Se pushean repos hijos `pronto-*`.
23. Autoridad Única de Transiciones de Estado (Orden + Pago) (P0)
- Constantes canónicas: `pronto-libs/src/pronto_shared/constants.py`
- Servicio canónico: `pronto-libs/src/pronto_shared/services/order_state_machine.py`
- Prohibido `workflow_status = ...` fuera del servicio canónico
- Prohibido `payment_status = ...` fuera del servicio canónico
- Estados: solo en constants.py (`OrderStatus`, `PaymentStatus`)

---

# 0.6) TRAZABILIDAD Y OBSERVABILIDAD (P0)

## 0.6.1 Correlation ID (OBLIGATORIO)
- Todo request debe generar un correlation ID único
- Header canónico: `X-Correlation-ID`
- El correlation ID debe propagarse a todos los servicios y logs

## 0.6.2 Logging Estructurado (OBLIGATORIO)
- Usar `pronto_shared/trazabilidad.py` - StructuredLogger
- Formato JSON con campos obligatorios:
  - `timestamp`: ISO8601
  - `level`: DEBUG|INFO|WARNING|ERROR
  - `correlation_id`: ID del request
  - `service`: nombre del servicio
  - `action`: operación
  - `user_id`: ID del usuario
  - `user_type`: employee|customer|anonymous
  - `duration_ms`: tiempo de ejecución
  - `message`: mensaje legible
  - `error`: detalles del error (si aplica)

## 0.6.3 Mensajes de Usuario (OBLIGATORIO)
- NO exponer errores técnicos al usuario
- Usar códigos de error amigables (`USER_MESSAGES` en trazabilidad.py)
- Idiomas soportados: `es` (default), `en`

## 0.6.4 Errores y Excepciones
- Capturar contexto completo (stack trace, variables relevantes)
- No exponer PII en logs
- Registrar correlation ID en todo error

## 0.6.5 Monitoreo
- Endpoint de health: `/health` con estado y versión
- Métricas básicas: requests totales, errores, duración promedio
- Usar `ProcessMonitor` de trazabilidad.py

## 0.6.6 Auditoría de Acciones de Negocio
- Registrar quién hizo qué y cuándo (audit_action)
- Formato: `USER|ACTION|TYPE|CODE|RETVAL|SESSION|TIME`

## 0.6.7 Logs de Trazabilidad (OBLIGATORIO)
- Todos los logs aplicativo deben vivir en `pronto-logs/`
- Directorio raíz: `pronto-logs/`
- Subdirectorios por servicio:
  - `pronto-logs/api/` - Logs de pronto-api
  - `pronto-logs/employees/` - Logs de pronto-employees
  - `pronto-logs/client/` - Logs de pronto-client
  - `pronto-logs/nginx/` - Logs de nginx (pronto-static)
- Usar `pronto_shared/logging_config.py` para configuración
- Formato: JSON estructurado (ver 0.6.2)
- Rotación: diaria, retención 7 días

---

# 0.5) GIT Y CONTROL DE VERSIONES

## 0.5.1 Nueva Funcionalidad = Nuevo Branch (P0)
Cada feature / fix / doc / mejora debe vivir en su branch.

Convención:
- `feature/<name>`
- `fix/<name>`
- `improvement/<name>`
- `docs/<name>`
- `experiment/<name>`

## 0.5.2 Commits Atómicos
Commits pequeños, completos y funcionales.

Formato:
`tipo(ámbito): descripción`
Tipos: `feat|fix|improvement|docs|refactor|test|chore`

## 0.5.3 Multi-proyecto
Usar:
- `./pronto-scripts/bin/pronto-git-all.sh status`
- `./pronto-scripts/bin/pronto-git-all.sh sync -m "..."`
- `./pronto-scripts/bin/pronto-git-all.sh pull --rebase`

## 0.5.5 Versionado del Root (P0)
- Root es workspace aggregator local **no se pushea**.
- Copia de seguridad versionada en: `pronto-scripts/pronto-root/`
- Cada vez que se modifique un archivo en la carpeta `pronto/` del root, copiar a `pronto-scripts/pronto-root/`:
  - `.env`, `.env.example`, `.gitignore`, `.agents/`
  - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `DOCKER_COMPOSE.md`, `CHANGELOG.md`
  - `docker-compose.yml`, `docker-compose.api.yml`, `docker-compose.client.yml`, `docker-compose.employees.yml`, `docker-compose.infra.yml`, `docker-compose.tests.yml`
  - `pronto-apps.sh`, `pronto-dev.sh`, `start-api.sh`
- Esta copia es la única fuente versionada del contenido del root.

## 0.5.6 Control de versión del sistema (P0)
- Variable canónica de versión: `PRONTO_SYSTEM_VERSION` (en `.env` y `.env.example`).
- Formato obligatorio: `1.0000` (1 entero + 4 dígitos decimales).
- Valor inicial base: `1.0000`.
- Cada modificación aplicada por un agente AI debe incrementar `+1` en los 4 dígitos decimales.
  - Ejemplo: `1.0000` → `1.0001` → `1.0002`.
- Al modificar versión en root, replicar el cambio en `pronto-scripts/pronto-root/.env` y `pronto-scripts/pronto-root/.env.example`.
- Los aplicativos `pronto-api`, `pronto-client` y `pronto-employees` deben exponer/mostrar la versión vigente.

## 0.5.7 Bitácora de versión AI (P0)
- Cada cambio aplicado por AI debe registrar evidencia en `pronto-docs/versioning/AI_VERSION_LOG.md`.
- Formato obligatorio por entrada:
  - `FECHA (YYYY-MM-DD)`
  - `VERSION_ANTERIOR`
  - `VERSION_NUEVA`
  - `AGENTE`
  - `MODULOS`
  - `RESUMEN`
- Si no hay incremento de `PRONTO_SYSTEM_VERSION` y entrada de bitácora, el cambio queda **REJECTED**.


---

# 1) ARQUITECTURA INMUTABLE (P0)

## 1.1 Docker
- Root contiene `docker-compose.yml` global.
- Cada servicio tiene su Dockerfile.
- Prohibido modificar (sin orden explícita):
  - Servicios, puertos, redes, volúmenes, orden de arranque.

## 1.2 Repos (fuentes de verdad)
- `pronto-api` → API
- `pronto-static` → Estáticos Vue
- `pronto-client` → SSR clientes
- `pronto-employees` → SSR empleados
- `pronto-libs` → librería compartida
- `pronto-tests` → tests centralizados
- `pronto-scripts` → automatización + DDL

---

# 2) INFRAESTRUCTURA Y DATOS (P0)

## 2.1 PostgreSQL
- Nunca borrar/resetear/recrear.
- Sin DDL runtime.

## 2.2 Redis
- Uso permitido: sesiones TTL, notificaciones, cache, locks ligeros.
- Prohibido tocar pods/config.

## 2.3 Prohibido (P0)
- `DROP` / `TRUNCATE`
- Borrar volúmenes
- Cambiar imágenes

---

# 3) DOMINIOS INMUTABLES (P0)

No se modifican sin orden explícita:
- Estados de órdenes
- Estructura clientes/empleados
- Productos/modifiers/paquetes
- Mesas/áreas
- Parámetros de sistema
- Acciones
- Roles / segmentación / vistas↔roles
- Diseño visual
- Vistas (general)

---

# 3.1) WORKFLOW DE ÓRDENES (P0)

## Estados de Orden (workflow_status)

| Estado | Descripción | Transiciones válidas |
|--------|-------------|---------------------|
| `new` | Orden creada por cliente | → `queued` (mesero acepta) |
| `queued` | Mesero aceptó orden | → `preparing` (chef inicia), → `ready` (quick-serve) |
| `preparing` | Chef preparando orden | → `ready` (chef termina) |
| `ready` | Orden lista para entregar | → `delivered` (mesero entrega) |
| `delivered` | Orden entregada al cliente | → `paid` (pago completado) |
| `cancelled` | Orden cancelada | Estado terminal |

## Estados de Pago (payment_status)

| Estado | Descripción |
|--------|-------------|
| `unpaid` | Sin pagar |
| `paid` | Pagado |

## Sesión/Dining Session (status)

| Estado | Descripción |
|--------|-------------|
| `open` | Sesión abierta (cliente ordenando) |
| `active` | Sesión activa con órdenes |
| `awaiting_tip` | Propina solicitada |
| `awaiting_payment` | Cliente pidió la cuenta (check) |
| `paid` | Sesión pagada y cerrada |

## Reglas de Workflow

1. **Orden automática a `queued`**: Si la mesa tiene mesero asignado, al crear orden se acepta automáticamente
2. **Quick-serve**: Si todos los items son `is_quick_serve=true`, la orden pasa directamente a `ready`
3. **Pago directo**: El pago puede completarse en cualquier momento (no requiere `awaiting_payment`)
4. **Check solicitado**: Se registra `check_requested_at` cuando el cliente pide la cuenta desde la app, pero no es requisito para pagar
5. **Roles para pago**: Mesero, Cajero, Admin, System pueden iniciar y confirmar pagos

---

# 4) ROLES Y ACCESOS (P0)

Roles canónicos:
- `waiter`, `chef`, `cashier`, `admin`, `system`

Jerarquía (SSR):
- `/system` → `system`
- `/admin` → `admin`, `system`
- `admin` puede acceder a: `/waiter`, `/chef`, `/cashier`
- `system` → todo

Aislamiento:
- No compartir contextos ni archivos entre recursos.
- Cada recurso usa únicamente su scope.

---

# 5) VISTAS Y TEMPLATES (P0)

1. Templates por rol son independientes.
2. Naming obligatorio:
   - `orders_waiter.html`
   - `orders_chef.html`
   - `orders_cashier.html`
3. Prohibido reutilizar template cross-role.

---

# 6) PRONTO-STATIC (FUENTE ÚNICA DE ESTÁTICOS) (P0)

Ruta base: `pronto-static/src/static_content/`

Reglas:
1. Todo CSS/JS/Images/Audio vive aquí.
2. Prohibido estáticos en `pronto-client` / `pronto-employees`.
3. No mover ni renombrar rutas existentes sin orden explícita.
4. Prohibido JavaScript vanilla (solo Vue).
5. Prohibido inline JS.

Context vars (templates):
- `assets_css`, `assets_css_clients`, `assets_css_employees`
- `assets_js`, `assets_js_clients`, `assets_js_employees`
- `assets_images`, `restaurant_assets`, `static_host_url`

Uso correcto:
```html
<link rel="stylesheet" href="{{ assets_css_employees }}/dashboard.css">
<script src="{{ assets_js_employees }}/main.js"></script>
7) PRONTO-LIBS (P1)
Toda función reutilizable vive aquí.
Prohibido duplicar helpers/servicios.
8) PRONTO-SCRIPTS (P1)
Estructura:
pronto-scripts/bin → scripts operativos (idempotentes)
pronto-scripts/python → librería python reusable
Reglas:
Si existe script en bin, debe usarse.
Si no existe, crearlo en bin.
Si existe pero no soporta caso, extender con flags (idempotente).

Scripts Críticos:
- `pronto-full-audit.sh`: Ejecuta auditorías LLM integrales por proyecto enfocadas en:
    1. **Integridad de Negocio:** Validación de flujos (orden, pago, entrega).
    2. **Pureza Arquitectónica:** Prohibición absoluta de estáticos locales fuera de `pronto-static`.
    3. **Calidad de Código:** Detección de imports rotos, código legacy, deduplicación y fallbacks peligrosos.
    4. **Seguridad:** Aislamiento de sesiones y protección de PII.
    5. **Integridad de Estructuras:** Consistencia DDL (SQL) vs Modelos (Python) vs Interfaces (TypeScript).
- `pronto-inconsistency-check`: Verifica invariantes locales y roles.
- `pronto-api-parity-check`: Valida consistencia frontend/backend.
9) PRONTO-TESTS (P1)
Centraliza:
UI/E2E (Playwright)
API funcional
Performance
9.1 Tests obligatorios para cambios Vue
Cambios en pronto-static/src/vue/** ⇒ ejecutar:
cd pronto-tests
npx playwright test vue-rendering.spec.ts
npx playwright test vue-integrity.spec.ts
10) VARIABLES DE AMBIENTE (P1)
Cada proyecto mantiene su .env.
No hardcode secrets.
.env en .gitignore.
Usar .env.example cuando aplique.
11) DOCUMENTACIÓN (P1)
Cambios funcionales ⇒ doc obligatoria en pronto-docs/<proyecto>/.
11.1 Features (P1)
Nueva feature ⇒ pronto-docs/features/<feature-name>/ con:
README.md
PLAN.md
APPLIED.md
references/ (opcional)
Prohibido comitear doc incompleta.
12) API CANÓNICA (/api) (P0)
12.1 Regla canónica por host
Única ruta canónica de API: "/api/*".
Resolución por host:
employees.<dominio>/api/* → pronto-employees
clients.<dominio>/api/* → pronto-client
Prohibido implementar/documentar/depender de "/{scope}/api/*".

12.2 Frontend employees (pronto-static) — wrapper obligatorio (P0)

Toda llamada a "/api/*" debe ser relativa (sin host hardcode).
Prohibido mutar "/api/*" fuera de:
pronto-static/src/vue/employees/core/http.ts
Canon:
credentials: 'include'
Prohibido: credentials: 'same-origin'
12.3 CSRF canónico employees (P0)
Fuente token: <meta name="csrf-token" ...>
Header: X-CSRFToken
Toda mutación a "/api/*" incluye X-CSRFToken (incluye FormData).
Si falta meta tag y se intenta mutar ⇒ wrapper falla loud (throw).

12.4 Autenticación clientes (P0)
12.4.1 Header canónico
pronto-client → pronto-api debe usar header: X-PRONTO-CUSTOMER-REF

12.5 Tipos de parámetros en rutas (P0)
- Entidades principales (Customer, Employee, DiningSession, Order, Table, MenuItem, Modifier, etc.) deben usar UUID.
- Solo entidades de lookup/técnicas usan Integer: Area, Role, DiscountCode, Promotion, ProductSchedule, WaiterCall, Notification.
- Flask route converters: usar `<uuid:id>` para entidades UUID, `<int:id>` solo para Integer.
- No usar `<str:id>` para IDs; usar converters explícitos.
- Validar contra el modelo: si el modelo usa `UUID(as_uuid=True)`, la ruta debe usar `<uuid:id>`.
- Servicios permitidos de Integer IDs:
  - pronto-employees: Area, Role, DiscountCode, Promotion, ProductSchedule, WaiterCall, AdminShortcut
  - others: revisar schema antes de decidir.

12.6 Gate de validación de tipos (P0)
Ejecutar para validar:
```bash
# Verificar que no haya <int:> para entidades UUID
rg -n --hidden "/<int:[a-z_]+_id>" pronto-employees/src/pronto_employees/routes/api/
rg -n --hidden "/<int:[a-z_]+_id>" pronto-client/src/pronto_clients/routes/api/
```
Si produce output ⇒ REJECTED

13) TOOLING CONFIABLE: PRONTO_ROUTES_ONLY (P1)

pronto-employees y pronto-client deben soportar PRONTO_ROUTES_ONLY=1.
En PRONTO_ROUTES_ONLY=1, create_app():
Solo registra rutas/blueprints
Prohibido side-effects:
No DB init/schema validate
No Redis init
No schedulers/webhooks
No escritura a filesystem
Side-effects viven en init_runtime(app) y corren solo si PRONTO_ROUTES_ONLY!=1.
Checklist mínimo (debe pasar):
app.url_map construido
No llamadas a get_session()
No conexiones Redis
No writes a disco
14) CONTRATOS PÚBLICOS (P0)
Fuente de verdad:
pronto-docs/contracts/<mod>/
Requisitos mínimos por módulo:
openapi.yaml (si aplica)
redis_keys.md
events.md
db_schema.sql (generado con pg_dump --schema-only)
files.md (si aplica)
cookies.md / csrf.md (si aplica)
15) ROUTER SEMÁNTICO (P0)
Fuente de verdad:
pronto-ai/router.yml
Router-Hash: `b461a7f3412424bd8308f60366f3d3fc3daa83d2fcca70af8a25f976f66c3fb1`
Regla:
Si cambia router.yml, actualizar hash y registrar evidencia en docs.
16) AGENTES (DEFINICIÓN + PRIORIDAD)
16.1 Prioridad
P0: Bloquea siempre
P1: Bloquea en cambios relevantes
P2: Reporta, no bloquea (salvo instrucción)
16.2 Agentes
Pronto-Guardrails-Agent (P0)
Escanea:
flask.session
JWT empleados
docker-compose*
Postgres/Redis touch
Estáticos fuera de pronto-static
Roles inválidos
Cross-scope imports
DDL runtime / SQL destructivo
Scripts fuera de pronto-scripts/bin
Salida:
STATUS: APPROVED|REJECTED
VIOLATIONS:
Pronto-Audit-Agent (P1)
- Sistema autónomo de auditoría integral (CrewAI).
- Escanea: AGENTS.md compliance, API parity, Seguridad, TypeScript/Vue quality, Deduplicación.
- Ubicación: `pronto-audit/`
- Entorno: Virtualenv propio (`pronto-audit/.venv`), gestionado por Poetry (Python 3.12 obligatorio).
- Salida: Reportes en `pronto-audit/reports/` y GitHub Issues.

Pronto-Precommit-Agent (P0)
Analiza archivos cambiados
Hook: .git/hooks/pre-commit -> pronto-scripts/bin/pre-commit-ai
Exit 1 si BLOCKER
Pronto-Static-Vue-Agent (P1)
Solo pronto-static
Reglas Vue build-only
Pronto-API-Agent (P1)
Solo pronto-api
No sesiones
No DDL runtime
Contrato API coherente
Pronto-Shared-Agent (P1)
Solo pronto-libs
No duplicados
Tests unitarios
Pronto-Tests-Agent (P1)
Playwright (UI)
API tests
Perf (si aplica)
Pronto-Docs-Agent (P1)
Verifica docs requeridas (incluye features y contracts)
Pronto-Scripts-Agent (P1)
Ubicación correcta
Parametrizable
Idempotente
No side-effects peligrosos
Pronto-Seed-Agent (P1)
Solo en PRONTO_ENV in {dev,test}
Requiere DB de dev/test
Prohibido en prod
Pronto-Logging-Agent (P2)
current_app.logger o get_logger
No swallow exceptions
Pronto-Business-Order-Auditor-Agent (P0)
Valida negocio + enforcement:
- Grafo (ORDER_TRANSITIONS) y reglas (validate_transition)
- Uso obligatorio de OrderStateMachine
- Quick-serve / parciales / pagos (cash/card)
- Inventario de flujo en pronto-prompts/business/order_request_flow_files.md
- Tests del flujo
Salida:
STATUS: APPROVED|REJECTED
BUSINESS_RULES:
- Workflow Graph: OK|FAIL
- Quick Serve: OK|FAIL
- Partial Orders: OK|FAIL
- Payment Cash: OK|FAIL
- Payment Card: OK|FAIL
- Auto Accept: OK|FAIL
CODE_INTEGRITY:
- Single Authority: OK|FAIL
- No Magic Strings: OK|FAIL
INVENTORY:
- Complete: OK|FAIL
TESTS:
- Coverage: OK|FAIL
VIOLATIONS:
Pronto-Guardrails-Order-State-Authority (P0)
Enforcement estructural:
- Bloquea escrituras directas de estados
- Bloquea strings mágicos fuera de archivos permitidos
Ejecutar:
rg -n --hidden "workflow_status\s*=" pronto-api/src | rg -v "order_state_machine\.py"
rg -n --hidden "payment_status\s*="  pronto-api/src | rg -v "order_state_machine\.py"
rg -n --hidden "['\"](new|queued|preparing|ready|delivered|paid|cancelled)['\"]" pronto-api/src \
  | rg -v "constants\.py|order_state_machine\.py"
Salida:
STATUS: APPROVED|REJECTED
VIOLATIONS:

## 16.3 Herramientas de Auditoría (Ejecución Manual/CI)
- `pronto-full-audit.sh`: Orquestador de auditoría LLM integral. Utiliza prompts especializados por proyecto para detectar inconsistencias de negocio, estáticos prohibidos y deuda técnica.
- `pronto-inconsistency-check`: Script de validación rápida de invariantes locales (roles, versiones, sesiones).
- `pronto-audit/bin/run-audit.sh`: Interfaz de ejecución para el agente basado en CrewAI (requiere `.venv` interno con Python 3.12).

17) GATES (ORDEN CANÓNICO) — EJECUCIÓN OBLIGATORIA
Gate A: Arquitectura (P0)
docker-compose* tocado sin orden explícita ⇒ REJECTED
Gate B: Seguridad (P0)
flask.session en api/employees ⇒ REJECTED
JWT empleados modificado sin orden explícita ⇒ REJECTED
Gate C: Estáticos (P0)
Estáticos fuera de pronto-static ⇒ REJECTED
Gate D: Roles (P0)
rol nuevo/typo ⇒ REJECTED
Gate E: Tests (P1)
api cambiado ⇒ API tests
vue cambiado ⇒ Playwright
libs cambiado ⇒ unit tests
Gate F: Docs (P1)
cambio funcional sin doc ⇒ REJECTED
Gate G: API Parity (P1)
ejecutar:
./pronto-scripts/bin/pronto-api-parity-check employees
./pronto-scripts/bin/pronto-api-parity-check clients
Gate H: Order State Authority (P0)
Ejecutar:
rg -n --hidden "workflow_status\s*=" pronto-api/src | rg -v "order_state_machine\.py"
rg -n --hidden "payment_status\s*="  pronto-api/src | rg -v "order_state_machine\.py"
Si produce output ⇒ REJECTED
18) ERROR TRACKING OBLIGATORIO — Pronto-Error-Tracker-Agent (P0)
Objetivo:
Forzar que TODO bug quede documentado y solo pase a resuelto con corrección verificada.
Ubicaciones:

pronto-docs/errors/
pronto-docs/resolved/
pronto-docs/resueltos.txt
18.1 Regla: No hay fix sin error documentado (P0)
Ante cualquier bug:
crear pronto-docs/errors/<YYYYMMDD>_<slug_error>.md ANTES del fix.
Formato EXACTO del archivo:
ID:
FECHA:
PROYECTO:
SEVERIDAD: (bloqueante | alta | media | baja)
TITULO:
DESCRIPCION:
PASOS_REPRODUCIR:
RESULTADO_ACTUAL:
RESULTADO_ESPERADO:
UBICACION:
EVIDENCIA:
HIPOTESIS_CAUSA:
ESTADO: ABIERTO
18.2 Cierre (P0)
Cuando se corrige:
Actualizar:
ESTADO: RESUELTO
agregar:
SOLUCION:
COMMIT:
FECHA_RESOLUCION:
Mover:
pronto-docs/errors/... → pronto-docs/resolved/...
Append a pronto-docs/resueltos.txt:
YYYY-MM-DD | ID | TITULO | COMMIT | PROYECTO
18.3 Reapertura (P0)
Si reaparece:
crear NUEVO archivo en pronto-docs/errors/ y referenciar ID anterior en DESCRIPCION.
18.4 Validaciones duras (P0)
No existe fix sin archivo en pronto-docs/errors/.
No existe archivo en pronto-docs/resolved/ con ESTADO != RESUELTO.
No existe entrada en pronto-docs/resueltos.txt sin archivo correspondiente.

---

# 19) MANDATO DE ACCESO Y LOGIN (P0)

1. La aplicación solo funciona con login y registro previo.
2. Prohibido realizar órdenes sin un usuario autenticado y una sesión activa.
3. El flujo de invitados (anonymous) es transicional hacia un registro o login obligatorio para finalizar el checkout.
4. **Caso Kiosko:** Se utilizará un usuario especial de tipo `kiosko`. Por ahora, su comportamiento y capacidades son idénticas a las de un usuario normal.

---

# 20) REGLAS OPERATIVAS PARA CAMBIOS SENSIBLES (P0)
Si una acción puede afectar:
Datos
Arquitectura
Auth
Roles
Segmentación
Estáticos
DDL / migraciones
No se ejecuta sin confirmación explícita del usuario.
20) NOTA: CASE-INSENSITIVE FS (macOS) (P1)
El repo solo trackea AGENTS.md.
Prohibido versionar agents.md en paralelo.
FIN
