#!/usr/bin/env bash
# Sharp edge 3 — list scale: N entries as N resources vs one collection.
#
# DEFAULT N=150, deliberately. At N=500 the per-item shape does not merely get
# slow — Cloudflare returns 429 "you have been ratelimited" partway through and
# the apply FAILS, leaving a half-built list. That is a real measured result
# from this account (2026-08-14), recorded in docs/runbooks/topic-32.md, and it
# is too slow and too fragile to run live. Use ITEM_COUNT=500 only if you want
# to reproduce the failure off-stage.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
d="$REPO_ROOT/demos/sharp-edges/list-scale"
N="${ITEM_COUNT:-150}"

timed() { # timed <label> <cmd...>
  local label="$1"; shift
  local s e
  s=$(date +%s); "$@" >/dev/null 2>&1; e=$(date +%s)
  printf '  %-38s %s seconds\n' "$label" "$((e - s))"
}

say "Sharp edge: the same $N list entries, two shapes. Measure, don't argue."

note "applying per-item ($N separate cloudflare_list_item resources)..."
terraform -chdir="$d/per-item" init -backend=false -input=false >/dev/null
timed "per-item APPLY ($N resources)" terraform -chdir="$d/per-item" apply -auto-approve -input=false \
  -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N"

note "applying bulk (ONE cloudflare_list holding $N items)..."
terraform -chdir="$d/bulk" init -backend=false -input=false >/dev/null
timed "bulk APPLY (1 resource)" terraform -chdir="$d/bulk" apply -auto-approve -input=false \
  -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N"

say "The measurement that matters: a NO-OP plan. This is what every PR pays."
timed "per-item PLAN (no-op)" terraform -chdir="$d/per-item" plan -input=false \
  -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N"
timed "bulk PLAN (no-op)" terraform -chdir="$d/bulk" plan -input=false \
  -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N"

say "Teardown — and the per-item shape charges you again on the way out"
timed "per-item DESTROY" terraform -chdir="$d/per-item" destroy -auto-approve -input=false \
  -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N"

note "bulk carries prevent_destroy — showing the guard refuse first:"
if terraform -chdir="$d/bulk" destroy -auto-approve -input=false \
     -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N" 2>&1 | grep -m1 -i "prevent_destroy"; then
  green "^ destroy BLOCKED by lifecycle — exactly what it is for."
fi
note "documented path for guarded resources: state rm + explicit API delete"
list_id=$(cf_api GET "/accounts/$CLOUDFLARE_ACCOUNT_ID/rules/lists" | jq -r '.result[]|select(.name=="lab_scale_bulk")|.id')
terraform -chdir="$d/bulk" state rm cloudflare_list.bulk >/dev/null 2>&1
[ -n "$list_id" ] && cf_api DELETE "/accounts/$CLOUDFLARE_ACCOUNT_ID/rules/lists/$list_id" >/dev/null
rm -f "$d/bulk"/terraform.tfstate* "$d/per-item"/terraform.tfstate*
green "both lists gone."

say "Trade-off: per-item buys per-item ownership (different teams can contribute entries) and pays for it on EVERY plan, forever. One collection is fast but has exactly one owner — Topic 9's lesson at a different altitude."
