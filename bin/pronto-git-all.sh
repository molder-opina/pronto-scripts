#!/bin/bash
set -e

# ==========================================
# PRONTO Git Multi-Project Manager
# Maneja todos los proyectos git en el folder pronto
# ==========================================

_get_script_dir() {
  local source="${BASH_SOURCE[0]}"
  while [ -h "$source" ]; do
    local dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source"
  done
  echo "$(cd -P "$(dirname "$source")" && pwd)"
}

SCRIPT_DIR="$(_get_script_dir)"

if [ -d "$SCRIPT_DIR/../../.git" ]; then
  PRONTO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
elif [ -d "$SCRIPT_DIR/../.git" ]; then
  PRONTO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -d "$SCRIPT_DIR/.git" ]; then
  PRONTO_ROOT="$SCRIPT_DIR"
else
  PRONTO_ROOT="/Users/molder/projects/github - molder/pronto"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECTS=(
  "pronto"
  "pronto-libs"
  "pronto-scripts"
  "pronto-api"
  "pronto-client"
  "pronto-static"
  "pronto-tests"
  "pronto-employees"
  "pronto-postgresql"
  "pronto-redis"
  "pronto-docs"
)

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_project() { echo -e "${CYAN}[${2}]${NC} $1"; }

show_help() {
  cat << EOF
${CYAN}╔════════════════════════════════════════════════════════════╗${NC}
${CYAN}║${NC}  PRONTO Git Multi-Project Manager v1.0               ${CYAN}║${NC}
${CYAN}╚════════════════════════════════════════════════════════════╝${NC}

${GREEN}Uso:${NC} $(basename "\$0") [comando] [opciones]

${GREEN}Comandos:${NC}
  ${GREEN}status${NC}      Muestra el estado de todos los proyectos
  ${GREEN}add${NC}         Añade todos los cambios (git add)
  ${GREEN}commit${NC}      Commit con mensaje automático
  ${GREEN}push${NC}        Push a todos los remotos
  ${GREEN}pull${NC}        Pull de todos los proyectos
  ${GREEN}sync${NC}        Realiza add + commit + push
  ${GREEN}fetch${NC}       Fetch de todos los proyectos
  ${GREEN}branch${NC}      Muestra branches actuales
  ${GREEN}branches${NC}     Lista todas las ramas locales/remotas
  ${GREEN}diff${NC}        Muestra diff de cambios no guardados
  ${GREEN}create-branch${NC} Crea nueva rama en todos los proyectos
  ${GREEN}checkout${NC}     Cambia a rama específica
  ${GREEN}merge${NC}        Merge rama específica

${GREEN}Opciones:${NC}
  ${GREEN}-m, --message MSG${NC}    Mensaje de commit
  ${GREEN}-p, --project PROJ${NC}   Solo afectar a un proyecto específico
  ${GREEN}-r, --rebase${NC}         Usar rebase en pull/merge
  ${GREEN}-v, --verbose${NC}        Salida detallada
  ${GREEN}-h, --help${NC}           Muestra esta ayuda

${GREEN}Proyectos:${NC}
  $(printf '  %s\n' "${PROJECTS[@]}")

${GREEN}Ejemplos:${NC}
  $(basename "\$0") status                    # Ver estado de todos
  $(basename "\$0") sync -m "Update utils"    # Commit y push todos
  $(basename "\$0") -p pronto-api status      # Solo pronto-api
  $(basename "\$0") pull --rebase             # Pull con rebase
  $(basename "\$0") checkout develop           # Cambiar a develop
  $(basename "\$0") create-branch feature/nueva

EOF
}

get_project_path() {
  local project="$1"
  if [ "$project" = "pronto" ]; then
    echo "$PRONTO_ROOT"
  else
    echo "${PRONTO_ROOT}/${project}"
  fi
}

is_git_repo() {
  local path="$1"
  [ -d "$path/.git" ] && [ -f "$path/.git/config" ] 2>/dev/null
}

