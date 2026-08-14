# Topic 11 — Kill-switch patterns: disabled in code, armed during incidents

**Concept in three sentences.** Incident controls you write *during* the
incident are untested, unreviewed, and slow — so the kill-switches live in
`incident.yaml` all year, deployed but `enabled = false`, reviewed like any
other code. Arming is a one-line data change (`incident_mode = "elevated"`),
not a code change: plan shows only `enabled` flips, the break-glass PR
template makes review a checkbox exercise, and the whole loop is measured in
seconds. A scheduled workflow checks **reality** (the API, not the repo) and
fails loudly for as long as any kill-switch stays armed.

## Files
- `infra/modules/waf-composed/rules/incident.yaml` — rules with `min_mode`
- `infra/modules/waf-composed/main.tf` — `mode_rank` locals binding
  `enabled` to the mode
- `infra/modules/waf-composed/variables.tf` — `incident_mode` validation
- `scripts/arm-killswitch.sh` (plan-only flip), `scripts/demo-11-arm.sh`
  (timed arm→verify→disarm loop)
- `.github/PULL_REQUEST_TEMPLATE/break-glass.md`
- `.github/workflows/killswitch-reminder.yml`

## Steps

```bash
# peacetime proof: rules exist, disabled (dashboard or API)
bash scripts/demo-11-arm.sh          # run WITH A STOPWATCH — it times itself
cat .github/PULL_REQUEST_TEMPLATE/break-glass.md   # the paved road for prod
```

## Expected output (REAL, captured 2026-08-14)

```
armed incident rules BEFORE: []  (expected: empty)
tfvars flipped to elevated; applying...
ARMED at the edge in 6 seconds. armed rules: [lab_ir_elevated_challenge]

Incident over — disarming (same loop, reverse direction)
DISARMED in 6 seconds. armed rules: []  (expected: empty)
```

**⏱ MEASURED: ARM = 6 s, DISARM = 6 s** — declaration to live-at-the-edge, end
to end, including the Terraform round trip. That number is the punchline: say
it out loud before you run the demo, then let the stopwatch confirm it.

Reminder workflow while armed:
```
Error: KILL-SWITCH ARMED: [lab_ir_elevated_challenge] — if the incident is
over, disarm with scripts/arm-killswitch.sh none
```

## Failure mode prevented
Writing firewall rules at 03:00 with shaking hands; a "temporary" lockdown
rule still challenging all traffic three weeks after the incident (the
reminder makes armed state expensive to forget); incident changes that
bypass review entirely (break-glass PRs are pre-approved in *shape*).

## Reset
`demo-11-arm.sh` disarms as its second act. If interrupted:
`bash scripts/arm-killswitch.sh none && terraform -chdir=infra/envs/lab apply`.

## What to say
> "We didn't write a firewall rule during this incident — we changed one word
> in a tfvars file and applied a plan that could only flip enabled-bits.
> The rule itself was reviewed months ago, in daylight, by calm people."
