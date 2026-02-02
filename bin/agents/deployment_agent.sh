#!/usr/bin/env bash
set -e

echo "🚀 [AGENTE DEPLOYMENT] Validando scripts de inicialización..."

EXIT_CODE=0

# Archivos a revisar para nuevas funcionalidades
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=AM)

# Flags para detectar cambios que requieren actualización de init scripts
NEEDS_INIT_UPDATE=0
MISSING_UPDATES=""

# 1. Detectar nuevas migraciones de base de datos
if echo "$CHANGED_FILES" | grep -q "migrations/.*\.sql\|migrations/.*\.py"; then
    echo "   📦 Detectadas nuevas migraciones de base de datos"
    
    # Verificar que init scripts mencionen las migraciones
    if ! grep -r "migrations\|migrate\|db upgrade" bin/init/ > /dev/null 2>&1; then
        NEEDS_INIT_UPDATE=1
        MISSING_UPDATES="${MISSING_UPDATES}\n   - Migraciones de BD no referenciadas en bin/init/"
    fi
fi

# 2. Detectar nuevas variables de entorno críticas en .env.example
if echo "$CHANGED_FILES" | grep -q "\.env\.example"; then
    echo "   🔐 Detectados cambios en .env.example"
    
    # Verificar que init scripts validen las nuevas variables
    if ! grep -r "validate_required_env_vars\|secrets.env" bin/init/ > /dev/null 2>&1; then
        NEEDS_INIT_UPDATE=1
        MISSING_UPDATES="${MISSING_UPDATES}\n   - Nuevas variables de entorno no validadas en bin/init/"
    fi
fi

# 3. Detectar nuevos servicios en docker-compose.yml
if echo "$CHANGED_FILES" | grep -q "docker-compose.yml"; then
    # Verificar si se agregaron nuevos servicios
    if git diff --cached docker-compose.yml | grep -q "^+.*services:"; then
        echo "   🐳 Detectados posibles nuevos servicios en docker-compose.yml"
        
        # Verificar que init scripts los mencionen
        if ! grep -r "docker-compose\|docker compose" bin/init/ > /dev/null 2>&1; then
            NEEDS_INIT_UPDATE=1
            MISSING_UPDATES="${MISSING_UPDATES}\n   - Nuevos servicios Docker no documentados en bin/init/"
        fi
    fi
fi

# 4. Detectar nuevos modelos de base de datos
# Nota: Con la nueva estructura, los modelos están en pronto-libs/src/pronto_shared/models.py
if echo "$CHANGED_FILES" | grep -q "pronto_shared/models.py\|src/pronto_shared/models.py"; then
    # Verificar si se agregaron nuevas clases (tablas)
    if git diff --cached src/pronto_shared/models.py 2>/dev/null | grep -q "^+class.*Base" || \
       echo "$CHANGED_FILES" | grep -q "pronto_shared/models.py.*\+class"; then
        echo "   🗄️ Detectados posibles nuevos modelos de base de datos"
        
        # Verificar que seed data o init scripts los mencionen
        if ! grep -r "seed\|load_seed_data" bin/init/ > /dev/null 2>&1; then
            NEEDS_INIT_UPDATE=1
            MISSING_UPDATES="${MISSING_UPDATES}\n   - Nuevos modelos pueden requerir seed data en bin/init/"
        fi
    fi
fi

# 5. Detectar nuevos servicios de negocio críticos
# Los servicios críticos ahora están en pronto_shared (pronto-libs)
CRITICAL_SERVICES=(
    "pronto_shared/services/business_config_service.py"
    "pronto_shared/services/secret_service.py"
    "pronto_shared/services/settings_service.py"
)

for service in "${CRITICAL_SERVICES[@]}"; do
    if echo "$CHANGED_FILES" | grep -q "$service"; then
        echo "   ⚙️ Detectados cambios en servicio crítico: $service"
        
        # Verificar que init scripts sincronicen estos servicios
        if ! grep -r "sync_env\|load_env\|ensure_seed" bin/init/ > /dev/null 2>&1; then
            NEEDS_INIT_UPDATE=1
            MISSING_UPDATES="${MISSING_UPDATES}\n   - Cambios en servicios críticos pueden requerir sync en bin/init/"
        fi
    fi
done

# 6. Detectar nuevas dependencias en requirements.txt
if echo "$CHANGED_FILES" | grep -q "requirements.txt\|requirements/"; then
    echo "   📚 Detectados cambios en dependencias Python"
    
    # Verificar que Dockerfiles se reconstruyan
    if ! grep -r "pip install\|requirements.txt" bin/init/ > /dev/null 2>&1; then
        NEEDS_INIT_UPDATE=1
        MISSING_UPDATES="${MISSING_UPDATES}\n   - Nuevas dependencias pueden requerir rebuild en bin/init/"
    fi
fi

# 7. Detectar cambios en package.json (frontend)
if echo "$CHANGED_FILES" | grep -q "package.json"; then
    echo "   📦 Detectados cambios en dependencias frontend"
    
    # Verificar que init scripts instalen dependencias
    if ! grep -r "npm install\|npm ci" bin/init/ > /dev/null 2>&1; then
        NEEDS_INIT_UPDATE=1
        MISSING_UPDATES="${MISSING_UPDATES}\n   - Nuevas dependencias frontend pueden requerir npm install en bin/init/"
    fi
fi

# 8. Verificar que init scripts existan y sean ejecutables
INIT_SCRIPTS=(
    "bin/init/init.sh"
    "bin/init/01_backup_envs.sh"
    "bin/init/02_apply_envs.sh"
    "bin/init/03_seed_params.sh"
    "bin/init/04_deploy.sh"
)

for script in "${INIT_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "   ❌ Error: Script de inicialización faltante: $script"
        EXIT_CODE=1
    elif [ ! -x "$script" ]; then
        echo "   ⚠️ Warning: Script no ejecutable: $script"
    fi
done

# Reportar resultados
if [ $NEEDS_INIT_UPDATE -eq 1 ]; then
    echo ""
    echo "   ⚠️ ADVERTENCIA: Cambios detectados que pueden requerir actualización de scripts de inicialización:"
    echo -e "$MISSING_UPDATES"
    echo ""
    echo "   📝 Acción requerida:"
    echo "      1. Revisar si los cambios requieren pasos de inicialización"
    echo "      2. Actualizar bin/init/ si es necesario"
    echo "      3. Documentar en docs/DEPLOYMENT.md"
    echo ""
    echo "   ℹ️ Si los cambios NO requieren actualización de init, puedes ignorar este warning."
    echo ""
    # No bloqueamos el commit, solo advertimos
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "🚀 [AGENTE DEPLOYMENT] Visto Bueno (VoBo) ✅"
else
    echo "🚀 [AGENTE DEPLOYMENT] Rechazado ❌"
fi

exit $EXIT_CODE
