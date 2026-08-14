#!/usr/bin/env bash
# Sharp edge 2 — dual writers: two states, one record, permanent mutual drift.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
d="$REPO_ROOT/demos/sharp-edges/dual-writers"
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

live() { cf_api GET "/zones/$zone_id/dns_records?name=lab-dual.lab.$LAB_ZONE" | jq -r '.result[0].content // "<absent>"'; }

say "Sharp edge: two roots, one DNS record — nobody errors, everybody 'drifts'"

note "Root A creates lab-dual (content: owned-by-A)..."
terraform -chdir="$d/root-a" init -backend=false -input=false >/dev/null
terraform -chdir="$d/root-a" apply -auto-approve -input=false -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" >/dev/null
rec_id=$(cf_api GET "/zones/$zone_id/dns_records?name=lab-dual.lab.$LAB_ZONE" | jq -r '.result[0].id')
green "live content: $(live)"

note "Root B imports the same record and applies ITS truth (owned-by-B)..."
terraform -chdir="$d/root-b" init -backend=false -input=false >/dev/null
terraform -chdir="$d/root-b" apply -auto-approve -input=false -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" -var "record_id=$rec_id" >/dev/null
red "live content: $(live)   <- B's pipeline is green; A never consented"

note "Root A's nightly plan now sees 'drift' it can't explain..."
terraform -chdir="$d/root-a" plan -input=false -no-color -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" | grep -E "content|Plan:" | head -5

note "...and A's auto-apply 'heals' it:"
terraform -chdir="$d/root-a" apply -auto-approve -input=false -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" >/dev/null
green "live content: $(live)   <- flipped back. This repeats FOREVER, both pipelines green."

say "Fix: one record, one owner root. Detection: Topic 27 drift + audit log shows the other pipeline's token as the actor."
note "reset: destroying the demo record from A; discarding B's local state..."
terraform -chdir="$d/root-a" destroy -auto-approve -input=false -var "zone_id=$zone_id" -var "zone_name=$LAB_ZONE" >/dev/null
rm -rf "$d/root-b/.terraform" "$d/root-b"/terraform.tfstate*
green "reset done."
