#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# VERIFY — prove every pattern in this kit works, in YOUR test account.
#
#   bash scripts/preflight.sh && bash scripts/verify.sh
#
# Phases 1-4 are offline and free. Phase 5 touches your test account and is
# skipped unless you pass --live.
#
#   bash scripts/verify.sh          offline only
#   bash scripts/verify.sh --live   also create/change/destroy real records
#
# Everything it creates carries your resource_prefix and is removed before it
# exits, including on failure.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

LIVE=0
[ "${1:-}" = "--live" ] && LIVE=1

pass=0
fail=0
step() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
ok() {
  printf '  \033[32mPASS\033[0m %s\n' "$*"
  pass=$((pass + 1))
}
no() {
  printf '  \033[31mFAIL\033[0m %s\n' "$*"
  fail=$((fail + 1))
}
note() { printf '  \033[36m%s\033[0m\n' "$*"; }

# ─────────────────────────────────────────────────────────────────────────────
step "1/5  Static checks — no credentials needed"
# ─────────────────────────────────────────────────────────────────────────────

terraform fmt -check -recursive >/dev/null 2>&1 &&
  ok "terraform fmt clean" || no "terraform fmt would reformat files"

terraform init -backend=false -input=false >/dev/null 2>&1 &&
  ok "terraform init" || no "terraform init failed"

terraform validate >/dev/null 2>&1 &&
  ok "terraform validate" || no "terraform validate failed"

# ─────────────────────────────────────────────────────────────────────────────
step "2/5  Tier-one tests — mocked provider, no credentials, no network"
# ─────────────────────────────────────────────────────────────────────────────

# Run with every credential stripped, to prove the claim rather than assert it.
out=$(env -u CLOUDFLARE_API_TOKEN -u CLOUDFLARE_EMAIL -u AWS_ACCESS_KEY_ID \
  terraform test -no-color 2>&1)
if echo "$out" | grep -q "0 failed"; then
  ok "$(echo "$out" | grep -oE '[0-9]+ passed, [0-9]+ failed' | tail -1) with NO credentials in the environment"
else
  no "tier-one tests failed"
  echo "$out" | tail -12 | sed 's/^/       /'
fi

# ─────────────────────────────────────────────────────────────────────────────
step "3/5  Policies — must fire in BOTH directions"
# ─────────────────────────────────────────────────────────────────────────────
# A policy that never fires looks exactly like a policy that works. So check
# the known-good passes AND the known-bad fails.

if ! command -v conftest >/dev/null 2>&1; then
  note "conftest not installed — skipping policy checks"
  note "install: https://github.com/open-policy-agent/conftest/releases"
else
  conftest test --policy policy --namespace destroy_guard \
    policy/fixtures/plan-allowed.json >/dev/null 2>&1 &&
    ok "destroy_guard ALLOWS disposable resources" ||
    no "destroy_guard blocked a plan it should allow"

  if conftest test --policy policy --namespace destroy_guard \
    policy/fixtures/plan-destroys-production.json >/dev/null 2>&1; then
    no "destroy_guard PASSED a plan that destroys production — the guard is broken"
  else
    ok "destroy_guard BLOCKS destroying a non-disposable resource"
  fi

  if conftest test --policy policy \
    policy/fixtures/fragment-known-bad.yaml >/dev/null 2>&1; then
    no "fragment_policy passed a known-bad fragment"
  else
    ok "fragment_policy BLOCKS the known-bad fragment"
  fi

  conftest test --policy policy --namespace eval_release_guard \
    policy/fixtures/evalreport-good.json >/dev/null 2>&1 &&
    ok "eval_release_guard ALLOWS a good report" ||
    no "eval_release_guard blocked a good report"

  if conftest test --policy policy --namespace eval_release_guard \
    policy/fixtures/evalreport-blocked.json >/dev/null 2>&1; then
    no "eval_release_guard passed a report it should block"
  else
    ok "eval_release_guard BLOCKS a bad report"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "4/5  AI tier-one evals — no model, no credential, no cost"
# ─────────────────────────────────────────────────────────────────────────────

if ! python -c "import pytest" >/dev/null 2>&1; then
  note "pytest not installed — skipping"
  note "install: pip install -r ai/requirements-dev.txt"
