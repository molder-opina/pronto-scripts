# Guía Maestra del Proyecto Pronto (Generado por Gemini)

Este documento consolida la información clave del proyecto a partir de `pronto-ai/AGENTS.md` y los archivos `README.md` de los subdirectorios.

---
# Contenido Principal (de pronto-ai/AGENTS.md)
---

# Development Principles

- **Reuse before Creation**: Before implementing a new function, always verify if a similar one already exists. If it exists, reuse, extend, or parameterize it.
- **Import Conventions**: **Always check `pronto_shared` first.** If a service, model, or utility exists in shared, import it from there. Do not duplicate logic in app-specific folders.
- **Modularization**: If a new function must be created, design it to be modular and reusable across the project. For shell scripts, extract reusable logic into `bin/lib/` libraries.
- **Shell Script Limits**: Maintain scripts below 300 lines. If they grow larger, modularize them using the shared helpers in `bin/lib/`.
- **Documentation**: All new reusable modules and significant shared functions must be documented in this file for future reference.

---

## Essential Rules (from AGENTS.md)

### Non-Negotiable Principles

1. **NO architecture changes** without explicit approval
2. **NO deleting databases or tables**
3. **NO touching PostgreSQL/Redis pods**
4. **NO Flask.session** (only allowlist in pronto-client: `dining_session_id`, `customer_ref`)
5. **JWT is immutable** for employee authentication
6. **ALL static assets** in pronto-static (NEVER local)
7. **Canonical roles**: `waiter`, `chef`, `cashier`, `admin`, `system`

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/nombre-funcionalidad

# Commit with semantic message
git commit -m "tipo(ámbito): descripción"

