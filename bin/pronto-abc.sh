#!/usr/bin/env bash
set -euo pipefail

# ABC ops script for dev/test data management.
# WARNING: Destructive commands require --yes and are blocked outside dev/test
# unless --force is provided explicitly.

DB_URL_DEFAULT="${DATABASE_URL:-postgresql://pronto:pronto123@localhost:5432/pronto}"
DB_URL="${DB_URL_DEFAULT}"
PRONTO_ENV_VALUE="${PRONTO_ENV:-dev}"
YES=false
FORCE=false

print_usage() {
  cat <<'EOF'
Uso:
  ./pronto-scripts/bin/pronto-abc.sh <command> [options]

Comandos de órdenes:
  orders:status
  orders:list
  orders:clean --yes
  orders:pay-all --yes
  orders:cancel-all --yes
  orders:set-status --status <new|queued|preparing|ready|delivered|paid|cancelled> --yes

Comandos de sesiones/feedback:
  sessions:clean --yes
  feedback:clean --yes

Comandos de catálogo/estructura:
  areas:clean --yes
  tables:clean --yes
  modifiers:clean --yes
  products:clean --yes

Comandos de personas:
  employees:clean --yes
  customers:clean --yes
  tables:assign-waiter --waiter-id <uuid> [--area-id <int> | --all-tables] --yes

Comandos de settings:
  settings:list
  settings:set --key <key> --value <value> [--value-type string|integer|boolean] [--category <name>] --yes
  settings:reset-defaults --yes

Orquestación:
  full:clean --yes
  status

Opciones globales:
  --db-url <postgres_url>  Override DATABASE_URL
  --yes                    Confirmar operación destructiva
  --force                  Permitir ejecución fuera de dev/test

Ejemplos:
  ./pronto-scripts/bin/pronto-abc.sh orders:status
  ./pronto-scripts/bin/pronto-abc.sh orders:pay-all --yes
  ./pronto-scripts/bin/pronto-abc.sh tables:assign-waiter --waiter-id 6103b4d0-40e3-42c5-b9cc-ad5215bff3b9 --all-tables --yes
  ./pronto-scripts/bin/pronto-abc.sh full:clean --yes
EOF
}

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

psql_cmd() {
  psql "$DB_URL" -v ON_ERROR_STOP=1 "$@"
}

psql_exec() {
  local sql="$1"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -X -q -c "$sql"
}

require_safe_env() {
  if [[ "$FORCE" == "true" ]]; then
    return
  fi
  case "${PRONTO_ENV_VALUE}" in
    dev|test) ;;
    *)
      die "PRONTO_ENV='${PRONTO_ENV_VALUE}' bloqueado. Usa PRONTO_ENV=dev/test o --force."
      ;;
  esac
}

require_yes() {
  [[ "$YES" == "true" ]] || die "Esta operación requiere --yes."
}

validate_uuid() {
  local value="$1"
  [[ "$value" =~ ^[0-9a-fA-F-]{36}$ ]] || die "UUID inválido: ${value}"
}

orders_status() {
  psql_cmd -c "
    SELECT workflow_status, payment_status, COUNT(*) AS total
    FROM pronto_orders
    GROUP BY workflow_status, payment_status
    ORDER BY workflow_status, payment_status;
  "
}

orders_list() {
  psql_cmd -c "
    SELECT
      id,
      COALESCE(order_number, '-') AS order_number,
      workflow_status,
      payment_status,
      COALESCE(total_amount, total, 0) AS total_amount,
      created_at
    FROM pronto_orders
    ORDER BY created_at DESC
    LIMIT 200;
  "
}

orders_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    DELETE FROM pronto_order_item_modifiers;
    DELETE FROM pronto_split_bill_assignments;
    DELETE FROM pronto_order_items;
    DELETE FROM pronto_kitchen_orders;
    DELETE FROM pronto_order_status_history;
    DELETE FROM pronto_feedback_tokens WHERE order_id IS NOT NULL;
    DELETE FROM pronto_orders;
    COMMIT;
  "
  log "OK: órdenes limpiadas."
}

