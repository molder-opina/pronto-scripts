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
# Setup development environment
./bin/setup-dev.sh

# Run all services locally
./bin/start-local.sh
```

### Database

```bash
# Run migrations
./scripts/migrate.sh

# Seed test data
./scripts/seed.sh
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
