#!/bin/bash

# Script to apply database migrations using docker-compose
# Usage: bash bin/apply-migration-compose.sh <migration_file.sql>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/lib/docker-runtime.sh
source "${SCRIPT_DIR}/lib/docker-runtime.sh"

MIGRATION_FILE="$1"

if [ -z "$MIGRATION_FILE" ]; then
    echo "❌ Error: Migration file not specified"
    echo "Usage: bash bin/apply-migration-compose.sh <migration_file.sql>"
    exit 1
fi

if [ ! -f "$MIGRATION_FILE" ]; then
    echo "❌ Error: Migration file not found: $MIGRATION_FILE"
    exit 1
fi

echo "🔄 Applying migration: $MIGRATION_FILE"

# Get database credentials from environment or use defaults
DB_NAME=${MYSQL_DATABASE:-pronto}
DB_USER=${MYSQL_USER:-pronto}
DB_PASSWORD=${MYSQL_PASSWORD:-pronto-pass}

echo "📦 Running migration using docker-compose..."

# Use docker-compose exec to run the migration
docker-compose exec -T mysql mysql \
    -u "$DB_USER" \
    -p"$DB_PASSWORD" \
    "$DB_NAME" < "$MIGRATION_FILE"

echo "✅ Migration applied successfully!"
echo ""
echo "📋 Verifying migration..."
docker-compose exec -T mysql mysql \
    -u "$DB_USER" \
    -p"$DB_PASSWORD" \
    "$DB_NAME" \
    -e "DESCRIBE customers;" | grep -i avatar

echo ""
echo "✨ Migration completed and verified!"