orders_pay_all() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    WITH target AS (
      SELECT id, session_id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS rn
      FROM pronto_orders
      WHERE workflow_status NOT IN ('paid', 'cancelled')
    ),
    updated AS (
      UPDATE pronto_orders o
      SET
        workflow_status = 'paid',
        payment_status = 'paid',
        status = 'completed',
        payment_method = CASE ((t.rn - 1) % 4)
          WHEN 0 THEN 'cash'
          WHEN 1 THEN 'card'
          WHEN 2 THEN 'transfer'
          ELSE 'wallet'
        END,
        paid_at = COALESCE(o.paid_at, NOW()),
        updated_at = NOW()
      FROM target t
      WHERE o.id = t.id
      RETURNING o.session_id
    )
    UPDATE pronto_dining_sessions s
    SET
      payment_status = 'paid',
      status = 'paid',
      closed_at = COALESCE(s.closed_at, NOW()),
      total_paid = GREATEST(COALESCE(s.total_paid, 0), COALESCE(s.total_amount, 0)),
      updated_at = NOW()
    WHERE s.id IN (SELECT DISTINCT session_id FROM updated WHERE session_id IS NOT NULL);
    COMMIT;
  "
  log "OK: órdenes activas pagadas (métodos rotativos: cash/card/transfer/wallet)."
}

orders_cancel_all() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    UPDATE pronto_orders
    SET
      workflow_status = 'cancelled',
      status = 'cancelled',
      updated_at = NOW()
    WHERE workflow_status NOT IN ('paid', 'cancelled');
    COMMIT;
  "
  log "OK: órdenes activas canceladas."
}

orders_set_status() {
  local status="$1"
  case "$status" in
    new|queued|preparing|ready|delivered|paid|cancelled) ;;
    *) die "Estado inválido: ${status}" ;;
  esac

  require_safe_env
  require_yes

  psql_exec "
    BEGIN;
    UPDATE pronto_orders
    SET
      workflow_status = '${status}',
      status = CASE
        WHEN '${status}' = 'paid' THEN 'completed'
        WHEN '${status}' = 'cancelled' THEN 'cancelled'
        ELSE COALESCE(status, 'pending')
      END,
      payment_status = CASE
        WHEN '${status}' = 'paid' THEN 'paid'
        ELSE payment_status
      END,
      paid_at = CASE
        WHEN '${status}' = 'paid' THEN COALESCE(paid_at, NOW())
        ELSE paid_at
      END,
      updated_at = NOW()
    WHERE workflow_status NOT IN ('paid', 'cancelled') OR '${status}' IN ('paid', 'cancelled');
    COMMIT;
  "
  log "OK: estado de órdenes actualizado a '${status}'."
}

sessions_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    DELETE FROM pronto_order_item_modifiers;
    DELETE FROM pronto_split_bill_assignments;
    DELETE FROM pronto_order_items;
    DELETE FROM pronto_kitchen_orders;
    DELETE FROM pronto_order_status_history;
    DELETE FROM pronto_feedback_tokens WHERE order_id IS NOT NULL;
    DELETE FROM pronto_orders;

    UPDATE pronto_tables SET current_session_id = NULL WHERE current_session_id IS NOT NULL;
    DELETE FROM pronto_waiter_calls;
    DELETE FROM pronto_payments;
    DELETE FROM pronto_feedback WHERE session_id IS NOT NULL;
    DELETE FROM pronto_feedback_tokens WHERE session_id IS NOT NULL;
    DELETE FROM pronto_table_log WHERE session_id IS NOT NULL;
    DELETE FROM pronto_split_bill_assignments;
    DELETE FROM pronto_split_bill_people;
    DELETE FROM pronto_split_bills;
    DELETE FROM pronto_dining_sessions;
    COMMIT;
  "
  log "OK: sesiones limpiadas."
}

feedback_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    DELETE FROM pronto_feedback;
    DELETE FROM pronto_feedback_tokens;
    COMMIT;
  "
  log "OK: feedback y tokens limpiados."
}

tables_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    UPDATE pronto_dining_sessions SET table_id = NULL WHERE table_id IS NOT NULL;
    UPDATE pronto_tables SET current_session_id = NULL WHERE current_session_id IS NOT NULL;
    DELETE FROM pronto_waiter_table_assignments;
    DELETE FROM pronto_table_transfer_requests;
    DELETE FROM pronto_table_log WHERE table_id IS NOT NULL;
    DELETE FROM pronto_tables;
    COMMIT;
  "
  log "OK: mesas limpiadas."
}

areas_clean() {
  require_safe_env
  require_yes
  tables_clean
  psql_exec "
    BEGIN;
    DELETE FROM pronto_areas;
    COMMIT;
  "
  log "OK: áreas limpiadas."
}

