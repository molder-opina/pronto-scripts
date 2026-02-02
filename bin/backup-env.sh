#!/bin/bash
# Script de backup automático para archivos de configuración .env
# Crea backups con timestamp en config/backups/

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directorio de backups
BACKUP_DIR="config/backups"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}🔄 Iniciando backup de archivos de configuración...${NC}"

# Función para hacer backup de un archivo
backup_file() {
    local file=$1
    local backup_path="${BACKUP_DIR}/${file##*/}.${TIMESTAMP}"

    if [ -f "$file" ]; then
        cp "$file" "$backup_path"
        echo -e "${GREEN}✅ Backup creado: ${backup_path}${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Archivo no encontrado: ${file}${NC}"
        return 1
    fi
}

# Hacer backup de archivos críticos
backup_file ".env"

# Opcional: Limpiar backups antiguos (mantener últimos 10)
echo -e "\n${YELLOW}🧹 Limpiando backups antiguos...${NC}"
cd "$BACKUP_DIR"

# Mantener solo los últimos 10 backups de cada archivo
for base_file in ".env"; do
    ls -t ${base_file}.* 2>/dev/null | tail -n +11 | xargs -r rm -f
    count=$(ls -1 ${base_file}.* 2>/dev/null | wc -l)
    echo -e "${GREEN}📦 Backups de ${base_file}: ${count}${NC}"
done

cd - > /dev/null

echo -e "\n${GREEN}✨ Backup completado exitosamente!${NC}"
echo -e "${GREEN}📁 Ubicación: ${BACKUP_DIR}/${NC}"
