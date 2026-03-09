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
15. **Todo flujo sin autenticación es prohibited**:
    - No debe existir ningún endpoint, ruta o página accesible sin autenticación válida.
    - Excepciones: `/health`, `/api/sessions/open` (solo con table_id válido), login/register pages y navegación pública de cliente (`/` y vistas de menú informativas sin mutación).
    - En `pronto-client`, la autenticación se exige al primer intento de crear/confirmar orden o iniciar checkout/pago.
    - Todo endpoint de mutación (POST/PUT/DELETE) requiere autenticación.
    - Tests deben usar autenticación real, no flujos anónimos.
16. **Prohibido @csrf.exempt para "hacer funcionar" código** (P0):
    - CSRF es protección obligatoria, no debe deshabilitarse para arreglar problemas.
    - Si un endpoint falla por CSRF, la solución correcta es asegurar que el cliente envíe el token CSRF.
    - Excepciones permitidas y acotadas:
      - `/api/sessions/open` (solo con `table_id` válido para abrir sesión de mesa).
      - `POST /waiter/login` en `pronto-employees/src/pronto_employees/routes/waiter/auth.py` (login de consola scope `waiter`).
      - `POST /chef/login` en `pronto-employees/src/pronto_employees/routes/chef/auth.py` (login de consola scope `chef`).
      - `POST /cashier/login` en `pronto-employees/src/pronto_employees/routes/cashier/auth.py` (login de consola scope `cashier`).
      - `POST /admin/login` en `pronto-employees/src/pronto_employees/routes/admin/auth.py` (login de consola scope `admin`).
      - `POST /system/login` en `pronto-employees/src/pronto_employees/routes/system/auth.py` (login de consola scope `system`).
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
17. Sincronía obligatoria Modelo/DB/Init/Seeds (P0):
    - Todo cambio estructural (crear/modificar/renombrar/eliminar tablas, columnas, constraints, índices o modelos persistentes) debe actualizar sus scripts en `pronto-scripts/init/sql/**`.
    - Si el cambio impacta datos base/catálogos o fixtures operativos, también debe actualizar `pronto-scripts/init/sql/40_seeds/**`.
    - Antes de commit es obligatorio validar con:
      - `./pronto-scripts/bin/pronto-migrate --check`
      - `./pronto-scripts/bin/pronto-init --check`
    - Si no aplica actualización de seeds, debe declararse explícitamente en la validación de commit (`PRONTO_INIT_SEED_NO_DATA_CHANGE=1`).
18. Reutilización: Antes de crear funcionalidad nueva, revisar `pronto-libs (pronto_shared)` y reutilizar ahí.
19. No cambios silenciosos en `docker-compose*` ni en `pronto-scripts/bin`.
20. Herramienta estándar de búsqueda: `rg`.
21. Python deps: cada servicio `pronto-*` debe tener una sola fuente de verdad en `requirements.txt` en la raíz del proyecto del servicio (sin duplicados bajo `src/`). Excepción: `pronto-audit` usa `pyproject.toml` (poetry) y mantiene su propio ambiente virtual (`.venv`) interno.
22. PostgreSQL canónico: **16-alpine**
23. Root PRONTO es workspace aggregator local. **No se pushea**.
- Versión versionada en: `pronto-scripts/pronto-root/`
- Ver sección 0.5.5 para flujo de versionado.
- Se pushean repos hijos `pronto-*`.
24. Autoridad Única de Transiciones de Estado (Orden + Pago) (P0)
- Constantes canónicas: `pronto-libs/src/pronto_shared/constants.py`
- Servicio canónico: `pronto-libs/src/pronto_shared/services/order_state_machine.py`
- Prohibido `workflow_status = ...` fuera del servicio canónico
- Prohibido `payment_status = ...` fuera del servicio canónico
- Estados: solo en constants.py (`OrderStatus`, `PaymentStatus`)
25. Regla de Recurrencia de Errores y Deuda Técnica (P0)
- Ante cualquier bug, deuda técnica o anti-patrón detectado, es obligatorio ejecutar validación transversal en todo el código para identificar ocurrencias similares.
- No se permite cerrar un hallazgo corrigiendo solo un archivo/punto aislado si existen más ocurrencias del mismo patrón.
- La búsqueda transversal debe cubrir al menos: `pronto-api`, `pronto-client`, `pronto-employees`, `pronto-static`, `pronto-libs`, `pronto-scripts`.
- Herramienta canónica de búsqueda: `rg` (con evidencias de búsqueda y resultados).
- Si hay múltiples ocurrencias, debe documentarse: alcance total, archivos impactados y estado por ocurrencia (corregido/pendiente con plan).

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

