#!/usr/bin/env bash
# Sharp edge 1 — phase ownership ping-pong. See demos/sharp-edges/phase-ownership/README.md
# Phase used: http_request_firewall_managed (deliberately NOT the custom-rules
# phase that the real lab WAF owns, so this demo can never fight with it).
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
d="$REPO_ROOT/demos/sharp-edges/phase-ownership"
zone_id=$(cf_api GET "/zones?name=$LAB_ZONE" | jq -r '.result[0].id')

say "Sharp edge: a zone has ONE entrypoint ruleset per phase. Two roots claiming it is a fight — and the API referees."

note "Root A claims phase http_request_firewall_managed..."
terraform -chdir="$d/root-a" init -backend=false -input=false >/dev/null
terraform -chdir="$d/root-a" apply -auto-approve -input=false -var "zone_id=$zone_id" >/dev/null
green "A owns the phase. A's pipeline is green."

note "Root B claims the SAME phase..."
terraform -chdir="$d/root-b" init -backend=false -input=false >/dev/null
if terraform -chdir="$d/root-b" apply -auto-approve -input=false -var "zone_id=$zone_id" >/tmp/phase-b.log 2>&1; then
  red "B unexpectedly SUCCEEDED — API behaviour changed; re-verify before teaching this"
else
  grep -iE "error|exists|conflict" /tmp/phase-b.log | head -4 | sed 's/^/    /'
  green "^ B FAILS. The phase slot is taken, and this loud error is the HEALTHY outcome."
  note  "  The pathological path is what B's team does next: delete A's ruleset in the dashboard"
  note  "  so their pipeline goes green — and A's next apply recreates it. That is the ping-pong."
fi

note "reset: destroying A's demo ruleset (lab- prefixed, created by this demo)..."
terraform -chdir="$d/root-a" destroy -auto-approve -input=false -var "zone_id=$zone_id" >/dev/null
rm -f "$d/root-a"/terraform.tfstate* "$d/root-b"/terraform.tfstate*
green "phase slot free again."
say "Fix: one root owns a phase. Other teams contribute FRAGMENTS to it (Topic 10), never their own ruleset resource."
