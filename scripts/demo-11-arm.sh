#!/usr/bin/env bash
# Topic 11 — the stopwatch demo: how long from "incident declared" to
# "kill-switch live at the edge"? Arms elevated, applies, verifies via API,
# then disarms and applies again. Prints the measured loop time.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
cd "$REPO_ROOT"

zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

armed_refs() {
  local rid
  rid=$(cf_api GET "/zones/$zone_id/rulesets?per_page=50" | jq -r '.result[] | select(.name=="lab-waf-composed") | .id')
  [ -n "$rid" ] && cf_api GET "/zones/$zone_id/rulesets/$rid" \
    | jq -r '[.result.rules[] | select((.ref // "" | startswith("lab_ir_")) and .enabled) | .ref] | join(",")'
}

say "Topic 11: kill-switches live in code all year, disabled. Incident declared — start the clock."
note "armed incident rules BEFORE: [$(armed_refs)]  (expected: empty)"

start=$(date +%s)

scripts/arm-killswitch.sh elevated >/dev/null
note "tfvars flipped to elevated; applying..."
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false >/dev/null

end=$(date +%s)
green "ARMED at the edge in $((end - start)) seconds. armed rules: [$(armed_refs)]"

say "Incident over — disarming (same loop, reverse direction)"
start=$(date +%s)
scripts/arm-killswitch.sh none >/dev/null
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false >/dev/null
end=$(date +%s)
green "DISARMED in $((end - start)) seconds. armed rules: [$(armed_refs)]  (expected: empty)"

note "record both numbers in docs/runbooks/topic-11.md"
