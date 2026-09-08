#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# PREFLIGHT — run this FIRST, before anything touches an account.
#
#   bash scripts/preflight.sh
#
# Checks your tools, your credentials, and — most importantly — that the zone
# you are pointing at is a TEST zone. Exits non-zero if anything is missing, so
# you can put it in front of the rest.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

ok=0
fail=0
warn=0

green() { printf '  \033[32m%s\033[0m %s\n' "PASS" "$*"; ok=$((ok + 1)); }
red() { printf '  \033[31m%s\033[0m %s\n' "FAIL" "$*"; fail=$((fail + 1)); }
yellow() { printf '  \033[33m%s\033[0m %s\n' "WARN" "$*"; warn=$((warn + 1)); }
# NOT named `head`: that would shadow head(1), which this script uses below.
section() { printf '\n\033[1m%s\033[0m\n' "$*"; }

section "TOOLS"

need_tool() { # need_tool <cmd> <why> <required|optional>
  if command -v "$1" >/dev/null 2>&1; then
    green "$1 ($($1 --version 2>&1 | head -1 | cut -c1-46))"
  elif [ "${3:-required}" = "optional" ]; then
    yellow "$1 not found — $2"
  else
    red "$1 not found — $2"
  fi
}

need_tool terraform "required for everything"
need_tool conftest "required to run the policies" optional
need_tool jq "required by the drift workflow"
need_tool git "required"
need_tool python "required by scripts/drift_report.py" optional

# Terraform >= 1.9: cross-variable validation in the module.
if command -v terraform >/dev/null 2>&1; then
  tfv=$(terraform version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  tfv="${tfv:-0.0.0}"
  major=$(echo "$tfv" | cut -d. -f1)
  minor=$(echo "$tfv" | cut -d. -f2)
  if [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -ge 9 ]; }; then
    green "terraform $tfv >= 1.9 (needed for cross-variable validation)"
  else
    red "terraform $tfv is below 1.9. The module's resource_prefix validation references another variable, which needs 1.9+."
  fi
fi

section "CREDENTIALS"

# Names only. Never print a token value — this output gets pasted into tickets.
if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
  green "CLOUDFLARE_API_TOKEN is set (${#CLOUDFLARE_API_TOKEN} chars, value not shown)"
else
  red "CLOUDFLARE_API_TOKEN is not set. export it in THIS shell."
fi

section "TARGET ZONE"

ZONE_NAME="${TF_VAR_zone_name:-${SANDBOX_ZONE_NAME:-}}"
ZONE_ID="${TF_VAR_zone_id:-${SANDBOX_ZONE_ID:-}}"

if [ -z "$ZONE_NAME" ]; then
  red "TF_VAR_zone_name is not set. export TF_VAR_zone_name=sandbox.example.com"
else
  green "target zone: $ZONE_NAME"

  # ── THE SAFETY CHECK ────────────────────────────────────────────────────
  # This kit creates and destroys records. Pointing it at a production zone is
  # the one mistake that actually hurts, so make it hard to do by accident.
  case "$ZONE_NAME" in
  *sandbox* | *test* | *lab* | *dev* | *staging* | *example.com)
    green "zone name looks like a test zone"
    ;;
  *)
    yellow "zone name does not contain sandbox/test/lab/dev/staging."
    printf '       This kit CREATES AND DESTROYS records. If %s is a\n' "$ZONE_NAME"
    printf '       production zone, stop now and point it somewhere else.\n'
    printf '       Set ALLOW_ANY_ZONE=1 to silence this check.\n'
    [ "${ALLOW_ANY_ZONE:-}" = "1" ] || fail=$((fail + 1))
    ;;
  esac
fi

if [ -n "${CLOUDFLARE_API_TOKEN:-}" ] && [ -n "$ZONE_NAME" ]; then
  resp=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" 2>/dev/null)
  live_id=$(echo "$resp" | jq -r '.result[0].id // empty' 2>/dev/null)
  status=$(echo "$resp" | jq -r '.result[0].status // empty' 2>/dev/null)

  if [ -n "$live_id" ]; then
    green "zone reachable with this token (status: $status)"
    if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "$live_id" ]; then
      red "TF_VAR_zone_id ($ZONE_ID) does not match the live id for $ZONE_NAME ($live_id)"
    elif [ -z "$ZONE_ID" ]; then
      yellow "TF_VAR_zone_id is not set. The live id is: $live_id"
    else
      green "TF_VAR_zone_id matches the live zone"
    fi

    # How much is already here? A busy zone is probably not a sandbox.
    n=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      "https://api.cloudflare.com/client/v4/zones/$live_id/dns_records?per_page=100" |
      jq -r '.result | length' 2>/dev/null)
    if [ "${n:-0}" -gt 25 ]; then
      yellow "$n DNS records already exist here. Are you sure this is a sandbox?"
    else
      green "${n:-0} existing DNS records — consistent with a sandbox"
    fi
  else
    red "could not read $ZONE_NAME with this token. Check the token's zone scope."
  fi
fi

section "REPO"

[ -f infra/envs/sandbox/main.tf ] && green "sandbox root present" || red "run this from the repo root"
[ -f policy/destroy_guard.rego ] && green "policies present" || red "policy/ missing"

if [ -f infra/envs/sandbox/terraform.tfvars ]; then
  green "terraform.tfvars exists"
else
  yellow "no terraform.tfvars — copy infra/envs/sandbox/terraform.tfvars.example and fill it in, or use TF_VAR_* env vars"
fi

# The prefix in the policy must match the prefix the module will use, or the
# destroy guard will block your own teardown.
if [ -f policy/destroy_guard.rego ]; then
  if grep -q '"tftest-"' policy/destroy_guard.rego; then
    green "destroy_guard allows the tftest- prefix (contract tests can clean up)"
  else
    yellow "destroy_guard does not list tftest- as disposable; contract-test teardown will be blocked"
  fi
fi

printf '\n\033[1m%s\033[0m\n' "SUMMARY"
printf '  %s passed, %s warnings, %s failures\n\n' "$ok" "$warn" "$fail"

if [ "$fail" -gt 0 ]; then
  printf '  \033[31mNot ready.\033[0m Fix the failures above, then run this again.\n\n'
  exit 1
fi

printf '  \033[32mReady.\033[0m Next: bash scripts/verify.sh\n\n'
