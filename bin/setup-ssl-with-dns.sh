#!/bin/bash

# Script para configurar certificados SSL usando DNS challenge de Cloudflare
# Uso: sudo ./setup-ssl-with-dns.sh <EMAIL> <CLOUDFLARE_API_TOKEN>

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

EMAIL="${1}"
CF_API_TOKEN="${2}"
SUBDOMAINS=("pronto-app.molderx.xyz" "pronto-admin.molderx.xyz" "pronto-static.molderx.xyz")

# Validación de argumentos
if [ -z "$EMAIL" ] || [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}Error: Faltan argumentos${NC}"
    echo "Uso: sudo $0 <EMAIL> <CLOUDFLARE_API_TOKEN>"
    echo ""
    echo "Ejemplo:"
    echo "  sudo $0 admin@molderx.xyz your-cloudflare-token"
    exit 1
fi

# Verificar que se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Este script debe ejecutarse como root (usa sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}=== Configuración de Certificados SSL con DNS Challenge ===${NC}"
echo "Email: $EMAIL"
echo ""

# Verificar si certbot está instalado
if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Certbot no está instalado. Instalando...${NC}"
    apt-get update
    apt-get install -y certbot
    echo -e "${GREEN}Certbot instalado correctamente${NC}"
    echo ""
fi

# Instalar plugin de Cloudflare para certbot
echo -e "${YELLOW}Instalando plugin de Cloudflare para certbot...${NC}"
apt-get install -y python3-certbot-dns-cloudflare

# Crear archivo de credenciales de Cloudflare
mkdir -p /root/.secrets
CF_CREDS_FILE="/root/.secrets/cloudflare.ini"

cat > "$CF_CREDS_FILE" <<EOF
# Cloudflare API token
dns_cloudflare_api_token = ${CF_API_TOKEN}
EOF

chmod 600 "$CF_CREDS_FILE"
echo -e "${GREEN}Archivo de credenciales creado${NC}"
echo ""

# Obtener certificado con wildcard o múltiples dominios
echo -e "${YELLOW}Obteniendo certificados SSL con DNS challenge...${NC}"

# Construir lista de dominios para el comando
DOMAIN_ARGS=""
for subdomain in "${SUBDOMAINS[@]}"; do
    DOMAIN_ARGS="$DOMAIN_ARGS -d $subdomain"
done

# Ejecutar certbot con DNS challenge
certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$CF_CREDS_FILE" \
    --dns-cloudflare-propagation-seconds 30 \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    $DOMAIN_ARGS

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Certificados SSL obtenidos correctamente${NC}"
else
    echo -e "${RED}✗ Error al obtener certificados${NC}"
    exit 1
fi
echo ""

# Copiar configuración final de nginx
echo -e "${YELLOW}Configurando nginx...${NC}"

# Remover configuración temporal si existe
rm -f /etc/nginx/sites-enabled/pronto-temp.conf

# Copiar configuración final con SSL
cp /apps/pronto/pronto-app/nginx-reverse-proxy.conf /etc/nginx/sites-available/pronto.conf
ln -sf /etc/nginx/sites-available/pronto.conf /etc/nginx/sites-enabled/pronto.conf

# Verificar sintaxis de nginx
if ! nginx -t; then
    echo -e "${RED}Error en la configuración de nginx${NC}"
    exit 1
fi

# Recargar nginx
systemctl reload nginx

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Nginx configurado correctamente${NC}"
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
