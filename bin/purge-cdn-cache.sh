#!/usr/bin/env bash
# bin/purge-cdn-cache.sh — Purga el cache de CloudFlare CDN
#
# Uso:
#   bin/purge-cdn-cache.sh              # Purga todo el cache
#   bin/purge-cdn-cache.sh /assets/*    # Purga solo assets

set -euo pipefail

# Configuración de CloudFlare
# NOTA: Configurar estas variables de entorno antes de usar:
# - CLOUDFLARE_ZONE_ID: ID de la zona en CloudFlare
# - CLOUDFLARE_API_TOKEN: Token de API con permisos de purge cache

ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

if [[ -z "$ZONE_ID" || -z "$API_TOKEN" ]]; then
    echo "⚠️  Variables de entorno no configuradas:"
    echo "   Configura CLOUDFLARE_ZONE_ID y CLOUDFLARE_API_TOKEN"
    echo ""
    echo "   Ejemplo:"
    echo "   export CLOUDFLARE_ZONE_ID='tu_zone_id'"
    echo "   export CLOUDFLARE_API_TOKEN='tu_api_token'"
    echo ""
    echo "   Puedes obtener estos valores en:"
    echo "   https://dash.cloudflare.com/"
    exit 1
fi

# Verificar si se especificó un path
if [[ $# -eq 0 ]]; then
    echo "🧹 Purgando TODO el cache de CloudFlare..."

    RESPONSE=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data '{"purge_everything":true}')
else
    PATH_PATTERN="$1"
    echo "🧹 Purgando cache de CloudFlare para: ${PATH_PATTERN}"

    RESPONSE=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"files\":[\"https://pronto-static.molderx.xyz${PATH_PATTERN}\"]}")
fi

# Verificar respuesta
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true' || echo "")

if [[ -n "$SUCCESS" ]]; then
    echo "✅ Cache purgado exitosamente"
else
    echo "❌ Error al purgar cache:"
    echo "$RESPONSE"
    exit 1
fi
