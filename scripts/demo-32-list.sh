#!/usr/bin/env bash
# Sharp edge 3 — list scale: time plans for 500 per-item resources vs one
# 500-item collection. REAL numbers from THIS account; record them.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID
d="$REPO_ROOT/demos/sharp-edges/list-scale"
N="${ITEM_COUNT:-500}"

say "Sharp edge: the same 500 list entries as 500 resources vs 1 resource — measure, don't argue"

for shape in per-item bulk; do
  note "applying $shape (n=$N)..."
  terraform -chdir="$d/$shape" init -backend=false -input=false >/dev/null
  terraform -chdir="$d/$shape" apply -auto-approve -input=false \
    -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N" >/dev/null
  green "$shape applied"
done

say "The measurement: terraform plan wall-clock, warm provider, no changes pending"
for shape in per-item bulk; do
  note "timing plan on $shape ..."
  /usr/bin/time -f "  %e seconds" terraform -chdir="$d/$shape" plan -input=false \
    -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N" >/dev/null 2>/tmp/time-$shape.txt \
    || { time terraform -chdir="$d/$shape" plan -input=false \
         -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N" >/dev/null; } 2>/tmp/time-$shape.txt
  cat /tmp/time-$shape.txt | tail -3
done

say "Teardown (both lists are lab_-prefixed demo objects)"
note "per-item: normal destroy (500 deletes — feel the pain one more time)..."
time terraform -chdir="$d/per-item" destroy -auto-approve -input=false \
  -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N" >/dev/null

note "bulk: prevent_destroy guards it — demonstrating the guard first:"
if terraform -chdir="$d/bulk" destroy -auto-approve -input=false \
     -var "account_id=$CLOUDFLARE_ACCOUNT_ID" -var "item_count=$N" 2>&1 | grep -m1 "prevent_destroy"; then
  green "^ destroy BLOCKED by lifecycle — exactly what it is for."
fi
note "teardown path for guarded resources: state rm + explicit API delete"
list_id=$(cf_api GET "/accounts/$CLOUDFLARE_ACCOUNT_ID/rules/lists" | jq -r '.result[] | select(.name=="lab_scale_bulk") | .id')
terraform -chdir="$d/bulk" state rm cloudflare_list.bulk >/dev/null
cf_api DELETE "/accounts/$CLOUDFLARE_ACCOUNT_ID/rules/lists/$list_id" >/dev/null
rm -rf "$d/bulk"/terraform.tfstate* "$d/per-item"/terraform.tfstate*
green "both lists gone. Write the two plan timings into docs/runbooks/topic-32.md."