# Push
git push -u origin feature/nombre-funcionalidad
```

### Authentication & Scopes

- **Scopes**: `waiter`, `chef`, `cashier`, `admin`, `system`
- **ScopeGuard**: Required in `@bp.before_request` for blueprint protection
- **CSRF**: `X-CSRFToken` header mandatory for all mutations

### Error Tracking

- **New bug** → Create file: `pronto-docs/errors/YYYYMMDD_slug.md`
- **Resolved bug** → Move to `pronto-docs/resolved/`
- **Mandatory format** in each file

### API Rules

- All API endpoints: `/api/*`
- No `/{scope}/api/*` patterns
- CSRF token from `<meta name="csrf-token">`
- Run parity checks:
  ```bash
  ./pronto-scripts/bin/pronto-api-parity-check employees
  ./pronto-scripts/bin/pronto-api-parity-check clients
  ```

### Database & Migrations

- **Init scripts**: `pronto-scripts/init/sql/00_bootstrap..40_seeds`
- **Migrations**: `pronto-scripts/init/sql/migrations/`
- **Run migrations**: `./pronto-scripts/bin/pronto-migrate --apply`
- **NO DDL at runtime** in Flask apps

---


## Project Structure

```
pronto/
├── pronto-ai/              # AI agents, skills, and development tools
├── pronto-api/             # REST API service (Flask)
├── pronto-backups/         # Database backups
├── pronto-client/          # Customer-facing web app (Flask)
├── pronto-docs/            # Project documentation
├── pronto-employees/       # Employee dashboard (Flask)
├── pronto-libs/            # Shared library (pronto_shared) - CHECK HERE FIRST
├── pronto-postgresql/      # PostgreSQL container data
├── pronto-redis/           # Redis container data
├── pronto-scripts/         # Utility scripts for operations
├── pronto-static/          # Nginx + Vue 3 frontend assets
├── pronto-tests/           # E2E, integration, and unit tests
├── docker-compose.yml      # Main orchestration
├── docker-compose.*.yml    # Service-specific compose files
└── .env.example            # Environment template
```

---

## Application Overview

**Name:** Pronto Restaurant Management System

**Core Technologies:**
- **Backend:** Python 3.11+, Flask, SQLAlchemy, PostgreSQL, Redis
- **Frontend:** Vue.js 3, Vite, TypeScript, TailwindCSS
- **Infrastructure:** Docker, Docker Compose, Nginx

**Container Services:**

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| postgres | postgres:16-alpine | 5432 | Primary relational database |
| redis | redis:7-alpine | 6379 | Cache and message broker |
| client | pronto-client | 6080 | Customer-facing web app |
| employees | pronto-employees | 6081 | Staff management dashboard |
| api | pronto-api | 6082 | External API service |
| static | pronto-static | 9088 | Nginx server for static content |

---

## Scripts & Operations

### bin/ Directory Structure (143 scripts)

```
bin/
├── *.sh (51)              # Main operation scripts
├── lib/ (6)               # Shared shell libraries
├── agents/ (15)           # Pre-commit validation agents
├── init/ (8)              # Initialization scripts
├── mac/ (11)              # macOS-specific scripts
├── python/ (19)           # Python utilities
├── maintenance/ (3)       # Migration and maintenance
└── tests/ (6)             # Testing scripts
```

### Lifecycle Scripts

| Script | Purpose |
|--------|---------|
| `bin/up.sh` | Start the full application stack |
| `bin/down.sh` | Stop and remove all containers |
| `bin/rebuild.sh` | Primary update script (build + restart) |
| `bin/restart.sh` | Restart containers without rebuilding |
| `bin/status.sh` | Display running containers and URLs |
| `bin/build.sh` | Build Docker images only |

### Shared Libraries (bin/lib/)

| Library | Purpose |
|---------|---------|
| `build_helpers.sh` | Build and dependency preparation (TS, Python wheels) |
| `cleanup_helpers.sh` | Container and image removal functions |
| `docker_runtime.sh` | Docker/Podman runtime abstraction |
| `os_detect.sh` | Operating system detection |
| `stack_helpers.sh` | Stack management and service discovery |
| `static_helpers.sh` | Static content sync and validation |

### Database Scripts

| Script | Purpose |
|--------|---------|
| `bin/postgres-backup.sh` | Create database backup |
| `bin/postgres-restore.sh` | Restore from backup |
| `bin/postgres-shell.sh` | Open psql shell |
| `bin/cleanup-old-sessions.sh` | Remove old session data |
| `bin/validate-seed.sh` | Health check and seed provisioning |

### Python Utilities (bin/python/)

| Script | Purpose |
|--------|---------|
| `check-employees.py` | Verify employee records |
| `clean-orders.py` | Clean order data |
| `create-test-data.py` | Generate test data |
| `fix-*.py` | Various data fixes |
| `validate-database.py` | Database validation |

### Typical Workflows

```bash
# Start fresh
bin/down.sh && bin/up.sh --seed

# Apply code changes
bin/rebuild.sh

# Apply config changes only
bin/restart.sh

# Verify health
bin/status.sh && bin/test-all.sh

# macOS specific
bin/mac/rebuild.sh
bin/mac/status.sh
```

---

## Shared Library (pronto_shared)

**Location:** `pronto-libs/src/pronto_shared/`

### Core Modules

| Module | Purpose |
|--------|---------|
| `config.py` | Configuration management |
| `db.py` | Database engine and sessions |
| `models.py` | SQLAlchemy ORM models |
| `extensions.py` | Flask extensions |
| `constants.py` | Global constants |

### Security & Authentication

| Module | Purpose |
|--------|---------|
| `jwt_service.py` | JWT generation and validation |
| `jwt_middleware.py` | JWT decorators and helpers |
| `scope_guard.py` | Scope isolation |
| `permissions.py` | Permission system |
| `security.py` | General security utilities |
| `security_middleware.py` | Security middleware |
| `auth/service.py` | Authentication service |

### Services (35+ modules)

**Order Management:**
- `order_service.py` - Core order operations
- `order_modification_service.py` - Order modifications
- `order_state_machine.py` - Order state transitions
- `cancel_order_service.py` - Order cancellation

**Menu & Products:**
- `menu_service.py` - Menu management
- `menu_validation.py` - Menu validation
- `price_service.py` - Price calculations

**Payments:**
- `payments.py` - General payment logic
- `payment_providers/` - Provider implementations
  - `base_provider.py`, `cash_provider.py`, `clip_provider.py`, `stripe_provider.py`

**Users & Roles:**
- `employee_service.py` - Employee management
- `customer_service.py` - Customer management
- `role_service.py` - Role management
- `custom_role_service.py` - Custom roles

**Notifications:**
- `notification_service.py` - Notifications
- `notification_stream_service.py` - SSE streaming

**Business:**
- `business_config_service.py` - Business configuration
- `business_info_service.py` - Business information
- `area_service.py` - Area management
- `settings_service.py` - Settings

**Other Services:**
- `email_service.py`, `image_service.py`, `ai_image_service.py`
- `analytics_service.py`, `recommendation_service.py`
- `feedback_service.py`, `report_export_service.py`
- `ticket_pdf_service.py`, `waiter_call_service.py`
- `seed.py` - Database seeding

### Utilities

| Module | Purpose |
|--------|---------|
| `datetime_utils.py` | Date/time utilities |
| `serializers.py` | Data serialization |
| `validation.py` | Input validation |
| `utils.py` | General utilities |
| `error_handlers.py` | Error handling |
| `error_catalog.py` | Error definitions |
| `logging_config.py` | Logging configuration |

### Orchestrator (AI/ML)

Located in `pronto_shared/orchestrator/`:
- `orchestrator.py` - Main orchestrator
- `classifier.py` - Classification logic
- `router.py` - Request routing
- `memory.py` - Memory management
- `ollama_client.py` - Ollama integration

---

## Architecture & Security

### JWT Authentication (Stateless)

The system uses **JWT (JSON Web Tokens)** for stateless authentication for employee applications.

**Token Types:**

| Token | Duration | Contains |
|-------|----------|----------|
| Access Token | 24 hours | employee_id, name, email, role, additional_roles, active_scope |
| Refresh Token | 7 days | employee_id only |

**Available Decorators:**

```python
from pronto_shared.jwt_middleware import jwt_required, scope_required, role_required, admin_required
from pronto_employees.decorators import login_required, web_login_required, web_role_required

# API routes (returns JSON)
@jwt_required              # Requires valid JWT
@scope_required("waiter")  # Requires specific scope
@role_required(["waiter", "cashier"])  # Requires one of these roles
@admin_required            # Requires admin or system role

# Web routes (redirects to login)
@web_login_required        # Redirects if not authenticated
@web_role_required(["admin", "system"])  # Redirects if wrong role
```

**Usage Examples:**

```python
from pronto_shared.jwt_middleware import get_current_user, get_employee_id, get_employee_role

user = get_current_user()      # Full JWT payload
employee_id = get_employee_id()  # Just the ID
role = get_employee_role()     # Just the role
```

**Scope Guard:**

Routes are protected by scope isolation:
- `/waiter/api/*`, `/chef/api/*`, `/cashier/api/*`, `/admin/api/*`, `/system/api/*`
- Middleware validates that `jwt.active_scope` matches the URL scope

### CRITICAL: No Flask Session for Employee Auth

```python
# ❌ NEVER for employee auth:
from flask import session
session.get("employee_id")      # DON'T DO THIS
session.get("employee_role")    # DON'T DO THIS
session.clear()                 # DON'T DO THIS for logout

# ✅ ALWAYS use JWT helpers:
from pronto_shared.jwt_middleware import get_employee_id
employee_id = get_employee_id()

# ✅ For logout, delete cookies:
response.delete_cookie("access_token", path="/")
response.delete_cookie("refresh_token", path="/")

# ✅ OK for client-facing:
session.get("customer_id")      # Client authentication is OK
```

**Flask session may ONLY be used for:**
- SQLAlchemy database sessions (`db_session.get(Model, id)`)
- Client-facing web sessions (`session.get("customer_id")`)
- Flash messages (in web routes only)

---

## Frontend (pronto-static)

### Structure

```
pronto-static/
├── src/vue/
│   ├── clients/           # Customer app
│   │   ├── components/    # Vue components
│   │   ├── core/          # Core logic
│   │   ├── entrypoints/   # Entry points
│   │   ├── modules/       # Feature modules
│   │   ├── store/         # Pinia store
│   │   └── types/         # TypeScript types
│   ├── employees/         # Employee app (same structure)
│   └── shared/            # Shared code
│       ├── components/    # Global components
│       ├── domain/        # Domain logic
│       ├── lib/           # Libraries
│       ├── types/         # Shared types
│       └── utils/         # Utilities
├── static_content/assets/ # Compiled assets
├── vite.config.ts
├── tsconfig.json
└── package.json
```

### Build Commands

```bash
npm run dev:employees      # Dev server for employees
npm run dev:clients        # Dev server for clients
npm run build              # Build both targets
npm run build:employees    # Build employees only
npm run build:clients      # Build clients only
npm run lint               # ESLint
npm run format             # Prettier
```

### Static Content Variables

Use short variables in templates, NOT hardcoded URLs:

```html
<!-- ✅ CORRECT -->
<link rel="stylesheet" href="{{ assets_css_clients }}/menu.css">
<script src="{{ assets_js_employees }}/main.js"></script>

<!-- ❌ INCORRECT -->
<link rel="stylesheet" href="{{ pronto_static_container_host }}/assets/css/clients/menu.css">
```

**Available Variables:**

| Variable | Example URL |
|----------|-------------|
| `assets_css` | `http://localhost:9088/assets/css` |
| `assets_css_clients` | `http://localhost:9088/assets/css/clients` |
| `assets_css_employees` | `http://localhost:9088/assets/css/employees` |
| `assets_js` | `http://localhost:9088/assets/js` |
| `assets_js_clients` | `http://localhost:9088/assets/js/clients` |
| `assets_js_employees` | `http://localhost:9088/assets/js/employees` |
| `assets_images` | `http://localhost:9088/assets/pronto` |

---

## Testing & Validation

### Test Structure (pronto-tests/)

```
pronto-tests/
├── tests/
│   ├── design/            # Visual and accessibility tests
│   ├── functionality/
│   │   ├── api/           # API tests (pytest)
│   │   ├── e2e/           # End-to-end tests
│   │   ├── integration/   # Integration tests
│   │   ├── ui/            # UI tests (Playwright)
│   │   └── unit/          # Unit tests
│   └── performance/       # Performance tests
├── e2e/                   # Additional E2E tests
├── unit/                  # Additional unit tests
├── scripts/               # Test utilities
└── playwright.config.ts
```

### Test Commands

```bash
# All tests
./run-all-tests.sh

# Backend
pytest

# Frontend
npm run test              # Vitest

# E2E
npm run test (in pronto-tests/)

# Security
make security-scan        # Bandit, Semgrep, Gitleaks
make check-all            # All linters and security
```

### Quality Mandate: No Test, No Feature

Every new functionality MUST be accompanied by tests:
- **Unit tests:** `tests/functionality/unit/`
- **Integration tests:** `tests/functionality/integration/`
- **E2E tests:** `tests/functionality/e2e/`

---

## Pre-commit Agents (bin/agents/)

The project includes 15 specialized automated agents that verify code quality:

| Agent | Purpose | Checks |
|-------|---------|--------|
| `developer.sh` | General development | TODOs, print(), static asset variables |
| `designer.sh` | Design quality | Images >1MB, CSS !important, missing alt tags |
| `db_specialist.sh` | Database | Migration naming, destructive SQL warnings |
| `sysadmin.sh` | System security | .env files, Dockerfile USER, shell shebangs |
| `qa_tester.sh` | Test quality | Focused tests (.only, fit, fdescribe) |
| `scribe.sh` | Documentation | TODO markers, critical files |
| `container_specialist.sh` | Docker | latest tags, apt-get cleanup, HEALTHCHECK |
| `business_expert.sh` | Domain | Key terms, currency formatting |
| `waiter_agent.sh` | Waiter module | Templates, table assignment |
| `admin_agent.sh` | Admin module | Admin modules, permissions |
| `cashier_agent.sh` | Cashier module | Payment modules, providers |
| `chef_agent.sh` | Chef module | KDS, order state transitions |
| `system_agent.sh` | Security | Global security, ScopeGuard |
| `deployment_agent.sh` | Deployment | Deployment validation |
| `audit_agent.sh` | Multi-model audit | Claude, Minimax, GLM4 review |

**Run manually:**

```bash
./bin/agents/developer.sh
pre-commit run agent-developer --all-files

# Multi-model audit
./bin/agents/audit_agent.sh --all-files
```

---

## Database Safety

### Protected Tables

**Never execute DELETE, TRUNCATE, or DROP directly on:**
- `pronto_menu_categories` (12 categories)
- `pronto_menu_items` (94 products)
- `pronto_employees` (10 employees)

### Safe Cleanup

```bash
# Session cleanup only (preserves menu data)
bin/cleanup-old-sessions.sh

# Specific cleanup (orders, sessions, notifications only)
python scripts/maintenance/clean_db.py
```

### Re-seed Data

```bash
docker exec pronto-employee python3 -c "
import sys
sys.path.insert(0, '/opt/pronto/build')
from pronto_shared.config import load_config
from pronto_shared.db import get_session, init_engine
from pronto_shared.services.seed import load_seed_data
config = load_config('employee')
init_engine(config)
with get_session() as session:
    load_seed_data(session)
    session.commit()
"
```

---

## Utility Scripts (scripts/)

### Directory Structure

```
scripts/
├── *.py, *.sh, *.sql      # General utilities (migrations, seeding)
├── maintenance/           # Database maintenance (19 scripts)
│   ├── check_*.py         # Diagnostic scripts
│   ├── clean_*.py         # Cleanup operations
│   ├── fix_*.py           # Data fix scripts
│   └── list_*.py          # Query scripts
├── qa/                    # QA automation (19 scripts)
│   ├── qa_*.py            # QA automation
│   ├── test_*.py          # Test scripts
│   └── run_tests.py       # Test runner
└── sql/                   # SQL migrations (10+ files)
    └── *.sql              # Schema changes
```

### Common Commands

```bash
# Migrations
python scripts/apply_*.py
python scripts/migrate_*.py

# Maintenance
python scripts/maintenance/check_db.py
python scripts/maintenance/clean_db.py
python scripts/maintenance/fix_*.py

# QA
python scripts/qa/qa_full_cycle.py
python scripts/qa/test_*.py

# Seeding
python scripts/seed_*.py
```

---

## Employee Portal Roles

| Role | Purpose |
|------|---------|
| Admin | Full system management |
| Cashier | Payment processing |
| Chef | Kitchen display system (KDS) |
| Waiter | Table service and order taking |
| System | Super admin functions |

---

## Code Quality Standards

### Python
- Line length: 100 characters
- Linter: `ruff`
- Formatter: `black` or `ruff format`
- Type checker: `mypy`
- Security: `bandit`
- Type hints required for new code

### JavaScript/TypeScript
- Node >= 20.0.0
- Linter: `eslint`
- Formatter: `prettier`
- Vue 3 with TypeScript
- Vite for building

---

## Git Workflow

- **Pre-Commit Review:** Always review changes (`git status`, `git diff`) before staging.
- **Documentation Sync:** Update this file when introducing new patterns, scripts, or modules.
- **Agent Validation:** Pre-commit hooks run automatically; fix all errors before committing.

---

## Environment Configuration

### Key Variables (.env.example)

```bash
# Database
POSTGRES_HOST=pronto-postgres
POSTGRES_PORT=5432
POSTGRES_USER=pronto
POSTGRES_PASSWORD=pronto123

# Cache
REDIS_HOST=pronto-redis
REDIS_PORT=6379

# JWT
JWT_ACCESS_TOKEN_EXPIRES_HOURS=24
JWT_REFRESH_TOKEN_EXPIRES_DAYS=7

# Restaurant
RESTAURANT_NAME="Cafetería de Prueba"
TAX_RATE=0.16
CURRENCY=MXN

# Static Content
PRONTO_STATIC_CONTAINER_HOST=http://localhost:9088
```

---

**Last Updated:** 2026-02-02
**Maintainers:** Development Team

---
# Anexo: Contenido de `pronto-backups/README.md`
---
# Pronto Backups

Database backup scripts and utilities for Pronto system.

## Warning

**DO NOT commit actual backup files to this repository.**

All `.sql`, `.dump`, `.gz`, and backup files are ignored via `.gitignore`.

## Usage

### Manual Backup

```bash
# PostgreSQL backup
pg_dump -U pronto -h localhost pronto > backup_$(date +%Y%m%d).sql

# Compressed backup
pg_dump -U pronto -h localhost pronto | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Restore

```bash
# From SQL file
psql -U pronto -h localhost pronto < backup.sql

# From compressed file
gunzip -c backup.sql.gz | psql -U pronto -h localhost pronto
```

## Backup Strategy

1. **Daily** - Automated daily backups
2. **Weekly** - Full database dumps
3. **Pre-deployment** - Before major releases

## Change Backups (Required)

Estructura canónica:

```
pronto-backups/
  changes/
    CHG-YYYYMMDD-HHMMSS-gitshort/
      meta/           # Metadatos del cambio (agent, razón, timestamp, etc.)
      patch/          # Parches SQL aplicados
      files/          # Archivos de código modificados (diffs, copies)
      db/             # Backup de datos específicos del cambio
      logs/           # Logs del proceso de backup/restauración
```

Ejemplo de estructura completa:

```
CHG-20260202-150000-a1b2c3d/
  meta/
    agent.txt          # Nombre del agente que hizo el cambio
    reason.txt         # Razón del cambio
    timestamp.txt      # Timestamp del cambio
    git_commit.txt     # Commit hash relacionado
  patch/
    migrations/        # Migraciones SQL aplicadas
    data_fixes/        # Fix de datos aplicados
  files/
    pronto-employees/ # Archivos modificados por rol
    pronto-api/        # Archivos modificados por rol
    pronto-static/      # Archivos de frontend
  db/
    pre_change.sql     # Estado DB antes del cambio
    post_change.sql    # Estado DB después del cambio
  logs/
    backup.log         # Log del proceso de backup
    restore.log       # Log del proceso de restauración
```

Comandos:

```bash
# Crear backup de cambio
./pronto-scripts/bin/pronto-backup-change --reason "Descripción del cambio" --agent "NombreAgente"

# Restaurar desde un cambio específico
./pronto-scripts/bin/pronto-restore-change CHG-YYYYMMDD-HHMMSS-gitshort

# Limpieza de backups antiguos (garbage collection)
./pronto-scripts/bin/pronto-backups-gc
```

Flujo de trabajo recomendado:

1. **Antes del cambio:**
   ```bash
   # Crear punto de referencia
   ./pronto-scripts/bin/pronto-backup-change --reason "Preparación para feature X" --agent "Dev"
   ```

2. **Después del cambio exitoso:**
   ```bash
   # Confirmar el cambio con post-backup
   ./pronto-scripts/bin/pronto-backup-change --reason "Feature X completada" --agent "Dev"
   ```

3. **Si hay rollback necesario:**
   ```bash
   # Restaurar al estado anterior
   ./pronto-scripts/bin/pronto-restore-change CHG-YYYYMMDD-HHMMSS-gitshort
   ```

## DB Dump Policy

- Default: schema-only (`pg_dump --schema-only`)
- Data dumps: requieren confirmación explícita

## Storage

Backups should be stored in:
- Cloud storage (S3, GCS)
- Off-site backup server
- NOT in this repository

---
# Anexo: Contenido de `pronto-scripts/README.md`
---
# Pronto Scripts

Utility scripts and tools for Pronto development and operations.

## Structure

```
pronto-scripts/
├── bin/              # Executable scripts
├── scripts/          # Utility scripts
├── pronto-api/       # API-specific scripts
└── INCONSISTENCIAS.md
```

## Available Scripts

### Development

```bash
# Run all services
./bin/up.sh

# Run all services in debug mode
./bin/up-debug.sh

# Start services
./bin/start.sh

# Stop services
./bin/stop.sh

# Down services (stop and remove containers)
./bin/down.sh

# Restart services
./bin/restart.sh

# Build Docker images
./bin/build.sh

# Rebuild and restart
./bin/rebuild.sh
```

### Database

```bash
# Start PostgreSQL
./bin/postgres-up.sh

# Stop PostgreSQL
./bin/postgres-down.sh

# PostgreSQL status
./bin/postgres-status.sh

# Open PostgreSQL shell
./bin/postgres-psql.sh

# View PostgreSQL logs
./bin/postgres-logs.sh

# Backup database
./bin/postgres-backup.sh

# Restore database
./bin/postgres-restore.sh

# Rebuild PostgreSQL
./bin/postgres-rebuild.sh

# Apply migration
./bin/apply_migration.sh

# Apply migration with compose
./bin/apply_migration_compose.sh
```

### Seed & Test Data

```bash
# Check seed status
./bin/check-seed-status.sh

# Validate seed
./bin/validate-seed.sh

# Interactive seed
./bin/seed-interactive.sh
```

### Deployment

```bash
# Deploy to staging
./scripts/deploy-staging.sh

# Deploy to production
./scripts/deploy-prod.sh
```

## Usage

Most scripts can be run from the repository root:

```bash
./pronto-scripts/bin/script-name.sh
```

## Adding New Scripts

1. Place script in appropriate folder (`bin/` for executables, `scripts/` for utilities)
2. Make executable: `chmod +x script-name.sh`
3. Add documentation in this README
4. Include error handling and help text

## Environment

Scripts may require environment variables from `.env`:

```bash
source .env
./pronto-scripts/bin/script.sh
```

---
# Anexo: Contenido de `pronto-client/README.md`
---
# Pronto Client

Customer-facing web application for Pronto restaurant system.

## Requirements

- Python 3.11+
- pronto-shared library
- pronto-static assets

## Installation

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Development

```bash
cd src/pronto_clients
flask run --port 5000
```

## Docker

```bash
# Build
docker compose build client

# Run (requires static and infra services)
docker compose --profile apps up client
```

## Project Structure

```
pronto-client/
└── src/
    └── pronto_clients/
        ├── app.py           # Flask application
        ├── routes/          # Route blueprints
        ├── services/        # Business logic
        ├── templates/       # Jinja2 templates
        ├── utils/           # Utility functions
        ├── requirements.txt
        ├── Dockerfile
        └── wsgi.py
```

## Features

- Digital menu browsing
- Cart and order placement
- Order tracking
- Payment processing
- Customer profile management

## Dependencies

- `pronto-shared>=1.0.0` - Shared models and services
- `gunicorn>=21.2.0` - WSGI server

## Environment Variables

See `.env.example` in the root directory for required configuration.

---
# Anexo: Contenido de `pronto-docs/README.md`
---
# Pronto Docs Index

| Módulo | Doc | Contratos | Compose | Tests | Owner | Estado |
|---|---|---|---|---|---|---|
| pronto-api | pronto-docs/pronto-api/README.md | pronto-docs/contracts/pronto-api | docker-compose.yml, docker-compose.api.yml | pronto-tests/scripts/run-tests.sh functionality | equipo-api | OK |
| pronto-clients | pronto-docs/pronto-clients/README.md | pronto-docs/contracts/pronto-clients | docker-compose.yml, docker-compose.client.yml | pronto-tests/scripts/run-tests.sh functionality | equipo-client | OK |
| pronto-employees | pronto-docs/pronto-employees/README.md | pronto-docs/contracts/pronto-employees | docker-compose.yml, docker-compose.employees.yml | pronto-tests/scripts/run-tests.sh functionality | equipo-employees | OK |
| pronto-static | pronto-docs/pronto-static/README.md | pronto-docs/contracts/pronto-static | docker-compose.yml | pronto-tests/scripts/run-tests.sh design | equipo-frontend | OK |
| pronto-libs | pronto-docs/pronto-libs/README.md | pronto-docs/contracts/pronto-libs | n/a | pronto-tests/scripts/run-tests.sh unit | equipo-platform | OK |
| pronto-postgresql | pronto-docs/pronto-postgresql/README.md | pronto-docs/contracts/pronto-postgresql | docker-compose.yml, docker-compose.infra.yml | n/a | equipo-infra | OK |
| pronto-redis | pronto-docs/pronto-redis/README.md | pronto-docs/contracts/pronto-redis | docker-compose.yml, docker-compose.infra.yml | n/a | equipo-infra | OK |
| pronto-scripts | pronto-docs/pronto-scripts/README.md | pronto-docs/contracts/pronto-scripts | n/a | n/a | equipo-platform | OK |
| pronto-tests | pronto-docs/pronto-tests/README.md | pronto-docs/contracts/pronto-tests | docker-compose.tests.yml | n/a | equipo-qa | OK |
| pronto-docs | pronto-docs/pronto-docs/README.md | pronto-docs/contracts/pronto-docs | n/a | n/a | equipo-platform | OK |
| pronto-ai | pronto-docs/pronto-ai/README.md | pronto-docs/contracts/pronto-ai | n/a | n/a | equipo-platform | OK |
| pronto-backups | pronto-docs/pronto-backups/README.md | pronto-docs/contracts/pronto-backups | n/a | n/a | equipo-platform | OK |

---
# Anexo: Contenido de `pronto-tests/README.md`
---
# Estructura del Proyecto de Pruebas PRONTO

```
pronto-tests/
├── scripts/
│   └── run-tests.sh          # Script principal para ejecutar pruebas
├── tests/
│   ├── functionality/
│   │   ├── api/              # Pruebas de API (Pytest)
│   │   │   ├── test_auth_api.py
│   │   │   ├── test_jwt_*.py
│   │   │   └── ...
│   │   ├── ui/               # Pruebas de UI (Playwright)
│   │   │   ├── clients/
│   │   │   ├── employees/
│   │   │   └── *.spec.ts
│   │   ├── e2e/              # Pruebas End-to-End
│   │   │   ├── test_e2e_*.py
│   │   │   └── *.cjs
│   │   ├── unit/             # Pruebas Unitarias
│   │   │   └── test_*.py
│   │   └── integration/      # Pruebas de Integración
│   │       └── test_*.py
│   ├── performance/          # Pruebas de Performance
│   │   ├── performance.spec.ts
│   │   ├── benchmarks.spec.ts
│   │   └── performance-report.md
│   └── design/               # Pruebas de Diseño
│       ├── design-visual.spec.ts
│       ├── accessibility.spec.ts
│       ├── screenshots/      # Screenshots capturados
│       │   └── *.png
│       └── reports/          # Reportes de análisis
│           ├── design-report.md
│           └── accessibility-report.md
├── bin/                      # Scripts legacy
├── playwright.config.ts      # Configuración de Playwright
└── README.md
```

## Uso

### Ejecutar todas las pruebas
```bash
./scripts/run-tests.sh all
```

### Solo funcionalidad
```bash
./scripts/run-tests.sh functionality
```

### Solo performance
```bash
./scripts/run-tests.sh performance
```

### Solo diseño (con screenshots)
```bash
./scripts/run-tests.sh design
```

## Pruebas de Diseño

Las pruebas de diseño toman screenshots de las pantallas y los analizan con OpenCode AI:

1. **Screenshots capturados**: `tests/design/screenshots/`
2. **Reporte generado**: `tests/design/reports/design-report.md`

### Pantallas analizadas:
- Login
- Menú del cliente
- Creación de orden
- Panel del empleado
- Gestión de órdenes
- Checkout
- Confirmación de orden

## Requisitos

- Node.js 18+
- Python 3.11+
- Playwright (`npx playwright install`)
- OpenCode CLI (para análisis de diseño)

---
# Anexo: Contenido de `pronto-postgresql/README.md`
---
# Pronto PostgreSQL

Docker Compose configuration for PostgreSQL 16.

## Quick Start

```bash
cp .env.example .env
docker-compose up -d
```

## Configuration

Edit `.env` to customize:
- PostgreSQL credentials
- Network settings
- Application settings

## Services

- **PostgreSQL**: `postgres:16-alpine` on port 5432

---
# Anexo: Contenido de `pronto-employees/README.md`
---
# Pronto Employees

Employee portal for the Pronto restaurant management system.

## Overview

This service provides web interfaces for restaurant staff:

- **Admin** - Full system management, reports, configuration
- **Cashier** - Payment processing, order completion
- **Chef** - Kitchen order management, preparation tracking
- **Waiter** - Table service, order taking, customer requests
- **System** - Super admin functions, cross-scope access

## Requirements

- Python 3.11+
- PostgreSQL (via pronto-postgresql)
- Redis (via pronto-redis)
- pronto-shared library

## Development

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -e ../pronto-libs
pip install -r requirements.txt

# Run development server
cd src/pronto_employees
flask run --port 6081
```

## Docker

```bash
# Build
docker compose build employees

# Run
docker compose --profile apps up employees

# Access
open http://localhost:6081/admin/login
```

## Structure

```
pronto-employees/
├── src/
│   └── pronto_employees/
│       ├── routes/           # Blueprint routes by role
│       │   ├── admin/        # Admin dashboard & auth
│       │   ├── cashier/      # Cashier interface
│       │   ├── chef/         # Kitchen interface
│       │   ├── waiter/       # Waiter interface
│       │   ├── system/       # System admin
│       │   └── api/          # Internal API endpoints
│       ├── services/         # Business logic
│       ├── templates/        # Jinja2 templates
│       ├── app.py            # Flask application factory
│       ├── wsgi.py           # WSGI entry point
│       ├── requirements.txt  # Python dependencies
│       └── Dockerfile        # Container build
└── tools/                    # Development utilities
```

## Authentication

Uses JWT tokens stored in HTTP-only cookies:
- `access_token` - Short-lived access token
- `refresh_token` - Long-lived refresh token

Role-based access control restricts routes by employee scope.

## Environment Variables

Required environment variables are defined in the root `.env` file:
- `DATABASE_URL` - PostgreSQL connection
- `REDIS_URL` - Redis connection
- `SECRET_KEY` - Flask secret key
- `JWT_SECRET_KEY` - JWT signing key

---
# Anexo: Contenido de `pronto-redis/README.md`
---
# Pronto Redis

Redis configuration and utilities for Pronto system.

## Requirements

- Redis 7+

## Docker

```bash
# Start Redis
docker compose --profile infra up redis

# Access Redis CLI
docker compose exec redis redis-cli
```

## Usage

Redis is used in Pronto for:
- Session storage
- Cache layer
- Real-time notifications (pub/sub)
- Rate limiting
- Background job queues

## Key Patterns

```
# Sessions
session:{session_id}

# Cache
cache:menu:{restaurant_id}
cache:orders:{date}

# Pub/Sub channels
notifications:{restaurant_id}
orders:{table_id}

# Rate limiting
ratelimit:{ip}:{endpoint}
```

## Configuration

Default connection:
- Host: `localhost` (or `redis` in Docker)
- Port: `6379`
- Database: `0`

## Monitoring

```bash
# Monitor all commands
redis-cli MONITOR

# Get info
redis-cli INFO

# Check memory
redis-cli INFO memory
```

## Data Persistence

Production configuration should include:
- RDB snapshots
- AOF persistence
- Regular backups

---
# Anexo: Contenido de `pronto-ai/README.md`
---
# Pronto AI

AI agents and automation tools for Pronto development.

## Contents

- `AGENTS.md` - Documentation for AI coding agents
- `skills/` - Custom skills for Claude Code and other AI tools

## Usage

This folder contains configuration and documentation for AI-assisted development:

### Claude Code Skills

Skills in `skills/` folder can be loaded by Claude Code for:
- Code generation
- Automated refactoring
- Documentation generation
- Testing assistance

### Agent Configuration

See `AGENTS.md` for detailed agent configuration and usage patterns.

## Structure

```
pronto-ai/
├── AGENTS.md              # Agent documentation
├── skills/                # Custom AI skills
└── recreate-full-docs.txt # Documentation generation notes
```

---
# Anexo: Contenido de `pronto-api/README.md`
---
# Pronto API

REST API backend for Pronto restaurant management system.

## Requirements

- Python 3.11+
- PostgreSQL 16
- Redis 7

## Installation

```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Development

```bash
# Run with Flask dev server
flask run --port 5000

# Run with Gunicorn
gunicorn -b 0.0.0.0:5000 wsgi:application
```

## Docker

```bash
# Build
docker compose build api

# Run
docker compose --profile apps up api
```

## Project Structure

```
pronto-api/
├── src/
│   └── api_app/
│       ├── app.py          # Flask application factory
│       └── wsgi.py         # WSGI entry point
├── requirements.txt
└── Dockerfile
```

## Dependencies

- `pronto-shared` - Shared library with models and services
- `gunicorn` - WSGI HTTP Server

## API Endpoints

The API provides endpoints for:
- Orders management
- Menu and products
- Tables and areas
- Employee operations
- Customer sessions
- Payments processing

## Environment Variables

See `.env.example` in the root directory for required configuration.

---
# Anexo: Contenido de `pronto-static/README.md`
---
# Pronto Static Assets

Container nginx que sirve assets estáticos (CSS, JS, imágenes) compilados desde Vue.

## Estructura

```
src/
├── static_content/           # Archivos estáticos (servidos por nginx)
│   ├── Dockerfile            # Build: compila Vue → nginx
│   ├── nginx.conf            # Configuración nginx
│   ├── index.html
│   ├── styles.css
│   └── assets/               # Assets compilados y recursos
│       ├── css/
│       │   ├── shared/       # ✅ CSS compartido (base, components, utilities)
│       │   │   ├── base.css
│       │   │   ├── components.css
│       │   │   └── utilities.css
│       │   ├── employees/    # CSS específico de employees
│       │   └── clients/      # CSS específico de clients
│       ├── js/               # JavaScript compilado (output de Vite)
│       │   ├── employees/     # Output de vite build --target employees
│       │   └── clients/      # Output de vite build --target clients
│       ├── pronto/            # ✅ Branding y assets del sistema
│       │   ├── branding/     # Branding por restaurante
│       │   ├── menu/         # Assets de menú
│       │   ├── products/     # Assets de productos
│       │   └── avatars/      # Avatares
│       ├── images/           # Imágenes generales
│       ├── audio/            # Audio
│       └── lib/              # Librerías estáticas (UMD/min)
│
└── vue/                      # Fuentes TypeScript/Vue
    ├── shared/               # ✅ Código compartido (TypeScript)
    │   ├── lib/              # Utilidades (formatting, constants)
    │   ├── domain/           # Lógica de dominio (table-code)
    │   ├── types/            # TypeScript types compartidos
    │   ├── utils/            # Composables/ayudantes (useToggle, useFetch, etc.)
    │   └── components/       # Componentes Vue compartidos
    ├── employees/            # App Vue Employees
    │   ├── components/
    │   ├── core/
    │   ├── modules/
    │   └── entrypoints/
    └── clients/              # App Vue Clients
        ├── components/
        ├── core/
        ├── modules/
        ├── entrypoints/
        ├── store/
        └── types/
```

## Código Compartido

### TypeScript/Vue Shared (`src/vue/shared/`)

Utilidades y lógica compartida entre employees y clients:

```typescript
// Importar en cualquier app
import { formatCurrency, formatDateTime } from '@shared/lib';
import { buildTableCode, parseTableCode } from '@shared/domain';
import { OrderStatus, TableType } from '@shared/types';
```

**Contenido:**
- `lib/` - Utilidades generales (formatCurrency, constants)
- `domain/` - Lógica de dominio (table-code)
- `types/` - TypeScript types compartidos

### CSS Shared (`assets/css/shared/`)

Estilos CSS compartidos y reutilizables:

```html
<!-- Importar en tu HTML -->
<link rel="stylesheet" href="/assets/css/shared/base.css">
<link rel="stylesheet" href="/assets/css/shared/components.css">
<link rel="stylesheet" href="/assets/css/shared/utilities.css">
```

**Contenido:**
- `base.css` - Variables globales, reset, estilos base
- `components.css` - Componentes reutilizables (botones, cards, modales)
- `utilities.css` - Clases de utilidad (flexbox, spacing, colors)

Para más información, ver [CSS Shared README](./src/static_content/assets/css/shared/README.md).

## Desarrollo

```bash
# Instalar dependencias
pnpm install

# Compilar ambos targets
pnpm build

# Compilar solo empleados
PRONTO_TARGET=employees pnpm build

# Compilar solo clientes
PRONTO_TARGET=clients pnpm build

# Modo desarrollo (con hot reload)
PRONTO_TARGET=employees pnpm dev:employees
PRONTO_TARGET=clients pnpm dev:clients
```

## Producción

```bash
# Build Docker
docker build -t pronto-static ./src/static_content

# O con docker-compose
docker-compose up -d static
```

## Notas

- `node_modules/` **no** está excluido por defecto (la regla está comentada en `.gitignore`).
- Si quieres excluirlo, descomenta la línea `node_modules/` en `.gitignore`.

- Docker usa caché de capas, así que las dependencias se cachean automáticamente hasta que `package.json` cambie

---
# Anexo: Contenido de `pronto-libs/README.md`
---
# Pronto Shared Library

Shared library containing common modules for Pronto applications (pronto-employees, pronto-client).

## Installation

```bash
pip install pronto_shared-1.0.0-py3-none-any.whl
```

## Modules

- `pronto_shared.models` - SQLAlchemy models
- `pronto_shared.services` - Business logic services
- `pronto_shared.auth` - Authentication utilities
- `pronto_shared.jwt_service` - JWT token management
- `pronto_shared.jwt_middleware` - JWT middleware for Flask
- `pronto_shared.db` - Database connection utilities
- `pronto_shared.config` - Configuration management
- `pronto_shared.constants` - Application constants
- `pronto_shared.permissions` - Permission system
- `pronto_shared.security` - Security utilities
- `pronto_shared.serializers` - Data serialization

## Usage

```python
from pronto_shared.models import Employee, Order
from pronto_shared.services.order_service import list_orders
from pronto_shared.jwt_middleware import jwt_required
```
