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
