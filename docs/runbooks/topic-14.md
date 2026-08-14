# Topic 14 — Tunnel design: config source, ingress ordering, HA replicas, secret rotation

**Concept in three sentences.** `config_src = "cloudflare"` puts the tunnel's
ingress rules in Cloudflare under Terraform's control — connectors become
stateless commodity processes, which is what makes HA trivial: run the same
token twice, kill either replica, nothing happens. Ingress rules match top-
down and the catch-all **must** be last (cloudflared refuses otherwise) — the
module encodes that ordering structurally. Rotation is the grown-up pattern:
bring up a parallel tunnel, cut the DNS record over in place, drain the old —
zero downtime, measured, because the environment (not the module) owns the
public DNS record.

## Files
- `infra/modules/tunnel-site/` — tunnel, remote config (catch-all last),
  token data source, optional private route, `manage_dns` flag
- `infra/envs/lab/main.tf` — `enable_tunnel` gate, `tunnel`/`tunnel_next`
  pair, env-owned `cloudflare_dns_record.lab_app` (the rotation pivot)
- `infra/envs/lab/tunnel-compose/docker-compose.yml` — nginx + TWO
  cloudflared replicas on one token
- `scripts/demo-14-ha-kill.sh`, `scripts/demo-14-rotate-tunnel.sh`

## Steps

```bash
# 1. enable + apply (plan first; expect adds only)
sed -i 's/^# *enable_tunnel.*/enable_tunnel = true/' infra/envs/lab/lab.auto.tfvars \
  || echo 'enable_tunnel = true' >> infra/envs/lab/lab.auto.tfvars
terraform -chdir=infra/envs/lab plan && terraform -chdir=infra/envs/lab apply

# 2. run the replicas (Docker Desktop must be up)
cd infra/envs/lab
export TUNNEL_TOKEN=$(terraform output -raw tunnel_token)
docker compose -f tunnel-compose/docker-compose.yml up -d && cd ../../..

# 3. prove it serves
curl -s https://lab-app.lab.$LAB_ZONE | head -3

# 4. HA: kill a replica mid-curl-loop
bash scripts/demo-14-ha-kill.sh

# 5. rotation with a downtime meter
bash scripts/demo-14-rotate-tunnel.sh
```

## Expected output *(unverified until first live run; script contracts)*

```
curl: <h1>cf-terraform-lab: served through a Cloudflare Tunnel</h1>
ha-kill: 15/15 probes HTTP 200 with cloudflared-1 stopped
rotation: NNN probes, 0 non-200 — the rotation was invisible to clients.
```

## The naive rotation — documented, deliberately NOT performed
Changing `tunnel_secret` (or tainting the tunnel) in place **destroys and
recreates the tunnel the live DNS record points at**: the plan contains
`- destroy` on `cloudflare_zero_trust_tunnel_cloudflared.this`, its id
changes, and `lab-app` points at a corpse from apply-start until a new
connector registers — minutes of hard downtime, more if the token pipeline
to the connectors is slow. The two-step patterns exists precisely so no plan
ever destroys the tunnel that DNS currently targets.

## Failure mode prevented
Config drift between a laptop's `config.yml` and reality (remote-managed
config); "the tunnel box" as a pet server (stateless replicas); rotation as
an outage (parallel + cutover); a catch-all in the middle silently
swallowing later ingress rules (ordering by construction).

## Reset
`docker compose -f infra/envs/lab/tunnel-compose/docker-compose.yml down`;
rotation demo cleans its own `tunnel-g2` compose project. To fully remove:
`enable_tunnel = false` + apply (destroys only `lab-tunnel*` + the lab DNS
record — verify with the destroy guard as always).

## What to say
> "Watch the probe column while I kill this container — nothing happens.
> Two stateless replicas, one tunnel. And the rotation you're about to see
> has a curl loop running the whole time: the number to remember is zero."
