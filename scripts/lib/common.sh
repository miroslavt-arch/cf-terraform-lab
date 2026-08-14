#!/usr/bin/env bash
# Shared plumbing for every demo script. Portable: Git Bash / macOS / Linux.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_LAB="$REPO_ROOT/infra/envs/lab"

# Tokens live OUTSIDE the repo, in ~/.cf-lab-env. Missing file is fine for
# offline demos; scripts that need credentials call need_env explicitly.
# shellcheck disable=SC1090
[ -f "$HOME/.cf-lab-env" ] && source "$HOME/.cf-lab-env"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
note()  { printf '\033[36m>> %s\033[0m\n' "$*"; }

say() { # the "what to say" beat — pause so the audience reads the screen
  echo
  bold "──────────────────────────────────────────────────────"
  bold "$*"
  bold "──────────────────────────────────────────────────────"
}

need_env() {
  local missing=0
  for v in "$@"; do
    if [ -z "${!v:-}" ]; then red "missing env var: $v (fill ~/.cf-lab-env)"; missing=1; fi
  done
  [ "$missing" = 0 ] || exit 1
}

cf_api() { # cf_api GET /zones/... [token-var (default CLOUDFLARE_API_TOKEN)]
  local method="$1" path="$2" tokenvar="${3:-CLOUDFLARE_API_TOKEN}" body="${4:-}"
  local args=(-s -X "$method" -H "Authorization: Bearer ${!tokenvar}" -H "Content-Type: application/json")
  [ -n "$body" ] && args+=(--data "$body")
  curl "${args[@]}" "https://api.cloudflare.com/client/v4${path}"
}
