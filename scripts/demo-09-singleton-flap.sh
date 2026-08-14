#!/usr/bin/env bash
# Topic 9 — two roots, one singleton: watch the value flap across applies.
# Requires: CLOUDFLARE_API_TOKEN (write), LAB_ZONE. Applies only touch the
# security_level setting on the lab zone; reset re-applies the real baseline.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
cd "$REPO_ROOT/demos/singleton-conflict"

zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')
[ "$zone_id" != "null" ] || { red "zone $LAB_ZONE not found"; exit 1; }

current() {
  cf_api GET "/zones/$zone_id/settings/security_level" | jq -r '.result.value'
}

say "Topic 9: zone settings are singletons — two roots that both 'own' one setting will flap it forever, with green pipelines all round"

note "current security_level: $(current)"

note "Root A applies (believes: high)..."
terraform -chdir=root-a init -backend=false -input=false >/dev/null
terraform -chdir=root-a apply -auto-approve -input=false -var "zone_id=$zone_id" >/dev/null
green "root A applied. dashboard value now: $(current)"

note "Root B applies (believes: essentially_off)..."
terraform -chdir=root-b init -backend=false -input=false >/dev/null
terraform -chdir=root-b apply -auto-approve -input=false -var "zone_id=$zone_id" >/dev/null
red  "root B applied. dashboard value now: $(current)   <- A's value silently overwritten"

note "Root A runs its nightly pipeline again..."
terraform -chdir=root-a apply -auto-approve -input=false -var "zone_id=$zone_id" >/dev/null
green "value now: $(current)   <- and back again. Forever."

say "The fix: ONE owner. envs/lab's zone-baseline owns settings; overrides go through its allow-list. Restoring the real baseline now..."
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false >/dev/null 2>&1 \
  && green "baseline restored: security_level = $(current)" \
  || note "envs/lab not initialized/applied yet — restore manually once Topic 9 baseline is live"
