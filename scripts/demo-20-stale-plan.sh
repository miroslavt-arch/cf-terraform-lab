#!/usr/bin/env bash
# Topic 20 — THE MONEY DEMO: a saved plan is a contract with the state it was
# computed from. Mutate state out of band and terraform REFUSES the stale plan.
#
# Local, deterministic reproduction of the same invariant the CI pipeline
# relies on (tf-pr saves plan artifact -> tf-apply replays it): we save a
# plan, change a harmless lab record's TTL out of band, then try to apply
# the saved plan. Works entirely on lab- resources.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
cd "$ENV_LAB"

say "Topic 20: an approved plan is pinned to the exact state it was computed from — drift in between voids it"

note "1/3 — saving a plan (this is what the PR pipeline stores as an artifact)..."
terraform plan -input=false -out=stale-demo.tfplan >/dev/null
green "plan saved: stale-demo.tfplan"

note "2/3 — meanwhile, 'someone' edits a lab record out of band (TTL 300 -> 600 via raw API)..."
zone_id=$(terraform output -raw zone_id)
rec=$(cf_api GET "/zones/$zone_id/dns_records?type=TXT&name=lab-hello.lab.$LAB_ZONE")
rec_id=$(echo "$rec" | jq -r '.result[0].id')
content=$(echo "$rec" | jq -r '.result[0].content')
cf_api PATCH "/zones/$zone_id/dns_records/$rec_id" CLOUDFLARE_API_TOKEN \
  "{\"ttl\": 600}" | jq -r '"  API says: ttl now " + (.result.ttl|tostring)'
# refresh state so terraform's snapshot moves past the plan's snapshot
terraform apply -refresh-only -auto-approve -input=false >/dev/null
green "state has moved on (refresh-only apply recorded the out-of-band TTL)"

note "3/3 — now applying the SAVED plan..."
if terraform apply -input=false stale-demo.tfplan 2>&1 | tee /tmp/stale-out.txt; then
  red "apply unexpectedly succeeded — invariant broken?!"
else
  echo
  green "^ Terraform REFUSED: 'saved plan is stale'. The artifact your reviewer approved is the ONLY thing that can be applied, and only against the world it was computed for."
fi

note "reset: re-plan + apply to restore TTL 300..."
terraform apply -auto-approve -input=false >/dev/null
rm -f stale-demo.tfplan
green "estate back to code truth. Demo is rerunnable."
