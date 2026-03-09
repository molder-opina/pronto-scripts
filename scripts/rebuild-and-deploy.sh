#!/bin/bash

# Script to rebuild and redeploy Pronto application with all fixes

set -e

echo "=========================================="
echo "Rebuilding Pronto Application"
echo "=========================================="
echo ""

# Step 1: Stop running containers
echo "Step 1: Stopping running containers..."

# Limpiar colas de notificaciones en Redis
if docker-compose ps | grep -q redis; then
    echo "🧹 Limpiando colas de notificaciones (Redis)..."
    docker-compose exec -T redis redis-cli FLUSHDB || echo "⚠️ No se pudo limpiar Redis (¿contenedor detenido?)"
fi

docker-compose down
echo "✓ Containers stopped"
echo ""

# Step 2: Rebuild client image with updated code
echo "Step 2: Rebuilding client image..."
docker-compose build --no-cache client
echo "✓ Client image rebuilt"
echo ""

# Step 3: Rebuild employee image (in case there are related changes)
echo "Step 3: Rebuilding employee image..."
docker-compose build --no-cache employee
echo "✓ Employee image rebuilt"
echo ""

# Step 4: Start all services
echo "Step 4: Starting all services..."
docker-compose up -d
echo "✓ Services started"
echo ""

# Step 5: Wait for services to be ready
echo "Step 5: Waiting for services to be ready..."
sleep 10
echo "✓ Services should be ready"
echo ""

# Step 6: Check service status
echo "Step 6: Checking service status..."
docker-compose ps
echo ""

echo "=========================================="
echo "Rebuild Complete!"
echo "=========================================="
echo ""
echo "Services are now running with updated code:"
echo "  - Client App: http://localhost:6080"
echo "  - Employee App: http://localhost:6081"
echo ""
echo "To test the order flow, run:"
echo "  ./test-order-flow.sh"
echo ""
