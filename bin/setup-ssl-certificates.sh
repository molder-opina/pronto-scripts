#!/bin/bash

# Script para configurar certificados SSL con Let's Encrypt
# Uso: sudo ./setup-ssl-certificates.sh <EMAIL>

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

# Copiar configuración de nginx si no existe
NGINX_CONF="/etc/nginx/sites-available/pronto.conf"
if [ ! -f "$NGINX_CONF" ]; then
    echo -e "${YELLOW}Copiando configuración de nginx...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    NGINX_SOURCE=""
    if [ -n "${NGINX_REVERSE_PROXY_CONF:-}" ] && [ -f "${NGINX_REVERSE_PROXY_CONF}" ]; then
        NGINX_SOURCE="${NGINX_REVERSE_PROXY_CONF}"
    fi

    if [ -z "${NGINX_SOURCE}" ]; then
        echo -e "${RED}Error: No se encontró nginx-reverse-proxy.conf${NC}"
        echo "   Define NGINX_REVERSE_PROXY_CONF con la ruta del archivo."
        exit 1
    fi
    cp "${NGINX_SOURCE}" "$NGINX_CONF"

    # Crear enlace simbólico
    if [ ! -L "/etc/nginx/sites-enabled/pronto.conf" ]; then
        ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/pronto.conf
    fi

    echo -e "${GREEN}Configuración de nginx copiada${NC}"
fi

# Verificar sintaxis de nginx
echo -e "${YELLOW}Verificando configuración de nginx...${NC}"
if nginx -t 2>&1 | grep -q "test failed"; then
    echo -e "${RED}Error en la configuración de nginx${NC}"
    nginx -t
    exit 1
fi
echo -e "${GREEN}Configuración de nginx válida${NC}"
echo ""

# Crear directorio para el challenge de Let's Encrypt
mkdir -p /var/www/certbot

# Recargar nginx para aplicar cambios
echo -e "${YELLOW}Recargando nginx...${NC}"
systemctl reload nginx
echo -e "${GREEN}Nginx recargado${NC}"
echo ""

# Obtener certificados para cada subdominio
for subdomain in "${SUBDOMAINS[@]}"; do
    echo -e "${YELLOW}Obteniendo certificado SSL para ${subdomain}...${NC}"

    # Verificar si el certificado ya existe
    if [ -d "/etc/letsencrypt/live/$subdomain" ]; then
        echo -e "${GREEN}El certificado para $subdomain ya existe. Renovando...${NC}"
        certbot renew --cert-name "$subdomain" --nginx --non-interactive
    else
        echo -e "${YELLOW}Creando nuevo certificado para $subdomain...${NC}"
        certbot certonly \
            --nginx \
            --non-interactive \
            --agree-tos \
            --email "$EMAIL" \
            -d "$subdomain"
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Certificado SSL para $subdomain configurado correctamente${NC}"
    else
        echo -e "${RED}✗ Error al obtener certificado para $subdomain${NC}"
        exit 1
    fi
    echo ""
done

# Recargar nginx con los certificados SSL
echo -e "${YELLOW}Recargando nginx con certificados SSL...${NC}"
systemctl reload nginx

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Nginx recargado correctamente${NC}"
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