git_status() {
  local path="$1"
  local project="$2"
  
  if ! is_git_repo "$path"; then
    log_warn "${project}: No es un repositorio git"
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  local status=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  local remote=$(git remote get-url origin 2>/dev/null || echo "sin remote")
  
  if [ "$status" -gt 0 ]; then
    log_project "${branch} | ${status} cambios sin commit" "$project"
  else
    local ahead=$(git rev-list --count HEAD...origin/${branch} 2>/dev/null || echo "0")
    if [ "$ahead" -gt 0 ]; then
      log_project "${branch} | ${ahead} commits por enviar" "$project"
    else
      log_project "${branch} | sincronizado" "$project"
    fi
  fi
}

git_add() {
  local path="$1"
  local project="$2"
  local verbose="$3"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  local added=$(git add -A 2>/dev/null | wc -l | tr -d ' ')
  if [ "$added" -gt 0 ]; then
    log_success "${project}: ${added} archivos añadidos"
  else
    log_warn "${project}: Sin cambios que añadir"
  fi
}

git_commit() {
  local path="$1"
  local project="$2"
  local message="$3"
  local verbose="$4"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    log_warn "${project}: No hay cambios para hacer commit"
    return 0
  fi
  
  if [ -z "$message" ]; then
    local date=$(date '+%Y-%m-%d %H:%M')
    message="Update: ${date}"
  fi
  
  if git commit -m "$message" > /dev/null 2>&1; then
    log_success "${project}: Commit realizado"
    if [ "$verbose" = "true" ]; then
      git log --oneline -1 | sed 's/^/    /'
    fi
  else
    log_error "${project}: Error al hacer commit"
  fi
}

git_push() {
  local path="$1"
  local project="$2"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  local ahead=$(git rev-list --count HEAD...origin/${branch} 2>/dev/null || echo "0")
  
  if [ "$ahead" = "0" ]; then
    log_warn "${project}: Nada que enviar (al día)"
    return 0
  fi
  
  if git push origin ${branch} > /dev/null 2>&1; then
    log_success "${project}: Push realizado (${ahead} commits)"
  else
    log_error "${project}: Error al hacer push"
  fi
}

git_pull() {
  local path="$1"
  local project="$2"
  local rebase="$3"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  
  if [ "$rebase" = "true" ]; then
    if git pull --rebase origin ${branch} > /dev/null 2>&1; then
      log_success "${project}: Pull --rebase completado"
    else
      log_warn "${project}: Conflictos o error en pull --rebase"
    fi
  else
    if git pull origin ${branch} > /dev/null 2>&1; then
      log_success "${project}: Pull completado"
    else
      log_warn "${project}: Error en pull"
    fi
  fi
}

git_fetch() {
  local path="$1"
  local project="$2"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  if git fetch origin > /dev/null 2>&1; then
    log_success "${project}: Fetch realizado"
  else
    log_warn "${project}: Fetch falló o sin remote"
  fi
}

git_diff() {
  local path="$1"
  local project="$2"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  local changes=$(git status --porcelain 2>/dev/null)
  
  if [ -n "$changes" ]; then
    echo -e "${YELLOW}=== ${project} ===${NC}"
    git status --short
    echo ""
  fi
}

git_branch_info() {
  local path="$1"
  local project="$2"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  local remote=$(git remote get-url origin 2>/dev/null || echo "sin remote")
  
  echo -e "${CYAN}${project}:${NC} ${branch}"
  echo "    Remote: ${remote}"
  
  local ahead=$(git rev-list --count HEAD...origin/${branch} 2>/dev/null || echo "0")
  local behind=$(git rev-list --count origin/${branch}...HEAD 2>/dev/null || echo "0")
  
  [ "$ahead" -gt 0 ] && echo "    ↑ ${ahead} commits por enviar"
  [ "$behind" -gt 0 ] && echo "    ↓ ${behind} commits por recibir"
}

git_create_branch() {
  local path="$1"
  local project="$2"
  local newBranch="$3"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  if git checkout -b "$newBranch" > /dev/null 2>&1; then
    log_success "${project}: Rama '${newBranch}' creada"
  else
    log_error "${project}: Error al crear rama '${newBranch}'"
  fi
}

git_checkout() {
  local path="$1"
  local project="$2"
  local targetBranch="$3"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  if git checkout "$targetBranch" > /dev/null 2>&1; then
    log_success "${project}: Cambiado a '${targetBranch}'"
  else
    log_error "${project}: Error al cambiar a '${targetBranch}'"
  fi
}

