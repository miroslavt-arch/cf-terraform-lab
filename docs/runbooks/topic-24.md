# Topic 24 — terraform test tier one: provider mocking, sub-second logic tests

**Concept in three sentences.** `mock_provider "cloudflare" {}` swaps the real
provider for a stub that fabricates computed values — so every piece of
*logic* (merges, orderings, defaults, validations) is testable with zero
credentials, zero network, and sub-second latency. That speed is what makes
the tests run on every PR without anyone arguing about it. Tier two (real
provider, real zone, `lab-tftest-*` names, auto-destroyed) exists too — but
nightly and on demand, never in the PR hot path.

## Files
- `tests/unit.tftest.hcl` — 5 run blocks: settings composition, default
  propagation, `expect_failures` on bad input, fragment ordering,
  kill-switch arming
- `tests/contract/contract.tftest.hcl` — tier two (separate
  `-test-directory`, so plain `terraform test` stays offline)
- `versions.tf` + `variables.tf` at repo root — the no-resource test harness
- `.github/workflows/tf-pr.yml` (tier one on PRs) ·
  `.github/workflows/contract-nightly.yml` (tier two nightly)

## Steps

```bash
bash scripts/demo-24-unit-tests.sh     # runs `time terraform test` + proves no creds
# tier two, on demand only (needs write token + TF_VAR_contract_zone_id/_name):
terraform test -test-directory=tests/contract
```

## Expected output (REAL, captured 2026-08-14)

```
tests\unit.tftest.hcl... in progress
  run "settings_composition"... pass
  run "default_propagation"... pass
  run "invalid_record_type_rejected"... pass
  run "fragment_ordering"... pass
  run "killswitch_arming"... pass
Success! 5 passed, 0 failed.

real    0m0.358s
```

**Measured: 0.358 s for the whole suite, offline.** (Acceptance bar was
"under ~5 s" — beaten by an order of magnitude.)

Windows note: `-filter=tests/unit.tftest.hcl` matches nothing in Git Bash
(Terraform discovers `tests\unit...` with a backslash). Run bare
`terraform test` — the contract tier lives in its own directory precisely so
the default run is safe.

## Failure mode prevented
Logic regressions discovered at apply time against production; test suites
so slow or credential-hungry that they decay into "run before release,
maybe"; PR bots needing write tokens (tier one needs nothing at all).

## Reset
None — tier one leaves no trace. Tier two auto-destroys its `lab-tftest-*`
records at run end (that's `terraform test`'s contract).

## What to say
> "No token, no network — watch: the whole suite in a third of a second.
> There is no meeting where anyone argues about whether we can afford to run
> these on every PR."
