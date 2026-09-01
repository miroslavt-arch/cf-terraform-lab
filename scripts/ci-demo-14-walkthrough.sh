#!/usr/bin/env bash
# Topic 14 - tunnel design. WALKTHROUGH, not a live run.
#
# Honest reason it does not apply: the lab's API token can READ tunnels but
# not create them (POST /cfd_tunnel returns "Authentication error"), and the
# HA demo needs two cloudflared containers on a machine you control, which a
# throwaway GitHub runner is not.
#
# So this prints the design decisions and the exact code that implements them,
# and verifies the claims it makes against the module source rather than
# asserting them.
source "$(dirname "$0")/lib/common.sh"
mod="$REPO_ROOT/infra/modules/tunnel-site/main.tf"

say "Topic 14: tunnel design - config source, ingress ordering, HA, secret rotation"

red "NOT RUN LIVE. The lab token can read tunnels but not create them, and the"
red "HA demo needs two local containers. Everything below is the real module."
echo

note "1/4 - CONFIG SOURCE: where do the routing rules live?"
grep -n 'config_src' "$mod" | sed 's/^/    /'
echo "    A local config.yml means routing lives on a box, edited by whoever has SSH."
echo "    config_src = cloudflare makes the ingress rules Terraform-managed API"
echo "    objects, which makes the connector STATELESS."

note "2/4 - HIGH AVAILABILITY falls out of that statelessness."
echo "    A stateless connector holds no config - it dials out and asks what to do."
echo "    So HA is: run the same token twice. Kill either one, nothing happens."
echo "    No leader election, no shared storage, no pets."
grep -n 'cloudflared-1\|cloudflared-2\|TUNNEL_TOKEN' "$REPO_ROOT/infra/envs/lab/tunnel-compose/docker-compose.yml" | sed 's/^/    /'

note "3/4 - INGRESS ORDERING: first match wins, catch-all MUST be last."
awk '/ingress = \[/,/\]/' "$mod" | sed 's/^/    /'
echo "    cloudflared refuses a config whose final rule has a hostname, so the"
echo "    module encodes the ordering structurally - nobody can append a rule"
echo "    after the catch-all and silently make it unreachable."

note "4/4 - SECRET ROTATION: the naive way causes an outage."
echo "    Changing the tunnel secret in place makes Terraform destroy and"
echo "    recreate the tunnel. But the tunnel's ID is what your DNS record"
echo "    points at - so you have destroyed the thing your hostname resolves"
echo "    to, and you are down from apply-start until a new connector registers."
echo
echo "    The two-step version: stand up a SECOND tunnel alongside the first,"
echo "    start connectors for it, then repoint the DNS record - an in-place"
echo "    content update, atomic at the edge. Then drain and remove the old one."
echo
echo "    For that to work the DNS record must be owned by the ENVIRONMENT, not"
echo "    the module, or destroying the module destroys the record:"
grep -n 'manage_dns' "$mod" | sed 's/^/    /'
grep -n 'rotation_generation\|rotation_cutover' "$REPO_ROOT/infra/envs/lab/main.tf" | head -6 | sed 's/^/    /'

say "That is Topic 9's ownership question showing up inside an operational runbook - which is why these topics are taught in this order."
green "Full runbook: docs/runbooks/topic-14.md"
