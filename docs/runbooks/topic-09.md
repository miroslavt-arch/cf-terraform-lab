# Topic 9 — Settings baseline: singleton ownership and the allow-listed override door

**Concept in three sentences.** Zone settings are singletons: Cloudflare holds
exactly one value per setting, so exactly one Terraform root must own them —
two owners means the value flaps forever with green pipelines on both sides.
The baseline is a `locals` map in `zone-baseline` (the single reviewed source
of truth), applied via `for_each = merge(local.baseline, var.overrides)`.
Overrides exist, but only through a `validation`-enforced allow-list — an
override door, not an override wall.

## Files
- `infra/modules/zone-baseline/main.tf` — `settings_baseline` locals map +
  the merge + `cloudflare_zone_setting.this` for_each
- `infra/modules/zone-baseline/variables.tf` — validation 4: the allow-list
  (`security_level`, `browser_check`, `challenge_ttl`)
- `demos/singleton-conflict/root-a`, `root-b` — the counter-example
- `scripts/demo-09-singleton-flap.sh`

## Steps

1. Show the baseline is live (after first apply):
   ```bash
   terraform -chdir=infra/envs/lab output settings_applied
   ```
2. Try a NON-allow-listed override — edit `envs/lab/main.tf`
   `settings_overrides` to add `always_use_https = "off"`, then:
   ```bash
   terraform -chdir=infra/envs/lab plan
   ```
3. Run the flap:
   ```bash
   bash scripts/demo-09-singleton-flap.sh
   ```

## Expected output

Step 2 (plan-time rejection — REAL message text from the module):

```
Error: Invalid value for variable
settings_overrides only accepts: security_level, browser_check, challenge_ttl.
All other zone settings are owned by the baseline in this module — override
requests for them belong in a PR against the baseline, not in a call-site
override.
```

Step 3 *(unverified until first live run — shape below is the script's
output contract)*:

```
current security_level: high
root A applied. dashboard value now: high
root B applied. dashboard value now: essentially_off   <- A's value silently overwritten
value now: high   <- and back again. Forever.
baseline restored: security_level = high
```

## Failure mode prevented
The two-owner flap: team A's nightly apply and team B's nightly apply
overwrite each other forever, no errors anywhere, dashboard value depends on
who ran last. And its cousin: ad-hoc overrides quietly disabling a security
baseline.

## Reset
`scripts/demo-09-singleton-flap.sh` restores the baseline itself (final
step). Manual: `terraform -chdir=infra/envs/lab apply`. Revert any
`main.tf` edit from step 2 (`git checkout -- infra/envs/lab/main.tf`).

## What to say
> "Both pipelines are green. Both teams pass review. The value still flaps
> daily. Singletons need exactly one owner — and the owner publishes an
> allow-listed door so it doesn't become a bottleneck."
