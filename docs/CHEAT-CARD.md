# CHEAT CARD — keep this open on your second screen

One line per topic, in delivery order. The structured version — every topic as
**explain / run / review**, plus the six workflows and how each is triggered — is
[RUN-OF-SHOW.md](RUN-OF-SHOW.md). This page is the glanceable one.

**Every command on this page is Git Bash.** In PowerShell they fail with
`The term 'source' is not recognized` — that is the shell, not the lab.

---

## Before you share your screen

```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && clear
```

Then `Ctrl` `+` four or five times to make the font readable from the back.

**Pre-flight** — expect `No changes`, `No changes`, `active`, `5 passed`:

```bash
terraform -chdir=infra/envs/lab plan -input=false 2>&1 | grep -E "No changes|^Plan:"; terraform -chdir=brownfield/adopt plan -input=false -var zone_id=6fe522935f35ff5b7e1a049c1a90d11e -var zone_name=$LAB_ZONE 2>&1 | grep -E "No changes|^Plan:"; curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=$LAB_ZONE" | jq -r '.result[0].status'; terraform test 2>&1 | tail -1
```

**Three tabs, left to right:**

| Tab | What |
|---|---|
| 1 | [repo](https://github.com/miroslavt-arch/cf-terraform-lab) |
| 2 | [Actions → demo](https://github.com/miroslavt-arch/cf-terraform-lab/actions/workflows/demo.yml) |
| 3 | [Cloudflare DNS](https://dash.cloudflare.com/f40b69d8637a12568c6a62d218822384/zesty-beta.sxplab.com/dns/records) |

---

## The ten topics, in order

### 0:08 — Topic 24 · tests that cost nothing

```bash
bash scripts/demo-24-unit-tests.sh
```

**Point at:** the credential names printed, then the same suite passing with all
of them stripped from the environment. **`5 passed, 0 failed`** in about a second.

> "No network, no token, no account. If your tests need a cloud account, they are
> not unit tests — they are integration tests you are running too often."

---

### 0:18 — Topic 7 · the module as a contract

```bash
bash scripts/demo-07-validation.sh
```

**Point at:** the four `validation` blocks rejecting bad input *before* any API
call, and `?ref=v0.1.0` on line 25 of `infra/envs/lab/main.tf`.

> "The module is pinned to a git tag. My environment cannot drift because someone
> pushed to main. Upgrading is a commit I make deliberately, not something that
> happens to me."

---

### 0:30 — Topic 9 · singletons need one owner

```bash
bash scripts/demo-09-singleton-flap.sh
```

**Point at:** two roots both claiming the same zone setting; each apply reverts
the other. Nothing errors. **That is the problem.**

> "Neither side is wrong and neither side is told. This runs for months and
> surfaces during an incident."

---

### 0:40 — Topic 10 + 11 · composition, then the kill-switch

```bash
bash scripts/demo-10-fragment-lint.sh
bash scripts/demo-11-arm.sh
```

**Point at (10):** three YAML fragments concatenated in a fixed order, owner and
review-date stamped into every rule description, and the OPA rule *failing* the
bad fragment. **Point at (11):** `incident_mode` flipping `enabled` across the
incident rules in one variable.

> "The order is deterministic because it is `concat`, not because everyone
> remembered. And the policy is a check that exits non-zero, not a wiki page."

---

### 0:52 — Topic 20 · the human gate  ← **the centrepiece, give it the full 20 min**

**Run this one from Tab 2**, not the terminal. Menu → `topic-20-stale-plan-invariant`
→ Run workflow. It stops at **Review deployments**. Let the room look at it.

> "The job is not slow. It is *stopped*. It has no write credential yet, and it
> does not get one until a human ticks a box. Same gate a production change goes
> through."

Approve → tick `lab-apply` → Approve and deploy. Then the refusal:

```
Error: Saved plan is stale
```

> "What my reviewer approved is the only thing that can execute. I moved the world
> after planning, and Terraform itself refused. Process can be skipped; this cannot."

Terminal route if the console is slow: `bash scripts/demo-20-stale-plan.sh`

---

### 1:12 — Topic 27 · drift, with a name attached

```bash
bash scripts/demo-27-make-drift.sh
```

**Point at:** an out-of-band change made by API, then `plan -detailed-exitcode`
returning **2** and the report naming the record and the field.

> "Exit code 2 is the whole trick. Zero means clean, one means broken, two means
> *the world moved*. That is the one you schedule."

**Say the limit plainly:** the audit-log join returns 403 on this account, so the
detection is real and the attribution is not. The script says so in one line.

---

### 1:24 — Topic 14 · tunnels and HA  *(walkthrough — does not run)*

Open `infra/modules/tunnel-site/` in Tab 1. Or the Actions entry
`topic-14-tunnel-design-walkthrough`.

> "I am walking this one rather than running it. The lab token can read tunnels
> but not create them, and the HA demo needs two containers on a machine I
> control. I would rather show you the real module than fake a run."

**Point at:** two replicas behind one tunnel, the catch-all last ingress rule,
and the two-step rotation that never leaves zero healthy connectors.

---

### 1:36 — Topic 29 · brownfield adoption

```bash
bash scripts/demo-29-adopt.sh
```

**Point at:** records created by hand outside Terraform → discovery →
`import` blocks with `for_each` over a CSV → `-generate-config-out` → normalise
→ apply → and the gate: **plan must come back clean or the script exits 1**.

> "Adoption is not finished when it applies. It is finished when a fresh plan says
> no changes. Until then you have two descriptions of one estate."

---

### 1:48 — Topic 32 · four sharp edges, then close

```bash
bash scripts/demo-32-noise.sh    # canonicalisation: the API rewrites what you asked for
bash scripts/demo-32-dual.sh     # two writers, one DNS record
bash scripts/demo-32-phase.sh    # two roots, one ruleset phase
```

Fourth edge (**list scale**) is numbers only — needs account-level list
permissions this token lacks:

> "Five hundred items as five hundred resources versus one resource holding five
> hundred items. I measured it rather than running it, because it takes too long
> and it fails on purpose."

**On plan noise:** > "The fix is to write what the API will store. `ignore_changes`
here would hide a real difference along with the cosmetic one."

---

## Closing line

> "Every failure I showed you was the same failure wearing different clothes: a
> shared thing with two owners. Decide ownership deliberately. Make the rule
> executable, because a policy that is not a check is a hope. And put the human
> approval where the credential is, not where the merge button is."

---

## Panic buttons

| It went wrong | Do this |
|---|---|
| `source: not recognized` | You are in PowerShell. Open Git Bash. Nothing is broken |
| `unbound variable`, or 401s | You skipped `source ~/.cf-lab-env` in *this* terminal |
| `No such file or directory: scripts/...` | You are inside `scripts/`. `cd ..` |
| Pre-flight says `1 to change` | A prior run was cut short. Run the RESET below |
| Workflow stuck on "Waiting" | That is the gate working. Say so, then approve it |
| A live demo fails on stage | Say "that is a real failure, let us read it" and read it. It is a better moment than the demo |

**RESET** (safe any time, restores the baseline):

```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && terraform -chdir=infra/envs/lab apply -auto-approve -input=false >/dev/null && terraform -chdir=infra/envs/lab plan -input=false | grep -E "No changes|^Plan:"
```