git_merge() {
  local path="$1"
  local project="$2"
  local sourceBranch="$3"
  local rebase="$4"
  
  if ! is_git_repo "$path"; then
    return 1
  fi
  
  cd "$path" 2>/dev/null || return 1
  
  local currentBranch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  
  if [ "$rebase" = "true" ]; then
    if git rebase "$sourceBranch" > /dev/null 2>&1; then
      log_success "${project}: Rebase de '${sourceBranch}' completado"
    else
      log_warn "${project}: Conflictos en rebase de '${sourceBranch}'"
    fi
  else
    if git merge "$sourceBranch" > /dev/null 2>&1; then
      log_success "${project}: Merge de '${sourceBranch}' completado"
    else
      log_warn "${project}: Conflictos al merge de '${sourceBranch}'"
    fi
  fi
}

COMMAND="status"
MESSAGE=""
PROJECT=""
REBASE="false"
VERBOSE="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--message)
      MESSAGE="$2"
      shift 2
      ;;
    -p|--project)
      PROJECT="$2"
      shift 2
      ;;
    -r|--rebase)
      REBASE="true"
      shift
      ;;
    -v|--verbose)
      VERBOSE="true"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      COMMAND="$1"
      shift
      ;;
  esac
done

if [ -n "$PROJECT" ]; then
  PROJECTS=("$PROJECT")
fi

case $COMMAND in
  status)
    log_info "Estado de proyectos git:"
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_status "$path" "$project"
    done
    ;;
    
  add)
    log_info "Añadiendo cambios..."
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_add "$path" "$project" "$VERBOSE"
    done
    ;;
    
  commit)
    if [ -z "$MESSAGE" ]; then
      log_error "Mensaje de commit requerido. Usa -m 'tu mensaje'"
      exit 1
    fi
    log_info "Haciendo commit: ${MESSAGE}"
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_commit "$path" "$project" "$MESSAGE" "$VERBOSE"
    done
    ;;
    
  push)
    log_info "Enviando cambios..."
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_push "$path" "$project"
    done
    ;;
    
  pull)
    log_info "Recibiendo cambios..."
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_pull "$path" "$project" "$REBASE"
    done
    ;;
    
  sync)
    log_info "Sincronizando (add + commit + push)..."
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_add "$path" "$project" "$VERBOSE"
      git_commit "$path" "$project" "$MESSAGE" "$VERBOSE"
      git_push "$path" "$project"
    done
    ;;
    
  fetch)
    log_info "Obteniendo cambios remotos..."
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_fetch "$path" "$project"
    done
    ;;
    
  branch|branches)
    log_info "Información de branches:"
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_branch_info "$path" "$project"
      echo ""
    done
    ;;
    
  diff)
    log_info "Mostrando cambios no guardados..."
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_diff "$path" "$project"
    done
    ;;
    
  create-branch)
    if [ -z "$MESSAGE" ]; then
      log_error "Nombre de rama requerido. Usa -m 'nombre-rama'"
      exit 1
    fi
    log_info "Creando rama: ${MESSAGE}"
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_create_branch "$path" "$project" "$MESSAGE"
    done
    ;;
    
  checkout)
    if [ -z "$MESSAGE" ]; then
      log_error "Rama objetivo requerida. Usa -m 'nombre-rama'"
      exit 1
    fi
    log_info "Cambiando a rama: ${MESSAGE}"
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_checkout "$path" "$project" "$MESSAGE"
    done
    ;;
    
  merge)
    if [ -z "$MESSAGE" ]; then
      log_error "Rama source requerida. Usa -m 'source-branch'"
      exit 1
    fi
    log_info "Mergeando: ${MESSAGE}"
    echo ""
    for project in "${PROJECTS[@]}"; do
      path=$(get_project_path "$project")
      git_merge "$path" "$project" "$MESSAGE" "$REBASE"
    done
    ;;
    
  *)
    log_error "Comando desconocido: $COMMAND"
    show_help
    exit 1
    ;;
esac

echo ""
log_success "Operación completada"
