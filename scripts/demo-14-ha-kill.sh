#!/usr/bin/env bash
# Topic 14 — HA: two cloudflared replicas on one tunnel. Kill one live, show
# the hostname keeps serving. Requires the tunnel applied (enable_tunnel=true)
# and `docker compose up -d` already running in tunnel-compose/.
source "$(dirname "$0")/lib/common.sh"
need_env LAB_ZONE
compose_dir="$ENV_LAB/tunnel-compose"
url="https://lab-app.lab.$LAB_ZONE"

probe() { curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url"; }

say "Topic 14: HA is two replicas and zero ceremony — kill a connector, nothing happens"

note "replicas running:"
docker compose -f "$compose_dir/docker-compose.yml" ps --format 'table {{.Name}}\t{{.Status}}' | grep -E "cloudflared|NAME"

note "baseline: $url -> HTTP $(probe)"

note "killing replica 1..."
docker compose -f "$compose_dir/docker-compose.yml" stop cloudflared-1 >/dev/null

note "probing for 15s through the surviving replica..."
fails=0
for i in $(seq 1 15); do
  code=$(probe)
  printf "  t+%02ds  HTTP %s\n" "$i" "$code"
  [ "$code" = "200" ] || fails=$((fails+1))
  sleep 1
done

if [ "$fails" -eq 0 ]; then
  green "zero failed probes with one replica dead. That's the whole HA story."
else
  red "$fails/15 probes failed — check replica 2 logs: docker compose logs cloudflared-2"
fi

note "restoring replica 1..."
docker compose -f "$compose_dir/docker-compose.yml" start cloudflared-1 >/dev/null
green "both replicas back. Demo reset."
