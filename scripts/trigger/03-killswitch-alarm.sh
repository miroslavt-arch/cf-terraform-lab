#!/usr/bin/env bash
# TRIGGER 3 — make the hourly kill-switch alarm fire. Topic 11.
#
# killswitch-reminder.yml runs every hour and succeeds silently. It only speaks
# up when an incident rule is STILL ARMED — the thing everyone forgets to undo
# once the incident is over. This arms one, runs the alarm, and disarms.
#
#   usage: bash scripts/trigger/03-killswitch-alarm.sh
source "$(dirname "$0")/lib.sh"
need_gh; need_env CLOUDFLARE_API_TOKEN LAB_ZONE

say "TRIGGER 3 — arm the kill-switch, then let the alarm find it"

RS=$(composed_ruleset_id)
[ -n "$RS" ] || { red "lab-waf-composed not found"; exit 1; }
ZID=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
RULE_ID=$(cf_api GET "/zones/$ZID/rulesets/$RS" \
  | jq -r '.result.rules[]|select(.ref=="lab_ir_elevated_challenge")|.id')

note "1/4 — peacetime: the alarm is green and says nothing."
before=$(latest_run killswitch-reminder.yml)
gh workflow run killswitch-reminder.yml --repo "$GH_REPO" >/dev/null
ID=$(wait_new_run killswitch-reminder.yml "$before") || { red "did not start"; exit 1; }
CC=$(wait_run "$ID")
echo "    hourly check with nothing armed: $CC   ($ACTIONS_URL/runs/$ID)"

note "2/4 — incident! arming lab_ir_elevated_challenge..."
if set_rule_enabled "$ZID" "$RS" lab_ir_elevated_challenge true; then
  echo "    armed — managed-challenge is now live on the zone"
else
  red "    could not arm the rule"; exit 1
fi

say "This is the easy part. Every team is good at arming. Nobody is good at disarming."

before=$(latest_run killswitch-reminder.yml)
note "3/4 — the next hourly check (running it now rather than waiting)..."
gh workflow run killswitch-reminder.yml --repo "$GH_REPO" >/dev/null
ID=$(wait_new_run killswitch-reminder.yml "$before") || { red "did not start"; exit 1; }
CC=$(wait_run "$ID")
if [ "$CC" = "failure" ]; then
  green "alarm FAILED the run — correct. A failing scheduled job emails the repo owner,"
  green "and it will keep failing every hour until somebody disarms."
  echo "    $ACTIONS_URL/runs/$ID"
else
  red "expected 'failure', got '$CC' — read the run."
fi

say "It checks REALITY, not intent. It asks the API what is enabled, not what the tfvars claim."

note "4/4 — disarming and confirming peacetime..."
set_rule_enabled "$ZID" "$RS" lab_ir_elevated_challenge false || true
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false >/dev/null 2>&1 || true
cf_api GET "/zones/$ZID/rulesets/$RS" \
  | jq -r '.result.rules[]|select(.ref|startswith("lab_ir_"))|"    \(.ref) enabled=\(.enabled)"'
green "kill-switch dark again."
