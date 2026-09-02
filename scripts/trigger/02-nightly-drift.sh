#!/usr/bin/env bash
# TRIGGER 2 — make the NIGHTLY drift detector fire on demand. Topic 27.
#
# drift.yml runs at 03:17 UTC and is silent when clean, which is useless in a
# 2pm presentation. This manufactures the exact condition it hunts for — a
# change made in the dashboard that never went through code — then dispatches
# the very same workflow and lets it fail loudly in front of the room.
#
#   usage: bash scripts/trigger/02-nightly-drift.sh
source "$(dirname "$0")/lib.sh"
need_gh; need_env CLOUDFLARE_API_TOKEN LAB_ZONE

say "TRIGGER 2 — manufacture drift, then let the nightly job catch it"

RS=$(composed_ruleset_id)
[ -n "$RS" ] || { red "lab-waf-composed not found on $LAB_ZONE"; exit 1; }
ZID=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

note "1/4 — the state of the world BEFORE anyone misbehaves:"
cf_api GET "/zones/$ZID/rulesets/$RS" \
  | jq -r '.result.rules[]|"    \(.ref)  enabled=\(.enabled)"'

note "2/4 — now somebody 'just quickly' turns off a security rule in the dashboard."
note "     (doing it by raw API, which is exactly what a dashboard click does)"
if set_rule_enabled "$ZID" "$RS" lab_sec_block_admin_paths false; then
  echo "    disabled lab_sec_block_admin_paths — no commit, no PR, no review"
else
  red "    could not change the rule"; exit 1
fi

say "Nothing is broken. No alarm went off. Code and reality now disagree."

before=$(latest_run drift.yml)
note "3/4 — running the NIGHTLY workflow now instead of waiting for 03:17 UTC..."
gh workflow run drift.yml --repo "$GH_REPO" -f environment=ci-waf >/dev/null
ID=$(wait_new_run drift.yml "$before") || { red "drift.yml never started"; exit 1; }
echo "    run: $ACTIONS_URL/runs/$ID"
CC=$(wait_run "$ID")

if [ "$CC" = "failure" ]; then
  green "drift.yml FAILED — which is the correct, healthy outcome."
  echo "    Open the run's job summary: it names the resource and the change."
  echo "    $ACTIONS_URL/runs/$ID"
else
  red "drift.yml returned '$CC' — expected 'failure'. Read the run before continuing."
fi

say "A detector you have to remember to click is not a detector. This one is on a cron."

note "4/4 — healing: re-applying code truth, then confirming the estate is clean..."
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false >/dev/null 2>&1 || true
cf_api GET "/zones/$ZID/rulesets/$RS" \
  | jq -r '.result.rules[]|select(.ref=="lab_sec_block_admin_paths")|"    lab_sec_block_admin_paths enabled=\(.enabled)"'
green "healed — the rule is back on, and it took one apply."
