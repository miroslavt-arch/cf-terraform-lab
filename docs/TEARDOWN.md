# TEARDOWN — remove the lab, and only the lab

Two independent safety nets, both in `scripts/teardown.sh`:

1. `terraform destroy` only ever runs against the lab's own state files.
2. Every planned deletion is checked for a lab marker (`lab-` / `tftest-`
   prefix, a `.lab.` hostname, or a `lab:` comment). **One unmarked resource
   aborts the entire run** — nothing is destroyed.

## Dry run (the default — destroys nothing)

```bash
source ~/.cf-lab-env
cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
bash scripts/teardown.sh
```

Prints every resource that *would* be destroyed, per environment, with the
name it matched on. Read the list. If anything in it is unfamiliar, stop.

## Execute

```bash
bash scripts/teardown.sh --execute
```

You are asked to type the zone name (`gracious-binary.sxplab.com`) to confirm.
Anything else skips that environment.

## What gets removed

| Resource | Names |
|---|---|
| DNS records | `lab-hello`, `lab-app`, `lab-legacy-*`, demo records under `lab.<zone>` |
| WAF ruleset | `lab-waf-composed` |
| Legacy ruleset | `lab-legacy-ratelimit` (Topic 29 seed) |
| Tunnels | `lab-tunnel`, `lab-tunnel-g2` |
| Account lists | `lab_scale_per_item`, `lab_scale_bulk` |

## What is deliberately NOT removed

- **Zone settings.** They are singletons that always exist — there is no
  "delete", only "set to something else". Teardown leaves them at the
  baseline values. To revert them, set them by hand in the dashboard; the
  originals for this sandbox were `security_level=medium` and Cloudflare
  defaults elsewhere.
- **The zone itself**, the account, your API tokens, the R2 bucket, and the
  GitHub repo. All are yours to delete manually if you want them gone.
- **Anything without a lab marker.** By construction — that's the guard.

## Guarded resources (`prevent_destroy`)

`demos/sharp-edges/list-scale/bulk` carries `prevent_destroy = true` as the
lab's worked example of protecting an expensive-to-recreate object. A plain
`terraform destroy` on it fails by design. The documented path is:

```bash
terraform -chdir=demos/sharp-edges/list-scale/bulk state rm cloudflare_list.bulk
# then delete via API (the demo script does exactly this at its end)
```

That two-step is the point: removing a guarded resource should require an
explicit, deliberate act, not a flag.

## Verify afterwards

```bash
bash scripts/teardown-verify.sh
```

Read-only. Lists any `lab-*` DNS records, rulesets, tunnels, or `lab_*` lists
still visible via the API. Empty sections mean a clean teardown.

## Rebuilding from scratch

The sandbox zone may expire before the repo does. To rebuild against a fresh
zone: update `LAB_ZONE` in `~/.cf-lab-env` and `zone_name` in
`infra/envs/lab/lab.auto.tfvars`, create new zone-scoped tokens, then
`terraform -chdir=infra/envs/lab apply`. Roughly a 15-minute replay — the code
is not tied to this particular zone.
