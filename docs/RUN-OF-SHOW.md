# RUN OF SHOW — explain, run, review

Every topic follows the same three beats. Nothing else. Once the room learns
the rhythm they stop wondering what is happening and start watching the point.

| Beat | What you do |
|---|---|
| **1. EXPLAIN** | Say the idea *before* anything runs. No screen action. 60–90 seconds. |
| **2. RUN** | One command in the terminal, or one trigger in Actions. Then be quiet and let it run. |
| **3. REVIEW** | Open the code or the run and show **how** it did that and **why** it is built that way. |

The mistake to avoid is merging beats 2 and 3. Run it, let them watch the
output land, *then* go to the source. If you narrate the code while the job is
still running, they will watch neither.

---

## Which terminal

**Every command here is Git Bash. None of them work in PowerShell.** In
PowerShell you get `The term 'source' is not recognized` — that is the shell,
not the lab.

VS Code: Terminal → New Terminal → the **v** beside `+` → **Git Bash**.

Run this once before you share your screen:

```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && clear
```

Then `Ctrl` `+` four or five times so the back row can read it.

## Tabs, left to right

| Tab | URL |
|---|---|
| **1** | https://github.com/miroslavt-arch/cf-terraform-lab |
| **2** | https://github.com/miroslavt-arch/cf-terraform-lab/actions |
| **3** | https://dash.cloudflare.com/f40b69d8637a12568c6a62d218822384/zesty-beta.sxplab.com/dns/records |

## Pre-flight — expect `No changes`, `No changes`, `active`, `5 passed`

```bash
terraform -chdir=infra/envs/lab plan -input=false 2>&1 | grep -E "No changes|^Plan:"; terraform -chdir=brownfield/adopt plan -input=false -var zone_id=6fe522935f35ff5b7e1a049c1a90d11e -var zone_name=$LAB_ZONE 2>&1 | grep -E "No changes|^Plan:"; curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=$LAB_ZONE" | jq -r '.result[0].status'; terraform test 2>&1 | tail -1
```

---

# THE SIX WORKFLOWS — what they are and how each one starts

This is the part people ask about, so know it cold. **Three different things
can start a job, and which one applies is the whole story.**

| Workflow | Starts when | What it does | Where you see it |
|---|---|---|---|
| **tf-pr** | **a pull request opens or updates** — a git event, no button | unit tests → `fmt` → conftest on WAF fragments → `plan` with the **read-only** token → OPA destroy-guard → uploads plan artifact `tfplan-<sha>` → comments the plan on the PR | the PR itself |
| **tf-apply** | **manual dispatch** with `plan_run_id` + `sha` | downloads **that exact artifact** and runs `terraform apply <planfile>` — never a fresh plan. Runs in `lab-apply`: 1-min timer + required reviewer | Actions, paused at "Review deployments" |
| **drift** | **cron 03:17 UTC**, or dispatch | imports the live ruleset into ephemeral state, plans it against committed code, counts anything that is not a no-op. Clean → silent. Dirty → report + **fail** | Actions job summary |
| **killswitch-reminder** | **cron hourly**, or dispatch | asks the Cloudflare API whether any `lab_ir_*` rule is `enabled`. Dark → silent. Armed → **fail**, every hour, until disarmed | Actions; a failing scheduled job emails the owner |
| **contract-tests** | **cron 02:42 UTC**, or dispatch | tier-two `terraform test` against the real zone with `tftest-` resources, auto-destroyed. Needs the write token, so it **queues at the gate** | Actions |
| **demo (run a topic)** | **manual dispatch**, pick from a 12-entry menu | runs one topic's script on a runner and publishes the output to the job summary with deep links into Cloudflare | Actions job summary |

## The three ways anything starts — say this out loud once

> "Notice there are only three ways a job starts here, and they are not
> interchangeable. **A git push** starts the PR pipeline — I do not click
> anything, the pull request *is* the trigger. **A clock** starts the two
> detectors, because a check you have to remember to run is not a check.
> And **a human clicking dispatch** starts anything that writes, because the
> write credential lives behind an approval and nothing reaches it by accident."

