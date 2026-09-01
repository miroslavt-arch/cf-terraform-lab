#!/usr/bin/env bash
# Topic 11 - kill-switch, CI-native version.
#
# The laptop demo edits envs/lab tfvars and applies. A runner has no state for
# that root, so this one IMPORTS the same live ruleset into an ephemeral
# state, flips incident_mode against it, times the loop, flips it back, and
# then drops it from state with `state rm`.
#
# It never destroys the ruleset: that object belongs to infra/envs/lab.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
env_dir="$REPO_ROOT/infra/envs/ci-waf"
cd "$env_dir"

zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
rs_id=$(cf_api GET "/zones/$zone_id/rulesets?per_page=50" | jq -r '.result[]|select(.name=="lab-waf-composed")|.id')
[ -n "$rs_id" ] || { red "lab-waf-composed not found on $LAB_ZONE - apply infra/envs/lab first"; exit 1; }

armed() {
  cf_api GET "/zones/$zone_id/rulesets/$rs_id" \
    | jq -r '[.result.rules[]|select((.ref // ""|startswith("lab_ir_")) and .enabled)|.ref]|join(",")'
}

tf() { terraform "$@" -var "zone_name=$LAB_ZONE" -var "ruleset_id=$rs_id"; }

say "Topic 11: kill-switches live in the ruleset all year, disabled. Arming is a DATA change, not a code change."

note "0/4 - importing the live ruleset into an ephemeral state (no resources created)..."
terraform init -input=false >/dev/null
tf apply -auto-approve -input=false -var "incident_mode=none" >/dev/null
green "imported lab-waf-composed ($rs_id)"
note "armed incident rules BEFORE: [$(armed)]   (expected: empty - peacetime)"

note "1/4 - INCIDENT DECLARED. Flipping incident_mode to elevated and applying..."
start=$(date +%s)
tf apply -auto-approve -input=false -var "incident_mode=elevated" >/dev/null
end=$(date +%s)
green "ARMED at the edge in $((end - start)) seconds. armed rules: [$(armed)]"

note "2/4 - the plan for that change touches nothing but 'enabled' flags."
note "      The rule logic itself was written and reviewed months ago."

note "3/4 - incident over. Flipping back to none..."
start=$(date +%s)
tf apply -auto-approve -input=false -var "incident_mode=none" >/dev/null
end=$(date +%s)
green "DISARMED in $((end - start)) seconds. armed rules: [$(armed)]   (expected: empty)"

note "4/4 - releasing the ruleset from this ephemeral state (state rm, NOT destroy -"
note "      the object belongs to infra/envs/lab)..."
terraform state rm module.waf.cloudflare_ruleset.composed >/dev/null 2>&1 || true
rm -f terraform.tfstate*
green "done. The killswitch-reminder workflow checks the live API hourly and fails loudly while anything stays armed."
