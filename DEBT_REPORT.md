# Technical Debt Report - pronto-scripts

**Generated:** 2026-03-09
**Files Analyzed:** 129 Python files (excluding venv)

## Summary

pronto-scripts contiene scripts de utilidad, mantenimiento, QA y migración. La mayoría son scripts de uso interno que no requieren alta cobertura de tests. El código está bien organizado por función.

## Critical Issues

**No critical issues found.**

## High Priority Issues

### 1. Large Test Files (Maintainability)

| File | Lines | Purpose |
|------|-------|---------|
| `pronto-api/scripts/run_api_tests.py` | 1524 | API test runner |
| `lib/api_parity_check.py` | 1011 | API parity verification |

**Recommendation:** These are test utilities and are acceptable as-is.

## Medium Priority Issues

### 2. Hardcoded Test Passwords

**Location:** Multiple test scripts
**Severity:** LOW (acceptable for test scripts)

```python
# test_auth.py:89
test_password = "ChangeMe!123"  # nosec B105

# test_qa_full_flow_v2.py:278
email, password = "juan.mesero@cafeteria.test", "ChangeMe!123"
```

**Status:** Already marked with `# nosec B105` comments indicating intentional test credentials.

## Low Priority Issues

### 3. Archived Scripts

**Location:** `bin/archived/`, `scripts/archived/`

Archived scripts should be reviewed periodically and removed if no longer needed.

**Files:**
- `bin/archived/init-postgres-tables.py`
- `bin/archived/init-seed.py`
- `scripts/archived/check_button_layout.py`
- `scripts/archived/debug_cache.py`
- `scripts/archived/fix_missing_tables.py`
- `scripts/archived/migrate_dashboard.py`
- `scripts/archived/qa_complete_cycle_fixed.py`

**Recommendation:** Delete or move to separate archive repository.

## Organization

The scripts are well-organized by function:

```
pronto-scripts/
├── bin/
│   ├── python/          # Utility scripts
│   ├── tests/           # Verification scripts
│   └── archived/        # Old scripts
├── lib/                 # Shared libraries
├── scripts/
│   ├── maintenance/     # DB maintenance
│   ├── qa/              # QA automation
│   └── archived/        # Old scripts
└── restaurant/          # Restaurant operations
```

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Python Files | 129 |
| Files > 500 lines | 7 |
| Files > 1000 lines | 2 |
| Test/Verification Scripts | ~30 |
| Critical Issues | 0 |

## Action Items

### Low Priority
- [ ] Review and delete archived scripts
- [ ] Consider consolidating similar QA scripts

## Conclusion

pronto-scripts es un módulo de utilidades internas sin deuda técnica crítica. Los scripts de testing con passwords hardcodeados son aceptables para su propósito.