# 0.7) CANON DE NOMENCLATURA (P0)

Reglas obligatorias para todo el monorepo. Violación ⇒ **REJECTED**.

1. **Directorios**:
   - Directorios funcionales del monorepo: siempre `kebab-case` (ej: `pronto-static`, `shared-utils`).
   - Excepciones canónicas: paquetes Python (`pronto_api`, `pronto_clients`, `pronto_employees`, `pronto_shared`, `pronto_audit`, `api_app`), directorios dunder (`__pycache__`) y dotdirs (`.git`, `.github`, `.venv`, etc.).
   - Directorios generados/vendor/archive conservan su naming upstream y quedan fuera de enforcement (`node_modules/`, `build/`, `dist/`, `archive/`, `archived/`, `vendor/`, `pronto-backups/**`, `pronto-logs/`, `postgres_data/`).
2. **Python**:
   - Archivos de código: `snake_case.py` (PEP8).
   - Paquetes Python: `snake_case`.
   - Excepciones canónicas exactas: `__init__.py`, `conftest.py`.
   - Clases: `PascalCase`.
   - Funciones/Variables: `snake_case`.
3. **Vue (Frontend)**:
   - Componentes (SFC): `PascalCase.vue` (ej: `RoleCard.vue`).
   - Directorios de componentes: `kebab-case` (ej: `components/roles/`).
   - Excepción canónica exacta permitida: `App.vue`.
4. **TypeScript / JavaScript**:
   - Módulos de lógica, composables, utils, helpers y tests: `kebab-case.ts|js` (ej: `use-rbac.ts`, `session-manager.ts`, `api-guard.ts`).
   - Entrypoints/configs canónicos pueden conservar naming del ecosistema cuando aplique: `main.ts`, `main.js`, `index.ts`, `index.js`, `vite.config.ts`, `playwright.config.ts`, `vitest.config.ts`.
   - Declaration files permitidos: `global.d.ts`, `shims-vue.d.ts`, `<kebab-case>.d.ts`.
   - Interfaces/Tipos: `PascalCase` (dentro del archivo).
5. **Shell Scripts**:
   - Scripts shell generales: `kebab-case.sh`.
   - En `pronto-scripts/bin/` los wrappers ejecutables canónicos pueden no usar extensión, pero si usan `.sh` deben respetar `kebab-case.sh`.
6. **HTML/CSS**:
   - Templates SSR/Jinja: `snake_case.html`.
   - Partials/includes SSR pueden usar prefijo `_snake_case.html`.
   - Hojas de estilo y assets CSS/JS no generados: `kebab-case.css|js`.
7. **Markdown / documentación**:
   - Documentación general: `kebab-case.md`.
   - Incidentes, errores, resolved y bitácoras fechadas: `YYYYMMDD_slug.md`.
   - Changelogs generados pueden usar IDs canónicos: `CHG-...`, `PRECOMMIT-...`, y anexos tipo `inconsistencies.<provider>.md`.
   - Documentos de autoridad exactos permitidos: `README.md`, `AGENTS.md`, `CHANGELOG.md`, `CLAUDE.md`, `GEMINI.md`, `DOCKER_COMPOSE.md`.
   - Documentos operativos canónicos de tooling pueden conservar `SCREAMING_SNAKE_CASE.md` cuando el nombre ya es contrato activo del proyecto.
8. **SQL/Backups**:
   - Migrations/init SQL respetan su contrato de prefijos existentes (`00_bootstrap`, `0110__core_tables.sql`, `YYYYMMDD_description.sql` según carpeta).
   - No inventar nuevos formatos fuera de esos contratos.
9. **Tooling / configs con nombre contractual**:
   - Se preservan nombres exactos de herramientas/ecosistema: `Dockerfile`, `Makefile`, `package.json`, `package-lock.json`, `pyproject.toml`, `poetry.lock`, `requirements.txt`, `tsconfig.json`, `pytest.ini`, `.env`, `.env.example`, `.gitignore`, `.dockerignore`, `.prettierrc`, `.eslintrc.cjs`.
