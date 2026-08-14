#!/usr/bin/env bash
# Post-teardown audit: ask the API what lab-* things still exist. Read-only.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID LAB_ZONE
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

say "Teardown verification — anything lab-flavored left behind?"

note "DNS records under lab.$LAB_ZONE:"
cf_api GET "/zones/$zone_id/dns_records?per_page=100" \
  | jq -r '.result[] | select(.name | contains(".lab.")) | "  " + .type + "  " + .name' || true

note "rulesets named lab-*:"
cf_api GET "/zones/$zone_id/rulesets?per_page=50" \
  | jq -r '.result[] | select(.name | startswith("lab-")) | "  " + .name + " (" + .phase + ")"' || true

note "tunnels named lab-*:"
cf_api GET "/accounts/$CLOUDFLARE_ACCOUNT_ID/cfd_tunnel?is_deleted=false" \
  | jq -r '.result[] | select(.name | startswith("lab-")) | "  " + .name + "  " + .status' || true

note "account lists named lab_*:"
cf_api GET "/accounts/$CLOUDFLARE_ACCOUNT_ID/rules/lists" \
  | jq -r '.result[] | select(.name | startswith("lab_")) | "  " + .name' || true

green "empty sections above = clean teardown. Zone settings are never torn down (they are singletons owned by the baseline; reverting them is a deliberate manual choice)."
