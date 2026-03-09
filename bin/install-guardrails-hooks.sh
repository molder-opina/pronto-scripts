#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
REPOS=(pronto-api pronto-client pronto-employees pronto-static)

usage() {
  cat <<'USAGE'
Usage:
  install-guardrails-hooks.sh [--with-smoke]

Options:
  --with-smoke   Enable smoke-critical in pre-push hooks (sets PRONTO_PREPUSH_SMOKE=1)
  -h, --help     Show this help
USAGE
}

WITH_SMOKE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-smoke)
      WITH_SMOKE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option $1" >&2
      usage
      exit 1
      ;;
  esac
done

for repo in "${REPOS[@]}"; do
  repo_path="$WORKSPACE_ROOT/$repo"
  if [ ! -d "$repo_path/.git" ]; then
    echo "[skip] $repo: not a git repository"
    continue
  fi

  pre_commit_hook="$repo_path/.git/hooks/pre-commit"
  cat > "$pre_commit_hook" <<HOOK
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="\$(git rev-parse --show-toplevel)"
WORKSPACE_ROOT="\$(dirname "\$REPO_ROOT")"

set +e
bash "\$WORKSPACE_ROOT/pronto-scripts/bin/pre-commit-ai" --staged --mode warn --repo "$repo"
code=\$?
set -e

if [ "\$code" -eq 1 ]; then
  exit 1
fi

if [ "\$code" -eq 2 ]; then
  echo "pre-commit-ai returned WARNINGS (exit 2). Commit allowed in local warn mode."
  exit 0
fi

exit 0
HOOK
  chmod +x "$pre_commit_hook"

  pre_push_hook="$repo_path/.git/hooks/pre-push"
  cat > "$pre_push_hook" <<HOOK
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="\$(git rev-parse --show-toplevel)"
WORKSPACE_ROOT="\$(dirname "\$REPO_ROOT")"

export PRONTO_GATE_CONTEXT=local
HOOK
  if [ "$WITH_SMOKE" -eq 1 ]; then
    cat >> "$pre_push_hook" <<'HOOK'
export PRONTO_PREPUSH_SMOKE=1
HOOK
  fi

  cat >> "$pre_push_hook" <<HOOK

bash "\$WORKSPACE_ROOT/pronto-scripts/bin/pronto-local-prepush" --repo "$repo"
HOOK

  chmod +x "$pre_push_hook"
  echo "[ok] installed hooks for $repo (pre-commit + pre-push)"
done

if [ "$WITH_SMOKE" -eq 1 ]; then
  echo "Guardrails hooks installation complete (smoke enabled in pre-push)."
else
  echo "Guardrails hooks installation complete (smoke disabled in pre-push)."
fi
