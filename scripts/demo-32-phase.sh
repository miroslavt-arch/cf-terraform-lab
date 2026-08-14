#!/usr/bin/env bash
# Sharp edge 1 — phase ownership ping-pong. See demos/sharp-edges/phase-ownership/README.md
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
d="$REPO_ROOT/demos/sharp-edges/phase-ownership"
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

say "Sharp edge: ONE entrypoint ruleset per phase — two roots claiming it is a fight, and the API referees"

note "Root A claims phase http_request_late_transform..."
terraform -chdir="$d/root-a" init -backend=false -input=false >/dev/null
terraform -chdir="$d/root-a" apply -auto-approve -input=false -var "zone_id=$zone_id" >/dev/null
green "A owns the phase. A's pipeline is green."

note "Root B claims the SAME phase..."
terraform -chdir="$d/root-b" init -backend=false -input=false >/dev/null
if terraform -chdir="$d/root-b" apply -auto-approve -input=false -var "zone_id=$zone_id" 2>&1 | grep -iE "already exists|duplicate|error" | head -3; then
  green "^ B FAILS: the phase slot is taken. This error is the healthy outcome —"
  note  "  the pathological one is B's team deleting A's ruleset by hand, which A's next plan recreates: ping-pong."
else
  red "B unexpectedly succeeded — API behavior changed; investigate before teaching this"
fi

note "reset: destroying A's demo ruleset (lab- prefixed, created by this demo)..."
terraform -chdir="$d/root-a" destroy -auto-approve -input=false -var "zone_id=$zone_id" >/dev/null
green "phase slot free again. Fix taught: one root owns a phase; teams contribute fragments (Topic 10)."
