# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Pronto is a full-stack restaurant management system with modular architecture:
- **Backend:** Python 3.11+, Flask, SQLAlchemy, PostgreSQL, Redis
- **Frontend:** Vue 3, Vite, TypeScript, TailwindCSS
- **Infrastructure:** Docker Compose with profiles (infra/apps)

## Build & Development Commands

### Docker (Primary Development)
```bash
bin/up.sh                               # Start full stack (use this, not raw docker compose)
bin/down.sh                             # Stop and remove containers
bin/rebuild.sh                          # Primary update script
bin/status.sh                           # Show status and accessible URLs
bin/up.sh --seed                        # Start fresh with seed data
```

### Python (Backend)
```bash
ruff check .                            # Lint
ruff format .                           # Format
mypy .                                  # Type check
pytest                                  # Run tests
```

### JavaScript/TypeScript (Frontend - pronto-static)
```bash
npm run dev:employees                   # Dev server for employee portal
npm run dev:clients                     # Dev server for client app
npm run build                           # Build both targets
npm run lint                            # ESLint
npm run format                          # Prettier
```

### Testing
```bash
./run-all-tests.sh                      # All tests (Backend, Frontend, E2E)
pytest                                  # Backend unit/integration
npm run test                            # Frontend (Vitest)
npm run test (in pronto-tests/)         # Playwright E2E
make security-scan                      # Bandit, Semgrep, Gitleaks
make check-all                          # All linters and security
```

## Architecture

### Service Structure
| Service | Port | Purpose |
|---------|------|---------|
| postgres | 5432 | Primary database |
| redis | 6379 | Cache/messaging |
| static | 9088 | Nginx asset server |
| api | 6082 | External REST API |
| client | 6080 | Customer web app |
| employees | 6081 | Staff portal |

### Key Directories
- `pronto-libs/` - **Shared library (pronto_shared)** - CHECK HERE FIRST
- `pronto-api/` - REST API service (Flask)
- `pronto-client/` - Customer-facing web app (Flask + Jinja2)
- `pronto-employees/` - Employee portal with role-based views (Flask + Jinja2)
- `pronto-static/` - Vue 3 frontend builds (Vite + TypeScript)
- `pronto-tests/` - E2E, integration, and unit tests (Playwright, pytest)
- `pronto-ai/` - AI agents, skills, and development tools
- `scripts/` - Development utility scripts (60+ files)
- `bin/` - Operation scripts (143 scripts total)
- `bin/lib/` - Shared shell libraries (6 files)
- `bin/agents/` - Pre-commit validation agents (15 scripts)

### Entry Points
- Backend: `pronto-*/src/*/wsgi.py`
- Frontend: `pronto-static/src/vue/{employees,clients}/`
- Shared: `pronto-libs/src/pronto_shared/`

## Critical Development Rules

### 1. Reuse Before Creation
Always check `pronto_shared` before creating new code:

**Core:**
- `models.py` - SQLAlchemy models
- `config.py` - Configuration management
- `db.py` - Database engine and sessions

**Auth & Security:**
- `jwt_service.py` - JWT generation/validation
- `jwt_middleware.py` - Auth decorators and helpers
- `permissions.py` - Permission system
- `scope_guard.py` - Scope isolation

**Services (35+ modules):**
- `order_service.py`, `menu_service.py`, `employee_service.py`
- `payment_providers/` - Cash, Clip, Stripe providers
- `notification_service.py`, `email_service.py`
- See `pronto-ai/AGENTS.md` for full list

### 2. JWT Authentication (Stateless for Employees)

**Token Types:**
- Access Token (24h) - Contains employee_id, name, email, role, active_scope
- Refresh Token (7 days) - Contains employee_id only

**Available Decorators:**
```python
from pronto_shared.jwt_middleware import jwt_required, scope_required, role_required, admin_required
from pronto_employees.decorators import login_required, web_login_required, web_role_required

# API routes (returns JSON)
@jwt_required          # Requires valid JWT
@scope_required("waiter")  # Requires specific scope
@role_required(["waiter", "cashier"])  # Requires one of these roles
@admin_required        # Requires admin or system role

# Web routes (redirects to login)
@web_login_required    # Redirects if not authenticated
@web_role_required(["admin"])  # Redirects if wrong role
```

