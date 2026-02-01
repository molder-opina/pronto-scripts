#!/bin/bash
# View PostgreSQL logs

set -euo pipefail


echo "📊 Mostrando logs de pronto-postgres..."
echo "(Ctrl+C para salir)"
echo ""

docker logs -f pronto-postgres