## Triggering, three routes

**Route A — a real git push.** The only route that starts `tf-pr`:

```bash
bash scripts/trigger/01-pr-pipeline.sh
```

Branches, edits one line, commits, pushes, opens the PR, waits for `tf-pr`,
then dispatches `tf-apply` pinned to that plan and stops so **you** click the
gate. Add `--auto-approve` when rehearsing alone.

**Route B — the Actions console.** Tab 2 → the workflow → **Run workflow**.
For `demo` you also pick a topic. Jobs in `lab-apply` pause; click **Review
deployments** → tick **lab-apply** → **Approve and deploy**.

**Route C — the terminal.** `bash scripts/demo-NN-*.sh`. Fastest, but the room
watches a terminal instead of a console.

## Making the scheduled workflows fire on demand

A cron is useless in a 2pm session. These manufacture the exact condition each
detector hunts for, then run it:

```bash
bash scripts/trigger/02-nightly-drift.sh
bash scripts/trigger/03-killswitch-alarm.sh
bash scripts/trigger/04-contract-tests.sh
```

Each heals what it broke as its last act. To undo everything at once:

```bash
bash scripts/trigger/99-reset.sh
```

---

# THE TOPICS

---

## Topic 24 — tests that cost nothing  ·  ~10 min

### 1. EXPLAIN

> "Most infrastructure teams have no unit tests, and the reason is always the
> same: testing infrastructure supposedly means creating infrastructure. So
> tests get slow, they cost money, they need credentials, and eventually
> nobody runs them."
>
> "Terraform has had a native test runner since 1.6, and with a mocked
> provider it never talks to an API at all. I am about to run the whole suite
> with every credential deliberately deleted from the environment."

### 2. RUN

```bash
bash scripts/demo-24-unit-tests.sh
```

Or Tab 2 → **demo (run a topic)** → `topic-24-terraform-test`.

Let them read the two blocks: the credential names present in the shell, then
the same suite passing with all of them stripped. About one second.

### 3. REVIEW

Open **`tests/unit.tftest.hcl`** (Tab 1). Point at:

- `mock_provider "cloudflare"` at the top — **why it needs no token**
- the **5 `run` blocks**, each naming one behaviour
- the block using **`expect_failures`** — proves a validation *fires*, not just that valid input works

Then open **`.github/workflows/tf-pr.yml`**, the `unit` job (line 20).

> "This is not a script somebody remembers to run. It is a required job on
> every pull request, and the `plan` job below it lists `needs: [unit,
> lint-fragments]` — so a plan is not even attempted until the offline tests
> pass. That is what makes it a gate rather than a suggestion."

**If asked, "what about tests that DO need the real API?"** — that is tier two,
`tests/contract/`. It creates `tftest-` resources against the real zone and
destroys them. It runs nightly, never on PRs. You can show it live:

```bash
bash scripts/trigger/04-contract-tests.sh
```

---

## Topic 7 — the module as a contract  ·  ~12 min

### 1. EXPLAIN

> "A module is an API. If the only way to find out you passed the wrong thing
> is a 500 from Cloudflare three minutes into an apply, that is a bad API."
>
> "Two things make it a real contract: a typed interface that rejects nonsense
> before any network call, and a version pin so your environment cannot change
> because somebody else pushed to main."

### 2. RUN

```bash
bash scripts/demo-07-validation.sh
```

Or Actions → `topic-07-module-design`.

### 3. REVIEW

Open **`infra/modules/zone-baseline/variables.tf`**. Point at:

- one `map(object)` with **`optional()`** defaults — callers pass what they mean, not eleven positional nulls
- the **four `validation` blocks** — each rejects a specific mistake with a message that says how to fix it
- the nested `metadata` object defaulting to `{}` — **why**: adding a field later does not break every existing caller

