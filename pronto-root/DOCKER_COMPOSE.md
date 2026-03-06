# Docker Compose Architecture

## Overview

This project uses a modular Docker Compose architecture with **profiles** to separate infrastructure from application services. This enables:

- **Independent scaling**: Start only what you need
- **Dev mode isolation**: Work on one service without others
- **No container_name conflicts**: Let Compose auto-name containers
- **Shared infrastructure**: Postgres/Redis reused across services

## Compose Files

| File | Purpose | Services |
|------|---------|----------|
| `docker-compose.yml` | Full stack (production) | infra + apps |
| `docker-compose.infra.yml` | Infrastructure only | postgres, redis |
| `docker-compose.client.yml` | Client app (dev mode) | client (connects to external network) |
| `docker-compose.employees.yml` | Employees app (dev mode) | employees, static (connects to external network) |
| `docker-compose.api.yml` | API service (dev mode) | api (connects to external network) |
| `docker-compose.tests.yml` | Test infrastructure | postgres, redis (isolated network) |

## Profiles

Services are organized into two profiles:

### `infra` Profile
- `postgres` - PostgreSQL 16
- `redis` - Redis 7

### `apps` Profile
- `static` - Nginx static content server
- `api` - API service
- `client` - Client app
- `employees` - Employees app

## Usage

### Start Infrastructure Only

```bash
# Using profiles
docker compose --profile infra up -d

# Or using infra compose
docker compose -f docker-compose.infra.yml up -d
```

### Start Full Stack

```bash
docker compose up -d
```

### Start Specific Services

```bash
# Start infra + apps
docker compose --profile infra --profile apps up -d

# Start only api
docker compose --profile infra up -d
docker compose -f docker-compose.api.yml up -d
```

### Dev Mode (Service-Specific Composes)

#### 1. Start Infrastructure

```bash
docker compose -f docker-compose.infra.yml up -d
```

#### 2. Start Service (connects to external network)

```bash
# Client app
docker compose -f docker-compose.client.yml up -d

# Employees app
docker compose -f docker-compose.employees.yml up -d

# API service
docker compose -f docker-compose.api.yml up -d
```

**Note**: Service-specific composes connect to the external `pronto_net` network created by `docker-compose.infra.yml`.

### Stop Services

```bash
# Stop all services in current compose
docker compose down

# Stop specific compose
docker compose -f docker-compose.client.yml down

# Stop infrastructure (last, after all services)
docker compose -f docker-compose.infra.yml down
```

### Testing

```bash
# Start test infrastructure
docker compose -f docker-compose.tests.yml up -d

# Run tests (from pronto-tests directory)
cd pronto-tests
./scripts/run-tests.sh all

# Cleanup test infrastructure
docker compose -f docker-compose.tests.yml down -v
```

## Network Architecture

### Full Stack Mode (`docker-compose.yml`)
```
pronto_net (internal network)
├── postgres
├── redis
├── static
├── api
├── client
└── employees
```

### Dev Mode (External Network)
```
pronto_net (external network, created by docker-compose.infra.yml)
├── postgres
└── redis
    (then add services from service-specific composes)
├── client (from docker-compose.client.yml)
├── employees (from docker-compose.employees.yml)
└── api (from docker-compose.api.yml)
```

### Test Mode (Isolated)
```
pronto_test_net (isolated network)
├── postgres (test db: pronto_test)
└── redis
```

## Best Practices

1. **Always start infrastructure first** in dev mode
2. **Stop services before infrastructure** to avoid orphaned containers
3. **Use service-specific composes** for focused development
4. **Auto-naming enabled**: Don't use `container_name` (allows scaling)
5. **External networks**: Service composes reference `pronto_net: { external: true }`

## Examples

### Scenario 1: Full Stack Development

```bash
# Start everything
docker compose up -d

# View logs
docker compose logs -f

# Stop everything
docker compose down
```

### Scenario 2: Working on Client App Only

```bash
# Step 1: Start infrastructure
docker compose -f docker-compose.infra.yml up -d

# Step 2: Start client app (with hot reload)
docker compose -f docker-compose.client.yml up -d

# Make code changes...

# Step 3: Stop client app
docker compose -f docker-compose.client.yml down

# Step 4: Stop infrastructure (when done)
docker compose -f docker-compose.infra.yml down
```

### Scenario 3: Running Tests

```bash
# Start test infrastructure
docker compose -f docker-compose.tests.yml up -d

# Run tests
cd pronto-tests && ./scripts/run-tests.sh all

# Cleanup (including volumes)
docker compose -f docker-compose.tests.yml down -v
```

## Port Mappings

| Service | Port |
|---------|------|
| Postgres | 5432 |
| Redis | 6379 |
| Static | 9088 |
| Client | 6080 |
| Employees | 6081 |
| API | 6082 |

## Troubleshooting

### Service can't connect to postgres/redis

Ensure infrastructure is running:
```bash
docker ps | grep -E "postgres|redis"
```

### Network not found error

Start infrastructure first:
```bash
docker compose -f docker-compose.infra.yml up -d
```

### Container naming conflicts

We no longer use `container_name`. If you see conflicts, stop orphaned containers:
```bash
docker compose down --remove-orphans
```

## Migration from Old Architecture

**Before**:
- All services in one compose
- Fixed container names (`pronto-client`, `pronto-employees`, etc.)
- No profiles

**After**:
- Modular composes with profiles
- Auto-named containers (`pronto-client-1`, `pronto-employees-1`, etc.)
- Separated infra/apps profiles
- External network support for dev mode

To migrate existing deployments:

```bash
# Stop old deployment
docker compose down

# Remove old volumes (optional, backup first!)
docker volume rm pronto_postgres_data

# Start new deployment
docker compose up -d
```

## See Also

- [Docker Compose Profiles](https://docs.docker.com/compose/profiles/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [Project AGENTS.md](./AGENTS.md) for development workflows
