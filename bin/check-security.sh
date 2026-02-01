#!/bin/bash

# Script para verificar la seguridad de Pronto App
# Uso: ./check-security.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DOMAINS=("pronto-app.molderx.xyz" "pronto-admin.molderx.xyz" "pronto-static.molderx.xyz")

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Verificación de Seguridad - Pronto App${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Función para verificar un header
check_header() {
    local domain=$1
    local header=$2
    local expected=$3

    local result
    result=$(curl -s -I "https://$domain" 2>&1 | grep -i "^$header:" | head -1)

    if [ -n "$result" ]; then
        if [[ "$result" == *"$expected"* ]] || [ -z "$expected" ]; then
            echo -e "  ${GREEN}✓${NC} $header encontrado"
            return 0
        else
            echo -e "  ${YELLOW}⚠${NC} $header presente pero valor inesperado"
            echo "    $result"
            return 1
        fi
    else
        echo -e "  ${RED}✗${NC} $header NO encontrado"
        return 1
    fi
}

# Función para verificar SSL
check_ssl() {
    local domain=$1

    echo -e "\n${YELLOW}Verificando certificado SSL para $domain...${NC}"

    # Verificar que el certificado es válido
    local ssl_info
    ssl_info=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -dates -issuer 2>/dev/null)

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Certificado SSL válido"

        # Mostrar fecha de expiración
        local expiry
        expiry=$(echo "$ssl_info" | grep "notAfter" | cut -d= -f2)
        echo -e "  ${BLUE}ℹ${NC} Expira: $expiry"

        # Mostrar emisor
        local issuer
        issuer=$(echo "$ssl_info" | grep "issuer" | cut -d= -f2-)
        echo -e "  ${BLUE}ℹ${NC} Emisor: $issuer"

        return 0
    else
        echo -e "  ${RED}✗${NC} Error al verificar certificado SSL"
        return 1
    fi
}

# Función para verificar redirección HTTP→HTTPS
check_redirect() {
    local domain=$1

    echo -e "\n${YELLOW}Verificando redirección HTTP→HTTPS para $domain...${NC}"

    local redirect
    redirect=$(curl -s -I -L "http://$domain" 2>&1 | grep -i "^location:" | head -1)

    if [[ "$redirect" == *"https://"* ]]; then
        echo -e "  ${GREEN}✓${NC} HTTP redirige a HTTPS correctamente"
        return 0
    else
        echo -e "  ${RED}✗${NC} HTTP NO redirige a HTTPS"
        return 1
    fi
}

# Función para verificar conectividad HTTPS
check_https_connectivity() {
    local domain=$1

    echo -e "\n${YELLOW}Verificando conectividad HTTPS para $domain...${NC}"

    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "https://$domain" 2>&1)

    if [ "$status" == "200" ] || [ "$status" == "302" ] || [ "$status" == "301" ]; then
        echo -e "  ${GREEN}✓${NC} HTTPS accesible (HTTP $status)"
        return 0
    else
        echo -e "  ${RED}✗${NC} HTTPS NO accesible (HTTP $status)"
        return 1
    fi
}

# Contador de tests
total_tests=0
passed_tests=0