**Get Current User:**
```python
from pronto_shared.jwt_middleware import get_current_user, get_employee_id, get_employee_role

user = get_current_user()      # Full JWT payload
employee_id = get_employee_id()  # Just the ID
role = get_employee_role()     # Just the role
```

**⚠️ CRITICAL: No Flask Session for Employee Auth**
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

### 3. Employee Portal Roles
- Admin - Full system management
- Cashier - Payment processing
- Chef - Kitchen display system
- Waiter - Table service and order taking
- System - Super admin functions

### 4. Static Content Variables
Use short variables in templates, NOT hardcoded URLs:
```html
<!-- ✅ CORRECT -->
<link rel="stylesheet" href="{{ assets_css_clients }}/menu.css">
<script src="{{ assets_js_employees }}/main.js"></script>

<!-- ❌ INCORRECT -->
<link rel="stylesheet" href="{{ pronto_static_container_host }}/assets/css/clients/menu.css">
```

Available variables: `assets_css`, `assets_css_clients`, `assets_css_employees`, `assets_js`, `assets_js_clients`, `assets_js_employees`, `assets_images`

### 5. Shell Script Limits
Keep scripts under 300 lines. Extract reusable logic into `bin/lib/` libraries.

## Database Safety

**Never execute DELETE, TRUNCATE, or DROP directly on:**
- `pronto_menu_categories` (12 categories)
- `pronto_menu_items` (94 products)
- `pronto_employees` (10 employees)

**Safe cleanup scripts:**
- `bin/cleanup-old-sessions.sh` - Session cleanup only
- `scripts/maintenance/clean_db.py` - Removes orders, sessions, notifications only

**If data is deleted, re-seed:**
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

## Pre-commit Agents (15 total)

The project uses specialized agents in `bin/agents/` that validate code before commits:

| Agent | Purpose |
|-------|---------|
| `developer.sh` | TODOs, print(), static asset variables |
| `designer.sh` | Images >1MB, CSS !important, accessibility |
| `db_specialist.sh` | Migration naming, destructive SQL |
| `sysadmin.sh` | .env files, Dockerfile USER, shebangs |
| `qa_tester.sh` | Focused tests (.only, fit, fdescribe) |
| `scribe.sh` | Documentation, TODO markers |
| `container_specialist.sh` | Docker latest tags, cleanup, HEALTHCHECK |
| `business_expert.sh` | Domain terms, currency formatting |
| `waiter_agent.sh` | Waiter module validation |
| `admin_agent.sh` | Admin module, permissions |
| `cashier_agent.sh` | Payment modules, providers |
| `chef_agent.sh` | KDS, order state transitions |
| `system_agent.sh` | Global security, ScopeGuard |
| `deployment_agent.sh` | Deployment validation |
| `audit_agent.sh` | Multi-model review (Claude, Minimax, GLM4) |

Run manually: `./bin/agents/developer.sh` or `pre-commit run agent-developer --all-files`

## Utility Scripts (scripts/)

```
scripts/
├── *.py, *.sh             # Migrations, seeding, general utilities
├── maintenance/           # Database maintenance (check_*, clean_*, fix_*)
├── qa/                    # QA automation (qa_*, test_*, run_tests.py)
└── sql/                   # SQL migrations
```

Common commands:
```bash
python scripts/maintenance/check_db.py     # Diagnostic
python scripts/maintenance/clean_db.py     # Cleanup (safe)
python scripts/qa/qa_full_cycle.py         # Full QA cycle
```

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
- Vue 3 with TypeScript
- Linter: `eslint`
- Formatter: `prettier`
- Build: Vite

## Key Configuration Files

- `.env.example` - Environment template (PostgreSQL, Redis, JWT, restaurant settings)
- `pronto-libs/pyproject.toml` - Python tooling config
- `pronto-static/package.json` - Frontend config
- `docker-compose.yml` - Service orchestration
- `DOCKER_COMPOSE.md` - Infrastructure documentation
- `pronto-ai/AGENTS.md` - Comprehensive development guide with pre-commit agents
