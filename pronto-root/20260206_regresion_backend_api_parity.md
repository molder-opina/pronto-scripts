# 20260206-F1: Regresión Backend API Ausente + Parity Gate

**Estado:** ABIERTO
**Impacto:** BLOQUEANTE
**Fecha:** 2026-02-06
**Autor:** Antigravity (Agent)

## Descripción
A pesar de que el bloqueo anterior (20260205-F1) fue marcado como resuelto, la re-auditoría confirma que endpoints críticos del backend (`/api/customers/*`, `/api/reports/*`, `/api/modifiers/*`) siguen respondiendo 404 o no están implementados. Esto impide la funcionalidad base de los módulos de Clientes, Reportes y Modificadores en el dashboard de empleados.

Además, el `parity-check` actual genera ruido excesivo ("Missing Unknown Method") al no inferir correctamente el método `GET` en llamadas `fetch()` implícitas, dificultando la identificación de falencias reales.

## Referencias
- Relacionado con: `20260205-F1` (Backend API Regression - marcado falsamente como resuelto)
- Relacionado con: `20260205-F2` (Customer module incomplete)

## Evidencia (Snapshots)
Artifacts path: `pronto-docs/errors/artifacts/20260206-F1/`

### Hashes (SHA256)
- `clients.parity.20260206.json`: `32eabbc11ca8f14c8686e32cd7264caf634bae6adf7be35eadfb717243d2ea1e`
- `employees.parity.20260206.json`: `80922146262bf9dfc17473fabacc472dde986b2db8a499be9040013d2783ece8`

## Plan de Solución
1. **Gate Fix:** Mejorar `api_parity_check.py` para inferir `GET` y limpiar falso ruido.
2. **Backend Implement:** Crear rutas canónicas (`customers.py`, `reports.py`, `modifiers.py`, `feedback.py`) y registrar blueprints correctamente en `routes/__init__.py`.
3. **Frontend Fix:** Migrar mutaciones a `requestJSON` para cumplir CSRF.
4. **Hardening:** Implementar `require_csrf` (stateless con doble submit si cookie presente) y asegurar `ScopeGuard`.

## Verificación
- `pronto-api-parity-check` debe reportar 0 "Missing Known Methods".
- Endpoints críticos responden 200 OK con estructura `success_response`.
