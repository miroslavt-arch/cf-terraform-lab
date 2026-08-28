# Topic 29 — Brownfield adoption: cf-terraforming, for_each imports, generation, normalization

**Concept in three sentences.** Brownfield adoption means taking resources
Terraform has never seen and reaching a **"No changes" plan without touching
them** — state-only operations, live estate untouched. Three tools cover the
spectrum: `cf-terraforming` to *discover* what exists, one `import` block
with `for_each` over a CSV to adopt *in bulk*, and
`plan -generate-config-out` to make Terraform *write the config itself* for
gnarly resources (then `normalize.py` strips the generated noise). The
iron gate: **nobody refactors until the plan is quiet** — a noisy plan means
your config and reality disagree, and refactoring on top of a lie compounds it.

## Files
- `brownfield/seed-legacy.sh` — builds the "legacy estate" via raw API
  (5 messy `lab-legacy-*` TXT records + `lab-legacy-headers` ruleset in the
  response-headers phase — a different phase from the WAF, no singleton fight)
- `brownfield/adopt/main.tf` — CSV-driven `import` block + hand-written
  canonical record config; local state (quarantined from envs/lab)
- `scripts/normalize.py` — strips nulls/computed echo from generated config
- `scripts/demo-29-adopt.sh` — the full pipeline with the gate at the end

## Steps

```bash
bash brownfield/seed-legacy.sh     # once: create the mess (raw API, no TF)
bash scripts/demo-29-adopt.sh      # discover -> import -> generate -> normalize -> GATE
```

## Expected output (REAL, captured 2026-08-14)

```
1/4 — planning the CSV-driven import blocks (5 records, ONE import block)...
  # cloudflare_dns_record.legacy["lab-legacy-alpha.lab.zesty-beta.sxplab.com"] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-bravo...."] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-charlie...."] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-delta...."] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-echo...."] will be imported
Plan: 5 to import, 0 to add, 0 to change, 0 to destroy.

2/4 — Terraform wrote the ruleset config itself: generated_ruleset.tf
3/4 — normalized generated_ruleset.tf: removed 84 noise lines
4/4 — Apply complete! Resources: 6 imported, 0 added, 0 changed, 0 destroyed.

THE GATE:
No changes. Your infrastructure matches the configuration.
```

**Read the counters aloud: `0 changed, 0 destroyed`.** That is the proof that
adoption touched nothing — Terraform took ownership of six live objects and
altered none of them.

### The failure this demo hit while being built (worth telling)
The first run reported **`5 changed`** — adoption was silently rewriting the
records. Cause: the seeded TXT content contained an em-dash, and Cloudflare
stores non-ASCII in TXT as octal escapes (three backslash-escaped
bytes instead of the character), so the config
never matched what the API held. The gate caught it. That is exactly what the
gate is *for*: without it, "adoption" would have quietly edited five live
records and nobody would have known.

## Failure mode prevented
The classic adoption disaster: import, see a noisy plan, apply it anyway,
and "adopt" turns into "rewrite live resources" (TTLs reset, comments wiped,
rules reordered). The quiet-plan gate makes non-destructiveness *provable*
before any refactor is allowed.

## Reset
Re-runnable as-is (seed is idempotent, imports are state-only). Full reset:
`terraform -chdir=brownfield/adopt destroy` (destroys only `lab-legacy-*`,
the destroy-guard checks it) + `rm -rf brownfield/adopt/.terraform*
brownfield/adopt/terraform.tfstate* brownfield/records.csv brownfield/ruleset.id`.

## What to say
> "These six resources were made by dashboard clicks — Terraform has never
> heard of them. Watch the plan counters: 5 to import, 0 to change, 0 to
> destroy. And the final plan says 'No changes' — that sentence is the
> certificate that adoption touched nothing."
