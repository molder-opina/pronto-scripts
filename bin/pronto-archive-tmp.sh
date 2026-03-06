#!/bin/bash
# pronto-archive-tmp.sh
# Archiva archivos temporales y basura de la raíz del proyecto hacia tmp/archived/

set -euo pipefail

# Obtener la raíz del proyecto (asumiendo que el script está en pronto-scripts/bin/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="tmp/archived/session_$TIMESTAMP"

# Lista de archivos/patrones conocidos como basura o temporales en la raíz
JUNK_PATTERNS=(
    ".aider.chat.history.md"
    ".aider.input.history"
    "api-audit.md"
    "final_audit_output.txt"
    "script_output.txt"
    "informe_seguridad_*.md"
    "pronto-client-ux-audit.md"
    "verify_logins.py"
    "verify_logins.sh"
    "verify_order_payment.py"
    "verify_phase_3.py"
    "start-api.sh"
    "diag.js"
    "screenshot-diag.png"
    "part1.css"
    "part2.css"
    "Si"
    "cookies.txt"
    "AUDIT_REPORT.md"
    "*.m4a"
    "plan.md"
    "final_audit_output.txt"
)

mkdir -p "$ARCHIVE_DIR"

echo "📦 Iniciando archivado de archivos temporales..."
count=0

# Usar un bucle que no cree un subshell para mantener el valor de count
while read -r file; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    echo "  -> Archivando: $filename"
    mv "$file" "$ARCHIVE_DIR/"
    count=$((count + 1))
done < <(for p in "${JUNK_PATTERNS[@]}"; do find . -maxdepth 1 -name "$p" -type f; done)

if [ $count -eq 0 ]; then
    echo "✨ No se encontraron archivos temporales para archivar."
    rmdir "$ARCHIVE_DIR" 2>/dev/null || true
    # Limpiar tmp/archived si quedó vacío
    rmdir "tmp/archived" 2>/dev/null || true
    rmdir "tmp" 2>/dev/null || true
else
    echo "✅ Se archivaron $count archivos en $ARCHIVE_DIR"
fi
