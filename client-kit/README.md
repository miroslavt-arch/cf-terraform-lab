# Terraform & AI delivery patterns

Working code for fifteen patterns, ready to run in a **test account**. Clone it,
point it at a sandbox zone, and a single command proves every pattern works
before you adopt any of it.

This is not a slide deck with snippets. `terraform test` passes, the policies
fire in both directions, and the sandbox root applies and destroys cleanly.

---

## Ten minutes to a green run

```bash
# 1. Tools
terraform -v            # need >= 1.9
conftest --version      # https://github.com/open-policy-agent/conftest/releases

# 2. Point at a TEST zone. Never production.
export CLOUDFLARE_API_TOKEN="..."          # edit rights on the sandbox zone only
export TF_VAR_zone_id="..."
export TF_VAR_zone_name="sandbox.example.com"

# 3. Check before touching anything
bash scripts/preflight.sh

# 4. Prove it works — offline first, free
bash scripts/verify.sh

# 5. Then against the real account (creates and destroys ~2 records)
bash scripts/verify.sh --live
```

`verify.sh --live` cleans up after itself, including on failure. Full detail in
[SETUP.md](SETUP.md).

**[ARCHITECTURE.md](ARCHITECTURE.md) is the reference** — twenty diagrams, one
per pattern, with the mechanism and the failure each one prevents.

---

## What's here

```
.
├─ ARCHITECTURE.md           twenty diagrams; how and why each pattern works
├─ SETUP.md                  test-account setup, step by step
│
├─ infra/
│  ├─ modules/zone-baseline/ the module contract: typed, validated, testable
│  └─ envs/sandbox/          a root you can actually apply
│
├─ tests/
│  ├─ unit.tftest.hcl        tier one: mocked, no credentials, ~1s, 8 tests
│  └─ contract/              tier two: real API, tftest- prefix, auto-destroyed
│
├─ policy/                   conftest / OPA, with fixtures for BOTH directions
│  ├─ destroy_guard.rego     refuse plans that destroy the wrong thing
│  ├─ fragment_policy.rego   what each team may add to a shared object
│  └─ eval_release_guard.rego  AI release thresholds as code
│
├─ .github/workflows/        drop-in, paths already match this tree
│  ├─ terraform-pr.yml       plan with a READ-ONLY credential, guard, artifact
│  ├─ terraform-apply.yml    apply that exact artifact, behind a human gate
│  ├─ drift-detection.yml    nightly: has reality moved?
│  ├─ invariant-check.yml    hourly: is anything still armed?
│  ├─ contract-tests.yml     nightly: real resources, auto-destroyed
│  ├─ ai-eval-pr.yml         AI: measure a prompt change before anyone sees it
│  ├─ ai-release.yml         AI: ship the exact bundle that was evaluated
│  └─ ai-drift.yml           AI: quality drift + model deprecation watch
│
├─ ai/                       the AI half, self-contained
│  ├─ eval/tier_one/         20 offline tests, no model call, 0.4s
│  ├─ eval/evalset.yaml      a frozen eval set
│  ├─ config/models.yaml     every model id, pinned to dated snapshots
│  └─ PROMPT-INVENTORY.md    brownfield worksheet
│
├─ examples/                 patterns not wired into the sandbox
└─ scripts/
   ├─ preflight.sh           are you ready, and is that really a test zone?
   ├─ verify.sh              prove all fifteen patterns
   ├─ drift_report.py        render drift, attribute it to a person
   └─ normalize.py           make generated config maintainable
```

Every line you need to edit is marked `# >>> CHANGE`. Search for that string —
there are 73 of them and nothing else needs touching.

---

## Adoption order

You do not need all of it, and doing it out of order wastes effort.

| | Pattern | Why here |
|---|---|---|
| 1 | **Destroy guard** | Highest value per line. Runs against a plan you already produce — no pipeline changes |
| 2 | **Tier-one tests** | They make everything after this safe to change |
| 3 | **The gated pipeline** | The big one. Do it once tests exist |
| 4 | **Drift detection** | Now that code is trustworthy, find where reality disagrees |
| 5 | **Module contracts** | Refactor toward these as modules stabilise |
| 6 | The rest | As the problems actually appear |

For the AI patterns the order **inverts**, and the reason is worth knowing: in
infrastructure the worst outcome is deleting something, so you start with the
destroy guard. In an AI system the worst outcome is not knowing whether you got
better or worse — so you start with **a frozen eval set and pinned models.**

---

## Two things that will bite you, written down

Both cost us real time. Both are in the comments where you'll hit them.

**`terraform init` needs `-test-directory` too**, not just `terraform test`. A
plain init does not install modules referenced from a non-default test
directory, and the suite dies at run time with `Module not installed` — which
reads like a broken test rather than a missing flag.

**Declare variables inside the test file.** A `.tftest.hcl` referencing `var.x`
without declaring it makes Terraform parse the `TF_VAR_x` value as an HCL
*expression*, so `sandbox.example.com` fails with `Extra characters after
expression`. Terraform warns this is deprecated and will become an error.

---

## What is verified, and what is not

A kit that overstates itself is worse than no kit.

**Verified — run end to end against a live account:**

- `terraform test` — 8 tests, all four validations proven to fire via `expect_failures`
- all three policies, against known-good **and** known-bad fixtures in both directions
- the sandbox root: apply, clean plan afterwards, destroy, zero residue
- drift detection catching a real out-of-band change (`plan` exit code 2) and healing
- AI tier-one evals — 20 tests, 0.4s, with every model credential stripped from the environment
- `preflight.sh` and `verify.sh --live`, 15/15 passing

**Not verified — design guidance, test before relying on it:**

- **`examples/tunnel-ha.tf`.** Written from a working module, but our credential
  could read tunnels and not create them.
- **The audit-log join in `drift_report.py`.** Detection works; the attribution
  API returned 403 for us. The script says so rather than pretending — keep
  that behaviour when you adapt it.
- **The AI workflows end to end.** The policies and tier-one evals genuinely
  run; `ai-eval-pr.yml` calls an eval runner you supply, and no real eval has
  flowed through it. Every threshold in `eval_release_guard.rego` is a starting
  point to calibrate against your own noise floor, not a measurement.

---

## One idea underneath all of it

Every pattern says **no**, cheaply, at the earliest layer that can catch that
class of mistake.

| Caught by | Cost |
|---|---|
| a `validation` block | seconds, one person |
| pre-commit | seconds, and it never enters git history |
| a policy on the PR | a review cycle |
| a human at the gate | minutes, plus someone's attention |
| **production** | hours to days, at 3am, during an incident |

Each layer costs roughly ten times the one above. That is the whole argument
for pushing checks left — and why a rule that lives in a wiki page is not a
rule.

**A policy that is not a check is a hope.** Everything here exits non-zero.
