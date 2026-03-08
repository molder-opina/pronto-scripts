#!/usr/bin/env bash

detect_compose_command() {
  local compose_file="$1"
  local project_name="${COMPOSE_PROJECT_NAME:-pronto-app}"

  export COMPOSE_PROJECT_NAME="${project_name}"

  if command_exists docker && docker compose version >/dev/null 2>&1; then
    CONTAINER_CLI="docker"
    COMPOSE_CMD=(docker compose -f "${compose_file}" -p "${project_name}")
  elif command_exists docker-compose; then
    CONTAINER_CLI="docker"
    COMPOSE_CMD=(docker-compose -f "${compose_file}" -p "${project_name}")
  elif command_exists podman && podman compose version >/dev/null 2>&1; then
    CONTAINER_CLI="podman"
    COMPOSE_CMD=(podman compose -f "${compose_file}" -p "${project_name}")
  elif command_exists podman-compose; then
    CONTAINER_CLI="podman"
    COMPOSE_CMD=(podman-compose -f "${compose_file}" -p "${project_name}")
  else
    echo "ERROR: No se encontró un runtime de contenedores compatible (docker/podman)." >&2
    return 1
  fi

  if ! "${COMPOSE_CMD[@]}" ps >/dev/null 2>&1; then
    if command_exists sudo; then
      COMPOSE_CMD=(sudo "${COMPOSE_CMD[@]}")
      if ! "${COMPOSE_CMD[@]}" ps >/dev/null 2>&1; then
        echo "ERROR: No se pudo acceder al daemon de contenedores. Verifica permisos." >&2
        return 1
      fi
    else
      echo "ERROR: El runtime requiere privilegios y 'sudo' no está disponible." >&2
      return 1
    fi
  fi
}

ensure_ports_free() {
  local entry
  local port
  local label

  for entry in "$@"; do
    IFS='|' read -r port label <<< "${entry}"
    [[ -z "${port}" ]] && continue

    if command_exists lsof; then
      if lsof -Pi :"${port}" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "ERROR: Puerto ${port} (${label}) ya está en uso"
        lsof -Pi :"${port}" -sTCP:LISTEN || true
        exit 1
      fi
    elif command_exists ss; then
      if ss -ltn "sport = :${port}" 2>/dev/null | awk 'NR>1 {exit 0} END {exit 1}'; then
        echo "ERROR: Puerto ${port} (${label}) ya está en uso"
        ss -ltn "sport = :${port}" || true
        exit 1
      fi
    elif command_exists netstat; then
      if netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"; then
        echo "ERROR: Puerto ${port} (${label}) ya está en uso"
        netstat -ltn 2>/dev/null | grep -E "[:.]${port}$" || true
        exit 1
      fi
    else
      echo "WARN: No se encontró lsof/ss/netstat; omitiendo verificación de puertos."
      return 0
    fi

    echo "   OK: Puerto ${port} disponible (${label})"
  done
}

reset_named_array() {
  local array_name="$1"
  eval "${array_name}=()"
}

append_named_array() {
  local array_name="$1"
  local value="$2"
  local escaped_value
  printf -v escaped_value '%q' "${value}"
  eval "${array_name}+=( ${escaped_value} )"
}

summarize_services() {
  local container_cli="$1"
  local summary_ref_name="$2"
  local failed_ref_name="$3"
  shift 3

  reset_named_array "${summary_ref_name}"
  reset_named_array "${failed_ref_name}"

  local target
  local label
  local container
  local status

  for target in "$@"; do
    IFS='|' read -r label container <<< "${target}"
    [[ -z "${container}" ]] && continue

    if ! "${container_cli}" ps -a --format '{{.Names}}' | grep -Fxq "${container}"; then
      append_named_array "${summary_ref_name}" "ERROR: ${label}: no encontrado (${container})"
      append_named_array "${failed_ref_name}" "${label} (${container})"
      continue
    fi

    status="$("${container_cli}" inspect -f '{{.State.Status}}' "${container}" 2>/dev/null || true)"
    case "${status}" in
      running)
        append_named_array "${summary_ref_name}" "OK: ${label}: running"
        ;;
      exited)
        append_named_array "${summary_ref_name}" "ERROR: ${label}: exited"
        append_named_array "${failed_ref_name}" "${label} (${container})"
        ;;
      *)
        append_named_array "${summary_ref_name}" "WARN: ${label}: ${status:-unknown}"
        append_named_array "${failed_ref_name}" "${label} (${container})"
        ;;
    esac
  done
}
