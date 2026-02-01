#!/usr/bin/env bash
# Script to apply PostgreSQL migrations to Supabase
# Usage: bash bin/apply_migration_pg.sh <migration_file.sql>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment variables
if [ -f "${PROJECT_ROOT}/config/general.env" ]; then
    set -a
    source "${PROJECT_ROOT}/config/general.env"
    set +a
fi

if [ -f "${PROJECT_ROOT}/config/secrets.env" ]; then
    set -a
    source "${PROJECT_ROOT}/config/secrets.env"
    set +a
fi

MIGRATION_FILE="$1"

if [ -z "$MIGRATION_FILE" ]; then
    echo "❌ Error: Migration file not specified"
    echo "Usage: bash bin/apply_migration_pg.sh <migration_file.sql>"
    exit 1
fi

if [ ! -f "$MIGRATION_FILE" ]; then
    echo "❌ Error: Migration file not found: $MIGRATION_FILE"
    exit 1
fi

echo "🔄 Applying PostgreSQL migration: $MIGRATION_FILE"

# Get database credentials from environment
DB_HOST="${SUPABASE_DB_HOST}"
DB_PORT="${SUPABASE_DB_PORT:-5432}"
DB_USER="${SUPABASE_DB_USER}"
DB_NAME="${SUPABASE_DB_NAME:-postgres}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD}"
DB_SSLMODE="${SUPABASE_DB_SSLMODE:-require}"

if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "❌ Error: Database credentials not found in environment"
    echo "Please ensure SUPABASE_DB_HOST, SUPABASE_DB_USER, and SUPABASE_DB_PASSWORD are set"
    exit 1
fi

echo "📦 Connecting to Supabase PostgreSQL database..."
echo "   Host: $DB_HOST"
echo "   Port: $DB_PORT"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ Error: psql command not found"
    echo "Please install PostgreSQL client tools:"
    echo "  macOS: brew install postgresql"
    echo "  Ubuntu/Debian: apt-get install postgresql-client"
    exit 1
fi

# Apply the migration
export PGPASSWORD="$DB_PASSWORD"
export PGSSLMODE="$DB_SSLMODE"
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$MIGRATION_FILE"; then
    echo ""
    echo "✅ Migration applied successfully!"
else
    echo ""
    echo "❌ Migration failed!"
    exit 1
fi

unset PGPASSWORD
unset PGSSLMODE

echo ""
echo "📋 Verifying tables were created..."
export PGPASSWORD="$DB_PASSWORD"
export PGSSLMODE="$DB_SSLMODE"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dt pronto_keyboard_shortcuts" || true
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dt pronto_feedback_questions" || true
unset PGPASSWORD
unset PGSSLMODE

echo ""
echo "✨ Migration completed!"
