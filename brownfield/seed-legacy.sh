#!/usr/bin/env bash
# Topic 29 — create the "legacy estate" exactly the way a dashboard user
# would: raw API calls, no Terraform, deliberately inconsistent values
# (mixed TTLs, missing comments) so adoption has something to normalize.
#
# Creates (idempotent-ish; skips records that already exist):
#   - 5 DNS records: lab-legacy-{alpha..echo}.lab.<zone>
#   - 1 ruleset in the http_response_headers_transform phase (a DIFFERENT
#     phase from the WAF ruleset, so the two never fight over a singleton)
# Writes brownfield/records.csv (name,id,type) — the import for_each source.
source "$(dirname "$0")/../scripts/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE

zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
[ "$zone_id" != "null" ] || { red "zone $LAB_ZONE not found"; exit 1; }

say "Seeding the legacy estate (dashboard-style raw API, Terraform knows NOTHING about these)"

csv="$REPO_ROOT/brownfield/records.csv"
echo "name,id,type" > "$csv"

i=0
for suffix in alpha bravo charlie delta echo; do
  i=$((i+1))
  name="lab-legacy-$suffix.lab.$LAB_ZONE"
  existing=$(cf_api GET "/zones/$zone_id/dns_records?name=$name" | jq -r '.result[0].id // empty')
  if [ -n "$existing" ]; then
    note "exists: $name ($existing)"
    echo "$name,$existing,TXT" >> "$csv"
    continue
  fi
  # deliberately messy: varying TTLs, no comments — classic hand-made estate
  ttl=$((i * 120))
  id=$(cf_api POST "/zones/$zone_id/dns_records" CLOUDFLARE_API_TOKEN \
    "{\"type\":\"TXT\",\"name\":\"$name\",\"content\":\"\\\"legacy record $suffix — made by hand\\\"\",\"ttl\":$ttl}" \
    | jq -r '.result.id')
  green "created: $name ($id, ttl=$ttl)"
  echo "$name,$id,TXT" >> "$csv"
done

note "creating the legacy ruleset (response-header transform phase)..."
existing_rs=$(cf_api GET "/zones/$zone_id/rulesets?per_page=50" | jq -r '.result[] | select(.name=="lab-legacy-headers") | .id')
if [ -n "$existing_rs" ]; then
  note "ruleset exists: $existing_rs"
else
  existing_rs=$(cf_api PUT "/zones/$zone_id/rulesets/phases/http_response_headers_transform/entrypoint" CLOUDFLARE_API_TOKEN '{
    "name": "lab-legacy-headers",
    "description": "made by hand in the dashboard, adopted in Topic 29",
    "rules": [{
      "ref": "lab_legacy_marker",
      "description": "stamp responses from the legacy era",
      "expression": "true",
      "action": "rewrite",
      "action_parameters": {"headers": {"x-lab-legacy": {"operation": "set", "value": "true"}}}
    }]
  }' | jq -r '.result.id')
  green "created ruleset: $existing_rs"
fi
echo "$existing_rs" > "$REPO_ROOT/brownfield/ruleset.id"

green "legacy estate ready. CSV: brownfield/records.csv — now run scripts/demo-29-adopt.sh"