10. **Prohibiciones**:
   - Prohibido espacios o caracteres especiales en nombres de archivos propios del proyecto.
   - Prohibido archivos de datos (`.txt`, `.cookies`, `.sql`, `.log`) en el root del proyecto.
   - Prohibido introducir nuevas excepciones ad hoc fuera de este canon o del checker central.
   - Todo contexto que sea público por definición debe ubicarse en `/public`.
   - Excepción única: todo lo relacionado con autenticación debe ubicarse en `/auth`, incluso si es público.
11. **Enforcement obligatorio**:
   - Checker canónico: `./pronto-scripts/bin/pronto-file-naming-check`.
   - Todo archivo nuevo debe nacer cumpliendo el canon; si un archivo legacy no puede renombrarse sin riesgo, debe quedar explícitamente cubierto por una excepción canónica del checker, nunca por improvisación local.
12. **Archivos Temporales (IA/Desarrollo)**: Todos los archivos temporales, reportes de un solo uso, capturas de pantalla o logs manuales generados por la IA o durante el desarrollo deben ubicarse exclusivamente en la carpeta `tmp/` en la raíz del proyecto. Esta regla aplica al espacio de trabajo local y no invalida las rutas de temporales internas de los contenedores.

---

# 0.8) JERARQUÍA DE DOCUMENTACIÓN (P0)

Para evitar desincronización y "deriva documental", se establece la siguiente jerarquía de autoridad:

