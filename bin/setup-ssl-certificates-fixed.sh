#!/bin/bash

# Script para configurar certificados SSL con Let's Encrypt
# Uso: sudo ./setup-ssl-certificates-fixed.sh <EMAIL>

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

EMAIL="${1}"
SUBDOMAINS=("pronto-app.molderx.xyz" "pronto-admin.molderx.xyz" "pronto-static.molderx.xyz")

# Validación de argumentos
if [ -z "$EMAIL" ]; then
    echo -e "${RED}Error: Falta el email${NC}"
    echo "Uso: sudo $0 <EMAIL>"
    echo ""
    echo "Ejemplo:"
    echo "  sudo $0 admin@molderx.xyz"
    exit 1
fi

# Verificar que se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Este script debe ejecutarse como root (usa sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}=== Configuración de Certificados SSL ===${NC}"
echo "Email: $EMAIL"
echo ""

# Verificar si certbot está instalado
if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Certbot no está instalado. Instalando...${NC}"
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
    echo -e "${GREEN}Certbot instalado correctamente${NC}"
    echo ""
fi

# Verificar que nginx esté instalado
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}Error: Nginx no está instalado${NC}"
    exit 1
fi

# Crear directorio para el challenge de Let's Encrypt
mkdir -p /var/www/certbot

# Paso 1: Aplicar configuración temporal sin SSL
echo -e "${YELLOW}Paso 1: Aplicando configuración temporal de nginx...${NC}"

# Backup de configuración existente si existe
if [ -f "/etc/nginx/sites-enabled/pronto.conf" ]; then
    rm -f /etc/nginx/sites-enabled/pronto.conf
fi

# Copiar configuración temporal
cp /apps/pronto/pronto-app/nginx-reverse-proxy-temp.conf /etc/nginx/sites-available/pronto-temp.conf
ln -sf /etc/nginx/sites-available/pronto-temp.conf /etc/nginx/sites-enabled/pronto-temp.conf

# Verificar sintaxis de nginx
if ! nginx -t; then
    echo -e "${RED}Error en la configuración temporal de nginx${NC}"
    exit 1
fi

# Recargar nginx
systemctl reload nginx
echo -e "${GREEN}Configuración temporal aplicada${NC}"
echo ""

# Paso 2: Obtener certificados para cada subdominio
echo -e "${YELLOW}Paso 2: Obteniendo certificados SSL...${NC}"
for subdomain in "${SUBDOMAINS[@]}"; do
    echo -e "${YELLOW}Obteniendo certificado SSL para ${subdomain}...${NC}"

    # Verificar si el certificado ya existe
    if [ -d "/etc/letsencrypt/live/$subdomain" ]; then
        echo -e "${GREEN}El certificado para $subdomain ya existe.${NC}"
    else
        echo -e "${YELLOW}Creando nuevo certificado para $subdomain...${NC}"
        certbot certonly \
            --webroot \
            -w /var/www/certbot \
            --non-interactive \
            --agree-tos \
            --email "$EMAIL" \
            -d "$subdomain"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Certificado SSL para $subdomain configurado correctamente${NC}"
    else
        echo -e "${RED}✗ Error al obtener certificado para $subdomain${NC}"
        echo -e "${YELLOW}Intentando con método standalone...${NC}"

        # Detener nginx temporalmente
        systemctl stop nginx

        certbot certonly \
            --standalone \
            --non-interactive \
            --agree-tos \
            --email "$EMAIL" \
            -d "$subdomain"

        # Reiniciar nginx
        systemctl start nginx

        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Error al obtener certificado para $subdomain${NC}"
            exit 1
        fi

        echo -e "${GREEN}✓ Certificado obtenido con método standalone${NC}"
    fi
    echo ""
done

# Paso 3: Aplicar configuración final con SSL
echo -e "${YELLOW}Paso 3: Aplicando configuración final con SSL...${NC}"

# Remover configuración temporal
rm -f /etc/nginx/sites-enabled/pronto-temp.conf

# Copiar configuración final con SSL
cp /apps/pronto/pronto-app/nginx-reverse-proxy.conf /etc/nginx/sites-available/pronto.conf
ln -sf /etc/nginx/sites-available/pronto.conf /etc/nginx/sites-enabled/pronto.conf

# Verificar sintaxis de nginx
if ! nginx -t; then
    echo -e "${RED}Error en la configuración final de nginx${NC}"
    exit 1
fi

# Recargar nginx con los certificados SSL
systemctl reload nginx

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Nginx recargado correctamente con SSL${NC}"
else
    echo -e "${RED}✗ Error al recargar nginx${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Configuración SSL completada ===${NC}"
echo ""
echo "Certificados SSL configurados para:"
for subdomain in "${SUBDOMAINS[@]}"; do
    echo "  • https://$subdomain"
done
echo ""
echo -e "${YELLOW}Nota:${NC} Los certificados se renovarán automáticamente."
echo ""
echo "Estado de nginx:"
systemctl status nginx --no-pager | head -5
echo ""
echo -e "${GREEN}Ahora puedes acceder a tu aplicación en:${NC}"
echo "  • https://pronto-app.molderx.xyz (Cliente)"
echo "  • https://pronto-admin.molderx.xyz (Administración)"
echo "  • https://pronto-static.molderx.xyz (Contenido estático)"
