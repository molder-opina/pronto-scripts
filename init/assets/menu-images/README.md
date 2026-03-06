# Menu Image Catalog (Seed Reference)

Este catálogo documenta las imágenes de ejemplo usadas por el seed canónico (`pronto_shared/services/seed.py`) para `MenuItem.image_path`.

## Objetivo
- Asegurar reproducibilidad en nuevos ambientes.
- Mantener trazabilidad de qué archivo corresponde a cada ruta del seed.
- Permitir recarga o regeneración futura de imágenes sin depender de memoria operativa.

## Ubicación de assets en runtime
- `pronto-static/src/static_content/assets/pronto/menu/*.png`

## Fuente de referencia
- `menu-image-catalog.csv`
- `legacy-menu-image-mapping.csv`

Campos principales:
- `menu_asset_file`: nombre de archivo esperado por seed.
- `runtime_asset_path`: ruta runtime usada en `image_path`.
- `status`: `present_preexisting` o `generated_example_2026-02-22`.
- `source_provider`: proveedor/fuente del ejemplo.
- `source_reference`: URL o descriptor de origen.

## Nota
Imágenes marcadas como `generated_example_2026-02-22` fueron descargadas como recursos de ejemplo gratuitos para completar faltantes del catálogo.

## Legacy Backfill
Para catálogos legacy (nombres históricos en inglés), se incluye backfill idempotente:
- `pronto-scripts/init/sql/migrations/20260222_01__backfill_legacy_menu_image_paths.sql`