1. **AGENTS.md**: Autoridad suprema (P0). Define la arquitectura, guardrails y reglas de nomenclatura. En caso de conflicto, la regla en este archivo invalida cualquier otra.
2. **.env.example**: Fuente de verdad para la configuración. Define las llaves válidas y sus valores por defecto.
3. **pronto-docs/contracts/**: Fuente de verdad para integraciones entre servicios.
4. **README.md locales**: Contexto operativo específico del servicio. **Prohibido duplicar** contenido de los niveles 1 y 2. Deben usar links relativos a la fuente de verdad global.

---

# 0.9) ESTÁNDARES DE CALIDAD DE CÓDIGO (P0)

**Eres un desarrollador senior obsesionado con cero deuda técnica nueva.**

## Reglas obligatorias para TODAS las implementaciones (P0)

Violación a cualquiera ⇒ **REJECTED**.

### 0.9.1 Calidad de Implementación (P0)
- **Implementación COMPLETA y bien hecha**: Siempre implementa la funcionalidad completa, funcional y probada. No aceptes versiones parciales o "luego termino".
- **Código limpio y legible**: Nombres claros y descriptivos. Prohibido: `x`, `tmp`, `data1`, `var`, `foo`, `bar`, etc. Usa nombres que expresen intención.
- **Eliminación de duplicación**: Extrae funciones, clases, utilitarios o módulos cuando detectes código repetido. DRY (Don't Repeat Yourself) es mandatorio.
- **Tests unitarios mínimos pero útiles**: Al menos 2-3 casos felices + 1-2 casos de borde/error por implementación.
- **Extensibilidad por diseño**: Piensa en que añadir funcionalidades similares mañana no rompa ni obligue a reescribir mucho. Open/Closed Principle.
- **Documentación inline breve pero clara**: Docstrings en funciones/clases, comentarios en puntos clave. No sobre-documentes ni sub-documentes.
- **CERO DEUDA TÉCNICA NUEVA**: NUNCA dejes TODO, FIXME, // TODO, hack, nota mental ni comentarios tipo "luego lo arreglo". Si no puedes hacerlo ahora, no lo hagas a medias.
- **Patrones y prácticas adecuadas**: Usa clean code, SOLID, principios del lenguaje/framework correspondientes.
- **Manejo de errores correcto**: Excepciones apropiadas, validaciones de input, valores por defecto seguros. Nunca silencies errores con `pass` sin razón documentada.

### 0.9.2 Implementaciones Rápidas/Sucias (P0)
Solo puedes hacer una implementación rápida/sucia/hack si el usuario dice **textualmente** alguna de estas frases:
- "hazlo sucio"
- "versión rápida y sucia"
- "hack rápido"
- "no importa la calidad ahora"

**En todos los demás casos → SIEMPRE versión completa y profesional.**

### 0.9.3 Límite de Tokens (P1)
Si por límite de tokens o complejidad extrema no cabe todo en una respuesta:
1. Entrega la parte principal primero
2. Marca claramente la deuda pendiente con un comentario grande:
   ```
   // DEUDA TÉCNICA PENDIENTE (necesita completarse):
   // - [descripción exacta]
   // - [impacto]
   ```
3. Luego entrega las partes restantes en mensajes siguientes si es necesario.
4. La deuda técnica pendiente debe completarse antes de considerarse terminado.

### 0.9.4 Response Style (P1)
- Responde directo con el código + tests + explicación mínima si hace falta.
- Sin preámbulos largos, sin preguntar "quieres rápido o bien", sin justificar.
- Asume siempre: bien hecho.

### 0.9.5 Cierre Sin Legacy Ni Deuda (P0)
- **Cero legacy**: ante cualquier patrón legacy detectado, la corrección debe eliminarlo del flujo afectado; no se permite dejar compatibilidad legacy activa sin plan de retiro explícito aprobado por el usuario.
- **Cero deuda técnica pendiente al cerrar tarea**: no se considera terminada una tarea si quedan FIXMEs, workarounds temporales, parches parciales o comportamientos inconsistentes derivados del cambio.
- **Regla de completitud obligatoria**: todo fix debe incluir saneamiento integral del patrón relacionado (frontend, backend, shared/libs y scripts impactados), con validación final del flujo principal.
- **Criterio de bloqueo**: si existe deuda técnica/legacy remanente del mismo hallazgo, el estado debe ser `REJECTED` hasta completar el saneamiento.
- **Modo "aplica completo"**: cuando el usuario pida explícitamente aplicar un cambio "completo", "sin legacy", "sin compatibilidad" o "sin deuda técnica", el agente debe ejecutar el saneamiento end-to-end del alcance afectado y evitar planes por semanas/fases artificiales, bridges temporales, compatibilidad transicional o cierres parciales.

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

# 3.2) REGLA DE COMBOS/PAQUETES Y ADITAMIENTOS (P0)

## Definición Canónica

1. **Combo/Paquete es una composición de productos existentes**:
   - Prohibido tratar combos como productos aislados "inventados" sin base en catálogo.
   - Cada combo debe derivarse de productos existentes en `pronto_menu_items`.

2. **Herencia de aditamientos obligatoria**:
   - Un combo debe heredar los `modifier_groups` de sus productos base.
   - Se permite agregar aditamientos específicos del combo (extras del combo), pero no reemplazar silenciosamente los heredados.

3. **Opciones incluidas de combo**:
   - Las opciones incluidas (ej: bebida/guarnición del combo) deben construirse desde productos existentes, no desde listas hardcodeadas desvinculadas del catálogo vigente.

4. **Semántica de seed/init**:
   - La normalización de combos debe ser idempotente.
   - Si existen grupos legacy de combo, deben migrarse/limpiarse hacia el esquema canónico sin duplicar enlaces.

5. **Paridad backend/frontend**:
   - `GET /api/menu` debe exponer combos con sus grupos heredados + grupos específicos del combo de forma consistente para `pronto-client`.

## Prohibiciones explícitas (P0)

- Prohibido crear combos "vacíos" sin productos base.
- Prohibido suprimir aditamientos heredados del producto base sin orden explícita del usuario.
- Prohibido mantener simultáneamente grupos legacy y canónicos para la misma semántica de combo si generan duplicidad/confusión.

---

# 4) ROLES Y ACCESOS (P0)

Roles canónicos:
- `waiter`, `chef`, `cashier`, `admin`, `system`

## 4.1) SISTEMA UNIFICADO DE PERMISOS (RBAC) (P0)

1. **Canon Establecido**: El Sistema 2 (RBAC basado en `SystemRole` y `SystemPermission`) es el único estándar del proyecto.
2. **Prohibición de Legacy**: Queda terminantemente prohibido el uso de `RoutePermission`, `EmployeeRouteAccess`, `CustomRole` o `RolePermission` (legacies eliminados).
3. **Servicio Consolidado**: Toda gestión de roles y bindings de permisos debe realizarse exclusivamente a través de `RBACService` en `pronto-libs`.
4. **Seguridad Alineada**: El endpoint `/auth/me` y el frontend deben utilizar exclusivamente los códigos de permiso definidos en el Enum `Permission` de `pronto_shared`. Backend y Frontend deben hablar el mismo lenguaje para evitar inconsistencias de UI vs Autorización.
5. **Idempotencia de Semillas**: Los scripts de inicialización (`seed.py`, `validate_and_seed.py`) deben ser limpios e idempotentes, poblando únicamente el sistema RBAC unificado.

---

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
12.1 Autoridad única de API (P0)
Única ruta canónica de API: "/api/*" servida exclusivamente por `pronto-api` en `:6082`.
Regla dura:
- Prohibido exponer endpoints de negocio fuera de `pronto-api` (`:6082`).
- Prohibido implementar lógica de negocio/API en `pronto-client` o `pronto-employees`.
- Prohibido implementar/documentar/depender de "/{scope}/api/*".
- Cualquier endpoint de API fuera de `:6082/api/*` ⇒ **REJECTED**.

12.2 Frontend employees (pronto-static) — wrapper obligatorio (P0)

Toda llamada a "/api/*" debe resolver canónicamente a `pronto-api` (`:6082`) sin bypass.
Prohibido mutar "/api/*" fuera de:
pronto-static/src/vue/employees/shared/core/http.ts
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

12.4.2 BFF prohibido para negocio/API (P0)
- `pronto-client` y `pronto-employees` solo pueden renderizar SSR/UI.
- No pueden definir ni mantener endpoints `/api/*` de negocio.
- Cualquier compatibilidad temporal debe declararse como `deprecated` y tener plan de retiro explícito.

12.4.3 Excepción controlada: BFF proxy técnico de transporte (P0)
- Se permite únicamente un BFF proxy técnico temporal para compatibilidad de despliegue/ruteo.
- Alcance permitido: reenviar requests `/api/*` hacia `pronto-api` en `:6082` sin alterar lógica de negocio.
- Prohibido en la excepción:
  - Validaciones/reglas de dominio.
  - Transformaciones semánticas de payload o estados de negocio.
  - Persistencia propia o side-effects de negocio fuera de `pronto-api`.
- Requisitos obligatorios:
  - Marcar implementación como `deprecated`.
  - Mantener trazabilidad (`X-Correlation-ID`) y headers de seguridad/csrf aplicables.
  - Definir plan de retiro explícito para volver a acceso canónico directo a `:6082/api/*`.

12.4.4 Excepción: Proxy SSR por consola (P0)
- Se permite proxy técnico scope-aware en `pronto-employees` para rutas `/<scope>/api/*`.
- Propósito: mantener sesiones JWT aisladas por consola (waiter/chef/cashier/admin/system).
- Implementación:
  - Blueprint `proxy_console_api` en `pronto-employees/src/pronto_employees/routes/api/proxy_console_api.py`.
  - Resuelve scope desde URL path (`/waiter/api/*` → scope=waiter).
  - Lee cookie namespaced `access_token_{scope}` y la propaga a `pronto-api:6082/api/*`.
  - Valida que JWT role coincida con scope (protección contra escalación horizontal).
  - Timeout máximo: 5s.
  - Propaga headers: `X-Correlation-ID`, `X-CSRFToken`, `Content-Type`, `Content-Length`.
  - Maneja streaming response y multipart/form-data.
- Restricciones:
  - Sin lógica de negocio.
  - Sin transformación de payload.
  - Sin modificación de status code (transparente).
- Deprecación: este proxy es transporte temporal hasta que Nginx/proxy externo resuelva scope-aware routing.
- Requisitos de seguridad:
  - Si `jwt_role != scope` → 403 SCOPE_MISMATCH.
  - Si scope inválido → 400 INVALID_SCOPE.

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
# Verificar que no haya <int:> en entidades UUID (excluyendo allowlist Integer)
rg -n --hidden "/<int:[a-z_]+_id>" pronto-employees/src/pronto_employees/routes/api/ | rg -v "waiter_calls|areas|roles|discount_codes|promotions|product_schedules|admin_shortcuts|notifications"
rg -n --hidden "/<int:[a-z_]+_id>" pronto-client/src/pronto_clients/routes/api/ | rg -v "waiter_calls|areas|roles|discount_codes|promotions|product_schedules|admin_shortcuts|notifications"
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
redis-keys.md
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
- Obligatorio: aplicar Regla de Recurrencia de Errores y Deuda Técnica (P0) en cada hallazgo.
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
Pronto-Init-Seed-Sync-Agent (P0)
Verifica sincronía estructural entre código persistente y `pronto-scripts/init/sql/**`.
En pre-commit pregunta/valida explícitamente si se ejecutaron `pronto-migrate --check` y `pronto-init --check`.
Bloquea commit si hay cambios estructurales sin actualización de init/migrations/seeds o sin confirmación requerida.
Pronto-Logging-Agent (P2)
current_app.logger o get_logger
No swallow exceptions
Pronto-Recurrence-Auditor-Agent (P0)
Valida que todo bug/deuda técnica se haya buscado transversalmente para detectar patrones repetidos.
Obligatorio por hallazgo:
- Evidencia de búsqueda global con `rg`
- Inventario de ocurrencias por archivo
- Estado por ocurrencia: corregido o pendiente con plan explícito
Salida:
STATUS: APPROVED|REJECTED
RECURRENCE_CHECK:
- Scope Covered: OK|FAIL
- Evidence Attached: OK|FAIL
- Similar Occurrences Addressed: OK|FAIL
VIOLATIONS:
Pronto-Zero-Technical-Debt-Agent (P0)
Enforcement de cierre limpio sin deuda ni legacy remanente.
Validaciones mínimas:
- No quedan `TODO|FIXME|HACK|TEMP` introducidos por el cambio.
- No quedan rutas/código legacy activos para el mismo flujo corregido.
- El fix quedó aplicado en todas las ocurrencias equivalentes detectadas.
Salida:
STATUS: APPROVED|REJECTED
ZERO_TECH_DEBT:
- Legacy Removed: OK|FAIL
- No Pending Workarounds: OK|FAIL
- Flow Fully Closed: OK|FAIL
VIOLATIONS:
Pronto-Responsive-UI-Agent (P1)
Valida que todo cambio de UI web sea responsive antes de commit.
Implementación canónica:
- `pronto-scripts/bin/pronto-responsive-check`
- Integración en hook: `pronto-scripts/bin/pre-commit-ai`
Cobertura mínima:
- `pronto-client/src/pronto_clients/templates/**`
- `pronto-static/src/static_content/assets/css/clients/**`
- `pronto-static/src/vue/clients/**`
Reglas:
- Detectar estilos rígidos (`px` fijos) sin estrategia responsive asociada.
- Detectar overlays/modales fixed sin ajustes móviles.
- Reportar sugerencias concretas de corrección (breakpoints, clamp/min/max, unidades fluidas).
Modo de bloqueo:
- Advertencia por defecto.
- Bloqueante si `PRONTO_RESPONSIVE_ENFORCE=1`.
Salida:
STATUS: APPROVED|WARNING|REJECTED
RESPONSIVE_RULES:
- Fluid Layout: OK|WARN|FAIL
- Breakpoints: OK|WARN|FAIL
- Modal Mobile Fit: OK|WARN|FAIL
SUGGESTIONS:
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

Pronto-AI-Audit-Orchestrator (P1)
- Registro declarativo: `pronto-prompts/registry.yml`
- Prompt maestro: `pronto-prompts/auditors/master/full_integrity_audit.md`
- Ejecuta auditoría completa o individual por agente.
- Script canónico: `./pronto-scripts/bin/pronto-ai-audit`

Auditores IA declarados (P1 salvo indicación explícita):
- `architecture_ownership_auditor`
- `api_scope_canon_auditor`
- `routes_only_auditor`
- `static_ownership_auditor`
- `frontend_backend_parity_auditor`
- `ui_render_selector_auditor`
- `asset_reference_integrity_auditor`
- `vue_ssr_integration_auditor`
- `scripts_runtime_parity_auditor`
- `code_integrity_auditor`
- `python_flask_quality_auditor`
- `vue_quality_auditor`
- `shell_script_quality_auditor`
- `dependency_vulnerability_auditor`
- `db_init_seed_parity_auditor` (P0 en cambios estructurales)
- `runtime_ddl_auditor` (P0 por hallazgo)
- `contract_completeness_auditor`
- `api_contract_snapshot_auditor`
- `security_guardrails_auditor` (P0 en hallazgos críticos)
- `validator_coverage_auditor`
- `test_obligation_auditor` (P0 si hay impacto crítico sin cobertura)
- `agents_sync_auditor`
- `readme_command_drift_auditor`

## 16.3 Herramientas de Auditoría (Ejecución Manual/CI)
- `pronto-full-audit.sh`: Orquestador de auditoría LLM integral. Utiliza prompts especializados por proyecto para detectar inconsistencias de negocio, estáticos prohibidos y deuda técnica.
- `pronto-inconsistency-check`: Script de validación rápida de invariantes locales (roles, versiones, sesiones).
- `pronto-audit/bin/run-audit.sh`: Interfaz de ejecución para el agente basado en CrewAI (requiere `.venv` interno con Python 3.12).
- `pronto-ai-audit`: Runner declarativo por registro (`pronto-prompts/registry.yml`) para auditoría completa o individual.
- `pronto-ai-audit-fast`: Perfil rápido de auditores críticos.
- `pronto-ai-audit-agent <id>`: Ejecuta un auditor individual.
- `pronto-ai-audit-report --in-dir <ruta>`: Reconstruye consolidado desde salidas individuales.
- `pronto-responsive-check`: Validador responsive para cambios frontend (warning por default, blocker con `PRONTO_RESPONSIVE_ENFORCE=1`).

## 16.4 Skills operativos obligatorios/recomendados para acelerar desarrollo (P1)

Regla general:
- Si un skill aplica claramente al tipo de tarea, el agente debe usar su enfoque/patrón de trabajo antes de improvisar.
- No usar un skill no sustituye guardrails P0/P1; los skills aceleran ejecución, no autorizan saltarse reglas.
- Si múltiples skills aplican, priorizar el de mayor reducción de riesgo primero y el de mayor velocidad de validación después.
- Si el usuario exige una corrección completa/end-to-end, usar los skills aplicables para cerrar el flujo entero en una sola línea de trabajo, no para justificar compatibilidades temporales o segmentaciones artificiales.

### Tier 1 — impacto inmediato (uso prioritario)

#### `plan-review` — OBLIGATORIO para planificación de trabajo no trivial
Usar cuando:
- se investiga un bug con múltiples archivos/superficies;
- se necesita un plan de implementación o remediación por fases;
- hay que priorizar lotes, riesgos, dependencias y validaciones;
- el trabajo toca más de un repo PRONTO o mezcla código + docs + scripts.

#### `senior-security` — OBLIGATORIO en auth, sesión, CSRF, JWT, permisos y rutas sensibles
Usar cuando:
- se modifican login/logout/refresh/me;
- se tocan cookies, headers auth, CSRF o JWT;
- se altera acceso a `/api/*`, SSR auth, proxies o scope enforcement;
- se revisan posibles bypasses, exposición de PII o endurecimiento de seguridad.

#### `flask-api-development` — OBLIGATORIO en cambios backend Flask
Usar cuando:
- se agregan o corrigen blueprints, endpoints, handlers o proxies técnicos Flask;
- se tocan request/response, serialización, errores HTTP o middleware;
- se modifican rutas en `pronto-api`, `pronto-client` SSR/BFF o `pronto-employees` SSR/proxy.

#### `playwright-cli` — OBLIGATORIO para smoke/regresión web ejecutable
Usar cuando:
- se necesita verificar flujos web reales de cliente o employees;
- se requiere reproducir bugs UI/SSR/auth en navegador;
- hay cambios en templates, navegación, modal flows, checkout, login o pago.

#### `playwright-skill` — RECOMENDADO para validación UX/E2E más rica
Usar cuando:
- además del smoke se necesita inspección visual, screenshots o validación paso a paso;
- hay regresiones de interacción, overlays, modales, tabs, responsive o accesibilidad percibida.

### Tier 2 — muy valiosos para estabilidad

#### `postgresql-database-engineering` — OBLIGATORIO en cambios estructurales o dudas de integridad DB
Usar cuando:
- se tocan modelos persistentes, constraints, índices, migrations o `pronto-scripts/init/sql/**`;
- hay drift entre ORM, schema y contratos SQL;
- se revisa rendimiento de queries o consistencia de datos/DDL.

#### `vueuse-functions` — RECOMENDADO en refactors Vue/composables
Usar cuando:
- se toca lógica reactiva en `pronto-static/src/vue/**`;
- hay duplicación de watchers/computed/event listeners/state sync;
- conviene extraer composables mantenibles en lugar de ampliar código ad hoc.

#### `ui-ux-expert` — RECOMENDADO para cambios de UI, responsive y accesibilidad
Usar cuando:
- se modifican pantallas, formularios, modales, layouts o navegación cliente/empleados;
- hay problemas de responsive, jerarquía visual, legibilidad o affordances;
- se requiere criterio UX, no solo que “compile”.

### Tier 3 — situacionales

#### `browser-use` — OPCIONAL para exploración guiada del navegador
Usar cuando:
- conviene automatizar inspección web ligera sin llegar a un test formal largo;
- se necesita capturar evidencia visual o recorrer manualmente un flujo repetitivo.

#### `ai-sdk` — OPCIONAL solo para features AI reales
Usar cuando:
- se construyen capacidades de IA, generación, agentes, RAG o tool-calling dentro del producto.

#### `find-skills` — OPCIONAL cuando falta una capacidad especializada
Usar cuando:
- el problema requiere una especialidad no cubierta por los skills ya definidos;
- se busca descubrir si existe un skill mejor que reduzca tiempo/riesgo.

### Mapa mínimo por repo
- `pronto-api`: `flask-api-development` + `senior-security`; añadir `postgresql-database-engineering` si toca persistencia; `plan-review` para bugs multiarchivo.
- `pronto-client`: `flask-api-development` + `senior-security` para BFF/SSR auth; `playwright-cli` para validación funcional; `ui-ux-expert` si toca templates/flujo visible.
- `pronto-employees`: `flask-api-development` + `senior-security` para scopes/JWT/proxy auth; `playwright-cli` para login por rol y consola.
- `pronto-static`: `playwright-cli` + `playwright-skill` para regresión; `vueuse-functions` y `ui-ux-expert` para refactors Vue y calidad UI.
- `pronto-tests`: `playwright-cli` prioritario para smoke/E2E; `plan-review` para curar suites mezcladas, duplicadas o frágiles.
- `pronto-scripts`: `plan-review` para lotes complejos de tooling; `postgresql-database-engineering` si toca init/migrations/schema; `senior-security` si el script afecta auth/guardrails.

### Orden recomendado de aplicación cuando hay duda
1. `plan-review`
2. `senior-security`
3. `flask-api-development`
4. `playwright-cli`
5. `playwright-skill`
6. `postgresql-database-engineering`
7. `vueuse-functions`
8. `ui-ux-expert`

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
Gate I: Init/Seeds Sync (P0)
Ejecutar (pre-commit obligatorio):
./pronto-scripts/bin/pronto-init-seed-review.sh

Si hay cambios estructurales y no hay actualización en `pronto-scripts/init/sql/**` o falta confirmación de validación (`PRONTO_INIT_SEED_VALIDATED=1`) ⇒ REJECTED
Gate J: Recurrencia Transversal de Hallazgos (P0)
Para cada bug/deuda técnica detectado:
- Ejecutar búsqueda transversal con `rg` para el patrón causal.
- Documentar ocurrencias similares y su estado (corregido/pendiente con plan).
Si no hay evidencia de búsqueda transversal o quedan ocurrencias críticas sin plan ⇒ REJECTED
Gate K: Responsive Web UI (P1)
Ejecutar:
./pronto-scripts/bin/pronto-responsive-check --staged
Resultado:
- Si hay warnings: registrar sugerencias y corregir antes de release.
- Si `PRONTO_RESPONSIVE_ENFORCE=1` y hay hallazgos ⇒ REJECTED
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

1. La navegación del cliente (catálogo/menú y vistas informativas) debe funcionar sin login.
2. El login/registro es obligatorio al primer intento de crear o confirmar una orden.
3. Prohibido realizar órdenes sin un usuario autenticado y una sesión activa.
4. El flujo de invitados (anonymous) es transicional hacia un registro o login obligatorio para finalizar checkout/pago.
5. **Caso Kiosko:** Se utilizará un usuario especial de tipo `kiosko`. Por ahora, su comportamiento y capacidades son idénticas a las de un usuario normal.

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
