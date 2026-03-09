# Notion Sync Scripts

This directory contains scripts to synchronize PRONTO markdown documentation with Notion.

## Files

### sync-pronto-docs-notion.py
Main Python script that syncs `pronto-docs/` markdown files to Notion.

**Configuration:**
The script reads configuration from environment variables. It looks for config files in this order:
1. `/Users/molder/.config/notion/notion.env`
2. `/Users/molder/.notion.env`
3. `notion.env` (in the same directory as this script)

Required environment variables:
- `NOTION_TOKEN`: Notion API integration token
- `NOTION_PARENT_PAGE_ID`: ID of the parent page in Notion where docs will be created

**Usage:**
```bash
# Sync all docs
python3 sync-pronto-docs-notion.py --docs-root "/Users/molder/projects/github-molder/pronto/pronto-docs"

# Sync with limit (default 200 files)
python3 sync-pronto-docs-notion.py --docs-root "/Users/molder/projects/github-molder/pronto/pronto-docs" --max-files 100
```

**Behavior:**
- Creates one Notion page per markdown file
- Pages are named "PRONTO Docs — <relative_path>"
- Appends content with a timestamp heading ("## Actualización YYYY-MM-DD HH:MM")
- Keeps API calls low by appending instead of replacing
- Updates only changed files (checks by title)

### install-notion-sync.sh
Shell script to install the Notion sync as a macOS launchd service.

**Usage:**
```bash
./install-notion-sync.sh
```

**What it does:**
- Copies the plist file to `~/Library/LaunchAgents/`
- Unloads any existing job
- Loads the new job into launchd
- Enables automatic daily execution

**Schedule:**
- Runs daily every 24 hours (86400 seconds)
- Runs from the pronto-scripts directory

**Logs:**
- Standard output: `/tmp/pronto-sync-notion.log`
- Error output: `/tmp/pronto-sync-notion-error.log`

**Uninstall:**
```bash
# Unload the job
launchctl unload ~/Library/LaunchAgents/com.pronto.sync-notion-docs.plist

# Remove the plist file
rm ~/Library/LaunchAgents/com.pronto.sync-notion-docs.plist
```

**Manual testing:**
```bash
# Test the sync script directly
python3 sync-pronto-docs-notion.py --docs-root "/Users/molder/projects/github-molder/pronto/pronto-docs" --max-files 5
```

## Setup Instructions

1. **Create notion.env file:**
   ```bash
   # Create one of these:
   mkdir -p /Users/molder/.config/notion
   nano /Users/molder/.config/notion/notion.env
   # OR
   nano /Users/molder/.notion.env
   ```

2. **Add your Notion credentials:**
   ```env
   NOTION_TOKEN=your_notion_integration_token_here
   NOTION_PARENT_PAGE_ID=your_parent_page_id_here
   ```

3. **Install the scheduled job:**
   ```bash
   cd pronto-scripts
   ./install-notion-sync.sh
   ```

4. **Verify installation:**
   ```bash
   # Check if job is loaded
   launchctl list | grep pronto

   # Check next scheduled run time
   launchctl print system | grep pronto
   ```

## Notes

- The sync is read-only on the repository side
- It only pushes updates to Notion
- API rate limiting is handled with sleep between calls (0.35s)
- Pages are not deleted, only updated with new sections
