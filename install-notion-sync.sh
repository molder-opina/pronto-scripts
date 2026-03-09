#!/bin/bash
# Install the Notion sync job as a launchd service
# This will run daily at 9 PM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_FILE="$SCRIPT_DIR/com.pronto.sync-notion-docs.plist"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCHD_DIR"

# Copy plist to LaunchAgents directory
cp "$PLIST_FILE" "$LAUNCHD_DIR/com.pronto.sync-notion-docs.plist"

# Unload existing job if it exists (ignore errors)
launchctl unload "$LAUNCHD_DIR/com.pronto.sync-notion-docs.plist" 2>/dev/null || true

# Load the job
launchctl load "$LAUNCHD_DIR/com.pronto.sync-notion-docs.plist"

# Start the job immediately (optional - comment out if you want to wait until next scheduled run)
# launchctl start com.pronto.sync-notion-docs

echo "Notion sync job installed successfully"
echo "Logs: /tmp/pronto-sync-notion.log"
echo "Error logs: /tmp/pronto-sync-notion-error.log"
echo ""
echo "To uninstall:"
echo "  launchctl unload ~/Library/LaunchAgents/com.pronto.sync-notion-docs.plist"
echo "  rm ~/Library/LaunchAgents/com.pronto.sync-notion-docs.plist"
