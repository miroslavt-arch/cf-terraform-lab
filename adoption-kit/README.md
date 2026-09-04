# Terraform adoption kit

Working files for ten patterns covered in the session — CI workflows, OPA
policies, module shapes, test suites, helper scripts. Copy what you need, when
you need it. Nothing here depends on anything else except where a section says
so.

**[ARCHITECTURE.md](ARCHITECTURE.md) — diagrams and how each pattern works.**
Read that first; this file is the index.

---

## What's here

```
adoption-kit/
├─ ARCHITECTURE.md              diagrams + mechanism for all ten patterns
├─ workflows/                   drop into .github/workflows/
│  ├─ terraform-pr.yml          plan on PR with a read-only credential
│  ├─ terraform-apply.yml       apply a pinned plan behind a human gate
│  ├─ drift-detection.yml       nightly: has reality moved?
│  ├─ invariant-check.yml       hourly: is anything still armed?
│  └─ contract-tests.yml        nightly: real API, real resources, auto-destroyed
├─ policy/                      conftest / OPA
│  ├─ destroy_guard.rego        refuse plans that destroy the wrong thing
│  ├─ fragment_policy.rego      what each team may contribute to a shared object
│  └─ fixtures/                 known-good and known-bad, for the meta-test
├─ examples/                    Terraform patterns, copy the shape
│  ├─ variables-with-validation.tf   the module contract
│  ├─ unit.tftest.hcl                tier-one tests, mocked, no credentials
│  ├─ contract-test.tftest.hcl       tier-two tests, real API
│  ├─ singleton-ownership.tf         the boolean that stops two owners
│  ├─ composed-ruleset.tf            fragments → one object, fixed order
│  ├─ import-blocks.tf               brownfield adoption
│  ├─ import-and-compare.tf          drift detection without remote state
│  ├─ tunnel-ha.tf                   two connectors, one tunnel
│  └─ docker-compose.tunnel.yml      the HA demo
├─ modules/README.md            what makes a module a contract
└─ scripts/
   ├─ drift_report.py           render drift + attribute it to a human
   └─ normalize.py              make generated config human-maintainable
```

Every file that needs editing marks the lines with `# >>> CHANGE`. Search for
that string.

---

## Start here — the order that works

You do not need all ten, and doing them out of order wastes effort.

### 1. Destroy guard — highest value per line in the kit

Works against any plan you already produce. No pipeline changes required to
try it:

```bash
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
conftest test --policy policy --namespace destroy_guard plan.json
```

Edit `disposable_prefixes` in [`policy/destroy_guard.rego`](policy/destroy_guard.rego).
**Start strict.** Allow nothing, see what your real plans trip, then widen
deliberately. Starting permissive and tightening later does not happen.

### 2. Tier-one tests — they make everything after this safe to change

Copy [`examples/unit.tftest.hcl`](examples/unit.tftest.hcl). Mocked provider,
no credentials, about a second. Add the `unit` job from
[`workflows/terraform-pr.yml`](workflows/terraform-pr.yml).

The one to not skip is `expect_failures` — it proves your validation *fires*.
Without it you only ever prove that valid input works, and a validation block
with a typo in its condition passes every happy-path test.

### 3. The gated pipeline — the big one

Both workflows, plus two GitHub environments:

| Environment | Holds | Protection |
|---|---|---|
| `plan` | read-only credential | none — planning is safe by token construction |
| `apply` | write credential | **required reviewers** + 1-minute wait timer |

Then never add a `plan` step to the apply workflow. That absence is the
guarantee.

### 4. Drift detection

[`workflows/drift-detection.yml`](workflows/drift-detection.yml). Two variants
in the file: use the plain one if the runner can reach your state backend, the
import-and-compare one if it cannot.

### 5. Module contracts

Refactor toward [`examples/variables-with-validation.tf`](examples/variables-with-validation.tf)
as modules stabilise. Pin consumers by tag on the same day.

### 6. The rest, as the problems actually appear

Adopting a pattern for a problem you do not have is how platform teams lose
credibility.

---

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| Terraform ≥ 1.7 | `mock_provider` needs 1.7; `import` blocks need 1.5 | [releases](https://developer.hashicorp.com/terraform/install) |
| conftest | runs the OPA policies | [releases](https://github.com/open-policy-agent/conftest/releases) |
| jq | plan JSON in the workflows | package manager |
| Python 3.9+ | the two helper scripts | package manager |

Terraform version is pinned in each workflow's `TF_VERSION`. Match it to what
your team runs locally — a version skew between laptop and CI produces plan
differences that look like drift.

---

## Verified vs not

Honest labelling, because a kit that overstates itself is worse than no kit.

**Verified working**, against a live account:

- both policies, against known-good and known-bad fixtures in each direction
- tier-one and tier-two test suites
- the gated pipeline end to end: push → PR → plan → artifact → gate → apply
- drift detection, catching a real out-of-band change and failing the run
- the invariant check, going green → armed → **fail** → disarmed
- brownfield adoption, importing a hand-built estate to a clean plan

**Not verified** — treat as design guidance and test before relying on it:

- **`examples/tunnel-ha.tf` and the HA rotation.** Documented from a working
  module, but our lab credential could read tunnels and not create them.
- **List-scale numbers.** Measured, not demonstrated; the credential lacked
  account-level list permissions.
- **The audit-log join in `drift_report.py`.** Detection works; the attribution
  API returned 403 for us. The script degrades gracefully and says so rather
  than pretending — keep that behaviour when you adapt it.

---

## The one idea underneath all of it

Every pattern here does the same thing: it says **no**, cheaply, at the
earliest layer that can possibly catch that class of mistake.

| Caught by | Cost when it fires |
|---|---|
| a `validation` block | seconds, one person |
| pre-commit | seconds, and it never enters git history |
| a policy on the PR | a review cycle |
| a human at the gate | minutes, plus someone's attention |
| **production** | hours to days, at 3am, during an incident |

Each layer costs roughly ten times the one above. That is the whole argument
for pushing checks left, and it is why a rule that lives in a wiki page is not
a rule.

**A policy that is not a check is a hope.** Everything in this kit exits
non-zero.
