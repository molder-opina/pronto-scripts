#!/bin/bash
# Script para probar la autenticación dentro del contenedor

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/../lib/docker_runtime.sh"

echo "Ejecutando pruebas de autenticación..."
sudo docker exec -it pronto-employees python3 /apps/pronto/bin/python/test_auth.py