Then **`infra/envs/lab/main.tf` line 25**:

```
source = "git::https://github.com/miroslavt-arch/cf-terraform-lab.git//infra/modules/zone-baseline?ref=v0.1.0"
```

> "That `?ref=v0.1.0` is the whole point. A relative path means my environment
> silently changes whenever somebody edits the module. A tag means upgrading is
> a commit I make on purpose, it shows up in a diff, and it can be reverted."

**If asked, "why not a registry?"** — a git tag gives you the same immutability
with no extra infrastructure. Move to a registry when you need discovery across
teams, not before.

---

## Topic 9 — singletons need exactly one owner  ·  ~10 min

### 1. EXPLAIN

> "Some things in a zone are singletons. There is exactly one 'minimum TLS
> version'. Not one per team — one. When two Terraform roots both think they
> own it, neither of them is wrong, and neither of them is told."

### 2. RUN

```bash
bash scripts/demo-09-singleton-flap.sh
```

Or Actions → `topic-09-singleton-ownership`.

### 3. REVIEW

Open **`demos/singleton-conflict/`** — two roots, both declaring the same
setting. Then **`infra/modules/zone-baseline/main.tf`** and find
**`manage_settings`**.

> "Look at what just happened: both applies succeeded. Both pipelines are
> green. Each one silently reverted the other, and the only way anyone finds
> out is when a customer reports something odd."
>
> "The fix is not cleverness, it is a boolean. `manage_settings` — exactly one
> root passes true. Everyone else consumes the module for records only. The
> contract is enforced in the type system, not in a wiki page."

**If asked, "wouldn't `ignore_changes` fix this?"** — no, and Topic 32 shows why:
it would stop managing the field entirely, so a real unauthorised change would
also stop being visible.

---

## Topic 10 — composing a WAF from fragments  ·  ~7 min

### 1. EXPLAIN

> "Three teams want rules in one WAF. Incident response, security, and an app
> team. They must not edit each other's rules, order matters enormously, and
> every rule needs an owner you can find at 3am."

### 2. RUN

```bash
bash scripts/demo-10-fragment-lint.sh
```

Or Actions → `topic-10-waf-composition`.

### 3. REVIEW

Open **`infra/modules/waf-composed/rules/`** — three YAML files, one per team.
Then **`main.tf` line 38**:

```
ordered_rules = concat(local.render.incident, local.render.security, local.render.app)
```

> "The order is deterministic because it is a `concat`, not because three teams
> remembered a convention. Incident rules always come first. It is impossible
> to get that wrong from a fragment."

Point at the **owner and review-date interpolated into every description** —
then Tab 3, Security rules, to show it on the live rule.

> "That string is not decoration. At 3am you read the rule in the dashboard and
> it tells you who owns it and when it was last reviewed."

Then **`policy/waf_fragments.rego`**, and in **`.github/workflows/tf-pr.yml`**
the `lint-fragments` job — including the **meta-test** at line 46:

> "The second step there deliberately runs the policy against a known-bad
> fixture and fails the build if it *passes*. A lint that has quietly stopped
> linting is worse than no lint, because you trust it."

Then **`.github/CODEOWNERS`**: each fragment routes review to its team.

---

## Topic 11 — the kill-switch  ·  ~5 min

### 1. EXPLAIN

> "During an incident you want to raise defences in seconds, not write new
> Terraform. So the emergency rules are already written, already reviewed,
> already deployed — and disabled. Arming them is a one-variable change."

### 2. RUN

```bash
bash scripts/demo-11-arm.sh
```

Then make the hourly alarm fire:

```bash
bash scripts/trigger/03-killswitch-alarm.sh
```

### 3. REVIEW

Open **`infra/modules/waf-composed/variables.tf`** → `incident_mode`
(`none` / `elevated` / `lockdown`, with validation), then in `main.tf` the
**`mode_rank`** local that binds each incident rule's `enabled` to it.

