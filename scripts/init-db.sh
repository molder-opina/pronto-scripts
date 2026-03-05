#!/bin/bash
# Init script for PostgreSQL database
# This script runs automatically when the PostgreSQL container starts

set -e

echo "Initializing Pronto database..."

# Wait for PostgreSQL to be ready
while ! pg_isready -U pronto > /dev/null 2>&1; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 1
done

echo "PostgreSQL is ready."

# Load seed initialization environment if present
if [[ -f /scripts/init/seed.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /scripts/init/seed.env
  set +a
fi

# Load seed data if requested
if [[ "${LOAD_SEED_DATA:-false}" == "true" ]]; then
  echo "🌱 Loading seed data..."

  # Run the seed initialization script
  if [[ -f /scripts/init-seed.py ]]; then
    cd /build
    if [[ -z "${SECRET_KEY:-}" ]]; then
      echo "❌ SECRET_KEY is required to run seed initialization"
      exit 1
    fi
    if [[ -z "${PASSWORD_HASH_SALT:-}" ]]; then
      echo "❌ PASSWORD_HASH_SALT is required to run seed initialization"
      exit 1
    fi
    export POSTGRES_HOST=localhost
    export POSTGRES_PORT=5432
    export POSTGRES_USER=pronto
    export POSTGRES_PASSWORD=pronto123
    export POSTGRES_DB=pronto

    python3 /scripts/init-seed.py
    echo "✅ Seed data loaded successfully"
  else
    echo "⚠️  Seed script not found at /scripts/init-seed.py"
  fi
else
  echo "ℹ️  Seed data loading disabled (set LOAD_SEED_DATA=true to enable)"
fi

echo ""
echo "Database initialization complete. You can connect to this database from other containers using:"
echo "  Host: postgres"
echo "  Port: 5432"
echo "  User: pronto"
echo "  Password: pronto123"
echo "  Database: pronto"
