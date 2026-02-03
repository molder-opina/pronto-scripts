#!/usr/bin/env bash
# pronto-scripts/bin/setup-restaurant-branding.sh - Setup branding assets for a restaurant
# Creates restaurant directory and copies generic branding assets
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATIC_ASSETS_DIR="${PROJECT_ROOT}/../pronto-static/src/static_content/assets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_usage() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🏪 Setup Restaurant Branding Assets"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Uso: $(basename "$0") [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -n, --name <nombre>     Nombre del restaurante (ej: 'Cafetería de Prueba')"
    echo "  -s, --slug <slug>       Slug manual (omite generación automática)"
    echo "  -c, --copy-only         Solo copia, no crea directorios si existen"
    echo "  -f, --force             Sobreescribe archivos existentes"
    echo "  -h, --help              Muestra esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $(basename "$0") -n 'Cafetería de Prueba'"
    echo "  $(basename "$0") -n 'El Restaurante de Juan'"
    echo "  $(basename "$0") --slug 'cafe-luna' --copy-only"
    echo ""
    echo "Flujo:"
    echo "  1. Genera slug desde nombre (o usa provisto)"
    echo "  2. Crea directorio: pronto-static/assets/<slug>/branding/"
    echo "  3. Copia assets de: pronto-static/assets/pronto/branding/*"
    echo "  4. Valida archivos copiados"
    echo ""
}

# Parse arguments
RESTAURANT_NAME=""
RESTAURANT_SLUG=""
COPY_ONLY=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            RESTAURANT_NAME="$2"
            shift 2
            ;;
        -s|--slug)
            RESTAURANT_SLUG="$2"
            shift 2
            ;;
        -c|--copy-only)
            COPY_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Opción desconocida: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$RESTAURANT_NAME" && -z "$RESTAURANT_SLUG" ]]; then
    echo -e "${RED}Error: Se requiere --name o --slug${NC}"
    show_usage
    exit 1
fi

# Generate slug from name if not provided
if [[ -z "$RESTAURANT_SLUG" ]]; then
    echo -e "${BLUE}→${NC} Generando slug para: ${YELLOW}$RESTAURANT_NAME${NC}"
    RESTAURANT_SLUG=$(python3 -c "
import unicodedata
import re
value = '$RESTAURANT_NAME'
value = unicodedata.normalize('NFKD', value)
value = value.encode('ascii', 'ignore').decode('ascii')
value = value.strip().lower()
value = re.sub(r'[^a-z0-9]+', '-', value)
value = value.strip('-')
print(value)
")
    echo -e "  ${GREEN}✓${NC} Slug generado: ${YELLOW}${RESTAURANT_SLUG}${NC}"
fi

# Define paths
SOURCE_BRANDING="${STATIC_ASSETS_DIR}/pronto/branding"
TARGET_DIR="${STATIC_ASSETS_DIR}/${RESTAURANT_SLUG}"
TARGET_BRANDING="${TARGET_DIR}/branding"

# Validate source branding exists
if [[ ! -d "$SOURCE_BRANDING" ]]; then
    echo -e "${RED}Error: Directorio de branding fuente no existe:${NC} $SOURCE_BRANDING"
    exit 1
fi

# Create target directory if needed
if [[ ! -d "$TARGET_BRANDING" ]]; then
    if [[ "$COPY_ONLY" == true ]]; then
        echo -e "${YELLOW}Modo copy-only: Directorio no existe, creando${NC}"
    fi
    echo -e "${BLUE}→${NC} Creando directorio: ${YELLOW}${TARGET_BRANDING}${NC}"
    mkdir -p "$TARGET_BRANDING"
elif [[ "$COPY_ONLY" == true ]]; then
    echo -e "${YELLOW}Modo copy-only: Directorio existe, omitiendo creación${NC}"
fi

# Copy branding assets
echo -e "${BLUE}→${NC} Copiando assets de branding..."

for file in "$SOURCE_BRANDING"/*; do
    filename=$(basename "$file")
    target_file="${TARGET_BRANDING}/${filename}"

    if [[ -f "$target_file" ]]; then
        if [[ "$FORCE" == true ]]; then
            echo -e "  ${YELLOW}[sobreescribiendo]${NC} $filename"
            cp -f "$file" "$target_file"
        else
            echo -e "  ${YELLOW}[omitido]${NC} $filename (ya existe)"
        fi
    else
        cp "$file" "$target_file"
        echo -e "  ${GREEN}✓${NC} $filename"
    fi
done

# Validate copied files
echo -e "\n${BLUE}→${NC} Validando archivos copiados..."
COPIED_COUNT=0
for file in "$TARGET_BRANDING"/*; do
    if [[ -f "$file" ]]; then
        COPIED_COUNT=$((COPIED_COUNT + 1))
        filename=$(basename "$file")
        filesize=$(du -h "$file" | cut -f1)
        echo -e "  ${GREEN}✓${NC} $filename (${filesize})"
    fi
done

# Summary
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Branding setup completado${NC}"
echo -e "  Restaurante: ${YELLOW}${RESTAURANT_NAME}${NC}"
echo -e "  Slug: ${YELLOW}${RESTAURANT_SLUG}${NC}"
echo -e "  Directorio: ${YELLOW}${TARGET_BRANDING}${NC}"
echo -e "  Archivos: ${YELLOW}${COPIED_COUNT}${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Sync to container if running
if docker ps | grep -q "pronto-static-1"; then
    echo -e "${BLUE}→${NC} Contenedor pronto-static-1 está corriendo"
    echo -e "  ${YELLOW}Nota: Los cambios se reflejarán automáticamente vía volume mount${NC}"
fi

exit 0
