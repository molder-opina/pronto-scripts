#!/usr/bin/env bash
set -e

echo "🐳 [AGENTE CONTAINER SPECIALIST] Revisando configuración de contenedores..."

EXIT_CODE=0

# 1. Check for 'latest' tag in docker-compose.yml
echo "   - Buscando tags 'latest' en docker-compose.yml..."
if grep "image:.*:latest" docker-compose.yml > /dev/null; then
    echo "   ⚠️  Advertencia: Uso de tag 'latest' detectado en docker-compose.yml. Se recomienda usar versiones específicas en producción."
    grep "image:.*:latest" docker-compose.yml
else
    echo "   ✅ No se detectaron tags explícitos 'latest' (o se usan variables)."
fi

# 2. Check for apt-get install cleanup in Dockerfiles
echo "   - Verificando limpieza de apt-get en Dockerfiles..."
DOCKERFILES=$(find . -name "Dockerfile*")
for dockerfile in $DOCKERFILES; do
    if grep "apt-get install" "$dockerfile" > /dev/null; then
        if ! grep -E "rm -rf /var/lib/apt/lists/\*|rm -rf /var/cache/apt/\*" "$dockerfile" > /dev/null; then
            echo "   ⚠️  Advertencia: $dockerfile instala paquetes sin limpiar caché (apt-get install sin rm -rf /var/lib/apt/lists/*). Incrementa el tamaño de la imagen."
        fi
    fi
done

# 3. Check for multiple CMD or ENTRYPOINT
echo "   - Verificando instrucciones CMD/ENTRYPOINT múltiples..."
for dockerfile in $DOCKERFILES; do
    CMD_COUNT=$(grep "^CMD" "$dockerfile" | wc -l)
    ENTRY_COUNT=$(grep "^ENTRYPOINT" "$dockerfile" | wc -l)
    if [ "$CMD_COUNT" -gt 1 ]; then
        echo "   ⚠️  Advertencia: $dockerfile tiene múltiples instrucciones CMD (solo la última tendrá efecto)."
    fi
    if [ "$ENTRY_COUNT" -gt 1 ]; then
        echo "   ⚠️  Advertencia: $dockerfile tiene múltiples instrucciones ENTRYPOINT (solo la última tendrá efecto)."
    fi
done

# 4. Check for HEALTHCHECK configuration
echo "   - Verificando HEALTHCHECK en docker-compose.yml..."
if ! grep "healthcheck:" docker-compose.yml > /dev/null; then
    echo "   ⚠️  Advertencia: No se detectaron configuraciones de HEALTHCHECK en docker-compose.yml."
else
    echo "   ✅ HEALTHCHECK detectado."
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "🐳 [AGENTE CONTAINER SPECIALIST] Visto Bueno (VoBo) ✅"
else
    echo "🐳 [AGENTE CONTAINER SPECIALIST] Rechazado ❌"
fi

exit $EXIT_CODE
