#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  bash pronto-scripts/bin/pronto-revision-checklist.sh [--output FILE] [--check]

Opciones:
  -o, --output FILE  Guarda reporte markdown además de stdout.
  -c, --check        Exit 1 si alguna verificación falla.
  -h, --help         Muestra esta ayuda.
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
OUT_FILE=""
CHECK_MODE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o|--output)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    -c|--check)
      CHECK_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: opción no soportada: $1" >&2
      usage
      exit 1
      ;;
  esac
done

cd "$ROOT_DIR"

folders=(pronto-api pronto-employees pronto-client pronto-static)
source_excludes=(-g "!**/node_modules/**" -g "!**/.venv/**" -g "!**/*.whl" -g "!**/dist/**" -g "!**/build/**")

failed=0
report_lines=()

add_pass() {
  report_lines+=("- [x] $1")
}

add_fail() {
  report_lines+=("- [ ] $1")
  failed=1
}

run_check() {
  local name="$1"
  shift
  if "$@"; then
    add_pass "$name"
  else
    add_fail "$name"
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

check_parity_employees() {
  ./pronto-scripts/bin/pronto-api-parity-check employees >"$tmp_dir/parity_employees.json"
  jq -e '.ok == true' "$tmp_dir/parity_employees.json" >/dev/null
}

check_parity_clients() {
  ./pronto-scripts/bin/pronto-api-parity-check clients >"$tmp_dir/parity_clients.json"
  jq -e '.ok == true' "$tmp_dir/parity_clients.json" >/dev/null
}

check_no_forbidden_csrf_exempt() {
  local matches violations
  matches="$(rg -n --hidden '@csrf\.exempt' pronto-api/src pronto-employees/src pronto-client/src -g '*.py' || true)"
  violations="$(printf "%s\n" "$matches" | rg -v '^$|pronto-api/src/api_app/routes/client_sessions\.py:|pronto-employees/src/pronto_employees/routes/waiter/auth\.py:|pronto-employees/src/pronto_employees/routes/chef/auth\.py:|pronto-employees/src/pronto_employees/routes/cashier/auth\.py:|pronto-employees/src/pronto_employees/routes/admin/auth\.py:|pronto-employees/src/pronto_employees/routes/system/auth\.py:' || true)"
  [ -z "$violations" ]
}

check_order_state_authority() {
  local workflow_matches payment_matches
  workflow_matches="$(rg -n --hidden 'workflow_status\s*=' pronto-api/src | rg -v 'order_state_machine\.py' || true)"
  payment_matches="$(rg -n --hidden 'payment_status\s*=' pronto-api/src | rg -v 'order_state_machine\.py' || true)"
  [ -z "$workflow_matches" ] && [ -z "$payment_matches" ]
}

check_uuid_route_gate() {
  local emp cli
  emp="$(rg -n --hidden '/<int:[a-z_]+_id>' pronto-employees/src/pronto_employees/routes/api/ | rg -v '/<int:(area_id|role_id|discount_code_id|promotion_id|product_schedule_id|call_id|waiter_call_id|notification_id|admin_shortcut_id)>' || true)"
  cli="$(rg -n --hidden '/<int:[a-z_]+_id>' pronto-client/src/pronto_clients/routes/api/ | rg -v '/<int:(area_id|role_id|discount_code_id|promotion_id|product_schedule_id|call_id|waiter_call_id|notification_id|admin_shortcut_id)>' || true)"
  [ -z "$emp" ] && [ -z "$cli" ]
}

check_py_compile() {
  python3 - <<'PY'
import pathlib
import py_compile
import sys

roots = ["pronto-api/src", "pronto-employees/src", "pronto-client/src"]
errors = []
for root in roots:
    for path in pathlib.Path(root).rglob("*.py"):
        try:
            py_compile.compile(str(path), doraise=True)
        except Exception as exc:
            errors.append((str(path), str(exc)))

if errors:
    print(f"PY_COMPILE_FAIL {len(errors)}")
    for path, err in errors[:20]:
        print(f"{path}: {err}")
    sys.exit(1)
print("PY_COMPILE_OK")
PY
}

check_no_absolute_urls_in_vue() {
  local matches
  matches="$(rg -n --hidden "requestJSON\\(\\s*['\\\"]https?://|fetch\\(\\s*['\\\"]https?://" pronto-static/src/vue -g '*.ts' -g '*.vue' || true)"
  [ -z "$matches" ]
}

check_no_local_static_folders() {
  local matches
  matches="$(rg --files pronto-client/src/pronto_clients pronto-employees/src/pronto_employees | rg '/static/|/assets/' || true)"
  [ -z "$matches" ]
}

check_template_assets_exist() {
  node - <<'NODE'
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const root = process.cwd();
const files = execSync(
  "rg --files pronto-client/src/pronto_clients/templates pronto-employees/src/pronto_employees/templates -g '*.html'",
  { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] }
).toString().trim().split('\n').filter(Boolean);

const baseByVar = {
  assets_css: 'css',
  assets_css_shared: 'css/shared',
  assets_css_clients: 'css/clients',
  assets_css_employees: 'css/employees',
  assets_js: 'js',
  assets_js_shared: 'js/shared',
  assets_js_clients: 'js/clients',
  assets_js_employees: 'js/employees',
  assets_images: 'images',
  assets_lib: 'lib',
};

const regex = /\{\{\s*(assets_[a-z_]+)\s*\}\}\/([^"'?\s)]+)/g;
const missing = [];

for (const file of files) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  let m;
  while ((m = regex.exec(text)) !== null) {
    const varName = m[1];
    const rel = m[2];
    const base = baseByVar[varName];
    if (!base) continue;
    if (rel.includes('{{') || rel.includes('}}') || rel.includes('{%')) {
      continue;
    }
    const relPath = `${base}/${rel}`.replace(/\/+/g, '/');
    const fullPath = path.join(root, 'pronto-static/src/static_content/assets', relPath);
    if (!fs.existsSync(fullPath)) {
      missing.push(`${relPath} <- ${file}`);
    }
  }
}

if (missing.length) {
  console.log('MISSING_ASSETS');
  missing.slice(0, 50).forEach((line) => console.log(line));
  process.exit(1);
}
console.log('ALL_REFERENCED_ASSETS_EXIST');
NODE
}

for folder in "${folders[@]}"; do
  total_count="$(rg --files "$folder" | wc -l | tr -d ' ')"
  source_count="$(rg --files "$folder" "${source_excludes[@]}" | wc -l | tr -d ' ')"
  report_lines+=("- [x] Inventario ${folder}: total=${total_count}, source=${source_count}")
done

run_check "Paridad API employees (frontend vs backend)" check_parity_employees
run_check "Paridad API clients (frontend vs backend)" check_parity_clients
run_check "Sin @csrf.exempt prohibidos (excepto /api/sessions/open)" check_no_forbidden_csrf_exempt
run_check "Order State Authority (sin writes directos en pronto-api)" check_order_state_authority
run_check "Gate UUID routes (sin /<int:*_id> en client/employees API)" check_uuid_route_gate
run_check "Compilación Python (api/employees/client)" check_py_compile
run_check "Sin URLs absolutas en fetch/requestJSON de Vue" check_no_absolute_urls_in_vue
run_check "Sin directorios estáticos locales en client/employees" check_no_local_static_folders
run_check "Todos los assets referenciados por templates existen en pronto-static" check_template_assets_exist

status="APPROVED"
if [ "$failed" -ne 0 ]; then
  status="REJECTED"
fi

report_header="## PRONTO Revision Checklist ($(date +%F))
STATUS: ${status}

### Cobertura
- Carpeta auditadas: pronto-api, pronto-employees, pronto-client, pronto-static
- Método: inventario total + gates P0/P1 automáticos + paridad frontend/backend + validación de assets

### Resultados"

report_body="$(printf '%s\n' "${report_lines[@]}")"
report="${report_header}
${report_body}
"

printf '%s\n' "$report"

if [ -n "$OUT_FILE" ]; then
  mkdir -p "$(dirname "$OUT_FILE")"
  printf '%s\n' "$report" > "$OUT_FILE"
fi

if [ "$CHECK_MODE" -eq 1 ] && [ "$failed" -ne 0 ]; then
  exit 1
fi

exit 0
