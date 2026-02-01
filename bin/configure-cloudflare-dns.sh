#!/bin/bash

# Script para configurar DNS en Cloudflare para Pronto App
# Uso: ./configure-cloudflare-dns.sh <CLOUDFLARE_API_TOKEN> <SERVER_IP>

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
CLOUDFLARE_API_TOKEN="${1}"
SERVER_IP="${2}"
DOMAIN="molderx.xyz"
SUBDOMAINS=("pronto-app" "pronto-admin" "pronto-static")

# Validación de argumentos
if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Error: Faltan argumentos${NC}"
    echo "Uso: $0 <CLOUDFLARE_API_TOKEN> <SERVER_IP>"
    echo ""
    echo "Ejemplo:"
    echo "  $0 your-api-token-here 123.456.789.10"
    exit 1
fi

echo -e "${GREEN}=== Configuración de DNS en Cloudflare ===${NC}"
echo "Dominio: $DOMAIN"
echo "IP del servidor: $SERVER_IP"
echo ""

# Obtener Zone ID
echo -e "${YELLOW}Obteniendo Zone ID...${NC}"
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

ZONE_ID=$(echo $ZONE_RESPONSE | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$ZONE_ID" ]; then
    echo -e "${RED}Error: No se pudo obtener el Zone ID${NC}"
    echo "Respuesta de Cloudflare:"
    echo $ZONE_RESPONSE | python3 -m json.tool
    exit 1
fi

echo -e "${GREEN}Zone ID obtenido: $ZONE_ID${NC}"
echo ""

# Función para crear o actualizar registro DNS
create_or_update_dns_record() {
    local subdomain=$1
    local full_domain="${subdomain}.${DOMAIN}"

    echo -e "${YELLOW}Configurando ${full_domain}...${NC}"

    # Verificar si el registro ya existe
    EXISTING_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$full_domain" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json")

    RECORD_ID=$(echo $EXISTING_RECORD | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$RECORD_ID" ]; then
        # Crear nuevo registro
        echo "  Creando nuevo registro A..."
        RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$full_domain\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}")
    else
        # Actualizar registro existente
        echo "  Actualizando registro existente (ID: $RECORD_ID)..."
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$full_domain\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}")
    fi

    # Verificar si fue exitoso
    SUCCESS=$(echo $RESPONSE | grep -o '"success":true')

    if [ -n "$SUCCESS" ]; then
        echo -e "  ${GREEN}✓ $full_domain configurado correctamente${NC}"
    else
        echo -e "  ${RED}✗ Error al configurar $full_domain${NC}"
        echo "  Respuesta:"
        echo $RESPONSE | python3 -m json.tool
    fi
    echo ""
}

# Crear registros para cada subdominio
for subdomain in "${SUBDOMAINS[@]}"; do
    create_or_update_dns_record "$subdomain"
done

echo -e "${GREEN}=== Configuración completada ===${NC}"
echo ""
echo "Registros DNS configurados:"
echo "  • pronto-app.molderx.xyz    → $SERVER_IP (Puerto 6080)"
echo "  • pronto-admin.molderx.xyz  → $SERVER_IP (Puerto 6081)"
echo "  • pronto-static.molderx.xyz → $SERVER_IP (Puerto 9088)"
echo ""
echo -e "${YELLOW}Nota:${NC} Los registros DNS pueden tardar unos minutos en propagarse."
echo ""
echo "Próximos pasos:"
echo "1. Configurar nginx en el servidor"
echo "2. Obtener certificados SSL con Let's Encrypt"
echo "3. Iniciar los contenedores Docker"
