# RUN THIS — the lab, end to end

Session on `zesty-beta.sxplab.com` (account `f40b69d8637a12568c6a62d218822384`).

**Every one of the ten topics runs from the GitHub Actions console**, and all
twelve menu entries have been verified green on this exact account. The
detailed walkthrough below covers Topics 27, 29 and 32 — the three built for
this session — and the full menu after it lets you take any question anywhere.

- **DO** = a click or a paste.
- **SAY** = narration. Written to be spoken, not read aloud — it's the
  argument you're making, in your own words.
- **SEE** = what appears, so you know it worked before you say the line.
- **IF ASKED** = the questions that come up.

## Order

| Time | Topic | The thread |
|---|---|---|
| 0:00 | Opening | Orientation + the safety model |
| 0:04 | **27** — drift detection | Your config stops describing production. How do you find out? |
| 0:16 | **29** — brownfield adoption | And when it was *never* in code — how do you adopt it without breaking it? |
| 0:30 | **32** — sharp edges | Here's what causes the drift in the first place |
| 0:45 | Close | The one idea underneath all three |

Running short: drop Topic 32's dual-writers demo, then its list-scale
segment. Never drop Topic 27's exit code or Topic 29's gate — those are the
two moments that land.

---

## WHICH TERMINAL — read this first

**Every command in this guide is Git Bash. None of them work in PowerShell.**

If you paste them into PowerShell you get errors like
`The term 'source' is not recognized...` — that is the only thing wrong; the
commands are fine, the shell is wrong.