modifiers_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    DELETE FROM pronto_order_item_modifiers;
    DELETE FROM pronto_menu_item_modifier_groups;
    DELETE FROM pronto_modifiers;
    DELETE FROM pronto_modifier_groups;
    COMMIT;
  "
  log "OK: aditamientos (grupos y modificadores) limpiados."
}

products_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    DELETE FROM pronto_order_item_modifiers;
    DELETE FROM pronto_split_bill_assignments;
    DELETE FROM pronto_order_items;
    DELETE FROM pronto_kitchen_orders;
    DELETE FROM pronto_order_status_history;
    DELETE FROM pronto_feedback_tokens WHERE order_id IS NOT NULL;
    DELETE FROM pronto_orders;

    DELETE FROM pronto_menu_item_day_periods;
    DELETE FROM pronto_menu_item_modifier_groups;
    DELETE FROM pronto_product_schedules;
    DELETE FROM pronto_recommendation_change_log;
    DELETE FROM pronto_modifiers;
    DELETE FROM pronto_modifier_groups;
    DELETE FROM pronto_menu_items;
    DELETE FROM pronto_menu_categories;
    COMMIT;
  "
  log "OK: productos y categorías limpiados."
}

employees_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    UPDATE pronto_dining_sessions SET employee_id = NULL WHERE employee_id IS NOT NULL;
    UPDATE pronto_orders
    SET employee_id = NULL, waiter_id = NULL, chef_id = NULL, delivery_waiter_id = NULL
    WHERE employee_id IS NOT NULL OR waiter_id IS NOT NULL OR chef_id IS NOT NULL OR delivery_waiter_id IS NOT NULL;
    UPDATE pronto_order_items SET delivered_by_employee_id = NULL WHERE delivered_by_employee_id IS NOT NULL;
    UPDATE pronto_order_status_history SET changed_by = NULL WHERE changed_by IS NOT NULL;
    UPDATE pronto_order_status_labels SET updated_by_emp_id = NULL WHERE updated_by_emp_id IS NOT NULL;
    UPDATE pronto_payments SET created_by = NULL WHERE created_by IS NOT NULL;
    UPDATE pronto_waiter_calls SET confirmed_by = NULL WHERE confirmed_by IS NOT NULL;
    UPDATE pronto_table_transfer_requests
    SET from_waiter_id = NULL, to_waiter_id = NULL, resolved_by_employee_id = NULL
    WHERE from_waiter_id IS NOT NULL OR to_waiter_id IS NOT NULL OR resolved_by_employee_id IS NOT NULL;
    UPDATE pronto_business_info SET updated_by = NULL WHERE updated_by IS NOT NULL;

    DELETE FROM pronto_employee_preferences;
    DELETE FROM pronto_waiter_table_assignments;
    DELETE FROM pronto_recommendation_change_log WHERE employee_id IS NOT NULL;

    DO \$\$
    BEGIN
      IF to_regclass('public.audit_logs') IS NOT NULL THEN
        DELETE FROM audit_logs;
      END IF;
    END
    \$\$;

    DELETE FROM pronto_employees;
    COMMIT;
  "
  log "OK: empleados limpiados."
}

customers_clean() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    UPDATE pronto_dining_sessions SET customer_id = NULL WHERE customer_id IS NOT NULL;
    UPDATE pronto_orders SET customer_id = NULL WHERE customer_id IS NOT NULL;
    DELETE FROM pronto_feedback WHERE customer_id IS NOT NULL;
    DELETE FROM pronto_feedback_tokens WHERE user_id IS NOT NULL;
    DELETE FROM pronto_customers;
    COMMIT;
  "
  log "OK: clientes limpiados."
}

settings_list() {
  psql_cmd -c "
    SELECT key, value, value_type, category, updated_at
    FROM pronto_system_settings
    ORDER BY category, key;
  "
}

settings_set() {
  local key="$1"
  local value="$2"
  local value_type="$3"
  local category="$4"
  require_safe_env
  require_yes

  psql_exec "
    INSERT INTO pronto_system_settings (key, value, value_type, category, description, updated_at)
    VALUES ('${key}', '${value}', '${value_type}', '${category}', 'Updated by pronto-abc script', NOW())
    ON CONFLICT (key)
    DO UPDATE
      SET value = EXCLUDED.value,
          value_type = EXCLUDED.value_type,
          category = EXCLUDED.category,
          updated_at = NOW();
  "
  log "OK: setting actualizado ${key}=${value} (${value_type}, ${category})."
}

