#!/usr/bin/env bash
# Topic 14 — ZERO-DOWNTIME tunnel credential rotation: the two-step
# parallel-tunnel + cutover pattern, measured by a curl loop the whole way.
#
#   step 1: terraform apply with rotation_generation bumped -> a SECOND tunnel
#           (lab-tunnel-g2) exists alongside the old one; start its connector
#   step 2: terraform moves the DNS record to the new tunnel -> traffic cuts
#           over atomically at the edge; old tunnel drains, then is removed
#
# The NAIVE alternative — taint/recreate the tunnel in place — destroys the
# tunnel the DNS record points at: hard downtime from apply start until the
# new connector comes up. Documented in the runbook; deliberately NOT run.
#
# This script drives the pattern via targeted applies against envs/lab and
# reports downtime measured at 1-second resolution. It is the Topic 14
# capstone; run demo-14-ha-kill.sh first for the simpler story.
source "$(dirname "$0")/lib/common.sh"
need_env CLOUDFLARE_API_TOKEN LAB_ZONE
compose_dir="$ENV_LAB/tunnel-compose"
url="https://lab-app.lab.$LAB_ZONE"

say "Topic 14: rotating a tunnel secret with zero downtime — parallel tunnel, then cutover"

note "starting the downtime meter (background curl loop, 1 probe/sec)..."
meter_log=$(mktemp)
( while true; do
    printf '%s %s\n' "$(date +%H:%M:%S)" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 "$url")"
    sleep 1
  done ) > "$meter_log" &
meter_pid=$!
trap 'kill $meter_pid 2>/dev/null || true' EXIT

note "STEP 1/2 — creating the parallel tunnel (rotation_generation = 2)..."
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false -var rotation_generation=2 -target='module.tunnel_next' >/dev/null
new_token=$(terraform -chdir="$ENV_LAB" output -raw tunnel_next_token)
note "starting a connector for the NEW tunnel..."
TUNNEL_TOKEN="$new_token" docker compose -f "$compose_dir/docker-compose.yml" -p tunnel-g2 up -d cloudflared-1 >/dev/null 2>&1
sleep 8   # let the connector register

note "STEP 2/2 — cutting DNS over to the new tunnel and retiring the old..."
terraform -chdir="$ENV_LAB" apply -auto-approve -input=false -var rotation_generation=2 -var rotation_cutover=true >/dev/null

sleep 5
kill $meter_pid 2>/dev/null || true

say "Downtime report"
total=$(wc -l < "$meter_log")
bad=$(grep -cv " 200$" "$meter_log" || true)
cat "$meter_log" | tail -20
if [ "$bad" -eq 0 ]; then
  green "$total probes, 0 non-200 — the rotation was invisible to clients."
else
  red "$total probes, $bad non-200 — inspect $meter_log"
fi
note "old connectors can now be stopped: docker compose -p tunnel-g2 down / original compose project"