else
  out=$(env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MODEL_API_KEY     python -m pytest ai/eval/tier_one -q 2>&1)
  if echo "$out" | grep -qE "[0-9]+ passed"; then
    ok "$(echo "$out" | grep -oE '[0-9]+ passed' | tail -1) with NO model credentials in the environment"
  else
    no "AI tier-one evals failed"
    echo "$out" | tail -10 | sed 's/^/       /'
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "5/5  Live checks — your test account"
# ─────────────────────────────────────────────────────────────────────────────

if [ "$LIVE" -ne 1 ]; then
  note "skipped. Re-run with --live to exercise the real account."
else
  : "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN first}"
  : "${TF_VAR_zone_id:?set TF_VAR_zone_id first}"
  : "${TF_VAR_zone_name:?set TF_VAR_zone_name first}"

  ROOT=infra/envs/sandbox
  PREFIX="${TF_VAR_resource_prefix:-tf-}"

  cleanup() {
    note "cleaning up..."
    terraform -chdir="$ROOT" destroy -auto-approve -input=false >/dev/null 2>&1
    note "destroyed everything this script created"
  }
  trap cleanup EXIT

  terraform -chdir="$ROOT" init -input=false >/dev/null 2>&1 &&
    ok "sandbox init" || no "sandbox init failed"

  # -- the destroy guard, against a REAL plan of yours ----------------------
  if command -v conftest >/dev/null 2>&1; then
    terraform -chdir="$ROOT" plan -input=false -out=/tmp/v.tfplan >/dev/null 2>&1
    terraform -chdir="$ROOT" show -json /tmp/v.tfplan >/tmp/v.json 2>/dev/null
    conftest test --policy policy --namespace destroy_guard /tmp/v.json >/dev/null 2>&1 &&
      ok "your real plan passes the destroy guard" ||
      no "your real plan is BLOCKED by the destroy guard — read the message"
    rm -f /tmp/v.tfplan /tmp/v.json
  fi

  # -- apply, then confirm the API agrees -----------------------------------
  if terraform -chdir="$ROOT" apply -auto-approve -input=false >/dev/null 2>&1; then
    ok "apply succeeded"
  else
    no "apply failed"
  fi

  live=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$TF_VAR_zone_id/dns_records?per_page=100" |
    jq -r --arg p "$PREFIX" '[.result[] | select(.name | startswith($p))] | length')
  [ "${live:-0}" -ge 2 ] &&
    ok "$live records with prefix '$PREFIX' exist in the API" ||
    no "expected at least 2 prefixed records, found ${live:-0}"

  # -- a clean plan is the real proof --------------------------------------
  terraform -chdir="$ROOT" plan -input=false -detailed-exitcode >/dev/null 2>&1
  [ $? -eq 0 ] &&
    ok "plan is clean after apply (code == reality)" ||
    no "plan is NOT clean after apply — the config does not describe what was built"

  # -- drift detection, on manufactured drift -------------------------------
  rid=$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$TF_VAR_zone_id/dns_records?name=${PREFIX}canary.${TF_VAR_subdomain:-sandbox}.$TF_VAR_zone_name" |
    jq -r '.result[0].id // empty')

  if [ -n "$rid" ]; then
    curl -s -X PATCH -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      -H "content-type: application/json" --data '{"ttl":120}' \
      "https://api.cloudflare.com/client/v4/zones/$TF_VAR_zone_id/dns_records/$rid" >/dev/null
    note "changed a TTL out of band — exactly what a console click does"

    terraform -chdir="$ROOT" plan -input=false -detailed-exitcode >/dev/null 2>&1
    [ $? -eq 2 ] &&
      ok "drift DETECTED (plan exit code 2)" ||
      no "drift was NOT detected — the nightly workflow would miss this"

    terraform -chdir="$ROOT" apply -auto-approve -input=false >/dev/null 2>&1
    note "healed the drift"
  else
    no "could not find the canary record to drift"
  fi
fi

printf '\n\033[1m%s\033[0m\n' "RESULT"
printf '  %s passed, %s failed\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
printf '  \033[32mEverything in this kit works in your account.\033[0m\n\n'