**Open Git Bash in VS Code:** Terminal → New Terminal, then click the **v**
next to the `+` in the terminal panel and choose **Git Bash**. (Or press
`` Ctrl+Shift+` `` and pick Git Bash from the dropdown.)

**Or standalone:** Start menu → **Git Bash**.

You're in the right shell when the prompt shows forward slashes and ends in
`$`, like `GRIGS@machine MINGW64 /d/Work/...cf-terraform-lab (main)$`.
PowerShell shows `PS D:\...>` instead.

## Before you share your screen

**GIT BASH — run this once. Everything else assumes it has run.**
```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab" && clear
```

This loads your tokens and puts you in the repo. Open a new terminal later?
Run it again.

Then enlarge the font: Ctrl and `+`, four or five times.

**Three Chrome tabs, left to right:**

| Tab | URL |
|---|---|
| **1** | https://github.com/miroslavt-arch/cf-terraform-lab |
| **2** | https://github.com/miroslavt-arch/cf-terraform-lab/actions/workflows/demo.yml |
| **3** | https://dash.cloudflare.com/f40b69d8637a12568c6a62d218822384/zesty-beta.sxplab.com/dns/records |

## THE FULL TOPIC MENU (Actions → demo (run a topic) → Run workflow)

All twelve entries verified green on this account. ★ = covered in detail below.

| Menu entry | Topic | What the audience sees | Needs |
|---|---|---|---|
| `topic-07-module-design` | 7 | validation fires at plan time with the module's own message | nothing |
| `topic-09-singleton-ownership` | 9 | two roots flap one zone setting, both pipelines green | write token |
| `topic-10-waf-composition` | 10 | per-team fragment lint blocks a `skip` action | nothing |
| `topic-11-kill-switch` | 11 | arms then disarms the live incident rules, timed | write token |
| `topic-14-tunnel-design-walkthrough` | 14 | design walkthrough, checked against module source | nothing |
| `topic-20-stale-plan-invariant` | 20 | the `Saved plan is stale` refusal | write token |
| `topic-24-terraform-test` | 24 | 5 mocked tests, no credentials, sub-second | nothing |
| ★ `topic-27-drift-detection` | 27 | exit code 2, resource named, drift healed | write token |
| ★ `topic-29-brownfield-adoption` | 29 | 5 imported, 0 changed, gate reaches No changes | write token |
| ★ `topic-32-plan-noise` | 32 | the never-settling plan | write token |
| ★ `topic-32-dual-writers` | 32 | two roots, one record, forever-flap | write token |
| ★ `topic-32-phase-ownership` | 32 | API refuses the second claimant | write token |

**Three of these are CI-native variants**, because a runner has no local
Terraform state:

- **11** imports the live `lab-waf-composed` ruleset into an ephemeral state,
  flips `incident_mode`, flips it back, then `state rm` — never `destroy`,
  because that object belongs to `infra/envs/lab`.
- **20** owns one record end to end to reproduce the stale-plan refusal.
- **27** creates its own record rather than drifting one `envs/lab` owns.

**Topic 14 cannot run live** — the lab token can read tunnels but not create
them, and the HA demo needs two local containers. Its job prints the design
and the real module code instead of faking a run. Say that out loud if asked;
it is a better answer than a screenshot.

**Topic 20's full human-gate demo is the pipeline itself** — open a PR and
watch `tf-pr` plan, then `tf-apply` pause at the gate. The menu entry covers
the invariant underneath it.

## TWO WAYS TO RUN EVERY TOPIC

Each topic can be driven either way. Pick one and stay consistent — mixing
them mid-session is how you lose the thread.

**A — from the GitHub console (recommended when presenting).** Tab 2 →
**Run workflow** → choose the topic → **Run workflow**. The job pauses at the
`lab-apply` gate; click **Review deployments → lab-apply → Approve and
deploy**. Output renders in the job summary, with links straight into the
Cloudflare dashboard.

That approval step is worth narrating rather than apologising for: *"even my
demo runs don't get a write credential until a human approves them."*

**B — from Git Bash.** The commands under each topic. Faster, no approval
click, but the audience watches a terminal instead of a console.

The two produce the same result. Topic 27 uses a slightly different script in
CI (`ci-demo-27-drift.sh`) because a runner has no local Terraform state — it
creates its own record, drifts it, detects, heals and cleans up.

**GIT BASH — pre-flight. Self-contained, safe in a fresh terminal.**
```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
terraform -chdir=infra/envs/lab plan -input=false 2>&1 | grep -E "No changes|^Plan:"
terraform -chdir=brownfield/adopt plan -input=false -var zone_id=6fe522935f35ff5b7e1a049c1a90d11e -var zone_name=$LAB_ZONE 2>&1 | grep -E "No changes|^Plan:"
curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "https://api.cloudflare.com/client/v4/zones?name=$LAB_ZONE" | jq -r '.result[0].status'
terraform test 2>&1 | tail -1
```
Expect exactly: `No changes` · `No changes` · `active` · `5 passed, 0 failed`.

If either plan says `Plan: 0 to add, 1 to change` instead, a previous run was
interrupted — run the RESET block at the bottom, then re-check.

---

# 0:00 — OPENING (4 min)

**Tab 1** — the repo root.

**DO** — point at the directories as you name them.

**SAY**

> "Quick orientation. `infra/modules` holds the reusable building blocks.
> `infra/envs` is the root that actually applies — environments are
> directories here, not Terraform workspaces. `policy` is Open Policy Agent
> rules that run against plan output. `brownfield` is a legacy estate I built
> by hand to adopt. `demos` is deliberately broken setups. `scripts` is one
> runnable demo per topic."
>
> "Everything you'll see is real: a real Cloudflare zone, real Terraform
> state. Nothing is pre-recorded. If something fails, that's a genuine failure
> and we'll look at it together."
>
> "Three topics, and the last one is a set of failures on purpose. In
> infrastructure code the failure modes *are* the curriculum — anyone can show
> you a working `terraform apply`. The useful knowledge is what happens when
> two teams think they own the same resource, or when the API quietly rewrites
> what you asked for."

**DO** — click into `policy`, then `destroy_guard.rego`.

**SAY**

> "Before I touch a live account in front of you — the safety model, shown
> rather than promised. Every resource this lab creates is named `lab-`
> something. This file reads the JSON of a Terraform plan, finds every
> resource being destroyed, and fails the plan if any of them lacks that
> marker."
>
> "The pattern is worth stealing on its own: if your safety rule lives in a
> runbook or a wiki page, it isn't a safety rule, it's a hope. If it exits
> non-zero, it's a rule. That distinction runs through all three topics."

**DO** — breadcrumb back to the repo root.

---

# 0:04 — TOPIC 27 — DRIFT DETECTION (12 min)

## Frame it (2 min, no commands)

**SAY**

> "Start with the thing that goes wrong quietly. You apply your Terraform, it's
> green, you walk away. And then production starts drifting away from your
> code."
>
> "Someone clicks something during an incident and never comes back to codify
> it. A vendor changes a default. Another team's pipeline writes to a resource
> you thought you owned. None of that produces an error anywhere. Two months
> later you're mid-incident, you open your repo to understand production —
> and your config has stopped describing it."
>
> "So: how do you find out, and how do you find out *who*?"

## Run it

**DO — option A, GitHub console:** Tab 2 → Run workflow →
`topic-27-drift-detection` → approve at the gate.

**DO — option B, GIT BASH:**
```bash
bash scripts/demo-27-make-drift.sh
```

**SEE**
```
1/3 - making drift: PATCHing lab-hello's TTL out of band...
  drifted: ttl -> 900
2/3 - the detector: plan -detailed-exitcode (exit 2 = drift)...
exit code 2 - drift detected, exactly as the nightly workflow would see it
3/3 - rendering to JSON and attributing the author from the audit log...

    Drift report
    1 resource(s) drifted from code truth:
    - module.zone_baseline.cloudflare_dns_record.this["lab/lab-hello"]  actions: update

    Audit lookup unavailable (HTTP Error 403). The audit token needs Account
    Settings: Read in addition to Access: Audit Logs: Read. Detection above
    is unaffected.

drift healed.
```

**SAY**

> "Step one made drift — a raw API call changing a TTL, which is exactly what
> the dashboard does when you click. No Terraform involved."
>
> "Step two is the detector, and it's one flag: `terraform plan
> -detailed-exitcode`. Zero means clean, one means error, **two means drift**.
> That's the whole mechanism. Your nightly drift detector is a scheduled
> workflow that runs a plan and checks an exit code — that's it."

**DO** — point at the drifted resource line.

**SAY**

> "Step three is where it gets useful. 'Something changed' is a useless alert
> — nobody can act on it. So the plan gets rendered to JSON, and every drifted
> resource is named precisely: module, resource type, the map key. You know
> exactly which object moved and what kind of change it was."
>
> "Then it correlates those resource IDs against the Cloudflare audit log to
> name the human who did it. That's what turns a nag into a conversation with
> a specific person about a specific click."

**SAY** — the 403, deliberately and without embarrassment

> "And you can see the attribution isn't wired up on this account. The audit
> token I have is scoped to a sandbox that got torn down, so Cloudflare
> returns a 403 — and the script says so plainly, in one line, rather than
> crashing or pretending. Detection works; the naming needs one permission
> added to that token. I'd rather show you the honest gap than a screenshot of
> it working somewhere else."

**DO** — point at `drift healed.`

**SAY**

> "And it put the TTL back, so the demo is repeatable."

## The real point (don't skip this — it's the topic's payoff)

**SAY**

> "Now the thing I actually want you to leave with. **Detection is the
> consolation prize.**"
>
> "If you are detecting drift, it means humans can still write to production.
> You've accepted a permanent background rate of drift and built a machine to
> notice it. That's better than not noticing — but it isn't the goal."
>
> "The structural fix is removing the ability. In Cloudflare that's changing
> human dashboard roles to **Administrator Read Only** — people keep full
> visibility, they lose the pencil — and letting the pipeline's scoped token
> be the only credential that can write. Then drift isn't detected, it's
> impossible."
>
> "I'm not applying that here for an honest reason: this sandbox login is my
> only access, and locking myself read-only would end the session. But that's
> the answer, and detection is what you run while you're negotiating your way
> toward it."

**IF ASKED**

- *"Why `-refresh-only`?"* — It asks "what changed in the real world?" without
  proposing to fix it. That's the right question for a detector; a normal plan
  conflates drift with pending intended changes.
- *"What does nightly cost?"* — One plan per environment. It's the cheapest
  safety net in this whole session.
- *"What if drift is legitimate?"* — Then codify it. The workflow failing is
  the prompt to make that decision consciously rather than by accident.
- *"Could you auto-revert it?"* — You can, and people do. Be careful: if the
  change was a genuine emergency fix, auto-revert undoes it at 3am. Detect,
  attribute, decide.

---

# 0:16 — TOPIC 29 — BROWNFIELD ADOPTION (14 min)

## Frame it (2 min, no commands)

**SAY**

> "Topic 27 assumed your infrastructure was already in Terraform. Now the
> harder, more common case: it never was."
>
> "Almost nobody starts greenfield. You inherit an estate built by dashboard
> clicks over five years, by people who have left, and you're asked to bring
> it under Terraform without an outage."
>
> "I want to state the definition of success before we start, because it's
> more precise than people expect. Success is: you reach a plan that says
> **No changes**, and you get there without modifying a single live resource.
> State-only operations. If adoption changes anything, adoption failed — you
> didn't adopt the estate, you overwrote it with your guess about the estate."

**DO** — **Tab 3** (Cloudflare DNS). Point at the five `lab-legacy-*` records.

**SAY**

> "These five records are the legacy estate. I made them with raw API calls,
> the way a dashboard user would — deliberately messy, TTLs of 120, 240, 360,
> 480, 600, because real estates are untidy. There's a rate-limit ruleset too.
> Terraform has never heard of any of it."

## Run it

**DO — option A, GitHub console:** Tab 2 → Run workflow →
`topic-29-brownfield-adoption` → approve at the gate. (The workflow seeds the
legacy estate first, so it works from a clean zone.)

**DO — option B, GIT BASH:**
```bash
bash scripts/demo-29-adopt.sh
```

**SAY while it runs**

> "Three techniques here, for three different situations. `cf-terraforming`
> is for discovery — what's actually out there. Then a single `import` block
> with `for_each` over a CSV adopts all five records at once; that's the bulk
> path and it scales to hundreds. Then for the ruleset — a gnarly nested
> object nobody wants to hand-write — `terraform plan -generate-config-out`
> makes Terraform write the configuration itself."
>
> "Generated config is correct but ugly: null optionals, computed attributes
> echoed back, all noise. A normalizer strips it."

**SEE**
```
  # cloudflare_dns_record.legacy["lab-legacy-alpha.lab.zesty-beta.sxplab.com"] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-bravo.lab.zesty-beta.sxplab.com"] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-charlie.lab.zesty-beta.sxplab.com"] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-delta.lab.zesty-beta.sxplab.com"] will be imported
  # cloudflare_dns_record.legacy["lab-legacy-echo.lab.zesty-beta.sxplab.com"] will be imported
Plan: 5 to import, 0 to add, 0 to change, 0 to destroy.

Terraform wrote the ruleset config itself: generated_ruleset.tf
normalized generated_ruleset.tf: removed 84 noise lines
Apply complete! Resources: 6 imported, 0 added, 0 changed, 0 destroyed.

THE GATE: the next plan must be 'No changes' before anyone refactors
No changes. Your infrastructure matches the configuration.
```

## The payoff (slow down here)

**DO** — point at `0 to change, 0 to destroy`, then at `No changes`.

**SAY**

> "Read those counters out loud: zero to change, zero to destroy. Terraform
> took ownership of six live objects and altered none of them. Then the gate:
> the next plan says No changes. That sentence is the certificate."
>
> "Here's the war story, and it's why I insist on the gate. The first time I
> ran this, the plan said **five to change**. Adoption was about to silently
> rewrite five live records. The cause: the content I'd seeded contained an
> em-dash, and Cloudflare stores non-ASCII in TXT records as octal escapes.
> So my config said one thing, the API held another, and Terraform was
> helpfully about to 'fix' the API to match my config."
>
> "On five lab records, who cares. On five hundred production records where
> the differences are TTLs and comments accumulated over years — that's an
> afternoon of unexplained changes and a very bad incident review."
>
> "So the rule is: nobody refactors, renames, or restructures until the plan
> is quiet. Refactoring on top of a mismatch compounds the mismatch."

**IF ASKED**

- *"How long for a real estate?"* — Import mechanics are fast. Reaching a
  quiet plan is the work, and it's iterative: plan, read the diff, decide
  whether the config or your understanding is wrong, repeat.
- *"Can I re-run this?"* — Yes. The script clears its own state first, so the
  import blocks always have something to import. State only; live resources
  untouched.
- *"What if the plan never goes quiet?"* — Then you've found a field where the
  provider and the API disagree. That's the next topic.

---

# 0:30 — TOPIC 32 — SHARP EDGES (15 min)

**SAY** — framing

> "Topic 27 was how you notice drift. Topic 29 was how you take control of an
> estate. This topic is *why the drift happens in the first place*."
>
> "Three failures. They look unrelated. They're the same disease at different
> altitudes, and I'll name it at the end rather than spoil it now."

## 32a — plan noise (5 min)

**DO — option A, GitHub console:** Tab 2 → Run workflow →
`topic-32-plan-noise` → approve at the gate.

**DO — option B, GIT BASH:**
```bash
bash scripts/demo-32-noise.sh
```

**SEE**
```
applied. API actually stored: example.com
      ~ content     = "example.com" -> "example.com."
Plan: 0 to add, 1 to change, 0 to destroy.
    after apply #1: Plan: 0 to add, 1 to change, 0 to destroy.
    after apply #2: Plan: 0 to add, 1 to change, 0 to destroy.
plan is QUIET. Code truth now equals API truth, byte for byte.
```

**SAY**

> "I wrote a CNAME target the way every DNS textbook on earth says to write
> one: fully qualified, with the trailing dot. `example.com.` Cloudflare
> stores it without the dot."
>
> "So every plan compares my config against the API and proposes a change.
> Watch what happens when I do the obvious thing and apply it — still dirty.
> Apply again — still dirty. It never converges. That pipeline is never green
> again, and every plan any engineer runs from now on has a meaningless diff
> in it."
>
> "The real damage isn't cosmetic. You've trained your team to see a non-empty
> plan and think 'that's just the usual noise'. You've broken the signal —
> and remember what we did twenty minutes ago: drift detection is *entirely*
> built on a plan being trustworthy. Noise here disables Topic 27 completely."

**SAY** — the wrong fix everyone reaches for

> "The tempting fix is `ignore_changes` on that attribute. It's worse than the
> problem. `ignore_changes` doesn't silence the false diff — it tells Terraform
> to stop managing that attribute entirely. So when someone genuinely repoints
> this CNAME, out of band or in a bad pull request, your plan says nothing.
> You've traded a cosmetic annoyance for blindness on the single most
> important field on that record."
>
> "The right fix is boring: write the value in the form the API stores. That's
> the last line — the plan goes quiet permanently."

**SAY** — the honesty note; it builds credibility

> "One thing worth telling you. I originally built this demo around letter
> case, because that used to be a classic Cloudflare gotcha. Provider version
> 5 normalizes case now, so it doesn't reproduce — I found that out by running
> it, not by reading about it. Same for TXT quote-wrapping. The trailing dot
> is the one that still bites. Verify your own gotchas against your own
> provider version, because they get fixed and you'll end up telling people a
> story that isn't true anymore."

## 32b — dual writers (4 min)

**DO — option A, GitHub console:** Tab 2 → Run workflow →
`topic-32-dual-writers` → approve at the gate.

**DO — option B, GIT BASH:**
```bash
bash scripts/demo-32-dual.sh
```

**SEE**
```
Root A creates lab-dual   -> live content: "owned-by-A"
Root B imports + applies  -> live content: "owned-by-B"
A's nightly plan:  ~ content = "owned-by-B" -> "owned-by-A"
A's auto-apply            -> live content: "owned-by-A"
```

**SAY**

> "Two Terraform roots, one DNS record. Root A created it. Root B *imported*
> it — and importing is such an innocent-looking action. Somebody onboarding a
> new module runs an import to 'bring the record under management'."
>
> "Now watch. B applies its truth. A's next plan reports drift it cannot
> explain, and A's auto-apply heals it. Back and forth, forever, both
> pipelines green, both teams able to prove they configured it correctly."
>
> "Nobody errors. Ever. That's what makes this expensive — no alert to route,
> no red build to investigate. And tie it back to Topic 27: this is *exactly*
> the drift you'd detect nightly, and when you check the audit log the actor
> is the other team's pipeline token. Drift attributed to a service credential
> rather than a human almost always means two writers, not a rogue admin."

## 32c — phase ownership (4 min)

**DO — option A, GitHub console:** Tab 2 → Run workflow →
`topic-32-phase-ownership` → approve at the gate.

**DO — option B, GIT BASH:**
```bash
bash scripts/demo-32-phase.sh
```

**SEE**
```
A owns the phase. A's pipeline is green.
Root B claims the SAME phase...
    Error: failed to make http request
^ B FAILS. The phase slot is taken, and this loud error is the HEALTHY outcome.
```

**SAY**

> "A zone gets one entrypoint ruleset per phase. Two roots both declaring one
> is a fight, and here the API referees. Root A applies and owns it. Root B's
> apply fails."
>
> "I want to argue this loud failure is the *best* outcome of the three. The
> API refused. Nobody's config silently won. Compare it to the dual-writer
> case, where nothing errors for months."
>
> "The pathological part is what happens next, and it's social rather than
> technical. B's pipeline is red, B's team is blocked, and somebody fixes it —
> by deleting A's ruleset in the dashboard, because that unblocks them in
> thirty seconds. Now B is green, and A's next apply recreates its own
> ruleset, breaking B again. That's the ping-pong: a people failure that a
> loud error message triggered."

## 32d — list scale (2 min, numbers only — do not run)

**SAY**

> "One more I measured but won't run, because it takes too long and it fails
> on purpose. Same five hundred IP addresses, modelled two ways: one list
> resource holding a collection, versus five hundred individual list-item
> resources."
>
> "The collection applies in fifty-one seconds; a no-op plan is thirty-one.
> The per-item version takes forty-three seconds for a *no-op plan*, and the
> apply **did not complete at all** — Cloudflare rate-limited the individual
> POSTs, Terraform aborted partway and left four hundred and ninety-six of
> five hundred entries, matching neither the code nor the previous state."
>
> "So the headline isn't 'slower', it's 'does not work'. And the number that
> lands hardest: deleting that whole list through one API call took two
> seconds. Terraform had to issue five hundred deletes because *you* told it
> these were five hundred independent resources."

## The synthesis

**SAY**

> "Here's the disease. The flapping record, the phase fight, the list — every
> one is a shared thing with two owners, or an ownership decision made without
> anyone noticing they were making it."
>
> "And the lesson underneath: the API referees loudly sometimes and not at all
> other times. The loud ones you fix in an afternoon, because your pipeline is
> red and you can't ignore it. The quiet ones run for months. So the quiet
> failures are the expensive ones, and the only defence is deciding ownership
> deliberately — before the API decides for you by accident."

---

# 0:45 — CLOSE

**SAY**

> "Three topics, one idea underneath."
>
> "We started with drift: production stops matching your code, and the
> detector is one exit code — but detection is the consolation prize. The real
> fix is taking the pencil away from humans."
>
> "Then adoption: when infrastructure was never in code at all, you prove you
> changed nothing before you touch anything. Zero changed, zero destroyed, and
> the plan goes quiet. That sentence is the certificate."
>
> "Then the sharp edges — and every one turned out to be a shared thing with
> two owners. Which is where the drift in topic one came from in the first
> place."
>
> "And the thread through all of it: make the rule executable. A destroy guard
> that exits non-zero. A gate that reaches 'No changes'. An exit code that
> means drift. Written-down rules get skipped at three in the morning.
> Executable ones don't."

---

# RESET — before delivering again

**GIT BASH**
```bash
source ~/.cf-lab-env && cd "D:/Work/Claude/Shared Subnet Diagram/cf-terraform-lab"
terraform -chdir=infra/envs/lab apply -auto-approve -input=false >/dev/null
echo "reset: $(terraform -chdir=infra/envs/lab plan -input=false | grep -cE 'No changes') (1 = clean)"
```

Every demo resets itself as its last act:
- **27** heals the drift it made
- **29** clears its own state at start-up, so it re-imports every time
- **32 noise / dual / phase** destroy what they create and delete their state

The only thing that can be left behind is Topic 27's TTL change if you
interrupt it mid-run — the `apply` above fixes that.

---

# OPTIONAL — make Topic 27's attribution work (3 min)

Detection works today. The audit-log *naming* needs a token on the current
account. If you want the full topic:

1. Open this pre-configured link (permissions already selected):
   https://dash.cloudflare.com/profile/api-tokens?name=lab-audit-ro-v2&accountId=f40b69d8637a12568c6a62d218822384&permissionGroupKeys=%5B%7B%22key%22%3A%22access_audit_log%22%2C%22type%22%3A%22read%22%7D%2C%7B%22key%22%3A%22account_settings%22%2C%22type%22%3A%22read%22%7D%5D
2. Confirm **Account Resources → Include →** the current account, then
   **Continue to summary → Create Token**, and copy the value.
3. **GIT BASH** — paste the token into the env file:
   ```bash
   notepad "$(cygpath -w ~/.cf-lab-env)"
   ```
   Replace the value of `CLOUDFLARE_AUDIT_TOKEN`, save, close.
4. **GIT BASH** — verify:
   ```bash
   source ~/.cf-lab-env
   curl -s -H "Authorization: Bearer $CLOUDFLARE_AUDIT_TOKEN" "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/logs/audit?since=2026-08-27T00:00:00Z&limit=1" | jq -r 'if .success then "AUDIT OK" else .errors[0].message end'
   ```
   `AUDIT OK` means the next `demo-27-make-drift.sh` will print the actor
   table instead of the 403 line.

If you skip this, the demo still works — the script explains the gap in one
line and the narration above already handles it.

---

# TROUBLESHOOTING (things that actually went wrong)

| Symptom | Cause and fix |
|---|---|
| `The term 'source' is not recognized` | **You are in PowerShell.** Switch the terminal to Git Bash and re-run. Nothing is broken |
| `command not found: terraform` / `jq` | Same cause — PowerShell, or a Git Bash opened before the tools were installed. Open a fresh Git Bash |
| `CLOUDFLARE_API_TOKEN: unbound` or 401s | You skipped the setup line. Run `source ~/.cf-lab-env` in this terminal |
| `No such file or directory: scripts/...` | Wrong directory. Run the setup line, which `cd`s into the repo |
| Pre-flight shows `Plan: 0 to add, 1 to change` | A previous run was interrupted. Run the RESET block |
| Topic 29 errors `resource already managed` | Stale adopt state. The script clears it automatically now; otherwise `rm -f brownfield/adopt/terraform.tfstate*` |
| Topic 27 says "drift detected" then "No drift" | Fixed — refresh-only plans record drift under `resource_drift`, not `resource_changes` |
| Topic 27 shows the 403 audit line | Expected on this account. See the OPTIONAL section above, or narrate it as the honest gap |
| Topic 32 noise shows no diff | You're on a provider that normalizes the trailing dot. Re-verify before promising it |
| Account-level 403s | The apply token's account scope is from the previous sandbox. Zone operations are unaffected; only `demo-32-list.sh` and audit attribution need it |