Then **`.github/workflows/killswitch-reminder.yml`**:

> "Here is the part I actually care about. Every team is good at arming. Nobody
> is good at disarming — the incident ends, everyone goes to bed, and a
> challenge stays on production for three weeks."
>
> "This runs every hour and asks the **Cloudflare API** what is enabled. Not the
> tfvars. Not what we intended. Reality. If anything `lab_ir_*` is on, the job
> fails, and a failing scheduled workflow emails me. It keeps failing until
> someone disarms."

You just watched it go green → **fail** → green again.

---

## Topic 20 — the human gate  ·  ~20 min  ·  **THE CENTREPIECE**

### 1. EXPLAIN

Do not rush this. Give it 2 full minutes with nothing on screen.

> "Here is the failure everyone has lived through. A reviewer approves a plan.
> The pipeline runs. But between the approval and the apply, the world moved —
> someone else merged, someone touched the dashboard — so the pipeline computes
> a *fresh* plan and applies that. The thing that executed is not the thing
> that was approved. Nobody lied. The process just has a hole in it."
>
> "Two ideas close it. First, the plan is an **artifact**, keyed by commit SHA,
> and apply replays that file rather than re-planning. Second, the write
> credential does not live in the repo — it lives inside a GitHub environment
> behind a required reviewer, so code cannot reach it until a human approves."

### 2. RUN

This is the one topic to run from a **real git push**:

```bash
bash scripts/trigger/01-pr-pipeline.sh
```

It branches, changes one line, pushes, and opens a PR. Then stop talking and
let `tf-pr` run in Tab 2.

When it prints the `tf-apply` URL, **open it and stop**:

> "Look at the job. It is not slow — it is **stopped**. It has no write
> credential yet. A one-minute timer is running and a named human has to tick a
> box. This is the same gate a production change goes through, and you are
> watching it work."

Then approve it yourself: **Review deployments** → tick **lab-apply** →
**Approve and deploy**.

For the stale-plan refusal:

```bash
bash scripts/demo-20-stale-plan.sh
```

```
Error: Saved plan is stale
```

### 3. REVIEW

Open **`.github/workflows/tf-pr.yml`** and walk four things:

- **line 56** `environment: lab-plan` and **line 58** the token is `CLOUDFLARE_API_TOKEN_PLAN` — *"the PR pipeline is planning with a credential that physically cannot write"*
- **line 78** the OPA destroy guard runs against plan **JSON**, not a diff
- **line 82** the artifact is named **`tfplan-<sha>`** — *"the commit SHA is the key. This is the contract."*
- **line 99** the PR comment says which artifact the apply will replay

Then **`.github/workflows/tf-apply.yml`**:

- **line 25** `environment: lab-apply` — where the reviewer and timer live
- **line 43** downloads `tfplan-${{ inputs.sha }}` from the pinned run
- **line 50** `terraform apply -input=false plan-<sha>.tfplan`

> "Read that last line. It is `apply <planfile>`. There is no `plan` command in
> this workflow at all. It is structurally incapable of applying something the
> reviewer did not see."

Finally, Settings → Environments → **lab-apply**: required reviewer, 1-minute
timer, and the write secret scoped to this environment only.

> "Process can be skipped. This cannot. And when I moved the world after
> planning, Terraform itself refused — that is not our policy, that is the tool."

---

## Topic 27 — drift, with a name attached  ·  ~12 min

### 1. EXPLAIN

> "Drift is when live infrastructure stops matching the code. It happens for
> ordinary reasons: an outage at 2am, a support engineer with dashboard access,
> a vendor script. The problem is not that it happens. The problem is that
> nothing tells you, so your code quietly stops describing production and you
> find out during the next incident."

### 2. RUN

```bash
bash scripts/trigger/02-nightly-drift.sh
```

This disables a live security rule out of band — exactly what a dashboard click
does — then runs the nightly workflow now instead of at 03:17 UTC. It should
**fail**.

