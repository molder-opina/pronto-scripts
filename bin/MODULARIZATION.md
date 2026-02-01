# Scripts Modularization Summary

## Overview

This document describes the modularization of large scripts in the `bin/` directory to improve maintainability and readability.

## Changes Made

### 1. `rebuild.sh` - Reduced from 572 to ~300 lines

**Extracted modules:**

- `bin/lib/build_helpers.sh` - Build and dependency preparation functions
  - `run_frontend_builds()` - Builds TypeScript bundles for client/employee apps
  - `prepare_dependencies()` - Downloads Python wheels for offline installation

- `bin/lib/cleanup_helpers.sh` - Container and image cleanup functions
  - `exists_container_by_name()` - Check if container exists by name pattern
  - `kill_and_rm_by_name()` - Force kill and remove containers
  - `cleanup_old_images()` - Clean up old Docker images

- `bin/lib/static_helpers.sh` - Static content synchronization
  - `slugify()` - Convert restaurant name to URL-safe slug
  - `ensure_static_placeholder()` - Create placeholder images
  - `sync_static_content()` - Sync static files to nginx (Linux only)

**Benefits:**

- Easier to test individual functions
- Better code organization
- Reusable functions across scripts
- Reduced cognitive load when reading main script

### 2. Migration Scripts - Moved to `bin/maintenance/`

**Relocated scripts:**

- `migrate-supabase-to-postgres.py` (755 lines) - One-time migration script
- `migrate-from-supabase.py` (9KB) - Legacy migration helper

**Rationale:**

- These are one-time migration scripts not used in regular operations
- Keeping them in main `bin/` clutters the directory
- Still accessible when needed for historical migrations

### 3. Database Validation - New modular structure

**Created:**

- `bin/validate-seed.sh` - Bash wrapper for validation
- `bin/python/validate_and_seed.py` - Python validation logic

**Organization:**

- Python scripts in `bin/python/` subdirectory
- Bash wrappers in `bin/` for easy execution
- Clear separation of concerns

## Directory Structure

```
bin/
├── lib/                          # Shared library functions
│   ├── build_helpers.sh         # Build and dependency functions
│   ├── cleanup_helpers.sh       # Container cleanup functions
│   ├── docker_runtime.sh        # Docker/Podman detection
│   ├── stack_helpers.sh         # Stack management helpers
│   └── static_helpers.sh        # Static content sync
├── python/                       # Python utility scripts
│   └── validate_and_seed.py    # Database validation/seeding
├── maintenance/                  # One-time/legacy scripts
│   ├── migrate-supabase-to-postgres.py
│   └── migrate-from-supabase.py
├── rebuild.sh                    # Main rebuild script (refactored)
├── validate-seed.sh             # Database validation wrapper
└── [other operational scripts]
```

## Usage Examples

### Using refactored rebuild.sh

```bash
# Same interface as before
./bin/rebuild.sh client employee
./bin/rebuild.sh --no-cache --seed client
```

### Using validation script

```bash
# Validate and seed database
./bin/validate-seed.sh
```

### Importing library functions

```bash
# In other scripts
source "${SCRIPT_DIR}/lib/build_helpers.sh"
prepare_dependencies
run_frontend_builds
```

## Guidelines for Future Scripts

1. **Keep main scripts under 300 lines**
   - Extract reusable functions to `bin/lib/`
   - Move complex logic to separate modules

2. **Use consistent naming**
   - Library files: `*_helpers.sh`
   - Python utilities: `bin/python/*.py`
   - Maintenance scripts: `bin/maintenance/*.py`

3. **Document dependencies**
   - Use `# shellcheck source=` comments
   - List required environment variables
   - Document function parameters

4. **Test modular functions**
   - Each library function should be testable independently
   - Use clear input/output contracts
   - Handle errors gracefully

## Migration Notes

- All existing functionality preserved
- No breaking changes to script interfaces
- Backward compatible with existing workflows
- Library functions can be reused in new scripts

## Future Improvements

- [ ] Add unit tests for library functions
- [ ] Create documentation for each library module
- [ ] Consider moving more large scripts to modular structure
- [ ] Add linting/validation for shell scripts
