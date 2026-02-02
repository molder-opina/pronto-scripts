#!/usr/bin/env bash
# Diagnóstico de Redis con docker-compose y servicios Pronto

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"

COMPOSE_BIN=${COMPOSE_BIN:-docker-compose}

if ! command -v "$COMPOSE_BIN" >/dev/null 2>&1; then
    echo "❌ No se encontró docker-compose. Instálalo o define COMPOSE_BIN con el binario correcto."
    exit 1
fi

echo "=============================================="
echo "  Verificación de Redis con docker-compose"
echo "=============================================="
echo ""

echo "1) Levantando servicio redis..."
$COMPOSE_BIN up -d redis >/dev/null

echo "2) Esperando a que Redis responda ping..."
ready=0
for _ in $(seq 1 20); do
    if $COMPOSE_BIN exec -T redis redis-cli ping >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done

if [[ $ready -ne 1 ]]; then
    echo "❌ Redis no respondió a tiempo. Revisa los logs con '$COMPOSE_BIN logs redis'."
    exit 1
fi
echo "   ✓ Redis responde correctamente."

diag_prefix="redisdiag$(date +%s)"
diag_stream="pronto:redis_diag:${diag_prefix}"
diag_channel="pronto:redis_diag_channel"

echo ""
echo "3) Ejecutando script de diagnóstico dentro del servicio employee..."
$COMPOSE_BIN run --rm --no-deps \
    -e REDIS_HOST=redis \
    -e REDIS_EVENTS_STREAM="$diag_stream" \
    -e REDIS_EVENTS_CHANNEL="$diag_channel" \
    -e DIAG_PREFIX="$diag_prefix" \
    employee python - <<'PY'
import json
import os
import sys

from redis import Redis

from pronto_shared import socketio_manager as sm

prefix = os.environ.get("DIAG_PREFIX", "redisdiag")
order_id = 900001
session_id = 800001
table_id = f"{prefix}:T1"
room = f"{prefix}:room"
call_id = 700001
stream = os.getenv("REDIS_EVENTS_STREAM")

client = Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    decode_responses=True,
)

keys = [
    f"pronto:orders:{order_id}",
    f"pronto:sessions:{session_id}",
    f"pronto:tables:{table_id}",
    f"pronto:notifications:{room}",
]
client.delete(*keys)

sm.emit_order_status_change(order_id=order_id, status="ready", session_id=session_id, table_number=table_id)
sm.emit_waiter_call(
    call_id=call_id,
    session_id=session_id,
    table_number=table_id,
    status="new",
    call_type="diagnostic",
)
sm.emit_custom_event("diagnostics.redis", {"marker": prefix}, room=room)

last_id, events = sm.read_events_from_stream("0-0", count=10)

summary = {
    "redis_host": os.getenv("REDIS_HOST", "redis"),
    "stream": stream,
    "last_stream_id": last_id,
    "keys": {key: client.get(key) for key in keys},
    "events": events,
}

missing = [key for key, value in summary["keys"].items() if not value]
if missing:
    print("❌ Redis no almacenó algunas claves esperadas:", missing)
    sys.exit(1)

if not events:
    print(f"❌ No se recibieron eventos en el stream {stream}")
    sys.exit(1)

print(json.dumps(summary, indent=2))
PY

echo ""
echo "4) Diagnóstico completado. El JSON anterior muestra los datos almacenados en Redis."
echo "   Puedes revisar los eventos en el stream '$diag_stream' con 'redis-cli xread ...' si lo necesitas."
echo ""
echo "✅ Redis y los servicios Pronto respondieron correctamente."
