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
15. Init/Migrations canónicos pre-boot (OBLIGATORIO):
    - `./pronto-scripts/bin/pronto-migrate --apply`
    - `./pronto-scripts/bin/pronto-init --check`
16. Separación dura Init vs Migrations:
    - Init: `pronto-scripts/init/sql/00_bootstrap..40_seeds` (idempotente, sin `ALTER/RENAME/backfills`)
    - Migrations: `pronto-scripts/init/sql/migrations/` (evolutivo: `ALTER/RENAME/backfills/seed changes`)
17. Reutilización: Antes de crear funcionalidad nueva, revisar `pronto-libs (pronto_shared)` y reutilizar ahí.
18. No cambios silenciosos en `docker-compose*` ni en `pronto-scripts/bin`.
19. Herramienta estándar de búsqueda: `rg`.
20. Python deps: cada servicio `pronto-*` debe tener una sola fuente de verdad en `requirements.txt` en la raíz del proyecto del servicio (sin duplicados bajo `src/`).
21. PostgreSQL canónico: **16-alpine**
22. Root PRONTO es workspace aggregator local. **No se pushea**.
- Versión versionada en: `pronto-scripts/pronto-root/`
- Ver sección 0.5.5 para flujo de versionado.
- Se pushean repos hijos `pronto-*`.

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
Router-Hash:
662348eb4422032402a7e7fe8fa09aabed72c579b2031bbf20d9db58678fdf72
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
19) REGLAS OPERATIVAS PARA CAMBIOS SENSIBLES (P0)
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
