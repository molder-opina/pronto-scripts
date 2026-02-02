# Inconsistencias Conocidas - Pronto Scripts

**Fecha:** 2026-02-02
**Estado:** Actualizado (rutas corregidas)

---

## Cambios aplicados

- Scripts Python ya usan `pronto-libs/src` en `PYTHONPATH` (sin `build/`).
- Scripts shell apuntan a `pronto-libs/src/pronto_shared` y `pronto-static/src/static_content`.
- Rutas absolutas locales fueron removidas.

---

## Estado de los Repositorios

| Repo | Estado |
|------|--------|
| `pronto-libs` | ✓ OK - Contiene `pronto_shared` package |
| `pronto-api` | ✓ OK |
| `pronto-client` | ✓ OK |
| `pronto-employees` | ✓ OK |
| `pronto-scripts` | ✓ Rutas actualizadas |
| `pronto-static` | ✓ OK |
| `pronto-tests` | ✓ OK |
| `pronto-docs` | ✓ OK |
| `pronto-redis` | ✓ OK |
| `pronto-postgresql` | ✓ OK |

---

## Nota

Si surge una nueva inconsistencia, documentarla aquí con la ruta exacta y el impacto.