settings_reset_defaults() {
  require_safe_env
  require_yes
  psql_exec "
    BEGIN;
    INSERT INTO pronto_system_settings (key, value, value_type, category, description, updated_at)
    VALUES
      ('system.session.client_ttl_seconds', '3600', 'integer', 'system', 'TTL sesión cliente (segundos)', NOW()),
      ('session.kiosk_non_expiring', 'true', 'boolean', 'business', 'Kiosko sin expiración', NOW()),
      ('system.session.employee_ttl_hours', '24', 'integer', 'system', 'TTL sesión empleados (horas)', NOW()),
      ('waiter_can_collect', 'true', 'boolean', 'payments', 'Permite al mesero cobrar', NOW()),
      ('currency_code', 'MXN', 'string', 'business', 'Código de moneda', NOW()),
      ('currency_symbol', '$', 'string', 'business', 'Símbolo de moneda', NOW())
    ON CONFLICT (key)
    DO UPDATE
      SET value = EXCLUDED.value,
          value_type = EXCLUDED.value_type,
          category = EXCLUDED.category,
          updated_at = NOW();
    COMMIT;
  "
  log "OK: parámetros de sistema reseteados a defaults canónicos."
}

tables_assign_waiter() {
  local waiter_id="$1"
  local area_id="${2:-}"
  local all_tables="${3:-false}"

  validate_uuid "$waiter_id"
  require_safe_env
  require_yes

  local exists_waiter
  exists_waiter="$(psql "$DB_URL" -X -qAt -c "SELECT COUNT(*) FROM pronto_employees WHERE id = '${waiter_id}'::uuid;")"
  [[ "${exists_waiter}" != "0" ]] || die "El waiter_id no existe: ${waiter_id}"

  local where_clause="WHERE t.is_active = true"
  if [[ "${all_tables}" != "true" && -n "${area_id}" ]]; then
    [[ "${area_id}" =~ ^[0-9]+$ ]] || die "--area-id debe ser entero"
    where_clause="${where_clause} AND t.area_id = ${area_id}"
  fi

  psql_exec "
    BEGIN;
    WITH target_tables AS (
      SELECT t.id
      FROM pronto_tables t
      ${where_clause}
    ),
    deactivated AS (
      UPDATE pronto_waiter_table_assignments w
      SET is_active = false, unassigned_at = NOW(), notes = COALESCE(w.notes, '') || ' | reassigned by pronto-abc'
      WHERE w.is_active = true AND w.table_id IN (SELECT id FROM target_tables)
      RETURNING w.table_id
    )
    INSERT INTO pronto_waiter_table_assignments (waiter_id, table_id, assigned_at, is_active, notes)
    SELECT '${waiter_id}'::uuid, tt.id, NOW(), true, 'assigned by pronto-abc'
    FROM target_tables tt
    ON CONFLICT (waiter_id, table_id, is_active)
    DO UPDATE SET assigned_at = EXCLUDED.assigned_at, unassigned_at = NULL, notes = EXCLUDED.notes;
    COMMIT;
  "
  log "OK: mesas asignadas al mesero ${waiter_id}."
}

show_status() {
  psql_cmd -c "
    SELECT 'orders' AS section, COUNT(*)::bigint AS total FROM pronto_orders
    UNION ALL
    SELECT 'sessions', COUNT(*)::bigint FROM pronto_dining_sessions
    UNION ALL
    SELECT 'feedback', COUNT(*)::bigint FROM pronto_feedback
    UNION ALL
    SELECT 'payments', COUNT(*)::bigint FROM pronto_payments
    UNION ALL
    SELECT 'areas', COUNT(*)::bigint FROM pronto_areas
    UNION ALL
    SELECT 'tables', COUNT(*)::bigint FROM pronto_tables
    UNION ALL
    SELECT 'modifier_groups', COUNT(*)::bigint FROM pronto_modifier_groups
    UNION ALL
    SELECT 'modifiers', COUNT(*)::bigint FROM pronto_modifiers
    UNION ALL
    SELECT 'products', COUNT(*)::bigint FROM pronto_menu_items
    UNION ALL
    SELECT 'categories', COUNT(*)::bigint FROM pronto_menu_categories
    UNION ALL
    SELECT 'employees', COUNT(*)::bigint FROM pronto_employees
    UNION ALL
    SELECT 'customers', COUNT(*)::bigint FROM pronto_customers
    UNION ALL
    SELECT 'system_settings', COUNT(*)::bigint FROM pronto_system_settings
    ORDER BY section;
  "
}