# Verificar cada dominio
for domain in "${DOMAINS[@]}"; do
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Verificando: $domain${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Verificar conectividad HTTPS
    ((total_tests++))
    if check_https_connectivity "$domain"; then
        ((passed_tests++))
    fi

    # Verificar redirección HTTP→HTTPS
    ((total_tests++))
    if check_redirect "$domain"; then
        ((passed_tests++))
    fi

    # Verificar certificado SSL
    ((total_tests++))
    if check_ssl "$domain"; then
        ((passed_tests++))
    fi

    # Verificar headers de seguridad
    echo -e "\n${YELLOW}Verificando headers de seguridad...${NC}"

    # Strict-Transport-Security
    ((total_tests++))
    if check_header "$domain" "strict-transport-security" "max-age"; then
        ((passed_tests++))
    fi

    # X-Frame-Options
    ((total_tests++))
    if check_header "$domain" "x-frame-options" ""; then
        ((passed_tests++))
    fi

    # X-Content-Type-Options
    ((total_tests++))
    if check_header "$domain" "x-content-type-options" "nosniff"; then
        ((passed_tests++))
    fi

    # X-XSS-Protection
    ((total_tests++))
    if check_header "$domain" "x-xss-protection" "1"; then
        ((passed_tests++))
    fi

    # Referrer-Policy
    ((total_tests++))
    if check_header "$domain" "referrer-policy" ""; then
        ((passed_tests++))
    fi

    # Permissions-Policy
    ((total_tests++))
    if check_header "$domain" "permissions-policy" ""; then
        ((passed_tests++))
    fi

    # Content-Security-Policy
    ((total_tests++))
    if check_header "$domain" "content-security-policy" ""; then
        ((passed_tests++))
    fi

    # Verificar que no se exponga la versión de nginx
    ((total_tests++))
    server_header=$(curl -s -I "https://$domain" 2>&1 | grep -i "^server:" | head -1)
    if [[ "$server_header" != *"/"* ]]; then
        echo -e "  ${GREEN}✓${NC} Versión de servidor oculta"
        ((passed_tests++))
    else
        echo -e "  ${YELLOW}⚠${NC} Versión de servidor visible: $server_header"
    fi
done

# Verificaciones adicionales del servidor
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Verificaciones del Servidor${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Verificar que nginx esté corriendo
echo -e "\n${YELLOW}Verificando servicios...${NC}"
((total_tests++))
if systemctl is-active --quiet nginx; then
    echo -e "  ${GREEN}✓${NC} Nginx está corriendo"
    ((passed_tests++))
else
    echo -e "  ${RED}✗${NC} Nginx NO está corriendo"
fi

# Verificar que los contenedores de Docker estén corriendo
((total_tests++))
if docker ps | grep -q "pronto-client"; then
    echo -e "  ${GREEN}✓${NC} Contenedor pronto-client está corriendo"
    ((passed_tests++))
else
    echo -e "  ${RED}✗${NC} Contenedor pronto-client NO está corriendo"
fi

((total_tests++))
if docker ps | grep -q "pronto-employee"; then
    echo -e "  ${GREEN}✓${NC} Contenedor pronto-employee está corriendo"
    ((passed_tests++))
else
    echo -e "  ${RED}✗${NC} Contenedor pronto-employee NO está corriendo"
fi

((total_tests++))
if docker ps | grep -q "pronto-static"; then
    echo -e "  ${GREEN}✓${NC} Contenedor pronto-static está corriendo"
    ((passed_tests++))
else
    echo -e "  ${RED}✗${NC} Contenedor pronto-static NO está corriendo"
fi

# Verificar puertos
echo -e "\n${YELLOW}Verificando puertos...${NC}"
((total_tests++))
if ss -tlnp | grep -q ":443"; then
    echo -e "  ${GREEN}✓${NC} Puerto 443 (HTTPS) está escuchando"
    ((passed_tests++))
else
    echo -e "  ${RED}✗${NC} Puerto 443 (HTTPS) NO está escuchando"
fi

((total_tests++))
if ss -tlnp | grep -q ":80"; then
    echo -e "  ${GREEN}✓${NC} Puerto 80 (HTTP) está escuchando"
    ((passed_tests++))
else
    echo -e "  ${RED}✗${NC} Puerto 80 (HTTP) NO está escuchando"
fi

# Verificar certificados próximos a expirar
echo -e "\n${YELLOW}Verificando expiración de certificados...${NC}"
((total_tests++))
cert_days=$(sudo certbot certificates 2>/dev/null | grep "pronto-app.molderx.xyz" -A 3 | grep "VALID:" | grep -oP '\d+' | head -1)

if [ -n "$cert_days" ]; then
    if [ "$cert_days" -gt 30 ]; then
        echo -e "  ${GREEN}✓${NC} Certificado válido por $cert_days días"
        ((passed_tests++))
    elif [ "$cert_days" -gt 7 ]; then
        echo -e "  ${YELLOW}⚠${NC} Certificado expira en $cert_days días (renovar pronto)"
        ((passed_tests++))
    else
        echo -e "  ${RED}✗${NC} Certificado expira en $cert_days días (URGENTE)"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} No se pudo verificar expiración del certificado"
fi

# Resumen final
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Resumen de Verificación${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

percentage=$((passed_tests * 100 / total_tests))

echo -e "Total de pruebas: $total_tests"
echo -e "Pruebas exitosas: ${GREEN}$passed_tests${NC}"
echo -e "Pruebas fallidas: ${RED}$((total_tests - passed_tests))${NC}"
echo -e "Porcentaje: ${BLUE}$percentage%${NC}"
echo ""

if [ $percentage -ge 90 ]; then
    echo -e "${GREEN}✓ Estado de seguridad: EXCELENTE${NC}"
    exit 0
elif [ $percentage -ge 75 ]; then
    echo -e "${YELLOW}⚠ Estado de seguridad: BUENO (revisar warnings)${NC}"
    exit 0
else
    echo -e "${RED}✗ Estado de seguridad: REQUIERE ATENCIÓN${NC}"
    exit 1
fi