### 3. REVIEW

Open **`.github/workflows/drift.yml`**:

- **line 18** `cron: "17 3 * * *"` — *"a detector you have to remember to click is not a detector"*
- **lines 64–77** the import-and-compare, and the `jq` that counts anything not a `no-op`
- **line 39** `environment: lab-plan` — *"read-only is enough to SEE drift; noticing should never require write access"*
- **lines 88–92** it exits **1** on drift

Then the run's **job summary** — it names the resource and the action.

> "Terraform's `plan -detailed-exitcode` returns 0 for clean, 1 for error, and
> **2 for 'the world moved'**. That third code is the whole trick, and it is the
> one you put on a schedule."

**Say the limit plainly:** the audit-log join returns 403 on this account, so
the detection is real and the *attribution* is not. The script prints one line
saying so.

> "I would rather show you a detector that works and an attribution that needs
> one more permission, than a slide claiming both."

---

## Topic 14 — tunnels and HA  ·  ~12 min  ·  walkthrough, does not run

### 1. EXPLAIN

> "A tunnel is an outbound-only connection from your network to Cloudflare, so
> you can publish an internal service with no inbound firewall rule and no
> public IP. The interesting part is not creating one. It is running one
> without a single point of failure, and rotating it without an outage."

Say the limit immediately:

> "I am walking this one through rather than running it. The lab token can read
> tunnels but not create them, and the HA demo needs two containers on a machine
> I control. I would rather show you the real module than fake a run."

### 2. RUN

Actions → `topic-14-tunnel-design-walkthrough` — it renders the design and the
module without applying.

### 3. REVIEW

Open **`infra/modules/tunnel-site/main.tf`**. Point at:

- `cloudflare_zero_trust_tunnel_cloudflared` with `config_src = "cloudflare"` — config is remote-managed, so a replica restart cannot pick up a stale local file
- the ingress list with a **catch-all last rule** — *"omit it and the tunnel refuses to start; it is the `default:` of a switch statement"*
- the DNS CNAME to `<tunnel-id>.cfargotunnel.com`
- **two replicas on one tunnel** — *"one tunnel, several connectors. Kill one and traffic keeps flowing; Cloudflare load-balances across healthy connectors."*

Then the rotation:

> "The naive rotation is delete-then-create, and there is a window where zero
> connectors are healthy. The two-step is: stand the new tunnel up alongside the
> old one, move DNS, drain, then delete. Never fewer than one healthy connector
> at any point."

---

## Topic 29 — brownfield adoption  ·  ~12 min

### 1. EXPLAIN

> "Nobody starts greenfield. You inherit an estate somebody built by hand, and
> you have to bring it under Terraform without a single outage — because these
> are live DNS records."

### 2. RUN

```bash
bash scripts/demo-29-adopt.sh
```

Or Actions → `topic-29-brownfield-adoption` (it seeds the legacy estate first).

### 3. REVIEW

Open **`brownfield/adopt/`**. Walk the sequence in order:

- **discovery** — `cf-terraforming` reads the live zone. *Note honestly:* it works locally and panics on the runner against provider 5.24. The script says which.
- **`import` blocks with `for_each` over a CSV** — *"declarative import. It is code, it is reviewable, and it is in the diff. This replaced the old `terraform import` command you had to run once by hand and hope."*
- **`plan -generate-config-out`** — Terraform writes the HCL for you
- **`scripts/normalize.py`** — *"generated config is correct and unreadable. This makes it something a human will maintain."*
- **the gate** — the script exits 1 unless the next plan is clean

> "That last step is the one people skip. Adoption is not finished when it
> applies. It is finished when a **fresh plan says no changes**. Until then you
> have two descriptions of one estate and you do not know which is true."

---

## Topic 32 — four sharp edges  ·  ~12 min, then close

### 1. EXPLAIN

> "Four things that cost me real time and that no tutorial mentions."

### 2. RUN

