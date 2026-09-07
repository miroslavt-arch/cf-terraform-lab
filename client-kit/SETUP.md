# Setting this up in a test account

About 30 minutes, most of it waiting for a token to be created. Nothing here
touches production, and the preflight script refuses to run against a zone that
does not look like a sandbox.

---

## 0. What you need

| | |
|---|---|
| A **test** zone | A domain or subdomain in an account you can break. Not production |
| Terraform ≥ 1.9 | The module uses cross-variable validation |
| conftest | To run the policies — [releases](https://github.com/open-policy-agent/conftest/releases) |
| `jq` | Used by the workflows and by `verify.sh` |
| Python 3.9+ | For the AI evals and the drift report |

Terraform 1.9 is a hard floor: the module's `resource_prefix` validation
references another variable, which older versions reject.

---

## 1. Create the credentials

You need **two** tokens. That separation is the point of the whole gated
pipeline, so do not shortcut it by using one token for both.

### Token A — plan / read-only

Scoped to the sandbox zone:

- Zone → Zone → **Read**
- Zone → DNS → **Read**
- Zone → Zone Settings → **Read**

This token goes in the `plan` GitHub environment. Because it cannot write, the
PR pipeline is safe by construction rather than by policy.

### Token B — apply / write

Same zone, but:

- Zone → Zone → **Read**
- Zone → DNS → **Edit**
- Zone → Zone Settings → **Edit**

This token goes in the `apply` environment, **behind a required reviewer**.

> Scope both tokens to the sandbox zone only. A token that can reach production
> makes every other control in this kit decorative.

---

## 2. Point the kit at your zone

```bash
export CLOUDFLARE_API_TOKEN="<token B, for local runs>"
export TF_VAR_zone_name="sandbox.example.com"
export TF_VAR_zone_id="<zone id from the dashboard overview>"

# Optional. Defaults shown.
export TF_VAR_resource_prefix="tf-"     # must match policy/destroy_guard.rego
export TF_VAR_subdomain="sandbox"       # records live under this
```

Or copy the tfvars file instead — it is gitignored:

```bash
cp infra/envs/sandbox/terraform.tfvars.example infra/envs/sandbox/terraform.tfvars
```

**Windows note:** these commands are Git Bash. In PowerShell `export` is not a
command; use `$env:CLOUDFLARE_API_TOKEN = "..."`.

---

## 3. Preflight

```bash
bash scripts/preflight.sh
```

Checks your tools, that the token can read the zone, that the zone id matches
the name, and that the zone **looks like a sandbox**. It counts existing DNS
records too — if there are more than 25 it warns you, because that is usually a
sign you are pointed somewhere real.

If your test zone genuinely has no sandbox-ish word in its name, set
`ALLOW_ANY_ZONE=1` to acknowledge it deliberately.

Expect `Ready.` before continuing.

---

## 4. Verify — offline first

```bash
bash scripts/verify.sh
```

Free, no credentials used. Runs `fmt`, `init`, `validate`, the tier-one
Terraform tests with every credential stripped from the environment, all three
policies in both directions, and the AI tier-one evals.

Expect **10 passed, 0 failed**.

---

## 5. Verify — live

```bash
bash scripts/verify.sh --live
```

This one creates two TXT records, changes one out of band, proves drift is
detected, heals it, and destroys everything — including if it fails partway.

Expect **15 passed, 0 failed**, ending in `destroyed everything this script
created`.

What it proves, in order:

1. your real plan passes the destroy guard
2. apply succeeds
3. the records exist when you ask the API directly
4. a fresh plan is clean — your code describes what was built
5. an out-of-band change is detected as drift (`plan` exit code **2**)
6. the drift heals with one apply
7. teardown leaves nothing behind

---

## 6. Wire up GitHub

### Two environments

**Settings → Environments → New environment.**

| Name | Secret | Protection |
|---|---|---|
| `plan` | `PROVIDER_TOKEN_READONLY` = token A | none — planning is safe by token construction |
| `apply` | `PROVIDER_TOKEN_WRITE` = token B | **Required reviewers** + **wait timer 1 minute** |

Put the write token on the **environment**, never in repo-level secrets. The
guarantee is that unreviewed code cannot reach it — repo secrets are reachable
from every workflow.

### Repo variables

**Settings → Secrets and variables → Actions → Variables:**

| Name | Value |
|---|---|
| `SANDBOX_ZONE_ID` | your zone id |
| `SANDBOX_ZONE_NAME` | your zone name |
| `ZONE_ID` | same id (used by `invariant-check.yml`) |

### Copy the workflows

They are already in `.github/workflows/` with paths matching this tree. Open
each one and work through the `# >>> CHANGE` markers — mostly the provider
name, the secret names, and the cron times.

---

## 7. The first real run

```bash
git checkout -b demo/first-change
# edit infra/envs/sandbox/main.tf — change a TTL from 300 to 600
git commit -am "sandbox: bump the hello record TTL"
git push -u origin demo/first-change
gh pr create --fill
```

`terraform-pr` runs on its own. Nobody clicks anything — the pull request *is*
the trigger. It will:

1. run the tier-one tests
2. lint policy, including the meta-test that a known-bad fixture still fails
3. plan with the **read-only** token
4. run the destroy guard over the plan JSON
5. upload `tfplan-<sha>` and comment the plan on the PR

Then dispatch the apply with that run id and SHA:

```bash
gh workflow run terraform-apply.yml -f plan_run_id=<run-id> -f sha=<sha>
```

**The job will stop.** That is the gate, not a failure. It has no write
credential yet. Approve it in the Actions tab and watch it apply *that exact
artifact* — there is no `plan` step in the apply workflow at all.

---

## 8. The AI half, if you want it

```bash
pip install -r ai/requirements-dev.txt
python -m pytest ai/eval/tier_one -q          # 20 passed, no model calls
```

Then, in order:

1. **Freeze an eval set.** `ai/eval/evalset.yaml` is the shape. Fifty real
   cases beat five hundred synthetic ones — sample from production.
2. **Pin every model** in `ai/config/models.yaml` to a dated snapshot, and turn
   on the deprecation watch in `ai-drift.yml` the same day.
3. **Record a baseline** into `ai/eval/baseline.json`.
4. Wire `ai/eval/run.py` — the one piece you supply, because scoring is
   specific to your task. The workflows call it with `--evalset`, `--model`,
   `--samples`, `--baseline`, `--out`.
5. Calibrate `policy/eval_release_guard.rego`. **Measure your noise floor
   first**: run the same eval against the same pin several times unchanged and
   see how much the score moves on its own. Set the tolerance above that. A
   guard tuned tighter than your noise blocks good releases and gets disabled
   within a month.

---

## Teardown

```bash
terraform -chdir=infra/envs/sandbox destroy
```

Note that the sandbox prefix is deliberately **not** in `disposable_prefixes`
in `policy/destroy_guard.rego`. Only `tftest-` and `ephemeral-` are. That means
a *pipeline* cannot destroy your sandbox records, but you can, by hand, which is
the intended split: automated teardown for test fixtures, deliberate human
action for anything else.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `export: command not found` | You are in PowerShell. Use Git Bash, or `$env:VAR = "..."` |
| `Module not installed` running contract tests | `init` needs `-test-directory=tests/contract` too |
| `Extra characters after expression` | A test file references `var.x` without declaring it. Declare it in the test file |
| Terraform rejects the module | Version below 1.9 — cross-variable validation |
| `preflight` fails on the zone name | Deliberate. Confirm it is not production, then `ALLOW_ANY_ZONE=1` |
| Apply workflow "stuck" on Waiting | That is the gate working. Approve it in Actions |
| destroy guard blocks your teardown | Correct by design. Destroy by hand, or add your prefix to `disposable_prefixes` |
