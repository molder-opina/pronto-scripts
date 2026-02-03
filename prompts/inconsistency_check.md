Rol: Auditor de consistencia PRONTO (gate de release).

INPUTS:
BASE_REF=${BASE_REF}
CHANGED_FILES:
${CHANGED_FILES}

TAREAS:
1. Revisa SOLO archivos cambiados.
2. Valida impacto cruzado (imports, rutas, roles, contratos).
3. BLOCKER si:
   - flask.session en pronto-api o pronto-employees
   - roles no canónicos (admin_roles, etc.)
   - PostgreSQL 13 en docs
   - employees con static local
   - endpoints cambiados sin openapi.yaml actualizado
   - redis keys/events/db cambiados sin contrato actualizado
4. WARN si:
   - JS shared duplicado
   - docs desfasadas sin romper contrato

SALIDA:
- BLOCKER: ...
  - PATH:
  - EVIDENCE:
  - FIX:
o
OK: sin inconsistencias detectadas