```bash
bash scripts/demo-32-noise.sh
bash scripts/demo-32-dual.sh
bash scripts/demo-32-phase.sh
```

### 3. REVIEW

**Plan noise** — `"example.com"` → `"example.com."`

> "I wrote a CNAME without the trailing dot. The API stores it with one. Now
> every plan shows a diff, applying does not converge, and the pipeline is never
> green again. The fix is to write the canonical form — what the API will
> actually store."
>
> "And `ignore_changes` would be the wrong fix. It would silence this diff by no
> longer managing `content` at all, so a real repoint of this CNAME would also
> pass unnoticed. You would trade a cosmetic itch for drift-blindness on the
> field that matters most."

**Dual writers** — B overwrites A, A "heals" it back, forever, both green.

**Phase ownership** — B's ruleset **fails loudly**.

> "This one is the healthy outcome. The phase slot is taken and the API says so.
> The pathological path is what B's team does next: delete A's ruleset in the
> dashboard so their pipeline goes green — and A's next apply recreates it.
> That is the ping-pong."
>
> "The fix is Topic 10: one root owns a phase, other teams contribute
> **fragments** to it, never their own ruleset resource."

**List scale** — numbers only; needs account-level list permissions this token
lacks.

> "Five hundred items as five hundred resources versus one resource holding
> five hundred items. I measured it rather than running it, because it takes
> too long and it fails on purpose."

---

# CLOSING

> "Several of the things I showed you were failures on purpose, and they were
> the same failure wearing different clothes: **a shared thing with two owners.**
> A zone setting. A DNS record. A ruleset phase. A list of five hundred entries
> that somebody modelled as five hundred owners without deciding to."
>
> "The API tells you about some of these immediately and never tells you about
> others. The loud ones cost you an afternoon. The quiet ones run for months and
> surface during an incident, when you discover your config stopped describing
> production some time in the spring."
>
> "So: decide ownership deliberately. Make the rule executable rather than
> written down, because a policy that is not a check is a hope. And put the
> human approval where the credential is, not where the merge button is."

---

# RESET — before delivering again

```bash
bash scripts/trigger/99-reset.sh
```

Closes demo PRs and deletes their branches, returns you to `main`, disarms any
incident rule, heals the ruleset, and verifies `No changes`.

The demo scripts already reset themselves; this covers the trigger scripts and
anything interrupted mid-run.

# WHAT IS NOT LIVE — say these, do not get caught by them

| Limit | What to say |
|---|---|
| **Topic 14 does not run.** Token cannot create tunnels; HA needs two containers. | "Walking this one through rather than faking a run." |
| **Topic 27's attribution returns 403.** No token on this account reads audit logs. | "The detector works and you can see it. The audit join needs one more permission, and the script says so in one line." |
| **Topic 32's list-scale is numbers only.** Needs account-level list permissions. | "Measured rather than run — it takes too long and fails on purpose." |
| **Topic 29's discovery fails in CI.** cf-terraforming v0.28 panics on provider 5.24 on Linux; works locally. | "That is the tool, not the account. Import blocks do the actual work." |
| **CODEOWNERS resolves to one account.** GitHub requires write access to be a code owner. | "The routing mechanism is real; three separate teams are not actually being notified." |

# TROUBLESHOOTING

| Symptom | Cause and fix |
|---|---|
| `The term 'source' is not recognized` | PowerShell. Switch to Git Bash. Nothing is broken |
| `command not found: terraform` / `jq` | Same cause, or a Git Bash opened before the tools were installed |
| `unbound variable`, or 401s | You skipped `source ~/.cf-lab-env` **in this terminal** |
| `No such file or directory: scripts/...` | You are inside `scripts/`. `cd ..` |
| Pre-flight shows `1 to change` | A previous run was interrupted. Run the reset |
| A workflow sits at "Waiting" | That is the gate working. Narrate it, then approve |
| A live demo fails on stage | Say "that is a real failure, let us read it together" and read it. It lands better than the demo would have |
