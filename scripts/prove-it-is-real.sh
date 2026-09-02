#!/usr/bin/env bash
# PROOF — for when someone thinks this is a mock.
#
# Everything here is verified by a THIRD PARTY: Cloudflare's public 1.1.1.1
# resolver, which has no idea this lab exists. We change a record with
# Terraform, then ask a public resolver what the internet now sees.
#
#   usage: bash scripts/prove-it-is-real.sh
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE

REC="lab-hello.lab.$LAB_ZONE"

resolve() { # ask the public internet, not our own tooling
  curl -s -H "accept: application/dns-json" \
    "https://1.1.1.1/dns-query?name=$1&type=TXT" \
    | jq -r '.Answer[]?|"      TTL=\(.TTL)  \(.data)"'
}

say "PROOF 1 — this record exists on the public internet"

note "asking 1.1.1.1 (Cloudflare's public resolver) what $REC is:"
resolve "$REC"
echo
note "that is not my terminal talking to itself. Anyone in this room can run:"
echo "      nslookup -type=TXT $REC 1.1.1.1"

say "PROOF 2 — change it with Terraform, watch the internet change"

ZID=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

live_ttl() { # the API is the authoritative source, with no DNS cache in the way
  cf_api GET "/zones/$ZID/dns_records?name=$REC" | jq -r '.result[0].ttl'
}

note "TTL on the live record right now, straight from the Cloudflare API:"
echo "      ttl = $(live_ttl)"

note "changing it in CODE (300 -> 120) and applying..."
sed -i -E 's/ttl     = 300/ttl     = 120/' "$ENV_LAB/main.tf"
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false 2>&1   | grep -E "will be updated|Apply complete" | sed 's/^/      /'

note "the same API call again - nothing cached, nothing mocked:"
echo "      ttl = $(live_ttl)"
note "and refresh the dashboard in Tab 3: the record shows 2 min instead of 5."
green "a line of code changed an object on Cloudflare's edge. That is the whole job."

say "PROOF 3 — the WAF rules are live objects, not a YAML file"

ZID=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
RS=$(cf_api GET "/zones/$ZID/rulesets?per_page=50" \
  | jq -r '.result[]|select(.name=="lab-waf-composed")|.id')

note "the live ruleset on the zone right now:"
cf_api GET "/zones/$ZID/rulesets/$RS" \
  | jq -r '.result.rules[]|"      \(.ref)  enabled=\(.enabled)  action=\(.action)"'

echo
note "open this in the dashboard and you are looking at the same object:"
echo "      https://dash.cloudflare.com/$CLOUDFLARE_ACCOUNT_ID/$LAB_ZONE/security/security-rules"

say "RESTORING"

note "putting the TTL back to 300..."
sed -i -E 's/ttl     = 120/ttl     = 300/' "$ENV_LAB/main.tf"
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false >/dev/null 2>&1
echo "      envs/lab plan: $(terraform -chdir="$ENV_LAB" plan -input=false 2>&1 | grep -oE 'No changes|Plan: .*' | head -1)"
green "restored."