full_clean() {
  require_safe_env
  require_yes
  orders_clean
  sessions_clean
  feedback_clean
  tables_clean
  areas_clean
  modifiers_clean
  products_clean
  customers_clean
  employees_clean
  settings_reset_defaults
  log "OK: full:clean completado."
}

if [[ $# -lt 1 ]]; then
  print_usage
  exit 1
fi

COMMAND="$1"
shift

# Parse global flags first pass.
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-url)
      [[ $# -ge 2 ]] || die "Falta valor para --db-url"
      DB_URL="$2"
      shift 2
      ;;
    --yes)
      YES=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
if ((${#ARGS[@]})); then
  set -- "${ARGS[@]}"
else
  set --
fi

case "$COMMAND" in
  status)
    show_status
    ;;
  orders:status)
    orders_status
    ;;
  orders:list)
    orders_list
    ;;
  orders:clean)
    orders_clean
    ;;
  orders:pay-all)
    orders_pay_all
    ;;
  orders:cancel-all)
    orders_cancel_all
    ;;
  orders:set-status)
    ORDER_STATUS=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --status)
          [[ $# -ge 2 ]] || die "Falta valor para --status"
          ORDER_STATUS="$2"
          shift 2
          ;;
        *)
          die "Opción no soportada para orders:set-status: $1"
          ;;
      esac
    done
    [[ -n "${ORDER_STATUS}" ]] || die "Debes indicar --status"
    orders_set_status "${ORDER_STATUS}"
    ;;
  sessions:clean)
    sessions_clean
    ;;
  feedback:clean)
    feedback_clean
    ;;
  areas:clean)
    areas_clean
    ;;
  tables:clean)
    tables_clean
    ;;
  modifiers:clean)
    modifiers_clean
    ;;
  products:clean)
    products_clean
    ;;
  employees:clean)
    employees_clean
    ;;
  customers:clean)
    customers_clean
    ;;
  tables:assign-waiter)
    WAITER_ID=""
    AREA_ID=""
    ALL_TABLES=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --waiter-id)
          [[ $# -ge 2 ]] || die "Falta valor para --waiter-id"
          WAITER_ID="$2"
          shift 2
          ;;
        --area-id)
          [[ $# -ge 2 ]] || die "Falta valor para --area-id"
          AREA_ID="$2"
          shift 2
          ;;
        --all-tables)
          ALL_TABLES=true
          shift
          ;;
        *)
          die "Opción no soportada para tables:assign-waiter: $1"
          ;;
      esac
    done
    [[ -n "${WAITER_ID}" ]] || die "Debes indicar --waiter-id"
    if [[ "${ALL_TABLES}" != "true" && -z "${AREA_ID}" ]]; then
      die "Debes indicar --area-id <int> o --all-tables"
    fi
    tables_assign_waiter "${WAITER_ID}" "${AREA_ID}" "${ALL_TABLES}"
    ;;
  settings:list)
    settings_list
    ;;
  settings:set)
    SETTING_KEY=""
    SETTING_VALUE=""
    SETTING_TYPE="string"
    SETTING_CATEGORY="general"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --key)
          [[ $# -ge 2 ]] || die "Falta valor para --key"
          SETTING_KEY="$2"
          shift 2
          ;;
        --value)
          [[ $# -ge 2 ]] || die "Falta valor para --value"
          SETTING_VALUE="$2"
          shift 2
          ;;
        --value-type)
          [[ $# -ge 2 ]] || die "Falta valor para --value-type"
          SETTING_TYPE="$2"
          shift 2
          ;;
        --category)
          [[ $# -ge 2 ]] || die "Falta valor para --category"
          SETTING_CATEGORY="$2"
          shift 2
          ;;
        *)
          die "Opción no soportada para settings:set: $1"
          ;;
      esac
    done
    [[ -n "${SETTING_KEY}" ]] || die "Debes indicar --key"
    [[ -n "${SETTING_VALUE}" ]] || die "Debes indicar --value"
    settings_set "${SETTING_KEY}" "${SETTING_VALUE}" "${SETTING_TYPE}" "${SETTING_CATEGORY}"
    ;;
  settings:reset-defaults)
    settings_reset_defaults
    ;;
  full:clean)
    full_clean
    ;;
  *)
    print_usage
    die "Comando desconocido: ${COMMAND}"
    ;;
esac
