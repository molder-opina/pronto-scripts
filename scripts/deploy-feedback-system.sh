#!/bin/bash
# Deploy Feedback System to Supabase
# Execute this script to apply the feedback system to your Supabase database

echo "========================================="
echo "Feedback System Deployment"
echo "========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get environment variables
DB_HOST=${SUPABASE_DB_HOST:-localhost}
DB_PORT=${SUPABASE_DB_PORT:-6543}
DB_NAME=${SUPABASE_DB_NAME:-postgres}
DB_USER=${SUPABASE_DB_USER:-postgres}
DB_PASSWORD=${SUPABASE_DB_PASSWORD}

echo -e "${GREEN}Database Configuration:${NC}"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo ""

# Check for required environment variables
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: SUPABASE_DB_PASSWORD environment variable not set${NC}"
    echo "Set it with: export SUPABASE_DB_PASSWORD='your_password'"
    exit 1
fi

# Check for psql command
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql command not found${NC}"
    echo "Install PostgreSQL client: brew install postgresql"
    exit 1
fi

echo -e "${GREEN}Step 1: Applying database migration${NC}"
echo ""

# Execute migration
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migrations/003_feedback_tokens_and_email_supabase.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Migration applied successfully${NC}"
else
    echo -e "${RED}✗ Migration failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 2: Verifying migration${NC}"
echo ""

# Verify tables were created
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "
SELECT 'pronto_feedback_tokens' as table_name, COUNT(*) as count FROM pronto_feedback_tokens
UNION ALL
SELECT 'pronto_config (feedback settings)' as table_name, COUNT(*) as count FROM pronto_config WHERE config_key LIKE 'feedback%'
UNION ALL
SELECT 'column: customer_email' as table_name, 1 as count FROM information_schema.columns WHERE table_name = 'pronto_orders' AND column_name = 'customer_email'
UNION ALL
SELECT 'column: feedback_requested_at' as table_name, 1 as count FROM information_schema.columns WHERE table_name = 'pronto_dining_sessions' AND column_name = 'feedback_requested_at'
UNION ALL
SELECT 'column: feedback_completed_at' as table_name, 1 as count FROM information_schema.columns WHERE table_name = 'pronto_dining_sessions' AND column_name = 'feedback_completed_at';
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ All tables and columns created successfully${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Could not verify all objects${NC}"
fi

echo ""
echo -e "${GREEN}Step 3: Checking SMTP configuration${NC}"
echo ""

if [ -z "$SMTP_HOST" ] || [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASSWORD" ]; then
    echo -e "${YELLOW}⚠ Warning: SMTP not configured in .env${NC}"
    echo "  To enable email sending, set these variables in .env:"
    echo "    SMTP_HOST=smtp.gmail.com"
    echo "    SMTP_PORT=587"
    echo "    SMTP_USER=your-email@domain.com"
    echo "    SMTP_PASSWORD=your-app-password"
    echo "    SMTP_FROM=noreply@your-domain.com"
    echo "    SMTP_USE_TLS=true"
else
    echo -e "${GREEN}✓ SMTP configured:${NC}"
    echo "  Host: $SMTP_HOST"
    echo "  User: $SMTP_USER"
    echo "  From: $SMTP_FROM"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Restart your application: bin/rebuild.sh"
echo "  2. Test the feedback flow:"
echo "     - Make a test order"
echo "     - Complete payment"
echo "     - Verify feedback prompt appears"
echo "     - Wait for timer to expire (10s)"
echo "     - Check email was sent (if configured)"
echo "  3. Test feedback email link:"
echo "     - Click the link in the email"
echo "     - Fill out and submit feedback form"
echo "     - Verify it saves to database"
echo ""
