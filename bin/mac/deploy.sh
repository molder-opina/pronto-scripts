#!/bin/bash

# Script de deployment automático para Pronto App
# Uso: ./bin/deploy.sh "mensaje del commit"

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVER_USER="root"
SERVER_HOST="89.116.212.110"

# Check if commit message is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Debes proporcionar un mensaje de commit${NC}"
    echo "Uso: ./bin/deploy.sh \"mensaje del commit\""
    exit 1
fi

COMMIT_MESSAGE="$1"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Pronto App - Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Git add, commit, and push
echo -e "${YELLOW}[1/5] Preparando cambios locales...${NC}"
git add .

echo -e "${YELLOW}[2/5] Haciendo commit: ${COMMIT_MESSAGE}${NC}"
git commit -m "$COMMIT_MESSAGE" || {
    echo -e "${YELLOW}No hay cambios para commitear, continuando...${NC}"
}

echo -e "${YELLOW}[3/5] Haciendo push a repositorio remoto...${NC}"
git push

echo ""
echo -e "${GREEN}✓ Cambios enviados al repositorio${NC}"
echo ""

# Step 2: Deploy to server
echo -e "${YELLOW}[4/5] Conectando al servidor ${SERVER_HOST}...${NC}"
echo ""

ssh -t ${SERVER_USER}@${SERVER_HOST} << 'ENDSSH'
    set -e

    echo "Cambiando a usuario pronto..."
    su - pronto << 'ENDSU'
        set -e

        echo "Navegando al directorio de la aplicación..."
        cd ~/pronto-app

        echo "Haciendo git pull..."
        git pull

        echo "Ejecutando rebuild..."
        bin/rebuild.sh

        echo "Iniciando aplicación en modo debug..."
        bin/up-debug.sh

        echo "✓ Deployment completado exitosamente"
ENDSU
ENDSSH

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Deployment completado${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Aplicación desplegada en: ${GREEN}https://pronto-admin.molderx.xyz${NC}"
echo ""
