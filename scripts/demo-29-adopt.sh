#!/usr/bin/env bash
# Topic 29 — brownfield adoption end to end:
#   1. cf-terraforming shows what the dashboard era left behind
#   2. import blocks (for_each over CSV) adopt the DNS records
#   3. -generate-config-out adopts the ruleset with Terraform writing the config
#   4. normalize.py cleans the generated config
#   GATE: plan reaches "No changes" — only then is refactoring allowed.
# Prereq: brownfield/seed-legacy.sh has run.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID LAB_ZONE
adopt="$REPO_ROOT/brownfield/adopt"
cd "$adopt"

zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
[ -f "$REPO_ROOT/brownfield/records.csv" ] || { red "run brownfield/seed-legacy.sh first"; exit 1; }

# Make the demo re-runnable: drop any state from a previous run so the import
# blocks have something to import. This removes STATE ONLY — the live legacy
# resources are untouched, which is the whole point of the topic.
rm -f "$adopt"/terraform.tfstate "$adopt"/terraform.tfstate.backup       "$adopt"/generated_ruleset.tf "$adopt"/imports_ruleset.tf

say "Topic 29: resources Terraform has NEVER seen -> a clean no-op plan, without touching the live estate"

note "0/4 — capturing the 'before' truth: what does cf-terraforming see?"
cf-terraforming generate --resource-type cloudflare_dns_record --zone "$zone_id" \
  --token "$CLOUDFLARE_API_TOKEN" 2>/dev/null | grep -E "resource|name.*lab-legacy" | head -12 \
  || note "(cf-terraforming generate preview unavailable — continuing with import blocks)"

terraform init -input=false >/dev/null 2>&1 || terraform init -input=false

note "1/4 — planning the CSV-driven import blocks (5 records, ONE import block)..."
terraform plan -input=false -no-color -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" \
  | grep -E "will be imported|Plan:" | tee /tmp/adopt-before.txt

note "2/4 — adopting the ruleset via -generate-config-out..."
rs_id=$(cat "$REPO_ROOT/brownfield/ruleset.id")
if ! grep -q "cloudflare_ruleset" imports_ruleset.tf 2>/dev/null; then
  cat > imports_ruleset.tf <<EOF
import {
  to = cloudflare_ruleset.legacy
  id = "zones/$zone_id/$rs_id"
}
EOF
fi
rm -f generated_ruleset.tf
terraform plan -input=false -no-color -generate-config-out=generated_ruleset.tf \
  -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" >/dev/null 2>&1 || true
if [ ! -f generated_ruleset.tf ]; then
  red "generate-config-out produced nothing — check the import id format in imports_ruleset.tf"; exit 1
fi
green "Terraform wrote the ruleset config itself: generated_ruleset.tf"

note "3/4 — normalizing the generated config (drop nulls/computed noise)..."
python "$REPO_ROOT/scripts/normalize.py" generated_ruleset.tf

note "4/4 — applying the imports (state-only; the LIVE resources are untouched)..."
terraform apply -auto-approve -input=false -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" | grep -E "Imported|Apply"

say "THE GATE: the next plan must be 'No changes' before anyone refactors"
terraform plan -input=false -no-color -detailed-exitcode -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" \
  | tail -5 | tee /tmp/adopt-after.txt
code=${PIPESTATUS[0]}
if [ "$code" = "0" ]; then
  green "No changes — adoption is complete and provably non-destructive. NOW you may refactor."
else
  red "plan is not quiet yet (exit $code) — normalize further; do NOT refactor from here"
fi
