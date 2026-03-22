#!/bin/bash

set -e

echo "🔍 Checking for DB access in client..."

# Check for actual database access patterns (not just function names)
# Look for actual usage of database functions, not just naming

# Check for actual get_session() calls (not function definitions)
if grep -r "get_session()" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ get_session() calls found in client"
  exit 1
fi

# Check for Session() instantiations
if grep -r "Session(" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ Session() instantiations found in client"
  exit 1
fi

# Check for actual engine usage
if grep -r "engine\." pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ engine. usage found in client"
  exit 1
fi

# Check for Base usage in models
if grep -r "Base(" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ Base() usage found in client"
  exit 1
fi

# Check for actual init_engine() calls
if grep -r "init_engine(" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ init_engine() calls found in client"
  exit 1
fi

# Check for actual create_engine() calls
if grep -r "create_engine(" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ create_engine() calls found in client"
  exit 1
fi

# Check for sessionmaker() calls
if grep -r "sessionmaker(" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ sessionmaker() calls found in client"
  exit 1
fi

# Check for scoped_session() calls
if grep -r "scoped_session(" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ scoped_session() calls found in client"
  exit 1
fi

# Check for SQLAlchemy imports that indicate direct DB access
if grep -r "from sqlalchemy import" pronto-client/src --exclude-dir=__pycache__ | grep -v "sqlalchemy.orm"; then
  echo "❌ Direct SQLAlchemy imports found in client"
  exit 1
fi

if grep -r "import sqlalchemy" pronto-client/src --exclude-dir=__pycache__ | grep -v "sqlalchemy.orm"; then
  echo "❌ Direct SQLAlchemy imports found in client"
  exit 1
fi

# Check for database connection strings
if grep -r "postgresql://" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ PostgreSQL URL found in client"
  exit 1
fi

if grep -r "sqlite://" pronto-client/src --exclude-dir=__pycache__; then
  echo "❌ SQLite URL found in client"
  exit 1
fi

if grep -r "DATABASE_URL" pronto-client/src --exclude-dir=__pycache__ | grep -v "API_BASE_URL"; then
  echo "❌ DATABASE_URL found in client"
  exit 1
fi

echo "✅ Architecture clean"